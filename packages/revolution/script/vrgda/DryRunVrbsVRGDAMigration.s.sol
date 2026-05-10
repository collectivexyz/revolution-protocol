// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import {console2} from "forge-std/console2.sol";

import {ICultureIndex} from "../../src/interfaces/ICultureIndex.sol";
import {IRevolutionTokenSale} from "../../src/interfaces/IRevolutionTokenSale.sol";

import {
    VrbsAddresses,
    VrbsMigrationHelpers,
    IAuctionHouseRead,
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
    struct ProposalArtifacts {
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
        address protocolFeeRecipient;
        uint256 ownerLiquidBefore;
        uint256 grantsLiquidBefore;
        uint256 creatorLiquidBefore;
        uint256 firstCreatorPointsBefore;
        uint256 protocolSupplyBefore;
        uint256 referralRewardsBefore;
        uint256 protocolFeeRecipientRewardsBefore;
        uint256 refundReceiverWethBefore;
        uint256 soldBefore;
    }

    function run() external {
        _requireBase();
        _requireVrbsContractsHaveCode();
        _requireAuctionPausedAndSettled();
        _requireTokenCanCutOver();

        address protocolFeeRecipient = _readProtocolFeeRecipient();
        uint256 maxLaunchPriceWei = _readMaxLaunchPriceWei();

        IRevolutionTokenSale.TokenSaleParams memory params = _readSaleParams();
        _validateSaleParams(params);
        _requireSaleStartSentinel(params);

        ProposalArtifacts memory artifacts = _readProposalArtifacts();

        (bool acceptCultureOwnership, uint256 launchPriceWei) = _preflightVrbsVRGDAProposal(
            artifacts.tokenImpl,
            artifacts.cultureIndexImpl,
            artifacts.tokenSaleProxy,
            artifacts.tokenSaleImpl,
            params,
            protocolFeeRecipient,
            maxLaunchPriceWei
        );

        (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas) = _buildCommunityActions(
            artifacts.tokenImpl, artifacts.cultureIndexImpl, artifacts.tokenSaleProxy, acceptCultureOwnership
        );

        _executeAsExecutor(targets, values, signatures, calldatas);
        _assertPostCutover(artifacts, params, protocolFeeRecipient, maxLaunchPriceWei);
        _buyFirstToken(artifacts.tokenSaleProxy, protocolFeeRecipient);

        console2.log("Vrbs VRGDA fork dry-run passed");
        console2.log("TokenSale proxy");
        console2.logAddress(artifacts.tokenSaleProxy);
        console2.log("Launch price", launchPriceWei);
        console2.log("Max launch price", maxLaunchPriceWei);
        console2.log("Current price", IRevolutionTokenSaleRead(artifacts.tokenSaleProxy).getCurrentPrice());
    }

    function _readProposalArtifacts() internal view returns (ProposalArtifacts memory artifacts) {
        artifacts.tokenImpl = vm.envAddress("VRGDA_NEW_TOKEN_IMPL");
        artifacts.cultureIndexImpl = vm.envAddress("VRGDA_NEW_CULTURE_INDEX_IMPL");
        artifacts.tokenSaleImpl = vm.envAddress("TOKEN_SALE_IMPL");
        artifacts.tokenSaleProxy = vm.envAddress("TOKEN_SALE_PROXY");
    }

    function _executeAsExecutor(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) internal {
        for (uint256 i; i < targets.length; ++i) {
            require(bytes(signatures[i]).length == 0, "dry-run only supports raw calldata");
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

    function _assertPostCutover(
        ProposalArtifacts memory artifacts,
        IRevolutionTokenSale.TokenSaleParams memory params,
        address expectedProtocolFeeRecipient,
        uint256 maxLaunchPriceWei
    ) internal view {
        IRevolutionTokenSaleRead sale = IRevolutionTokenSaleRead(artifacts.tokenSaleProxy);

        require(_implementationOf(VrbsAddresses.TOKEN) == artifacts.tokenImpl, "token impl mismatch");
        require(_implementationOf(VrbsAddresses.CULTURE_INDEX) == artifacts.cultureIndexImpl, "culture impl mismatch");
        require(_implementationOf(artifacts.tokenSaleProxy) == artifacts.tokenSaleImpl, "token sale impl mismatch");
        require(IRevolutionTokenRead(VrbsAddresses.TOKEN).minter() == artifacts.tokenSaleProxy, "minter mismatch");
        require(
            ICultureIndexRead(VrbsAddresses.CULTURE_INDEX).owner() == VrbsAddresses.EXECUTOR, "culture owner mismatch"
        );
        require(!sale.paused(), "sale is paused");
        require(sale.owner() == VrbsAddresses.EXECUTOR, "sale owner mismatch");
        require(address(sale.revolutionToken()) == VrbsAddresses.TOKEN, "sale token mismatch");
        require(sale.revolutionPointsEmitter() == VrbsAddresses.POINTS_EMITTER, "sale emitter mismatch");
        require(sale.WETH() == IAuctionHouseRead(VrbsAddresses.AUCTION).WETH(), "sale WETH mismatch");
        require(sale.protocolFeeRecipient() == expectedProtocolFeeRecipient, "sale protocol fee recipient mismatch");
        _assertSaleParams(artifacts.tokenSaleProxy, params, false);
        _assertLaunchPrice(artifacts.tokenSaleProxy, maxLaunchPriceWei);
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

    function _buyFirstToken(address tokenSale, address protocolFeeRecipient) internal {
        IRevolutionTokenSaleRead saleRead = IRevolutionTokenSaleRead(tokenSale);
        IRevolutionTokenSale sale = IRevolutionTokenSale(tokenSale);

        (uint256[] memory pieceIds, uint256 price) = saleRead.getAvailablePieces(1);
        require(pieceIds.length == 1, "no available piece");
        require(price > 0, "price is zero");
        require(ICultureIndex(VrbsAddresses.CULTURE_INDEX).topVotedPieceMeetsQuorum(), "top piece lacks quorum");

        ICultureIndex.ArtPiece memory artPiece = ICultureIndex(VrbsAddresses.CULTURE_INDEX).getPieceById(pieceIds[0]);
        require(artPiece.creators.length > 0, "piece has no creators");

        PurchaseSnapshot memory beforePurchase =
            _snapshotBeforePurchase(tokenSale, artPiece.creators[0].creator, protocolFeeRecipient);

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
        require(
            IProtocolRewardsRead(VrbsAddresses.PROTOCOL_REWARDS).balanceOf(beforePurchase.protocolFeeRecipient)
                > beforePurchase.protocolFeeRecipientRewardsBefore,
            "protocol fee recipient rewards did not increase"
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

    function _snapshotBeforePurchase(address tokenSale, address firstCreator, address protocolFeeRecipient)
        internal
        returns (PurchaseSnapshot memory snapshot)
    {
        IRevolutionTokenSaleRead sale = IRevolutionTokenSaleRead(tokenSale);

        snapshot.weth = sale.WETH();
        snapshot.grantsAddress = sale.grantsAddress();
        snapshot.firstCreator = firstCreator;
        snapshot.referral = address(0xBEEF);
        snapshot.refundReceiver = address(new RejectETHReceiver());
        snapshot.protocolFeeRecipient = protocolFeeRecipient;
        snapshot.ownerLiquidBefore = _liquidBalance(VrbsAddresses.EXECUTOR, snapshot.weth);
        snapshot.grantsLiquidBefore = _liquidBalance(snapshot.grantsAddress, snapshot.weth);
        snapshot.creatorLiquidBefore = _liquidBalance(firstCreator, snapshot.weth);
        snapshot.firstCreatorPointsBefore =
            IRevolutionPointsEmitterRead(VrbsAddresses.POINTS_EMITTER).balanceOf(firstCreator);
        snapshot.protocolSupplyBefore = IProtocolRewardsRead(VrbsAddresses.PROTOCOL_REWARDS).totalRewardsSupply();
        snapshot.referralRewardsBefore =
            IProtocolRewardsRead(VrbsAddresses.PROTOCOL_REWARDS).balanceOf(snapshot.referral);
        snapshot.protocolFeeRecipientRewardsBefore =
            IProtocolRewardsRead(VrbsAddresses.PROTOCOL_REWARDS).balanceOf(protocolFeeRecipient);
        snapshot.refundReceiverWethBefore = IERC20BalanceRead(snapshot.weth).balanceOf(snapshot.refundReceiver);
        snapshot.soldBefore = sale.soldByVRGDA();
    }

    function _liquidBalance(address account, address weth) internal view returns (uint256) {
        return account.balance + IERC20BalanceRead(weth).balanceOf(account);
    }
}
