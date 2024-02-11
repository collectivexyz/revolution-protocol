// SPDX-License-Identifier: GPL-3.0

/// @title Interface for Revolution Auction Houses

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

pragma solidity ^0.8.22;

import { IRevolutionBuilder } from "./IRevolutionBuilder.sol";
import { IGrantsRevenueStream } from "./IGrantsRevenueStream.sol";
import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";

interface IAuctionHouseEvents {
    event AuctionCreated(uint256 indexed tokenId, uint256 startTime, uint256 endTime);

    event AuctionBid(
        uint256 indexed tokenId,
        address bidder,
        address sender,
        uint256 value,
        bool extended,
        string comment
    );

    event AuctionExtended(uint256 indexed tokenId, uint256 endTime);

    event AuctionSettled(
        uint256 indexed tokenId,
        address winner,
        uint256 amount,
        uint256 pointsPaidToCreators,
        uint256 ethPaidToCreators
    );

    event AuctionTimeBufferUpdated(uint256 timeBuffer);

    event AuctionReservePriceUpdated(uint256 reservePrice);

    event AuctionMinBidIncrementPercentageUpdated(uint256 minBidIncrementPercentage);

    event CreatorRateBpsUpdated(uint256 rateBps);

    event MinCreatorRateBpsUpdated(uint256 rateBps);

    event EntropyRateBpsUpdated(uint256 rateBps);
}

interface IAuctionHouse is IAuctionHouseEvents, IGrantsRevenueStream {
    ///                                                          ///
    ///                           ERRORS                         ///
    ///                                                          ///

    /// @dev Reverts if the function caller is not the manager.
    error NOT_MANAGER();

    /// @dev Reverts if address 0 is passed but not allowed
    error ADDRESS_ZERO();

    /// @dev Reverts if the supplied token ID for a bid does not match the auction's token ID.
    error INVALID_TOKEN_ID();

    /// @dev Reverts if the auction has already expired.
    error AUCTION_EXPIRED();

    /// @dev Reverts if the sent value is less than the reserve price.
    error BELOW_RESERVE_PRICE();

    /// @dev Reverts if the bid is not sufficiently higher than the last bid based on the minimum bid increment percentage.
    error BID_TOO_LOW();

    /// @dev Reverts if bps is greater than 10,000.
    error INVALID_BPS();

    /// @dev Reverts if the creator rate is below the minimum required creator rate basis points.
    error CREATOR_RATE_TOO_LOW();

    /// @dev Reverts if the reserve price is invalid.
    error RESERVE_PRICE_INVALID();

    /// @dev Reverts if the new minimum creator rate is not greater than the previous minimum creator rate.
    error MIN_CREATOR_RATE_NOT_INCREASED();

    /// @dev Reverts if the minimum creator rate is not less than or equal to the creator rate.
    error MIN_CREATOR_RATE_ABOVE_CREATOR_RATE();

    /// @dev Reverts if the auction start time is not set, indicating the auction hasn't begun.
    error AUCTION_NOT_BEGUN();

    /// @dev Reverts if the auction has already been settled.
    error AUCTION_ALREADY_SETTLED();

    /// @dev Reverts if the auction has not yet completed based on the current block timestamp.
    error AUCTION_NOT_COMPLETED();

    /// @dev Reverts if the remaining gas is insufficient for creating an auction.
    error INSUFFICIENT_GAS_FOR_AUCTION();

    /// @dev Reverts if the top voted piece does not meet quorum.
    error QUORUM_NOT_MET();

    /// @dev Reverts if the bid comment is too long
    error COMMENT_TOO_LONG();

    /// @dev Reverts if an existing auction is in progress.
    error AUCTION_ALREADY_IN_PROGRESS();

    struct Auction {
        // ERC721 token ID
        uint256 tokenId;
        // The current highest bid amount
        uint256 amount;
        // The time that the auction started
        uint256 startTime;
        // The time that the auction is scheduled to end
        uint256 endTime;
        // The address of the current highest bid
        address payable bidder;
        // The address of the referral account who referred the current highest bidder
        address payable referral;
        // Whether or not the auction has been settled
        bool settled;
    }

    struct PaymentShares {
        // Scaled means it hasn't been divided by 10,000 for BPS to allow for precision in division by
        // consuming functions
        uint256 creatorDirectScaled;
        uint256 creatorGovernance;
        uint256 owner;
        uint256 grants;
    }

    function settleAuction() external;

    function settleCurrentAndCreateNewAuction() external;

    function createBid(uint256 tokenId, address bidder, address referral, string calldata comment) external payable;

    function pause() external;

    function unpause() external;

    function setTimeBuffer(uint256 timeBuffer) external;

    function setReservePrice(uint256 reservePrice) external;

    function setMinBidIncrementPercentage(uint8 minBidIncrementPercentage) external;

    function setCreatorRateBps(uint256 _creatorRateBps) external;

    function setMinCreatorRateBps(uint256 _minCreatorRateBps) external;

    function setEntropyRateBps(uint256 _entropyRateBps) external;

    function WETH() external view returns (address);

    function manager() external returns (IUpgradeManager);

    /**
     * @notice Initialize the auction house and base contracts.
     * @param revolutionToken The address of the Revolution ERC721 token contract.
     * @param revolutionPointsEmitter The address of the ERC-20 points emitter contract.
     * @param initialOwner The address of the owner.
     * @param weth The address of the WETH contract.
     * @param auctionParams The auction params for auctions.
     */
    function initialize(
        address revolutionToken,
        address revolutionPointsEmitter,
        address initialOwner,
        address weth,
        IRevolutionBuilder.AuctionParams calldata auctionParams
    ) external;
}
