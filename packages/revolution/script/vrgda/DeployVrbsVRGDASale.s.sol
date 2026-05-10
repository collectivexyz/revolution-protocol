// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import {console2} from "forge-std/console2.sol";

import {ERC1967Proxy} from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";

import {CultureIndex} from "../../src/culture-index/CultureIndex.sol";
import {RevolutionToken} from "../../src/RevolutionToken.sol";
import {RevolutionTokenSale} from "../../src/RevolutionTokenSale.sol";
import {IRevolutionTokenSale} from "../../src/interfaces/IRevolutionTokenSale.sol";

import {
    VrbsAddresses,
    VrbsMigrationHelpers,
    IAuctionHouseRead,
    IRevolutionPointsEmitterRead,
    IRevolutionTokenSaleRead
} from "./VrbsMigrationHelpers.sol";

/// @notice Deploys the one-community Vrbs VRGDA migration artifacts on Base:
///         - new RevolutionToken implementation with mintFromPiece
///         - new CultureIndex implementation with top-N selection + legacy quorum holder
///         - fresh RevolutionTokenSale implementation
///         - fresh, atomically initialized RevolutionTokenSale proxy owned by the Vrbs Executor by default
///
/// @dev Does not mutate the live Token/CultureIndex proxies. After this script, register upgrades and submit the
///      DAO proposal produced by BuildVrbsVRGDAProposal.
contract DeployVrbsVRGDASale is VrbsMigrationHelpers {
    struct DeploymentResult {
        address manager;
        address oldTokenImpl;
        address oldCultureIndexImpl;
        address tokenImpl;
        address cultureIndexImpl;
        address tokenSaleImpl;
        address tokenSaleProxy;
    }

    function run() external {
        _requireBase();
        _requireVrbsContractsHaveCode();
        _requireAuctionPausedAndSettled();
        _requireTokenCanCutOver();

        uint256 key = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(key);

        address protocolRewards = VrbsAddresses.PROTOCOL_REWARDS;
        address protocolFeeRecipient = vm.envAddress("PROTOCOL_FEE_RECIPIENT");
        address tokenSaleOwner = vm.envOr("TOKEN_SALE_OWNER", VrbsAddresses.EXECUTOR);
        address weth = IAuctionHouseRead(VrbsAddresses.AUCTION).WETH();

        _requireProtocolRewards(protocolRewards);
        _requireCode(weth, "auction WETH");
        require(protocolFeeRecipient != address(0), "PROTOCOL_FEE_RECIPIENT is zero");
        require(tokenSaleOwner == VrbsAddresses.EXECUTOR, "TOKEN_SALE_OWNER must be Vrbs Executor for DAO cutover");
        require(!IRevolutionPointsEmitterRead(VrbsAddresses.POINTS_EMITTER).paused(), "points emitter is paused");

        IRevolutionTokenSale.TokenSaleParams memory params = _readSaleParams();
        _validateSaleParams(params);
        _requireSaleStartSentinel(params);

        DeploymentResult memory result;
        result.manager = address(_manager());
        result.oldTokenImpl = _implementationOf(VrbsAddresses.TOKEN);
        result.oldCultureIndexImpl = _implementationOf(VrbsAddresses.CULTURE_INDEX);

        console2.log("CHAIN_ID", block.chainid);
        console2.log("DEPLOYER");
        console2.logAddress(deployer);
        console2.log("MANAGER");
        console2.logAddress(result.manager);
        console2.log("VRBS DAO");
        console2.logAddress(VrbsAddresses.DAO);
        console2.log("VRBS EXECUTOR / TOKEN SALE OWNER");
        console2.logAddress(tokenSaleOwner);
        console2.log("OLD TOKEN IMPL");
        console2.logAddress(result.oldTokenImpl);
        console2.log("OLD CULTURE INDEX IMPL");
        console2.logAddress(result.oldCultureIndexImpl);
        console2.log("WETH");
        console2.logAddress(weth);
        console2.log("PROTOCOL REWARDS");
        console2.logAddress(protocolRewards);
        console2.log("PROTOCOL FEE RECIPIENT");
        console2.logAddress(protocolFeeRecipient);

        vm.startBroadcast(key);

        result.tokenImpl = address(new RevolutionToken(result.manager));
        result.cultureIndexImpl = address(new CultureIndex(result.manager));
        result.tokenSaleImpl = address(new RevolutionTokenSale(result.manager, protocolRewards, protocolFeeRecipient));

        bytes memory init = abi.encodeWithSelector(
            RevolutionTokenSale.initialize.selector,
            VrbsAddresses.TOKEN,
            VrbsAddresses.POINTS_EMITTER,
            tokenSaleOwner,
            weth,
            params
        );
        result.tokenSaleProxy = address(new ERC1967Proxy(result.tokenSaleImpl, init));

        vm.stopBroadcast();

        _assertSaleConfig(result.tokenSaleProxy, tokenSaleOwner, weth, params);
        _requirePointsEmitterSafe(result.tokenSaleProxy);

        console2.log("NEW TOKEN IMPL");
        console2.logAddress(result.tokenImpl);
        console2.log("NEW CULTURE INDEX IMPL");
        console2.logAddress(result.cultureIndexImpl);
        console2.log("TOKEN SALE IMPL");
        console2.logAddress(result.tokenSaleImpl);
        console2.log("TOKEN SALE PROXY");
        console2.logAddress(result.tokenSaleProxy);
        console2.log("TOKEN SALE CURRENT PRICE", IRevolutionTokenSaleRead(result.tokenSaleProxy).getCurrentPrice());

        _writeDeploymentFile(protocolRewards, protocolFeeRecipient, tokenSaleOwner, weth, params, result);
    }

    function _writeDeploymentFile(
        address protocolRewards,
        address protocolFeeRecipient,
        address tokenSaleOwner,
        address weth,
        IRevolutionTokenSale.TokenSaleParams memory params,
        DeploymentResult memory result
    ) internal {
        string memory filePath = _outputFile("deploy");
        vm.writeFile(filePath, "");

        vm.writeLine(filePath, "# Vrbs VRGDA sale deployment output");
        vm.writeLine(filePath, "# Export the variables below before running registration/proposal scripts.");
        vm.writeLine(filePath, "");
        _writeAddressLine(filePath, "Manager", result.manager);
        _writeAddressLine(filePath, "DAO", VrbsAddresses.DAO);
        _writeAddressLine(filePath, "Executor", VrbsAddresses.EXECUTOR);
        _writeAddressLine(filePath, "RevolutionToken", VrbsAddresses.TOKEN);
        _writeAddressLine(filePath, "CultureIndex", VrbsAddresses.CULTURE_INDEX);
        _writeAddressLine(filePath, "Auction", VrbsAddresses.AUCTION);
        _writeAddressLine(filePath, "PointsEmitter", VrbsAddresses.POINTS_EMITTER);
        _writeAddressLine(filePath, "WETH", weth);
        _writeAddressLine(filePath, "ProtocolRewards", protocolRewards);
        _writeAddressLine(filePath, "ProtocolFeeRecipient", protocolFeeRecipient);
        _writeAddressLine(filePath, "TokenSaleOwner", tokenSaleOwner);
        _writeAddressLine(filePath, "OldTokenImpl", result.oldTokenImpl);
        _writeAddressLine(filePath, "OldCultureIndexImpl", result.oldCultureIndexImpl);
        _writeAddressLine(filePath, "NewTokenImpl", result.tokenImpl);
        _writeAddressLine(filePath, "NewCultureIndexImpl", result.cultureIndexImpl);
        _writeAddressLine(filePath, "TokenSaleImpl", result.tokenSaleImpl);
        _writeAddressLine(filePath, "TokenSaleProxy", result.tokenSaleProxy);
        _writeUintLine(filePath, "MinPriceWei", params.minPriceWei);
        _writeUintLine(filePath, "CreatorRateBps", params.creatorRateBps);
        _writeUintLine(filePath, "EntropyRateBps", params.entropyRateBps);
        _writeUintLine(filePath, "MinCreatorRateBps", params.minCreatorRateBps);
        _writeUintLine(filePath, "GrantsRateBps", params.grantsParams.totalRateBps);
        _writeAddressLine(filePath, "GrantsAddress", params.grantsParams.grantsAddress);
        _writeUintLine(filePath, "TargetPriceWad", uint256(params.vrgdaParams.targetPrice));
        _writeUintLine(filePath, "PriceDecayPercentWad", uint256(params.vrgdaParams.priceDecayPercent));
        _writeUintLine(filePath, "TokensPerTimeUnitWad", uint256(params.vrgdaParams.tokensPerTimeUnit));
        _writeUintLine(filePath, "SaleStartTime", params.saleStartTime);
        _writeUintLine(filePath, "SoldByVRGDA", params.soldByVRGDA);
        _writeUintLine(filePath, "PriceUpdateInterval", params.priceUpdateInterval);
        _writeUintLine(filePath, "PoolSize", params.poolSize);

        vm.writeLine(filePath, "");
        vm.writeLine(filePath, string.concat("export VRGDA_NEW_TOKEN_IMPL=", _addressToString(result.tokenImpl)));
        vm.writeLine(
            filePath, string.concat("export VRGDA_NEW_CULTURE_INDEX_IMPL=", _addressToString(result.cultureIndexImpl))
        );
        vm.writeLine(filePath, string.concat("export TOKEN_SALE_IMPL=", _addressToString(result.tokenSaleImpl)));
        vm.writeLine(filePath, string.concat("export TOKEN_SALE_PROXY=", _addressToString(result.tokenSaleProxy)));
        vm.writeLine(filePath, string.concat("export VRGDA_MIN_PRICE_WEI=", _uintToString(params.minPriceWei)));
        vm.writeLine(filePath, string.concat("export VRGDA_CREATOR_RATE_BPS=", _uintToString(params.creatorRateBps)));
        vm.writeLine(filePath, string.concat("export VRGDA_ENTROPY_RATE_BPS=", _uintToString(params.entropyRateBps)));
        vm.writeLine(
            filePath, string.concat("export VRGDA_MIN_CREATOR_RATE_BPS=", _uintToString(params.minCreatorRateBps))
        );
        vm.writeLine(
            filePath, string.concat("export VRGDA_GRANTS_RATE_BPS=", _uintToString(params.grantsParams.totalRateBps))
        );
        vm.writeLine(
            filePath, string.concat("export VRGDA_GRANTS_ADDRESS=", _addressToString(params.grantsParams.grantsAddress))
        );
        vm.writeLine(
            filePath,
            string.concat("export VRGDA_TARGET_PRICE_WAD=", _uintToString(uint256(params.vrgdaParams.targetPrice)))
        );
        vm.writeLine(
            filePath,
            string.concat(
                "export VRGDA_PRICE_DECAY_PERCENT_WAD=", _uintToString(uint256(params.vrgdaParams.priceDecayPercent))
            )
        );
        vm.writeLine(
            filePath,
            string.concat(
                "export VRGDA_TOKENS_PER_TIME_UNIT_WAD=", _uintToString(uint256(params.vrgdaParams.tokensPerTimeUnit))
            )
        );
        vm.writeLine(filePath, string.concat("export VRGDA_SALE_START_TIME=", _uintToString(params.saleStartTime)));
        vm.writeLine(filePath, string.concat("export VRGDA_SOLD_BY_VRGDA=", _uintToString(params.soldByVRGDA)));
        vm.writeLine(
            filePath, string.concat("export VRGDA_PRICE_UPDATE_INTERVAL=", _uintToString(params.priceUpdateInterval))
        );
        vm.writeLine(filePath, string.concat("export VRGDA_POOL_SIZE=", _uintToString(params.poolSize)));

        console2.log("Deployment output written to");
        console2.log(filePath);
    }
}
