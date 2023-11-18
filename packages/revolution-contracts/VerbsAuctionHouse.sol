// SPDX-License-Identifier: GPL-3.0

/// @title The Verbs DAO auction house

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

// LICENSE
// VerbsAuctionHouse.sol is a modified version of Zora's AuctionHouse.sol:
// https://github.com/ourzora/auction-house/blob/54a12ec1a6cf562e49f0a4917990474b11350a2d/contracts/AuctionHouse.sol
//
// AuctionHouse.sol source code Copyright Zora licensed under the GPL-3.0 license.

pragma solidity ^0.8.22;

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IVerbsAuctionHouse } from "./interfaces/IVerbsAuctionHouse.sol";
import { IVerbsToken } from "./interfaces/IVerbsToken.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { ITokenEmitter } from "./interfaces/ITokenEmitter.sol";
import { wadMul, wadDiv } from "./libs/SignedWadMath.sol";
import { ICultureIndex } from "./interfaces/ICultureIndex.sol";

contract VerbsAuctionHouse is IVerbsAuctionHouse, PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    // The Verbs ERC721 token contract
    IVerbsToken public verbs;

    // The ERC20 governance token
    ITokenEmitter public tokenEmitter;

    // The address of the WETH contract
    address public weth;

    // The minimum amount of time left in an auction after a new bid is created
    uint256 public timeBuffer;

    // The minimum price accepted in an auction
    uint256 public reservePrice;

    // The minimum percentage difference between the last bid amount and the current bid
    uint8 public minBidIncrementPercentage;

    // The split of the winning bid that is reserved for the creator of the Verb in basis points
    uint256 public creatorRateBps;

    // The split of (auction proceeds * creatorRate) that is sent to the creator as ether in basis points
    uint256 public entropyRateBps;

    // The duration of a single auction
    uint256 public duration;

    // The active auction
    IVerbsAuctionHouse.Auction public auction;

    /**
     * @notice Initialize the auction house and base contracts,
     * populate configuration values, and pause the contract.
     * @dev This function can only be called once.
     */
    function initialize(
        IVerbsToken _verbs,
        ITokenEmitter _tokenEmitter,
        address _weth,
        address _founder,
        uint256 _timeBuffer,
        uint256 _reservePrice,
        uint8 _minBidIncrementPercentage,
        uint256 _duration,
        uint256 _creatorRateBps,
        uint256 _entropyRateBps
    ) external initializer {
        __Pausable_init();
        __ReentrancyGuard_init();
        __Ownable_init(_founder);

        _pause();

        verbs = _verbs;
        tokenEmitter = _tokenEmitter;
        weth = _weth;
        timeBuffer = _timeBuffer;
        reservePrice = _reservePrice;
        minBidIncrementPercentage = _minBidIncrementPercentage;
        duration = _duration;
        creatorRateBps = _creatorRateBps;
        entropyRateBps = _entropyRateBps;
    }

    /**
     * @notice Settle the current auction, mint a new Verb, and put it up for auction.
     */
    function settleCurrentAndCreateNewAuction() external override nonReentrant whenNotPaused {
        _settleAuction();
        _createAuction();
    }

    /**
     * @notice Settle the current auction.
     * @dev This function can only be called when the contract is paused.
     */
    function settleAuction() external override whenPaused nonReentrant {
        _settleAuction();
    }

    /**
     * @notice Create a bid for a Verb, with a given amount.
     * @dev This contract only accepts payment in ETH.
     */
    function createBid(uint256 verbId) external payable override nonReentrant {
        IVerbsAuctionHouse.Auction memory _auction = auction;

        require(_auction.verbId == verbId, "Verb not up for auction");
        require(block.timestamp < _auction.endTime, "Auction expired");
        require(msg.value >= reservePrice, "Must send at least reservePrice");
        require(msg.value >= _auction.amount + ((_auction.amount * minBidIncrementPercentage) / 100), "Must send more than last bid by minBidIncrementPercentage amount");

        address payable lastBidder = _auction.bidder;

        // Refund the last bidder, if applicable
        if (lastBidder != address(0)) {
            _safeTransferETHWithFallback(lastBidder, _auction.amount);
        }

        auction.amount = msg.value;
        auction.bidder = payable(msg.sender);

        // Extend the auction if the bid was received within `timeBuffer` of the auction end time
        bool extended = _auction.endTime - block.timestamp < timeBuffer;
        if (extended) {
            auction.endTime = _auction.endTime = block.timestamp + timeBuffer;
        }

        emit AuctionBid(_auction.verbId, msg.sender, msg.value, extended);

        if (extended) {
            emit AuctionExtended(_auction.verbId, _auction.endTime);
        }
    }

    /**
     * @notice Pause the Verbs auction house.
     * @dev This function can only be called by the owner when the
     * contract is unpaused. While no new auctions can be started when paused,
     * anyone can settle an ongoing auction.
     */
    function pause() external override onlyOwner {
        _pause();
    }

    /**
     * @notice Set the split of the winning bid that is reserved for the creator of the Verb in basis points.
     * @dev Only callable by the owner.
     * @param _creatorRateBps New creator rate in basis points.
     */
    function setCreatorRateBps(uint256 _creatorRateBps) external onlyOwner {
        creatorRateBps = _creatorRateBps;
        emit CreatorRateBpsUpdated(_creatorRateBps);
    }

    /**
     * @notice Set the split of (auction proceeds * creatorRate) that is sent to the creator as ether in basis points.
     * @dev Only callable by the owner.
     * @param _entropyRateBps New entropy rate in basis points.
     */
    function setEntropyRateBps(uint256 _entropyRateBps) external onlyOwner {
        entropyRateBps = _entropyRateBps;
        emit EntropyRateBpsUpdated(_entropyRateBps);
    }

    /**
     * @notice Unpause the Verbs auction house.
     * @dev This function can only be called by the owner when the
     * contract is paused. If required, this function will start a new auction.
     */
    function unpause() external override onlyOwner {
        _unpause();

        if (auction.startTime == 0 || auction.settled) {
            _createAuction();
        }
    }

    /**
     * @notice Set the auction time buffer.
     * @dev Only callable by the owner.
     */
    function setTimeBuffer(uint256 _timeBuffer) external override onlyOwner {
        timeBuffer = _timeBuffer;

        emit AuctionTimeBufferUpdated(_timeBuffer);
    }

    /**
     * @notice Set the auction reserve price.
     * @dev Only callable by the owner.
     */
    function setReservePrice(uint256 _reservePrice) external override onlyOwner {
        reservePrice = _reservePrice;

        emit AuctionReservePriceUpdated(_reservePrice);
    }

    /**
     * @notice Set the auction minimum bid increment percentage.
     * @dev Only callable by the owner.
     */
    function setMinBidIncrementPercentage(uint8 _minBidIncrementPercentage) external override onlyOwner {
        minBidIncrementPercentage = _minBidIncrementPercentage;

        emit AuctionMinBidIncrementPercentageUpdated(_minBidIncrementPercentage);
    }

    /**
     * @notice Create an auction.
     * @dev Store the auction details in the `auction` state variable and emit an AuctionCreated event.
     * If the mint reverts, the minter was updated without pausing this contract first. To remedy this,
     * catch the revert and pause this contract.
     */
    function _createAuction() internal {
        try verbs.mint() returns (uint256 verbId) {
            uint256 startTime = block.timestamp;
            uint256 endTime = startTime + duration;

            auction = Auction({ verbId: verbId, amount: 0, startTime: startTime, endTime: endTime, bidder: payable(0), settled: false });

            emit AuctionCreated(verbId, startTime, endTime);
        } catch Error(string memory) {
            _pause();
        }
    }

    /**
     * @notice Settle an auction, finalizing the bid and paying out to the owner.
     * @dev If there are no bids, the Verb is burned.
     */
    function _settleAuction() internal {
        IVerbsAuctionHouse.Auction memory _auction = auction;

        require(_auction.startTime != 0, "Auction hasn't begun");
        require(!_auction.settled, "Auction has already been settled");
        require(block.timestamp >= _auction.endTime, "Auction hasn't completed");

        auction.settled = true;

        if (_auction.bidder == address(0)) {
            verbs.burn(_auction.verbId);
        } else {
            verbs.transferFrom(address(this), _auction.bidder, _auction.verbId);
        }

        if (_auction.amount > 0) {
            // Ether going to owner of the auction
            uint256 auctioneerPayment = uint256(wadDiv(wadMul(int256(_auction.amount), 10000 - int256(creatorRateBps)), 10000));

            //Total amount of ether going to creator
            uint256 creatorPayment = _auction.amount - auctioneerPayment;

            //Ether reserved to pay the creator directly
            uint256 creatorDirectPayment = uint256(wadDiv(wadMul(int256(creatorPayment), int256(entropyRateBps)), 10000));
            //Ether reserved to buy creator governance
            uint256 creatorGovernancePayment = creatorPayment - creatorDirectPayment;

            uint256 numCreators = verbs.getArtPieceById(_auction.verbId).creators.length;
            address deployer = verbs.getArtPieceById(_auction.verbId).dropper;

            //Build arrays for tokenEmitter.buyToken
            address[] memory vrgdaReceivers = new address[](numCreators);
            uint256[] memory vrgdaSplits = new uint256[](numCreators);

            //Transfer auction amount to the DAO treasury
            _safeTransferETHWithFallback(owner(), auctioneerPayment);

            //Transfer creator's share to the creator, for each creator, and build arrays for tokenEmitter.buyToken
            for (uint256 i = 0; i < numCreators; i++) {
                ICultureIndex.CreatorBps memory creator = verbs.getArtPieceById(_auction.verbId).creators[i];
                vrgdaReceivers[i] = creator.creator;
                vrgdaSplits[i] = creator.bps;

                //Calculate etherAmount for specific creator based on BPS splits
                uint256 etherAmount = uint256(wadDiv(wadMul(int256(creatorDirectPayment), int256(creator.bps)), 10000));

                //Transfer creator's share to the creator
                _safeTransferETHWithFallback(creator.creator, etherAmount);
            }

            //Buy token from tokenEmitter for all the creators
            tokenEmitter.buyToken{ value: creatorGovernancePayment }(vrgdaReceivers, vrgdaSplits, address(0), address(0), deployer);
        }

        emit AuctionSettled(_auction.verbId, _auction.bidder, _auction.amount);
    }

    /**
     * @notice Transfer ETH. If the ETH transfer fails, wrap the ETH and try send it as WETH.
     */
    function _safeTransferETHWithFallback(address to, uint256 amount) internal {
        if (!_safeTransferETH(to, amount)) {
            IWETH(weth).deposit{ value: amount }();
            IERC20(weth).transfer(to, amount);
        }
    }

    /**
     * @notice Transfer ETH and return the success status.
     * @dev This function only forwards 30,000 gas to the callee.
     */
    function _safeTransferETH(address to, uint256 value) internal returns (bool) {
        (bool success, ) = to.call{ value: value, gas: 30_000 }(new bytes(0));
        return success;
    }
}
