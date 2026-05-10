// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import {console2} from "forge-std/console2.sol";

import {IRevolutionTokenSale} from "../../src/interfaces/IRevolutionTokenSale.sol";

import {
    VrbsAddresses,
    VrbsMigrationHelpers,
    IAuctionHouseRead,
    IRevolutionTokenRead,
    ICultureIndexRead,
    IRevolutionTokenSaleRead
} from "./VrbsMigrationHelpers.sol";

/// @notice Read-only post-execution verifier for the Vrbs VRGDA migration.
contract VerifyVrbsVRGDAMigration is VrbsMigrationHelpers {
    function run() external {
        _requireBase();
        _requireVrbsContractsHaveCode();

        address expectedTokenImpl = vm.envAddress("VRGDA_NEW_TOKEN_IMPL");
        address expectedCultureIndexImpl = vm.envAddress("VRGDA_NEW_CULTURE_INDEX_IMPL");
        address expectedTokenSaleImpl = vm.envAddress("TOKEN_SALE_IMPL");
        address tokenSale = vm.envAddress("TOKEN_SALE_PROXY");
        address expectedProtocolFeeRecipient = _readProtocolFeeRecipient();
        uint256 maxLaunchPriceWei = _readMaxLaunchPriceWei();
        IRevolutionTokenSale.TokenSaleParams memory expectedParams = _readSaleParams();
        _validateSaleParams(expectedParams);
        _requireSaleStartSentinel(expectedParams);

        _requireCode(expectedTokenImpl, "VRGDA_NEW_TOKEN_IMPL");
        _requireCode(expectedCultureIndexImpl, "VRGDA_NEW_CULTURE_INDEX_IMPL");
        _requireCode(expectedTokenSaleImpl, "TOKEN_SALE_IMPL");
        _requireCode(tokenSale, "TOKEN_SALE_PROXY");

        _requireDaoExecutionWiring();
        require(_implementationOf(VrbsAddresses.TOKEN) == expectedTokenImpl, "token implementation mismatch");
        require(
            _implementationOf(VrbsAddresses.CULTURE_INDEX) == expectedCultureIndexImpl,
            "culture index implementation mismatch"
        );
        require(_implementationOf(tokenSale) == expectedTokenSaleImpl, "token sale implementation mismatch");
        require(IAuctionHouseRead(VrbsAddresses.AUCTION).paused(), "auction is not paused");
        require(!_auctionHasUnsettledToken(), "auction still has unsettled token");
        require(IRevolutionTokenRead(VrbsAddresses.TOKEN).minter() == tokenSale, "token minter is not token sale");
        require(!IRevolutionTokenRead(VrbsAddresses.TOKEN).isMinterLocked(), "token minter locked unexpectedly");
        require(!IRevolutionTokenSaleRead(tokenSale).paused(), "token sale is paused");
        require(IRevolutionTokenSaleRead(tokenSale).owner() == VrbsAddresses.EXECUTOR, "token sale owner not executor");
        require(
            ICultureIndexRead(VrbsAddresses.CULTURE_INDEX).owner() == VrbsAddresses.EXECUTOR,
            "culture owner not executor"
        );
        require(
            address(IRevolutionTokenSaleRead(tokenSale).revolutionToken()) == VrbsAddresses.TOKEN, "sale token mismatch"
        );
        require(
            IRevolutionTokenSaleRead(tokenSale).revolutionPointsEmitter() == VrbsAddresses.POINTS_EMITTER,
            "sale emitter mismatch"
        );
        require(
            IRevolutionTokenSaleRead(tokenSale).WETH() == IAuctionHouseRead(VrbsAddresses.AUCTION).WETH(),
            "sale WETH mismatch"
        );
        require(IRevolutionTokenSaleRead(tokenSale).WETH().code.length != 0, "sale WETH has no code");
        require(
            IRevolutionTokenSaleRead(tokenSale).protocolFeeRecipient() == expectedProtocolFeeRecipient,
            "sale protocol fee recipient mismatch"
        );
        _assertSaleParams(tokenSale, expectedParams, false);
        uint256 boundedPrice = _assertLaunchPrice(tokenSale, maxLaunchPriceWei);
        require(IRevolutionTokenSaleRead(tokenSale).saleStartTime() != type(uint256).max, "sale start was not bound");
        require(IRevolutionTokenSaleRead(tokenSale).saleStartTime() <= block.timestamp, "sale start is in future");

        uint256[] memory pieceIds;
        uint256 price;
        (pieceIds, price) = IRevolutionTokenSaleRead(tokenSale).getAvailablePieces(1);
        require(price > 0, "available pieces price is zero");
        pieceIds;

        require(
            ICultureIndexRead(VrbsAddresses.CULTURE_INDEX).legacyQuorumExcludedTokenHolder() == VrbsAddresses.AUCTION,
            "legacy quorum holder is not auction"
        );
        require(
            ICultureIndexRead(VrbsAddresses.CULTURE_INDEX).legacyQuorumCutoffBlock() != 0,
            "legacy quorum cutoff is unset"
        );
        require(
            ICultureIndexRead(VrbsAddresses.CULTURE_INDEX).legacyQuorumCutoffBlock() <= block.number,
            "legacy quorum cutoff is in the future"
        );

        console2.log("Vrbs VRGDA migration verified");
        console2.log("TokenSale");
        console2.logAddress(tokenSale);
        console2.log("Current price", boundedPrice);
        console2.log("Max launch price", maxLaunchPriceWei);
        console2.log("Legacy quorum cutoff", ICultureIndexRead(VrbsAddresses.CULTURE_INDEX).legacyQuorumCutoffBlock());
    }
}
