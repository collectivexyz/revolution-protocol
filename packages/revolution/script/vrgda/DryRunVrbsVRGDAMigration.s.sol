// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { console2 } from "forge-std/console2.sol";

import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";

import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { RevolutionToken } from "../../src/RevolutionToken.sol";
import { RevolutionTokenSale } from "../../src/RevolutionTokenSale.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { IRevolutionTokenSale } from "../../src/interfaces/IRevolutionTokenSale.sol";

import {
    VrbsAddresses,
    VrbsMigrationHelpers,
    IAuctionHouseRead,
    IOwnableRead,
    IOwnable2StepRead,
    ICultureIndexRead,
    IRevolutionPointsEmitterRead,
    IRevolutionTokenRead,
    IRevolutionTokenSaleRead
} from "./VrbsMigrationHelpers.sol";

interface IProtocolRewardsRead {
    function totalRewardsSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC20BalanceRead {
    function balanceOf(address account) external view returns (uint256);
}

interface IRewardSplitsRead {
    function computeTotalReward(uint256 paymentAmountWei) external pure returns (uint256);
}

contract RejectETHReceiver {
    receive() external payable {
        revert("reject ETH");
    }
}

/// @notice Base fork rehearsal for the full Vrbs VRGDA cutover plus first buy-now purchase.
/// @dev Run against a fork RPC. This script intentionally does not broadcast.
contract DryRunVrbsVRGDAMigration is VrbsMigrationHelpers {
    struct DryRunArtifacts {
        address manager;
        address oldTokenImpl;
        address oldCultureIndexImpl;
        address oldAuctionImpl;
        address tokenImpl;
        address cultureIndexImpl;
        address tokenSaleImpl;
        address tokenSaleProxy;
    }

    struct PurchaseSnapshot {
        address weth;
        address grantsAddress;
        address firstCreator;
        address referral;
        address refundReceiver;
        uint256 ownerLiquidBefore;
        uint256 grantsLiquidBefore;
        uint256 creatorLiquidBefore;
        uint256 firstCreatorPointsBefore;
        uint256 protocolSupplyBefore;
        uint256 referralRewardsBefore;
        uint256 refundReceiverWethBefore;
        uint256 soldBefore;
    }

    function run() external {
        _requireBase();
        _requireVrbsContractsHaveCode();
        _requireAuctionPausedAndSettled();
        _requireTokenCanCutOver();

        address protocolFeeRecipient = vm.envAddress("PROTOCOL_FEE_RECIPIENT");
        require(protocolFeeRecipient != address(0), "PROTOCOL_FEE_RECIPIENT is zero");

        IRevolutionTokenSale.TokenSaleParams memory params = _readSaleParams();
        _validateSaleParams(params);

        DryRunArtifacts memory artifacts = _deployArtifacts(protocolFeeRecipient, params);
        _registerUpgradesOnFork(artifacts);
        _prepareCultureOwnershipOnFork();

        bool acceptCultureOwnership =
            _preflightVrbsVRGDAProposal(artifacts.tokenImpl, artifacts.cultureIndexImpl, artifacts.tokenSaleProxy);

        (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas) = _buildCommunityActions(
            artifacts.tokenImpl, artifacts.cultureIndexImpl, artifacts.tokenSaleProxy, acceptCultureOwnership
        );
        signatures;

        _executeAsExecutor(targets, values, calldatas);
        _assertPostCutover(artifacts);
        _buyFirstToken(artifacts.tokenSaleProxy);

        console2.log("Vrbs VRGDA fork dry-run passed");
        console2.log("TokenSale proxy");
        console2.logAddress(artifacts.tokenSaleProxy);
        console2.log("Current price", IRevolutionTokenSaleRead(artifacts.tokenSaleProxy).getCurrentPrice());
    }

    function _deployArtifacts(address protocolFeeRecipient, IRevolutionTokenSale.TokenSaleParams memory params)
        internal
        returns (DryRunArtifacts memory artifacts)
    {
        IUpgradeManager manager = _manager();
        address weth = IAuctionHouseRead(VrbsAddresses.AUCTION).WETH();
        _requireCode(weth, "auction WETH");

        artifacts.manager = address(manager);
        artifacts.oldTokenImpl = _implementationOf(VrbsAddresses.TOKEN);
        artifacts.oldCultureIndexImpl = _implementationOf(VrbsAddresses.CULTURE_INDEX);
        artifacts.oldAuctionImpl = _implementationOf(VrbsAddresses.AUCTION);
        artifacts.tokenImpl = address(new RevolutionToken(address(manager)));
        artifacts.cultureIndexImpl = address(new CultureIndex(address(manager)));
        artifacts.tokenSaleImpl =
            address(new RevolutionTokenSale(address(manager), VrbsAddresses.PROTOCOL_REWARDS, protocolFeeRecipient));

        bytes memory init = abi.encodeWithSelector(
            RevolutionTokenSale.initialize.selector,
            VrbsAddresses.TOKEN,
            VrbsAddresses.POINTS_EMITTER,
            VrbsAddresses.EXECUTOR,
            weth,
            params
        );
        artifacts.tokenSaleProxy = address(new ERC1967Proxy(artifacts.tokenSaleImpl, init));

        _assertSaleConfig(artifacts.tokenSaleProxy, VrbsAddresses.EXECUTOR, weth, params);
        _requirePointsEmitterSafe(artifacts.tokenSaleProxy);
    }

    function _registerUpgradesOnFork(DryRunArtifacts memory artifacts) internal {
        IUpgradeManager manager = IUpgradeManager(artifacts.manager);
        address managerOwner = IOwnableRead(artifacts.manager).owner();
        require(managerOwner != address(0), "manager owner is zero");

        vm.startPrank(managerOwner);
        if (!manager.isRegisteredUpgrade(artifacts.oldTokenImpl, artifacts.tokenImpl)) {
            manager.registerUpgrade(artifacts.oldTokenImpl, artifacts.tokenImpl);
        }
        if (!manager.isRegisteredUpgrade(artifacts.oldCultureIndexImpl, artifacts.cultureIndexImpl)) {
            manager.registerUpgrade(artifacts.oldCultureIndexImpl, artifacts.cultureIndexImpl);
        }
        vm.stopPrank();

        require(
            !manager.isRegisteredUpgrade(artifacts.oldAuctionImpl, artifacts.tokenSaleImpl),
            "auction => token sale registered"
        );
    }

    function _prepareCultureOwnershipOnFork() internal {
        ICultureIndexRead cultureIndex = ICultureIndexRead(VrbsAddresses.CULTURE_INDEX);
        if (cultureIndex.owner() == VrbsAddresses.EXECUTOR) return;

        if (cultureIndex.pendingOwner() != VrbsAddresses.EXECUTOR) {
            address currentOwner = cultureIndex.owner();
            require(currentOwner != address(0), "culture owner is zero");
            vm.prank(currentOwner);
            IOwnable2StepRead(VrbsAddresses.CULTURE_INDEX).transferOwnership(VrbsAddresses.EXECUTOR);
        }

        require(cultureIndex.pendingOwner() == VrbsAddresses.EXECUTOR, "culture ownership not pending executor");
    }

    function _executeAsExecutor(address[] memory targets, uint256[] memory values, bytes[] memory calldatas) internal {
        for (uint256 i; i < targets.length; ++i) {
            vm.prank(VrbsAddresses.EXECUTOR);
            (bool ok, bytes memory result) = targets[i].call{value: values[i]}(calldatas[i]);
            if (!ok) {
                if (result.length > 0) {
                    assembly {
                        revert(add(result, 0x20), mload(result))
                    }
                }
                revert("dry-run action failed");
            }
        }
    }

    function _assertPostCutover(DryRunArtifacts memory artifacts) internal view {
        IRevolutionTokenSaleRead sale = IRevolutionTokenSaleRead(artifacts.tokenSaleProxy);

        require(_implementationOf(VrbsAddresses.TOKEN) == artifacts.tokenImpl, "token impl mismatch");
        require(_implementationOf(VrbsAddresses.CULTURE_INDEX) == artifacts.cultureIndexImpl, "culture impl mismatch");
        require(IRevolutionTokenRead(VrbsAddresses.TOKEN).minter() == artifacts.tokenSaleProxy, "minter mismatch");
        require(
            ICultureIndexRead(VrbsAddresses.CULTURE_INDEX).owner() == VrbsAddresses.EXECUTOR, "culture owner mismatch"
        );
        require(!sale.paused(), "sale is paused");
        require(sale.owner() == VrbsAddresses.EXECUTOR, "sale owner mismatch");
        require(address(sale.revolutionToken()) == VrbsAddresses.TOKEN, "sale token mismatch");
        require(sale.revolutionPointsEmitter() == VrbsAddresses.POINTS_EMITTER, "sale emitter mismatch");
        require(sale.WETH() == IAuctionHouseRead(VrbsAddresses.AUCTION).WETH(), "sale WETH mismatch");
        require(sale.saleStartTime() != type(uint256).max, "sale start sentinel not bound");
        require(sale.saleStartTime() == block.timestamp, "sale start not bound to execution block");
        require(
            ICultureIndexRead(VrbsAddresses.CULTURE_INDEX).legacyQuorumExcludedTokenHolder() == VrbsAddresses.AUCTION,
            "legacy quorum holder mismatch"
        );
        require(
            ICultureIndexRead(VrbsAddresses.CULTURE_INDEX).legacyQuorumCutoffBlock() == block.number,
            "legacy quorum cutoff mismatch"
        );
    }

    function _buyFirstToken(address tokenSale) internal {
        IRevolutionTokenSaleRead saleRead = IRevolutionTokenSaleRead(tokenSale);
        IRevolutionTokenSale sale = IRevolutionTokenSale(tokenSale);

        (uint256[] memory pieceIds, uint256 price) = saleRead.getAvailablePieces(1);
        require(pieceIds.length == 1, "no available piece");
        require(price > 0, "price is zero");
        require(ICultureIndex(VrbsAddresses.CULTURE_INDEX).topVotedPieceMeetsQuorum(), "top piece lacks quorum");

        ICultureIndex.ArtPiece memory artPiece = ICultureIndex(VrbsAddresses.CULTURE_INDEX).getPieceById(pieceIds[0]);
        require(artPiece.creators.length > 0, "piece has no creators");

        PurchaseSnapshot memory beforePurchase = _snapshotBeforePurchase(tokenSale, artPiece.creators[0].creator);

        uint256 protocolReward = IRewardSplitsRead(tokenSale).computeTotalReward(price);
        require(protocolReward > 0, "price too low for protocol reward dry-run");

        uint256 valueRemaining = price - protocolReward;
        uint256 grantsShare = (valueRemaining * saleRead.grantsRateBps()) / 10_000;
        uint256 ownerShare = valueRemaining - ((valueRemaining * saleRead.creatorRateBps()) / 10_000) - grantsShare;
        uint256 creatorDirectShare =
            (valueRemaining * saleRead.entropyRateBps() * saleRead.creatorRateBps() * artPiece.creators[0].bps) / 10_000
                / 10_000 / 10_000;
        uint256 creatorGovernanceShare = ((valueRemaining * saleRead.creatorRateBps()) / 10_000)
            - ((valueRemaining * saleRead.entropyRateBps() * saleRead.creatorRateBps()) / 10_000 / 10_000);

        require(creatorGovernanceShare > 0, "creator governance purchase is zero");

        vm.deal(beforePurchase.refundReceiver, price + 1 wei);
        vm.prank(beforePurchase.refundReceiver);
        (uint256 tokenId, uint256 paid) =
            sale.buyNow{value: price + 1 wei}(pieceIds[0], address(0xC0FFEE), price, beforePurchase.referral);

        require(paid == price, "paid price mismatch");
        require(IRevolutionTokenRead(VrbsAddresses.TOKEN).ownerOf(tokenId) == address(0xC0FFEE), "recipient mismatch");
        require(saleRead.soldByVRGDA() == beforePurchase.soldBefore + 1, "sold count did not increment");
        require(
            IERC20BalanceRead(beforePurchase.weth).balanceOf(beforePurchase.refundReceiver)
                == beforePurchase.refundReceiverWethBefore + 1 wei,
            "refund WETH fallback failed"
        );
        require(
            IProtocolRewardsRead(VrbsAddresses.PROTOCOL_REWARDS).totalRewardsSupply()
                > beforePurchase.protocolSupplyBefore,
            "protocol rewards did not increase"
        );
        require(
            IProtocolRewardsRead(VrbsAddresses.PROTOCOL_REWARDS).balanceOf(beforePurchase.referral)
                > beforePurchase.referralRewardsBefore,
            "referral protocol rewards did not increase"
        );
        if (ownerShare > 0) {
            require(
                _liquidBalance(VrbsAddresses.EXECUTOR, beforePurchase.weth) > beforePurchase.ownerLiquidBefore,
                "owner payout did not increase"
            );
        }
        if (grantsShare > 0) {
            require(
                _liquidBalance(beforePurchase.grantsAddress, beforePurchase.weth) > beforePurchase.grantsLiquidBefore,
                "grants payout did not increase"
            );
        }
        if (creatorDirectShare > 0) {
            require(
                _liquidBalance(beforePurchase.firstCreator, beforePurchase.weth) > beforePurchase.creatorLiquidBefore,
                "creator direct payout did not increase"
            );
        }
        require(
            IRevolutionPointsEmitterRead(VrbsAddresses.POINTS_EMITTER).balanceOf(beforePurchase.firstCreator)
                > beforePurchase.firstCreatorPointsBefore,
            "creator points did not increase"
        );
    }

    function _snapshotBeforePurchase(address tokenSale, address firstCreator)
        internal
        returns (PurchaseSnapshot memory snapshot)
    {
        IRevolutionTokenSaleRead sale = IRevolutionTokenSaleRead(tokenSale);

        snapshot.weth = sale.WETH();
        snapshot.grantsAddress = sale.grantsAddress();
        snapshot.firstCreator = firstCreator;
        snapshot.referral = address(0xBEEF);
        snapshot.refundReceiver = address(new RejectETHReceiver());
        snapshot.ownerLiquidBefore = _liquidBalance(VrbsAddresses.EXECUTOR, snapshot.weth);
        snapshot.grantsLiquidBefore = _liquidBalance(snapshot.grantsAddress, snapshot.weth);
        snapshot.creatorLiquidBefore = _liquidBalance(firstCreator, snapshot.weth);
        snapshot.firstCreatorPointsBefore =
            IRevolutionPointsEmitterRead(VrbsAddresses.POINTS_EMITTER).balanceOf(firstCreator);
        snapshot.protocolSupplyBefore = IProtocolRewardsRead(VrbsAddresses.PROTOCOL_REWARDS).totalRewardsSupply();
        snapshot.referralRewardsBefore =
            IProtocolRewardsRead(VrbsAddresses.PROTOCOL_REWARDS).balanceOf(snapshot.referral);
        snapshot.refundReceiverWethBefore = IERC20BalanceRead(snapshot.weth).balanceOf(snapshot.refundReceiver);
        snapshot.soldBefore = sale.soldByVRGDA();
    }

    function _liquidBalance(address account, address weth) internal view returns (uint256) {
        return account.balance + IERC20BalanceRead(weth).balanceOf(account);
    }
}
