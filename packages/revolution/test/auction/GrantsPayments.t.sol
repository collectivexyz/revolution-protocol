// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { unsafeWadDiv, toDaysWadUnsafe } from "../../src/libs/SignedWadMath.sol";
import { RevolutionPointsEmitter } from "../../src/RevolutionPointsEmitter.sol";
import { IRevolutionPointsEmitter } from "../../src/interfaces/IRevolutionPointsEmitter.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { ProtocolRewards } from "@cobuild/protocol-rewards/src/ProtocolRewards.sol";
import { wadDiv } from "../../src/libs/SignedWadMath.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { AuctionHouseTest } from "./AuctionHouse.t.sol";
import { IRevolutionPoints } from "../../src/interfaces/IRevolutionPoints.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { console2 } from "forge-std/console2.sol";

contract GrantsPaymentsTest is AuctionHouseTest {
    //test that grants receives correct amount of ether
    function test_GrantsBalance(
        uint256 creatorRateBps,
        uint256 entropyRateBps,
        uint256 grantsRateBps,
        uint256 bidAmount
    ) public {
        // Assume valid rates
        creatorRateBps = bound(creatorRateBps, auction.minCreatorRateBps(), 10000);
        entropyRateBps = bound(entropyRateBps, 0, 10000);
        grantsRateBps = bound(grantsRateBps, 0, 10000 - creatorRateBps);
        bidAmount = bound(bidAmount, auction.reservePrice(), 1e12 ether);

        super.setUp();
        super.setMockParams();

        super.setAuctionParams(
            15 minutes, // timeBuffer
            1 ether, // reservePrice
            24 hours, // duration
            5, // minBidIncrementPercentage
            creatorRateBps, // creatorRateBps
            entropyRateBps, //entropyRateBps
            1_000, //minCreatorRateBps
            IRevolutionBuilder.GrantsParams({ totalRateBps: grantsRateBps, grantsAddress: grantsAddress })
        );

        super.deployMock();

        //expect grants balance to start out at 0
        assertEq(address(auction.grantsAddress()).balance, 0, "Balance should start at 0");

        createDefaultArtPiece();
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

        vm.stopPrank();

        vm.prank(auction.owner());
        auction.unpause();
        vm.deal(address(1), bidAmount + 2 ether);

        vm.prank(address(1));
        auction.createBid{ value: bidAmount }(0, address(1), address(0)); // Assuming the first auction's tokenId is 0
        (uint256 tokenId, uint256 amount, , uint256 endTime, address payable bidder, , ) = auction.auction();

        assertEq(amount, bidAmount, "Bid amount should be set correctly");
        assertEq(bidder, address(1), "Bidder address should be set correctly");

        vm.warp(endTime + 1);
        createDefaultArtPiece();
        // Ether going to owner of the auction

        uint256 grantsPayment = (bidAmount * grantsRateBps) / 10000;

        auction.settleCurrentAndCreateNewAuction(); // This will settle the current auction and create a new one

        //assert that grants balance is correct
        assertEq(
            uint(address(revolutionPointsEmitter.grantsAddress()).balance),
            grantsPayment,
            "Grants should have correct balance"
        );
    }

    // //ensure grants + founder rate can't be set to more than 10k when setGrantRateBps is called
    function test_SetGrantsRate(uint256 newGrantsRate) public {
        vm.startPrank(auction.owner());
        newGrantsRate = bound(newGrantsRate, 0, 10000 - auction.creatorRateBps());

        auction.setGrantsRateBps(newGrantsRate);
        vm.stopPrank();
        assertEq(auction.grantsRateBps(), newGrantsRate, "Grants rate should be set to 10000 - creatorRateBps");

        vm.startPrank(auction.owner());

        uint256 invalidGrantsRate = 10001 - auction.creatorRateBps();

        vm.expectRevert(abi.encodeWithSignature("INVALID_BPS()"));
        auction.setGrantsRateBps(invalidGrantsRate);
        vm.stopPrank();
        //ensure grants rate didn't change
        assertEq(auction.grantsRateBps(), newGrantsRate, "Grants rate should not have changed");
    }

    // test that grants + founder rate can't be set to more than 10k in initialization
    function test_InitializationGrantsFounderRateBounds(uint256 creatorRate, uint256 grantsRate) public {
        vm.stopPrank();
        super.setUp();
        super.setMockParams();

        creatorRate = bound(creatorRate, auction.minCreatorRateBps(), 10000);
        grantsRate = bound(grantsRate, 0, 10001);

        super.setAuctionParams(
            15 minutes, // timeBuffer
            1 ether, // reservePrice
            24 hours, // duration
            5, // minBidIncrementPercentage
            creatorRate, // creatorRateBps
            5_000, //entropyRateBps
            1_000, //minCreatorRateBps
            IRevolutionBuilder.GrantsParams({ totalRateBps: grantsRate, grantsAddress: grantsAddress })
        );

        if (grantsRate + creatorRate > 10000) {
            vm.expectRevert(abi.encodeWithSignature("INVALID_BPS()"));
        }
        super.deployMock();
    }
}
