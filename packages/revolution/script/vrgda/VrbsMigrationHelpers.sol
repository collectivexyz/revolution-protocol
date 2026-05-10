// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { Script } from "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { IRevolutionToken } from "../../src/interfaces/IRevolutionToken.sol";
import { IRevolutionTokenSale } from "../../src/interfaces/IRevolutionTokenSale.sol";

/// @notice Live Vrbs community addresses on Base.
library VrbsAddresses {
    uint256 internal constant BASE_CHAIN_ID = 8453;

    address internal constant TOKEN = 0x9ea7fd1B8823a271BEC99b205B6c0C56d7C3eAe9;
    address internal constant DESCRIPTOR = 0x2F35C218461193DD289cC8D9951E1d3e7D0F228c;
    address internal constant AUCTION = 0x4153b0310354B189E18797D5d7Dfda2C924bdC3D;
    address internal constant EXECUTOR = 0x9bcb4E5978FFAFfDAbE72C2962957479F0E3b598;
    address internal constant DAO = 0x613B7dDCA4B05355B3541F8c018B374987549E79;
    address internal constant CULTURE_INDEX = 0x5DA551c18109B58831abE8A5b9eDc5f9a8e4887c;
    address internal constant POINTS = 0xDFb1cd29c4aB6985F1614e0d65782cd136115b6A;
    address internal constant POINTS_EMITTER = 0xEA0aF4b42Cb72C58A11E63a2175B99b2c809Fc28;
    address internal constant MAX_HEAP = 0x867076c5b2B2A6f265283D436faD77565B264C20;
    address internal constant VOTING_POWER = 0x059C233acFCAFd845ae84B84245aE3f6e332306b;
    address internal constant VRGDA = 0xD3079014C14322Cd868a74Cfb8d11F81E90CAC40;
}

interface IOwnableRead {
    function owner() external view returns (address);
}

interface IOwnable2StepRead is IOwnableRead {
    function pendingOwner() external view returns (address);
    function acceptOwnership() external;
}

interface IPausableRead {
    function paused() external view returns (bool);
}

interface IUUPSProxy {
    function upgradeTo(address newImpl) external;
}

interface IAuctionHouseRead is IOwnableRead, IPausableRead {
    function WETH() external view returns (address);
    function manager() external view returns (IUpgradeManager);
    function creatorRateBps() external view returns (uint256);
    function minCreatorRateBps() external view returns (uint256);
    function entropyRateBps() external view returns (uint256);
    function grantsRateBps() external view returns (uint256);
    function grantsAddress() external view returns (address);

    function auction()
        external
        view
        returns (
            uint256 tokenId,
            uint256 amount,
            uint256 startTime,
            uint256 endTime,
            address bidder,
            address referral,
            bool settled
        );
}

interface IRevolutionTokenRead is IRevolutionToken, IOwnableRead {
    function isMinterLocked() external view returns (bool);
}

interface ICultureIndexRead is IOwnable2StepRead {
    function legacyQuorumExcludedTokenHolder() external view returns (address);
    function legacyQuorumCutoffBlock() external view returns (uint256);
}

interface IRevolutionTokenSaleRead is IRevolutionTokenSale, IPausableRead, IOwnableRead {
    function revolutionToken() external view returns (IRevolutionToken);
    function revolutionPointsEmitter() external view returns (address);
    function minPriceWei() external view returns (uint256);
    function creatorRateBps() external view returns (uint256);
    function minCreatorRateBps() external view returns (uint256);
    function entropyRateBps() external view returns (uint256);
    function grantsAddress() external view returns (address);
    function grantsRateBps() external view returns (uint256);
    function saleStartTime() external view returns (uint256);
    function soldByVRGDA() external view returns (uint256);
    function priceUpdateInterval() external view returns (uint256);
    function poolSize() external view returns (uint256);
}

interface IRevolutionPointsEmitterRead is IPausableRead, IOwnableRead {
    function founderAddress() external view returns (address);
}

interface IDAOExecutorRead {
    function admin() external view returns (address);
}

interface IVrbsDAO {
    function timelock() external view returns (address);

    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);
}

