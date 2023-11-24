// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { VerbsAuctionHouseTest } from "./AuctionHouse.t.sol";
import { IVerbsAuctionHouse } from "../../src/interfaces/IVerbsAuctionHouse.sol";

contract VerbsAuctionHouseBasicTest is VerbsAuctionHouseTest {
    function testEventEmission() public {
        uint256 newCreatorRateBps = 2500;
        uint256 newEntropyRateBps = 6000;

        // Expect events when changing creatorRateBps
        vm.expectEmit(true, true, true, true);
        emit IVerbsAuctionHouse.CreatorRateBpsUpdated(newCreatorRateBps);
        auctionHouse.setCreatorRateBps(newCreatorRateBps);

        // Expect events when changing entropyRateBps
        vm.expectEmit(true, true, true, true);
        emit IVerbsAuctionHouse.EntropyRateBpsUpdated(newEntropyRateBps);
        auctionHouse.setEntropyRateBps(newEntropyRateBps);
    }

    function testValueUpdates() public {
        uint256 newCreatorRateBps = 2500;
        uint256 newEntropyRateBps = 6000;

        // Change creatorRateBps as the owner
        auctionHouse.setCreatorRateBps(newCreatorRateBps);
        assertEq(auctionHouse.creatorRateBps(), newCreatorRateBps, "creatorRateBps should be updated");

        // Change entropyRateBps as the owner
        auctionHouse.setEntropyRateBps(newEntropyRateBps);
        assertEq(auctionHouse.entropyRateBps(), newEntropyRateBps, "entropyRateBps should be updated");
    }

    function testOwnerOnlyAccess() public {
        uint256 newCreatorRateBps = 2500;
        uint256 newEntropyRateBps = 6000;

        // Attempt to change creatorRateBps as a non-owner
        vm.startPrank(address(2));
        vm.expectRevert();
        auctionHouse.setCreatorRateBps(newCreatorRateBps);
        vm.stopPrank();

        // Attempt to change entropyRateBps as a non-owner
        vm.startPrank(address(2));
        vm.expectRevert();
        auctionHouse.setEntropyRateBps(newEntropyRateBps);
        vm.stopPrank();
    }

    // Fallback function to allow contract to receive Ether
    receive() external payable {}

    function testInitializationParameters() public {
        assertEq(auctionHouse.weth(), address(mockWETH), "WETH address should be set correctly");
        assertEq(auctionHouse.timeBuffer(), 15 minutes, "Time buffer should be set correctly");
        assertEq(auctionHouse.reservePrice(), 1 ether, "Reserve price should be set correctly");
        assertEq(auctionHouse.minBidIncrementPercentage(), 5, "Min bid increment percentage should be set correctly");
        assertEq(auctionHouse.duration(), 24 hours, "Auction duration should be set correctly");
    }

    function testAuctionCreation() public {
        setUp();
        createDefaultArtPiece();

        auctionHouse.unpause();
        uint256 startTime = block.timestamp;

        (uint256 verbId, uint256 amount, uint256 auctionStartTime, uint256 auctionEndTime, address payable bidder, bool settled) = auctionHouse.auction();
        assertEq(auctionStartTime, startTime, "Auction start time should be set correctly");
        assertEq(auctionEndTime, startTime + auctionHouse.duration(), "Auction end time should be set correctly");
        assertEq(verbId, 0, "Auction should be for the zeroth verb");
        assertEq(amount, 0, "Auction amount should be 0");
        assertEq(bidder, address(0), "Auction bidder should be 0");
        assertEq(settled, false, "Auction should not be settled");
    }

    function testBiddingProcess() public {
        setUp();
        createDefaultArtPiece();

        auctionHouse.unpause();
        uint256 bidAmount = auctionHouse.reservePrice() + 0.1 ether;
        vm.deal(address(1), bidAmount + 2 ether);

        vm.startPrank(address(1));
        auctionHouse.createBid{ value: bidAmount }(0); // Assuming the first auction's verbId is 0
        (uint256 verbId, uint256 amount, , uint256 endTime, address payable bidder, ) = auctionHouse.auction();

        assertEq(amount, bidAmount, "Bid amount should be set correctly");
        assertEq(bidder, address(1), "Bidder address should be set correctly");
        vm.stopPrank();

        vm.warp(endTime + 1);
        createDefaultArtPiece();

        auctionHouse.settleCurrentAndCreateNewAuction(); // This will settle the current auction and create a new one

        assertEq(verbs.ownerOf(verbId), address(1), "Verb should be transferred to the auction house");
    }

    function testSettlingAuctions() public {
        setUp();
        createDefaultArtPiece();
        auctionHouse.unpause();

        (uint256 verbId, , , uint256 endTime, , ) = auctionHouse.auction();
        assertEq(verbs.ownerOf(verbId), address(auctionHouse), "Verb should be transferred to the auction house");

        vm.warp(endTime + 1);
        createDefaultArtPiece();

        auctionHouse.settleCurrentAndCreateNewAuction(); // This will settle the current auction and create a new one

        (, , , , , bool settled) = auctionHouse.auction();

        assertEq(settled, false, "Auction should not be settled because new one created");
    }

    function testAdministrativeFunctions() public {
        uint256 newTimeBuffer = 10 minutes;
        auctionHouse.setTimeBuffer(newTimeBuffer);
        assertEq(auctionHouse.timeBuffer(), newTimeBuffer, "Time buffer should be updated correctly");

        uint256 newReservePrice = 2 ether;
        auctionHouse.setReservePrice(newReservePrice);
        assertEq(auctionHouse.reservePrice(), newReservePrice, "Reserve price should be updated correctly");

        uint8 newMinBidIncrementPercentage = 10;
        auctionHouse.setMinBidIncrementPercentage(newMinBidIncrementPercentage);
        assertEq(auctionHouse.minBidIncrementPercentage(), newMinBidIncrementPercentage, "Min bid increment percentage should be updated correctly");
    }

    function testAccessControl() public {
        vm.startPrank(address(1));
        vm.expectRevert();
        auctionHouse.pause();
        vm.stopPrank();

        vm.startPrank(address(1));
        vm.expectRevert();
        auctionHouse.unpause();
        vm.stopPrank();
    }
}

contract ContractWithoutReceiveOrFallback {
    // This contract intentionally does not have receive() or fallback()
    // functions to test the behavior of sending Ether to such a contract.
}
