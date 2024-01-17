// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { AuctionHouseTest } from "./AuctionHouse.t.sol";

contract AuctionHouseMintTest is AuctionHouseTest {
    function test__MintFailureDueToEmptyNFTList() public {
        // Pre-conditions setup to ensure the CultureIndex is empty
        vm.expectRevert(abi.encodeWithSignature("QUORUM_NOT_MET()"));
        auction.unpause();

        // Expect that the auction is paused due to error
        assertEq(auction.paused(), true, "Auction house should be paused");
    }

    function test__BehaviorOnMintFailureDuringAuctionCreation() public {
        //check auction paused emitted
        vm.expectRevert(abi.encodeWithSignature("QUORUM_NOT_MET()"));
        auction.unpause();

        (
            uint256 tokenId,
            uint256 amount,
            uint256 auctionStartTime,
            uint256 auctionEndTime,
            address payable bidder,
            address payable referral,
            bool settled
        ) = auction.auction();

        // Check that auction is not created
        assertEq(tokenId, 0);
        assertEq(amount, 0);
        assertEq(auctionStartTime, 0);
        assertEq(auctionEndTime, 0);
        assertEq(bidder, address(0));
        assertEq(settled, false);
    }
}
