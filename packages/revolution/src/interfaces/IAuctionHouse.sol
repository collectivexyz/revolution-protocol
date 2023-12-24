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

interface IAuctionHouse {
    ///                                                          ///
    ///                           ERRORS                         ///
    ///                                                          ///

    /// @dev Reverts if the function caller is not the manager.
    error NOT_MANAGER();

    /// @dev Reverts if address 0 is passed but not allowed
    error ADDRESS_ZERO();

    /// @dev Reverts if the verb ID does not match the auction's verb ID.
    error INVALID_VERB_ID();

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

    struct Auction {
        // ID for the Verb (ERC721 token ID)
        uint256 verbId;
        // The current highest bid amount
        uint256 amount;
        // The time that the auction started
        uint256 startTime;
        // The time that the auction is scheduled to end
        uint256 endTime;
        // The address of the current highest bid
        address payable bidder;
        // Whether or not the auction has been settled
        bool settled;
    }

    event AuctionCreated(uint256 indexed verbId, uint256 startTime, uint256 endTime);

    event AuctionBid(uint256 indexed verbId, address bidder, address sender, uint256 value, bool extended);

    event AuctionExtended(uint256 indexed verbId, uint256 endTime);

    event AuctionSettled(uint256 indexed verbId, address winner, uint256 amount, uint256 creatorTokensEmitted);

    event AuctionTimeBufferUpdated(uint256 timeBuffer);

    event AuctionReservePriceUpdated(uint256 reservePrice);

    event AuctionMinBidIncrementPercentageUpdated(uint256 minBidIncrementPercentage);

    event CreatorRateBpsUpdated(uint256 rateBps);

    event MinCreatorRateBpsUpdated(uint256 rateBps);

    event EntropyRateBpsUpdated(uint256 rateBps);

    function settleAuction() external;

    function settleCurrentAndCreateNewAuction() external;

    function createBid(uint256 verbId, address bidder) external payable;

    function pause() external;

    function unpause() external;

    function setTimeBuffer(uint256 timeBuffer) external;

    function setReservePrice(uint256 reservePrice) external;

    function setMinBidIncrementPercentage(uint8 minBidIncrementPercentage) external;

    function setCreatorRateBps(uint256 _creatorRateBps) external;

    function setMinCreatorRateBps(uint256 _minCreatorRateBps) external;

    function setEntropyRateBps(uint256 _entropyRateBps) external;

    function WETH() external view returns (address);

    function manager() external returns (IRevolutionBuilder);

    /**
     * @notice Initialize the auction house and base contracts.
     * @param erc721Token The address of the Verbs ERC721 token contract.
     * @param revolutionPointsEmitter The address of the ERC-20 token emitter contract.
     * @param initialOwner The address of the owner.
     * @param weth The address of the WETH contract.
     * @param auctionParams The auction params for auctions.
     */
    function initialize(
        address erc721Token,
        address revolutionPointsEmitter,
        address initialOwner,
        address weth,
        IRevolutionBuilder.AuctionParams calldata auctionParams
    ) external;
}
