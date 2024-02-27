// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { AuctionHouseTest } from "./AuctionHouse.t.sol";
import { IAuctionHouseEvents } from "../../src/interfaces/IAuctionHouse.sol";
import { wadMul, wadDiv } from "../../src/libs/SignedWadMath.sol";

contract AuctionHouseBasicTest is AuctionHouseTest {
    function testEventEmission(uint256 newCreatorRateBps, uint256 newEntropyRateBps) public {
        vm.startPrank(auction.owner());
        vm.assume(newCreatorRateBps > auction.minCreatorRateBps());
        vm.assume(newCreatorRateBps <= 10_000);
        vm.assume(newEntropyRateBps <= 10_000);

        // Expect events when changing creatorRateBps
        vm.expectEmit(true, true, true, true);
        emit IAuctionHouseEvents.CreatorRateBpsUpdated(newCreatorRateBps);
        auction.setCreatorRateBps(newCreatorRateBps);

        // Expect events when changing entropyRateBps
        vm.expectEmit(true, true, true, true);
        emit IAuctionHouseEvents.EntropyRateBpsUpdated(newEntropyRateBps);
        auction.setEntropyRateBps(newEntropyRateBps);
    }

    function test_BidEventEmission() public {
        //setup bid
        uint256 bidAmount = 100 ether;
        uint256 tokenId = createDefaultArtPiece();

        // roll
        vm.roll(vm.getBlockNumber() + 1);

        vm.prank(auction.owner());
        auction.unpause();
        vm.deal(address(1), bidAmount + 2 ether);
        vm.stopPrank();
        vm.prank(address(1));
        // Expect an event emission
        vm.expectEmit(true, true, true, true);
        emit IAuctionHouseEvents.AuctionBid(tokenId, address(21), address(1), bidAmount, false);
        auction.createBid{ value: bidAmount }(0, address(21), address(0)); // Assuming the first auction's tokenId is 0
    }

    function testSetEntropyRateBps(uint256 newEntropyRateBps) public {
        vm.startPrank(auction.owner());
        vm.assume(newEntropyRateBps <= 10_000);

        // Expect an event emission
        vm.expectEmit(true, true, true, true);
        emit IAuctionHouseEvents.EntropyRateBpsUpdated(newEntropyRateBps);

        // Update the rate
        auction.setEntropyRateBps(newEntropyRateBps);

        // Assert new rate
        assertEq(auction.entropyRateBps(), newEntropyRateBps);
    }

    function testSetEntropyRateBpsRestrictToOwner() public {
        uint256 newEntropyRateBps = 5000;

        // Attempt to change entropyRateBps as a non-owner
        vm.stopPrank();
        vm.startPrank(address(2));
        vm.expectRevert();
        auction.setEntropyRateBps(newEntropyRateBps);
        vm.stopPrank();
    }

    function testSetEntropyRateBpsInvalidValues(uint256 invalidEntropyRateBps) public {
        vm.startPrank(auction.owner());
        vm.assume(invalidEntropyRateBps > 10_000);

        uint256 oldEntropyRateBps = auction.entropyRateBps();

        // Attempt to set an invalid entropy rate
        vm.expectRevert(abi.encodeWithSignature("INVALID_BPS()"));
        auction.setEntropyRateBps(invalidEntropyRateBps);

        // Assert that the rate was not updated
        assertEq(auction.entropyRateBps(), oldEntropyRateBps);

        int256 invalidEntropyRateBps2 = -1; // Greater than 10,000

        // Attempt to set an invalid entropy rate
        vm.expectRevert();
        auction.setEntropyRateBps(uint256(invalidEntropyRateBps2));

        // Assert that the rate was not updated
        assertEq(auction.entropyRateBps(), oldEntropyRateBps);
    }

    function testSetMinCreatorRateBps(uint256 newMinCreatorRateBps, uint256 creatorRateBps) public {
        vm.startPrank(auction.owner());
        if (creatorRateBps > 10_000) {
            vm.expectRevert(abi.encodeWithSignature("INVALID_BPS()"));
        } else if (creatorRateBps < auction.minCreatorRateBps()) {
            vm.expectRevert(abi.encodeWithSignature("CREATOR_RATE_TOO_LOW()"));
        } else {
            // Expect an event emission
            vm.expectEmit(true, true, true, true);
            emit IAuctionHouseEvents.CreatorRateBpsUpdated(creatorRateBps);
        }
        auction.setCreatorRateBps(creatorRateBps);

        //if newMinCreatorRate is greater than creatorRateBps, then expect error
        if (newMinCreatorRateBps > auction.creatorRateBps()) {
            vm.expectRevert(abi.encodeWithSignature("MIN_CREATOR_RATE_ABOVE_CREATOR_RATE()"));
        } else if (newMinCreatorRateBps <= auction.minCreatorRateBps()) {
            vm.expectRevert(abi.encodeWithSignature("MIN_CREATOR_RATE_NOT_INCREASED()"));
        } else {
            // Expect an event emission
            vm.expectEmit(true, true, true, true);
            emit IAuctionHouseEvents.MinCreatorRateBpsUpdated(newMinCreatorRateBps);
        }
        // Update the minimum rate
        auction.setMinCreatorRateBps(newMinCreatorRateBps);

        // Assert new minimum rate
        if (newMinCreatorRateBps <= auction.creatorRateBps() && newMinCreatorRateBps >= auction.minCreatorRateBps()) {
            assertEq(auction.minCreatorRateBps(), newMinCreatorRateBps);
        }
    }

    function testSetMinCreatorRateBpsRestrictToOwner(uint256 newMinCreatorRateBps) public {
        vm.assume(newMinCreatorRateBps < auction.creatorRateBps());

        // Attempt to change minCreatorRateBps as a non-owner
        vm.startPrank(address(2));
        vm.expectRevert();
        auction.setMinCreatorRateBps(newMinCreatorRateBps);
        vm.stopPrank();
    }

    function testSetMinCreatorRateBpsInvalidValues(uint256 invalidMinCreatorRateBps) public {
        vm.startPrank(auction.owner());
        invalidMinCreatorRateBps = bound(invalidMinCreatorRateBps, 0, 10_000);

        // Attempt to set an invalid minimum creator rate
        if (uint256(invalidMinCreatorRateBps) <= auction.minCreatorRateBps()) {
            vm.expectRevert(abi.encodeWithSignature("MIN_CREATOR_RATE_NOT_INCREASED()"));
        } else if (uint256(invalidMinCreatorRateBps) > auction.creatorRateBps()) {
            vm.expectRevert(abi.encodeWithSignature("MIN_CREATOR_RATE_ABOVE_CREATOR_RATE()"));
        }
        auction.setMinCreatorRateBps(uint256(invalidMinCreatorRateBps));
    }

    function testMinCreatorRateLoweringRestriction(uint256 lowerMinCreatorRateBps) public {
        vm.startPrank(auction.owner());
        vm.assume(lowerMinCreatorRateBps < auction.minCreatorRateBps());

        // Attempt to set a lower minimum creator rate than the current one
        vm.expectRevert(abi.encodeWithSignature("MIN_CREATOR_RATE_NOT_INCREASED()"));
        auction.setMinCreatorRateBps(lowerMinCreatorRateBps);
    }

    function testValueUpdates(uint256 newCreatorRateBps, uint256 newEntropyRateBps) public {
        vm.assume(newCreatorRateBps > auction.minCreatorRateBps());
        vm.assume(newCreatorRateBps <= 10_000);
        vm.assume(newEntropyRateBps <= 10_000);

        // Change creatorRateBps as the owner
        vm.prank(auction.owner());
        auction.setCreatorRateBps(newCreatorRateBps);
        assertEq(auction.creatorRateBps(), newCreatorRateBps, "creatorRateBps should be updated");

        // Change entropyRateBps as the owner
        vm.prank(auction.owner());
        auction.setEntropyRateBps(newEntropyRateBps);
        assertEq(auction.entropyRateBps(), newEntropyRateBps, "entropyRateBps should be updated");
    }

    function testOwnerOnlyAccess() public {
        uint256 newCreatorRateBps = 2500;
        uint256 newEntropyRateBps = 6000;

        // Attempt to change creatorRateBps as a non-owner
        vm.stopPrank();
        vm.startPrank(address(2));
        vm.expectRevert();
        auction.setCreatorRateBps(newCreatorRateBps);
        vm.stopPrank();

        // Attempt to change entropyRateBps as a non-owner
        vm.startPrank(address(2));
        vm.expectRevert();
        auction.setEntropyRateBps(newEntropyRateBps);
        vm.stopPrank();
    }

    // Fallback function to allow contract to receive Ether
    receive() external payable {}

    function testInitializationParameters() public {
        assertEq(auction.WETH(), address(weth), "WETH address should be set correctly");
        assertEq(auction.timeBuffer(), 15 minutes, "Time buffer should be set correctly");
        assertEq(auction.reservePrice(), 1 ether, "Reserve price should be set correctly");
        assertEq(auction.minBidIncrementPercentage(), 5, "Min bid increment percentage should be set correctly");
        assertEq(auction.duration(), 24 hours, "Auction duration should be set correctly");
    }

    function test_BidForAnotherAccount() public {
        //setup bid
        uint256 bidAmount = 100 ether;
        uint256 tokenId = createDefaultArtPiece();

        // roll
        vm.roll(vm.getBlockNumber() + 1);

        vm.prank(auction.owner());
        auction.unpause();
        vm.deal(address(1), bidAmount + 2 ether);

        vm.stopPrank();

        // try to bid with bidder address(0) first and expect revert
        vm.expectRevert(abi.encodeWithSignature("ADDRESS_ZERO()"));
        vm.startPrank(address(1));
        auction.createBid{ value: bidAmount }(0, address(0), address(0)); // Assuming the first auction's tokenId is 0

        // Expect an event emission
        vm.expectEmit(true, true, true, true);
        emit IAuctionHouseEvents.AuctionBid(tokenId, address(21), address(1), bidAmount, false);
        auction.createBid{ value: bidAmount }(0, address(21), address(0)); // Assuming the first auction's tokenId is 0

        // Retrieve auction details once and perform all assertions
        (
            uint256 tokenId2,
            uint256 amount,
            uint256 startTime,
            uint256 endTime,
            address payable bidder,
            address payable referral,
            bool settled
        ) = auction.auction();

        // Expect auction tokenId to be 0
        assertEq(tokenId2, 0, "Auction should be for tokenId 0");

        // Expect auction amount to be bidAmount
        assertEq(amount, bidAmount, "Bid amount should be set correctly");

        // Expect auction bidder to be 21
        assertEq(bidder, address(21), "Bidder address should be set correctly");

        // Expect auction settled to be false
        assertEq(settled, false, "Auction should not be settled");

        // Expect auction startTime to be set correctly
        assertEq(startTime, block.timestamp, "Auction start time should be set correctly");

        // expect auction referral to be address(0)
        assertEq(referral, address(0), "Auction referral should be 0");

        // Expect auction endTime to be set correctly
        assertEq(endTime, block.timestamp + auction.duration(), "Auction end time should be set correctly");

        vm.warp(endTime + 1);

        createDefaultArtPiece();

        vm.roll(vm.getBlockNumber() + 1);

        auction.settleCurrentAndCreateNewAuction(); // This will settle the current auction and create a new one

        // Expect 21 to be the owner of the revolution token
        assertEq(
            revolutionToken.ownerOf(tokenId),
            address(21),
            "Revolution token should be transferred to bidder param"
        );
    }

    function test_AuctionCreation() public {
        createDefaultArtPiece();

        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

        vm.prank(auction.owner());
        auction.unpause();
        uint256 startTime = block.timestamp;

        (
            uint256 tokenId,
            uint256 amount,
            uint256 auctionStartTime,
            uint256 auctionEndTime,
            address payable bidder,
            address payable referral,
            bool settled
        ) = auction.auction();
        assertEq(auctionStartTime, startTime, "Auction start time should be set correctly");
        assertEq(auctionEndTime, startTime + auction.duration(), "Auction end time should be set correctly");
        assertEq(tokenId, 0, "Auction should be for the zeroth tokenId");
        assertEq(amount, 0, "Auction amount should be 0");
        assertEq(bidder, address(0), "Auction bidder should be 0");
        assertEq(settled, false, "Auction should not be settled");
        assertEq(referral, address(0), "Auction referral should be 0");
    }

    function test_BiddingProcess(uint256 bidAmount) public {
        vm.assume(bidAmount > auction.reservePrice());
        vm.assume(bidAmount < 10_000_000 ether);

        createDefaultArtPiece();

        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

        vm.prank(auction.owner());
        auction.unpause();
        vm.deal(address(1), bidAmount + 2 ether);

        vm.startPrank(address(1));
        auction.createBid{ value: bidAmount }(0, address(1), address(0)); // Assuming the first auction's tokenId is 0
        (uint256 tokenId, uint256 amount, , uint256 endTime, address payable bidder, , ) = auction.auction();

        assertEq(amount, bidAmount, "Bid amount should be set correctly");
        assertEq(bidder, address(1), "Bidder address should be set correctly");
        vm.stopPrank();

        vm.warp(endTime + 1);
        createDefaultArtPiece();
        // Ether going to owner of the auction
        uint256 auctioneerPayment = uint256(
            wadDiv(wadMul(int256(bidAmount), 10_000 - int256(auction.creatorRateBps())), 10_000)
        );

        //Total amount of ether going to creator
        uint256 creatorPayment = bidAmount - auctioneerPayment;

        //Ether reserved to pay the creator directly
        uint256 creatorDirectPayment = uint256(
            wadDiv(wadMul(int256(creatorPayment), int256(auction.entropyRateBps())), 10_000)
        );

        //Ether reserved to buy creator governance
        uint256 creatorGovernancePayment = creatorPayment - creatorDirectPayment;

        // create art piece
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1);

        auction.settleCurrentAndCreateNewAuction(); // This will settle the current auction and create a new one

        assertEq(
            revolutionToken.ownerOf(tokenId),
            address(1),
            "Revolution token should be transferred to the auction house"
        );
    }

    function testSettlingAuctions() public {
        createDefaultArtPiece();

        vm.roll(vm.getBlockNumber() + 1);

        vm.prank(auction.owner());
        auction.unpause();

        (uint256 tokenId, , , uint256 endTime, , , ) = auction.auction();
        assertEq(
            revolutionToken.ownerOf(tokenId),
            address(auction),
            "Revolution token should be transferred to the auction house"
        );

        vm.warp(endTime + 1);
        vm.roll(vm.getBlockNumber() + 1);

        uint256 pieceId = createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1);

        //vote for pieceId
        vm.startPrank(address(auction));
        cultureIndex.vote(pieceId);

        auction.settleCurrentAndCreateNewAuction(); // This will settle the current auction and create a new one

        (, , , , , , bool settled) = auction.auction();

        assertEq(settled, false, "Auction should not be settled because new one created");
    }

    function testAdministrativeFunctions(
        uint256 newTimeBuffer,
        uint256 newReservePrice,
        uint8 newMinBidIncrementPercentage
    ) public {
        newReservePrice = bound(newReservePrice, 1, 10_000_000 ether);

        vm.startPrank(auction.owner());
        auction.setTimeBuffer(newTimeBuffer);
        assertEq(auction.timeBuffer(), newTimeBuffer, "Time buffer should be updated correctly");

        auction.setReservePrice(newReservePrice);
        assertEq(auction.reservePrice(), newReservePrice, "Reserve price should be updated correctly");

        auction.setMinBidIncrementPercentage(newMinBidIncrementPercentage);
        assertEq(
            auction.minBidIncrementPercentage(),
            newMinBidIncrementPercentage,
            "Min bid increment percentage should be updated correctly"
        );
    }

    // set creator rate bps to 10000 while grants rate is also set to 1000 and expect revert
    function testSetCreatorRateBpsWithGrantsRate(uint256 newCreatorRateBps) public {
        vm.startPrank(auction.owner());
        vm.assume(newCreatorRateBps > auction.minCreatorRateBps());
        vm.assume(newCreatorRateBps <= 10_000);

        // set grants rate to 1000
        auction.setGrantsRateBps(1000);

        // Attempt to set creatorRateBps to 10000 while grants rate is also set to 1000
        vm.expectRevert(abi.encodeWithSignature("INVALID_CREATOR_RATE()"));
        auction.setCreatorRateBps(newCreatorRateBps);
    }

    function testAccessControl() public {
        vm.stopPrank();

        vm.startPrank(address(1));
        vm.expectRevert();
        auction.pause();
        vm.stopPrank();

        vm.startPrank(address(1));
        vm.expectRevert();
        auction.unpause();
        vm.stopPrank();
    }
}

contract ContractWithoutReceiveOrFallback {
    // This contract intentionally does not have receive() or fallback()
    // functions to test the behavior of sending Ether to such a contract.
}
