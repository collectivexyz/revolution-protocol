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
import { IRevolutionToken } from "../../src/interfaces/IRevolutionToken.sol";
import { IAuctionHouse } from "../../src/interfaces/IAuctionHouse.sol";

contract HistoricPriceTest is AuctionHouseTest {
    function calculateAmountPaidToOwner(uint256 amount) public view returns (uint256) {
        // subtract auction.computeTotalReward
        amount = amount - auction.computeTotalReward(amount);

        // Accessing creatorRateBps and grantsRateBps from the auction contract
        uint256 creatorRateBps = auction.creatorRateBps();
        uint256 grantsRateBps = auction.grantsRateBps();

        uint256 creatorShare = (amount * creatorRateBps) / 10_000;
        uint256 grantsShare = (amount * grantsRateBps) / 10_000;
        uint256 amountPaidToOwner = amount - creatorShare - grantsShare;
        return amountPaidToOwner;
    }

    function test__HistoricPriceSaved() public {
        uint256 tokenId = createDefaultArtPiece();
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot
        vm.prank(auction.owner());
        auction.unpause();

        address bidder = makeAddr("bidder");

        auction.createBid{ value: 1.1 ether }(0, bidder, address(0));

        vm.warp(block.timestamp + auction.duration()); // Fast forward time to end the auction

        auction.settleCurrentAndCreateNewAuction();

        // ensure auctions mapping by tokenId contains the historic price
        (uint256 historicalPrice, address winner, uint256 amountPaidToOwner) = auction.auctions(tokenId);
        assertEq(historicalPrice, 1.1 ether, "Auction history should contain the historic price");
        assertEq(winner, bidder, "Auction history winner should be the bidder");
        assertEq(
            amountPaidToOwner,
            calculateAmountPaidToOwner(1.1 ether),
            "Auction history amountPaidToOwner should be correct"
        );

        IAuctionHouse.AuctionHistory memory historicalData = auction.getPastAuction(tokenId);
        assertEq(historicalData.amount, 1.1 ether, "Auction history should contain the historic price");
        assertEq(historicalData.winner, bidder, "Auction history winner should be the bidder");
    }

    // create multiple auctions and then make sure the historic prices are saved
    function test__MultipleHistoricPricesSaved() public {
        // mint revolutionpoints to newOwner
        vm.prank(revolutionPoints.minter());
        revolutionPoints.mint(address(this), 10 ether);

        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

        uint256 tokenId1 = createDefaultArtPiece();
        uint256 tokenId2 = createDefaultArtPiece();
        uint256 tokenId3 = createDefaultArtPiece();

        //vote for the art pieces
        cultureIndex.vote(tokenId1);
        cultureIndex.vote(tokenId2);
        cultureIndex.vote(tokenId3);

        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot
        vm.prank(auction.owner());
        auction.unpause();

        address bidder = makeAddr("bidder");

        auction.createBid{ value: 1.1 ether }(0, bidder, address(0));

        vm.warp(block.timestamp + auction.duration()); // Fast forward time to end the auction

        auction.settleCurrentAndCreateNewAuction();

        auction.createBid{ value: 1.2 ether }(1, bidder, address(0));

        vm.warp(block.timestamp + auction.duration()); // Fast forward time to end the auction

        auction.settleCurrentAndCreateNewAuction();

        // ensure auctions mapping by tokenId contains the historic price
        (uint256 historicalPrice1, address winner1, uint256 amountPaidToOwner1) = auction.auctions(tokenId1);
        (uint256 historicalPrice2, address winner2, uint256 amountPaidToOwner2) = auction.auctions(tokenId2);
        assertEq(historicalPrice1, 1.1 ether, "Auction history should contain the historic price");
        assertEq(historicalPrice2, 1.2 ether, "Auction history should contain the historic price");
        assertEq(winner1, bidder, "Auction history winner should be the bidder");
        assertEq(winner2, bidder, "Auction history winner should be the bidder");
        assertEq(
            amountPaidToOwner1,
            calculateAmountPaidToOwner(1.1 ether),
            "Auction history amountPaidToOwner should be correct"
        );
        assertEq(
            amountPaidToOwner2,
            calculateAmountPaidToOwner(1.2 ether),
            "Auction history amountPaidToOwner should be correct"
        );

        // ensure tokenId 3 has no historic price
        (uint256 historicalPrice3, address winner3, uint256 amountPaidToOwner3) = auction.auctions(tokenId3);
        assertEq(historicalPrice3, 0, "Auction history should contain the historic price");
        assertEq(winner3, address(0), "Auction history winner should be 0");
        assertEq(amountPaidToOwner3, calculateAmountPaidToOwner(0), "Auction history amountPaidToOwner should be 0");
    }

    // ensure if token burned because no bids, historic price is still 0
    function test__HistoricPriceBurned() public {
        uint256 tokenId = createDefaultArtPiece();
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot
        vm.prank(auction.owner());
        auction.unpause();

        vm.warp(block.timestamp + auction.duration()); // Fast forward time to end the auction

        auction.settleCurrentAndCreateNewAuction();

        // ensure auctions mapping by tokenId contains the historic price
        (uint256 historicalPrice, address winner, uint256 amountPaidToOwner) = auction.auctions(tokenId);
        assertEq(historicalPrice, 0, "Auction history should contain the historic price");
        assertEq(winner, address(0), "Auction history winner should be 0");
        assertEq(amountPaidToOwner, calculateAmountPaidToOwner(0), "Auction history amountPaidToOwner should be 0");
    }

    // ensure historical price is not sent if the vrb is burned because below reserve price
    function test__HistoricPriceBurnedBelowReserve() public {
        vm.prank(address(executor));
        auction.setReservePrice(1 ether);

        uint256 tokenId = createDefaultArtPiece();
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot
        vm.prank(auction.owner());
        auction.unpause();

        address bidder = makeAddr("bidder");

        auction.createBid{ value: 1 ether }(0, bidder, address(0));

        // now set higher reserve price
        vm.prank(address(executor));
        auction.setReservePrice(2 ether);

        vm.warp(block.timestamp + auction.duration()); // Fast forward time to end the auction

        auction.settleCurrentAndCreateNewAuction();

        // ensure auctions mapping by tokenId contains the historic price
        (uint256 historicalPrice, address winner, uint256 amountPaidToOwner) = auction.auctions(tokenId);
        assertEq(historicalPrice, 0, "Auction history should contain the historic price");
        assertEq(winner, address(0), "Auction history winner should be 0");
        assertEq(amountPaidToOwner, calculateAmountPaidToOwner(0), "Auction history amountPaidToOwner should be 0");
    }
}
