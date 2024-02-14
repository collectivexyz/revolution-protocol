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

contract ManifestosTest is AuctionHouseTest {
    function test__NoBids_SettlingAuctionEmptyManifesto() public {
        uint256 tokenId = createDefaultArtPiece();
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot
        vm.prank(auction.owner());

        auction.unpause();

        vm.warp(block.timestamp + auction.duration()); // Fast forward time to end the auction

        // Assuming revolutionToken.burn is called for auctions with no bids
        vm.expectEmit(true, true, true, true);
        emit IRevolutionToken.RevolutionTokenBurned(tokenId);

        auction.settleCurrentAndCreateNewAuction();

        (address member, string memory speech) = auction.manifestos(tokenId);

        // assert manifestos[0] is empty and set to zero address
        assertEq(speech, "", "Manifesto speech should be empty");
        assertEq(member, address(0), "Manifesto member should be zero address");
    }

    function test__Bids_SettlingAuctionEmptyManifesto() public {
        uint256 tokenId = createDefaultArtPiece();
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot
        vm.prank(auction.owner());

        auction.unpause();

        address bidder = makeAddr("bidder");

        auction.createBid{ value: 1 ether }(0, bidder, address(0));

        vm.warp(block.timestamp + auction.duration()); // Fast forward time to end the auction

        auction.settleCurrentAndCreateNewAuction();

        (address member, string memory speech) = auction.manifestos(tokenId);

        // assert manifestos[0] is empty and set to zero address
        assertEq(speech, "", "Manifesto speech should be empty");
        assertEq(member, bidder, "Manifesto member should be the bidder");
    }
}