/// @notice Shared helpers for the one-community Vrbs VRGDA migration.
abstract contract VrbsMigrationHelpers is Script {
    using Strings for uint256;

    bytes32 internal constant ERC1967_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    string internal constant DEFAULT_PROPOSAL_DESCRIPTION =
        "Migrate Vrbs membership minting from AuctionHouse to VRGDA buy-now TokenSale.";

    function _requireBase() internal view {
        require(block.chainid == VrbsAddresses.BASE_CHAIN_ID, "not Base chain");
    }

    function _manager() internal view returns (IUpgradeManager) {
        IUpgradeManager manager = IAuctionHouseRead(VrbsAddresses.AUCTION).manager();
        require(address(manager) != address(0), "manager is zero");
        _requireCode(address(manager), "RevolutionBuilder/manager");
        return manager;
    }

    function _implementationOf(address proxy) internal view returns (address impl) {
        impl = address(uint160(uint256(vm.load(proxy, ERC1967_IMPLEMENTATION_SLOT))));
        require(impl.code.length != 0, "proxy implementation has no code");
    }

    function _requireCode(address target, string memory label) internal view {
        require(target.code.length != 0, string.concat(label, " has no code"));
    }

    function _auctionState()
        internal
        view
        returns (uint256 tokenId, uint256 amount, uint256 startTime, uint256 endTime, address bidder, bool settled)
    {
        address referral;
        (tokenId, amount, startTime, endTime, bidder, referral, settled) = IAuctionHouseRead(VrbsAddresses.AUCTION)
            .auction();
        referral;
    }

    function _auctionHasUnsettledToken() internal view returns (bool) {
        (, , uint256 startTime, , , bool settled) = _auctionState();
        return startTime != 0 && !settled;
    }

    function _requireVrbsContractsHaveCode() internal view {
        _requireCode(VrbsAddresses.TOKEN, "Vrbs Token");
        _requireCode(VrbsAddresses.DESCRIPTOR, "Descriptor");
        _requireCode(VrbsAddresses.AUCTION, "Auction");
        _requireCode(VrbsAddresses.EXECUTOR, "Executor");
        _requireCode(VrbsAddresses.DAO, "DAO");
        _requireCode(VrbsAddresses.CULTURE_INDEX, "CultureIndex");
        _requireCode(VrbsAddresses.POINTS, "Vrb Votes");
        _requireCode(VrbsAddresses.POINTS_EMITTER, "Vrb Votes Emitter");
        _requireCode(VrbsAddresses.MAX_HEAP, "MaxHeap");
        _requireCode(VrbsAddresses.VOTING_POWER, "VotingPower");
        _requireCode(VrbsAddresses.VRGDA, "VRGDA");
    }

    function _requireAuctionPausedAndSettled() internal view {
        require(IAuctionHouseRead(VrbsAddresses.AUCTION).paused(), "auction is not paused");
        require(!_auctionHasUnsettledToken(), "auction still has unsettled token");
    }

    function _requireTokenCanCutOver() internal view {
        require(IRevolutionTokenRead(VrbsAddresses.TOKEN).minter() == VrbsAddresses.AUCTION, "auction is not token minter");
        require(!IRevolutionTokenRead(VrbsAddresses.TOKEN).isMinterLocked(), "token minter is locked");
    }

    function _requireDaoExecutionWiring() internal view {
        require(IVrbsDAO(VrbsAddresses.DAO).timelock() == VrbsAddresses.EXECUTOR, "DAO timelock is not executor");
        require(IDAOExecutorRead(VrbsAddresses.EXECUTOR).admin() == VrbsAddresses.DAO, "executor admin is not DAO");
    }

    function _requireOwnersForAtomicCutover(address tokenSale) internal view returns (bool acceptCultureOwnership) {
        address tokenOwner = IRevolutionTokenRead(VrbsAddresses.TOKEN).owner();
        address saleOwner = IOwnableRead(tokenSale).owner();

        require(tokenOwner == VrbsAddresses.EXECUTOR, "token owner is not Vrbs Executor");
        acceptCultureOwnership = _cultureIndexNeedsOwnershipAcceptance();
        require(saleOwner == VrbsAddresses.EXECUTOR, "token sale owner is not Vrbs Executor");
    }

    function _cultureIndexNeedsOwnershipAcceptance() internal view returns (bool) {
        ICultureIndexRead cultureIndex = ICultureIndexRead(VrbsAddresses.CULTURE_INDEX);
        address cultureOwner = cultureIndex.owner();

        if (cultureOwner == VrbsAddresses.EXECUTOR) return false;

        require(
            cultureIndex.pendingOwner() == VrbsAddresses.EXECUTOR,
            "culture index owner/pending owner is not Vrbs Executor"
        );
        return true;
    }

    function _requirePointsEmitterSafe(address tokenSale) internal view {
        IRevolutionPointsEmitterRead emitter = IRevolutionPointsEmitterRead(VrbsAddresses.POINTS_EMITTER);
        require(!emitter.paused(), "points emitter is paused");
        require(tokenSale != emitter.owner(), "token sale is points emitter owner");
        require(tokenSale != emitter.founderAddress(), "token sale is points emitter founder");
    }

    function _requireRegisteredUpgrades(address newTokenImpl, address newCultureIndexImpl, address tokenSale) internal view {
        IUpgradeManager manager = _manager();
        address oldTokenImpl = _implementationOf(VrbsAddresses.TOKEN);
        address oldCultureIndexImpl = _implementationOf(VrbsAddresses.CULTURE_INDEX);
        address oldAuctionImpl = _implementationOf(VrbsAddresses.AUCTION);
        address tokenSaleImpl = _implementationOf(tokenSale);

        require(manager.isRegisteredUpgrade(oldTokenImpl, newTokenImpl), "token upgrade not registered");
        require(manager.isRegisteredUpgrade(oldCultureIndexImpl, newCultureIndexImpl), "culture upgrade not registered");
        require(!manager.isRegisteredUpgrade(oldAuctionImpl, tokenSaleImpl), "auction => token sale is registered");
    }

    function _buildCommunityActions(
        address newTokenImpl,
        address newCultureIndexImpl,
        address tokenSale,
        bool acceptCultureOwnership
    )
        internal
        pure
        returns (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas)
    {
        uint256 actionCount = acceptCultureOwnership ? 6 : 5;
        uint256 offset = acceptCultureOwnership ? 1 : 0;

        targets = new address[](actionCount);
        values = new uint256[](actionCount);
        signatures = new string[](actionCount);
        calldatas = new bytes[](actionCount);

        if (acceptCultureOwnership) {
            targets[0] = VrbsAddresses.CULTURE_INDEX;
            calldatas[0] = abi.encodeWithSelector(IOwnable2StepRead.acceptOwnership.selector);
        }

        targets[offset] = VrbsAddresses.TOKEN;
        calldatas[offset] = abi.encodeWithSelector(IUUPSProxy.upgradeTo.selector, newTokenImpl);

        targets[offset + 1] = VrbsAddresses.CULTURE_INDEX;
        calldatas[offset + 1] = abi.encodeWithSelector(IUUPSProxy.upgradeTo.selector, newCultureIndexImpl);

        targets[offset + 2] = VrbsAddresses.CULTURE_INDEX;
        calldatas[offset + 2] = abi.encodeWithSelector(
            ICultureIndex.setLegacyQuorumExcludedTokenHolder.selector,
            VrbsAddresses.AUCTION,
            type(uint256).max
        );

        targets[offset + 3] = VrbsAddresses.TOKEN;
        calldatas[offset + 3] = abi.encodeWithSelector(IRevolutionToken.setMinter.selector, tokenSale);

        targets[offset + 4] = tokenSale;
        calldatas[offset + 4] = abi.encodeWithSelector(IRevolutionTokenSale.unpause.selector);
    }

    function _proposalDescription() internal returns (string memory) {
        return vm.envOr("PROPOSAL_DESCRIPTION", DEFAULT_PROPOSAL_DESCRIPTION);
    }

    function _writeAddressLine(string memory filePath, string memory label, address value) internal {
        vm.writeLine(filePath, string.concat(label, ": ", _addressToString(value)));
    }

    function _writeUintLine(string memory filePath, string memory label, uint256 value) internal {
        vm.writeLine(filePath, string.concat(label, ": ", value.toString()));
    }

    function _writeStringLine(string memory filePath, string memory label, string memory value) internal {
        vm.writeLine(filePath, string.concat(label, ": ", value));
    }

    function _writeBytesLine(string memory filePath, string memory label, bytes memory value) internal {
        vm.writeLine(filePath, string.concat(label, ": ", _bytesToHexString(value)));
    }

    function _addressToString(address addr) internal pure returns (string memory) {
        return Strings.toHexString(uint160(addr), 20);
    }

    function _bytesToHexString(bytes memory data) internal pure returns (string memory) {
        bytes16 symbols = "0123456789abcdef";
        bytes memory out = new bytes(2 + data.length * 2);
        out[0] = "0";
        out[1] = "x";
        for (uint256 i; i < data.length; ++i) {
            uint8 b = uint8(data[i]);
            out[2 + i * 2] = symbols[b >> 4];
            out[3 + i * 2] = symbols[b & 0x0f];
        }
        return string(out);
    }

    function _outputFile(string memory suffix) internal pure returns (string memory) {
        return string.concat("deploys/8453.vrbs-vrgda-", suffix, ".txt");
    }

    function _assertSaleConfig(
        address tokenSale,
        address owner,
        address weth,
        IRevolutionTokenSale.TokenSaleParams memory params
    ) internal view {
        IRevolutionTokenSaleRead sale = IRevolutionTokenSaleRead(tokenSale);

        require(sale.paused(), "token sale must start paused");
        require(sale.owner() == owner, "token sale owner mismatch");
        require(address(sale.revolutionToken()) == VrbsAddresses.TOKEN, "token sale token mismatch");
        require(sale.revolutionPointsEmitter() == VrbsAddresses.POINTS_EMITTER, "token sale points emitter mismatch");
        require(sale.WETH() == weth, "token sale WETH mismatch");
        require(sale.minPriceWei() == params.minPriceWei, "token sale min price mismatch");
        require(sale.creatorRateBps() == params.creatorRateBps, "token sale creator rate mismatch");
        require(sale.minCreatorRateBps() == params.minCreatorRateBps, "token sale min creator rate mismatch");
        require(sale.entropyRateBps() == params.entropyRateBps, "token sale entropy rate mismatch");
        require(sale.grantsAddress() == params.grantsParams.grantsAddress, "token sale grants address mismatch");
        require(sale.grantsRateBps() == params.grantsParams.totalRateBps, "token sale grants rate mismatch");
        require(sale.saleStartTime() == params.saleStartTime, "token sale start mismatch");
        require(sale.soldByVRGDA() == params.soldByVRGDA, "token sale sold count mismatch");
        require(sale.priceUpdateInterval() == params.priceUpdateInterval, "token sale price interval mismatch");
        require(sale.poolSize() == params.poolSize, "token sale pool size mismatch");
        require(sale.getCurrentPrice() > 0, "token sale current price is zero");
    }
}
