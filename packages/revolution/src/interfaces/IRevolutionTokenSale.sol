// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.22;

import { IGrantsRevenueStream } from "./IGrantsRevenueStream.sol";
import { IRevolutionBuilder } from "./IRevolutionBuilder.sol";

/// @title Interface for RevolutionTokenSale
/// @notice Greenfield VRGDA buy-now minter for Revolution ERC-721 tokens.
interface IRevolutionTokenSale is IGrantsRevenueStream {
    ///                                                          ///
    ///                           ERRORS                         ///
    ///                                                          ///

    error ADDRESS_ZERO();
    error INVALID_BPS();
    error INVALID_PRICE();
    error INVALID_VRGDA_PARAMS();
    error INVALID_POOL_SIZE();
    error INVALID_SOLD_COUNT();
    error INVALID_GRANTS_CONFIG();
    error INSUFFICIENT_PAYMENT();
    error MAX_PRICE_EXCEEDED();
    error CREATOR_RATE_TOO_LOW();
    error MIN_CREATOR_RATE_NOT_INCREASED();
    error MIN_CREATOR_RATE_ABOVE_CREATOR_RATE();
    error NOT_INITIAL_TOKEN_OWNER();
    error MANIFESTO_TOO_LONG();

    ///                                                          ///
    ///                           STRUCTS                        ///
    ///                                                          ///

    struct VRGDAParams {
        // Target price for a token if sold on pace, in wei scaled as a signed wad.
        int256 targetPrice;
        // Percent the price decays per unit of time with no sales, scaled by 1e18.
        int256 priceDecayPercent;
        // Number of NFTs to target selling in one full day, scaled by 1e18.
        int256 tokensPerTimeUnit;
    }

    struct TokenSaleParams {
        uint256 minPriceWei;
        uint256 creatorRateBps;
        uint256 entropyRateBps;
        uint256 minCreatorRateBps;
        IRevolutionBuilder.GrantsParams grantsParams;
        VRGDAParams vrgdaParams;
        uint256 saleStartTime;
        uint256 soldByVRGDA;
        uint256 priceUpdateInterval;
        uint256 poolSize;
    }

    struct PaymentShares {
        // Scaled means it hasn't been divided by 10,000 for BPS to allow for precision in division by
        // consuming functions.
        uint256 creatorDirectScaled;
        uint256 creatorGovernance;
        uint256 owner;
        uint256 grants;
    }

    struct PaidToCreators {
        uint256 points;
        uint256 eth;
    }

    struct SaleHistory {
        uint256 amount;
        address buyer;
        address recipient;
        uint256 amountPaidToOwner;
        uint256 settledBlockWad;
        uint256 pieceId;
    }

    // A new community member has joined the revolution.
    // What do you have to say for yourself?
    struct AcceptanceManifesto {
        address member;
        string speech;
    }

    ///                                                          ///
    ///                           EVENTS                         ///
    ///                                                          ///

    event TokenPurchased(
        uint256 indexed tokenId,
        uint256 indexed pieceId,
        address indexed buyer,
        address recipient,
        uint256 price,
        address referral,
        uint256 pointsPaidToCreators,
        uint256 ethPaidToCreators
    );

    /// @notice Legacy-compatible event name for existing indexer patterns.
    event AuctionSettled(
        uint256 indexed tokenId,
        address winner,
        uint256 amount,
        uint256 pointsPaidToCreators,
        uint256 ethPaidToCreators
    );

    event ManifestoUpdated(uint256 indexed tokenId, address member, string speech);
    event MinPriceUpdated(uint256 minPriceWei);
    event PoolSizeUpdated(uint256 poolSize);
    event PriceUpdateIntervalUpdated(uint256 priceUpdateInterval);
    event VRGDAParamsUpdated(int256 targetPrice, int256 priceDecayPercent, int256 tokensPerTimeUnit);
    event SaleStartTimeUpdated(uint256 saleStartTime);
    event SoldByVRGDAUpdated(uint256 soldByVRGDA);
    event CreatorRateBpsUpdated(uint256 rateBps);
    event MinCreatorRateBpsUpdated(uint256 rateBps);
    event EntropyRateBpsUpdated(uint256 rateBps);

    ///                                                          ///
    ///                          FUNCTIONS                       ///
    ///                                                          ///

    function initialize(
        address revolutionToken,
        address revolutionPointsEmitter,
        address initialOwner,
        address weth,
        TokenSaleParams calldata tokenSaleParams
    ) external;

    function buyNow(
        uint256 pieceId,
        address recipient,
        uint256 maxPrice,
        address referral
    ) external payable returns (uint256 tokenId, uint256 price);

    function getCurrentPrice() external view returns (uint256);

    function getPrice(uint256 sold) external view returns (uint256);

    function getAvailablePieces(uint256 count) external view returns (uint256[] memory pieceIds, uint256 price);

    function getPastSale(uint256 tokenId) external view returns (SaleHistory memory);

    function updateManifesto(uint256 tokenId, string calldata newSpeech) external;

    function pause() external;

    function unpause() external;

    function setMinPriceWei(uint256 minPriceWei) external;

    function setPoolSize(uint256 poolSize) external;

    function setPriceUpdateInterval(uint256 priceUpdateInterval) external;

    function setVRGDAParams(VRGDAParams calldata vrgdaParams) external;

    function setSaleStartTime(uint256 saleStartTime) external;

    function setSoldByVRGDA(uint256 soldByVRGDA) external;

    function setCreatorRateBps(uint256 creatorRateBps) external;

    function setMinCreatorRateBps(uint256 minCreatorRateBps) external;

    function setEntropyRateBps(uint256 entropyRateBps) external;

    function WETH() external view returns (address);
}
