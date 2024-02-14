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

    function test__Bids_SettlingAuctionAndSettingManifesto() public {
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

        string
            memory newSpeech = "I believe in the power of the revolution. I am here to make a change and I will do whatever it takes to make it happen.";

        vm.prank(bidder);
        auction.updateManifesto(tokenId, newSpeech);

        (member, speech) = auction.manifestos(tokenId);

        assertEq(speech, newSpeech, "Manifesto speech should be the new speech");
        assertEq(member, bidder, "Manifesto member should be the bidder");
    }

    function test__Bids_UpdateManifesto_NotInitialOwner() public {
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

        string
            memory newSpeech = "I believe in the power of the revolution. I am here to make a change and I will do whatever it takes to make it happen.";

        vm.expectRevert(abi.encodeWithSignature("NOT_INITIAL_TOKEN_OWNER()"));
        auction.updateManifesto(tokenId, newSpeech);
    }

    function test__TransferToken_UpdateManifesto_NotInitialOwner() public {
        uint256 tokenId = createDefaultArtPiece();
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot
        vm.prank(auction.owner());

        auction.unpause();

        address bidder = makeAddr("bidder");
        address newOwner = makeAddr("newOwner");

        auction.createBid{ value: 1 ether }(0, bidder, address(0));

        vm.warp(block.timestamp + auction.duration()); // Fast forward time to end the auction

        auction.settleCurrentAndCreateNewAuction();

        // Transfer the token to simulate change in ownership
        vm.prank(bidder);
        revolutionToken.transferFrom(bidder, newOwner, tokenId);

        string memory newSpeech = "Change is the only constant.";

        // Expect revert due to not being the initial token owner anymore
        vm.expectRevert(abi.encodeWithSignature("NOT_INITIAL_TOKEN_OWNER()"));
        auction.updateManifesto(tokenId, newSpeech);
    }

    function test_MultipleAuctions_ManifestosEmpty_CorrectWinner_SetAndVerifyLast() public {
        uint256 numberOfAuctions = 5;
        address[] memory winners = new address[](numberOfAuctions);

        uint256 tokenId = createDefaultArtPiece();

        address newOwner = makeAddr("newOwner");

        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

        vm.prank(auction.owner());
        auction.unpause();

        // mint revolutionpoints to newOwner
        vm.prank(revolutionPoints.minter());
        revolutionPoints.mint(newOwner, 10 ether);

        // Create and settle multiple auctions, storing winners
        for (uint256 i = 0; i < numberOfAuctions; i++) {
            address bidder = makeAddr(string(abi.encodePacked("bidder", i)));

            vm.roll(vm.getBlockNumber() + 2); // roll block number to enable voting snapshot

            winners[i] = bidder;

            auction.createBid{ value: 1 ether }(i, bidder, address(0));
            vm.warp(block.timestamp + auction.duration()); // Fast forward time to end the auction

            tokenId = createDefaultArtPiece();
            vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

            vm.prank(newOwner);
            cultureIndex.vote(tokenId);

            vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

            auction.settleCurrentAndCreateNewAuction();
        }

        // Verify all manifestos are empty but have the correct winner
        for (uint256 i = 0; i < numberOfAuctions; i++) {
            (address member, string memory speech) = auction.manifestos(i);
            assertEq(speech, "", "Manifesto speech should be empty");
            assertEq(member, winners[i], "Manifesto member should be the correct winner");
        }

        // Set and verify the last auction's manifesto
        string memory finalSpeech = "Together, we shape the future.";
        vm.prank(winners[numberOfAuctions - 1]);
        auction.updateManifesto(numberOfAuctions - 1, finalSpeech);
        (address finalMember, string memory finalManifestoSpeech) = auction.manifestos(numberOfAuctions - 1);
        assertEq(finalManifestoSpeech, finalSpeech, "Final manifesto speech should match");
        assertEq(finalMember, winners[numberOfAuctions - 1], "Final manifesto member should be the last winner");
    }

    function test__UpdateManifesto() public {
        uint256 tokenId = createDefaultArtPiece();
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot
        vm.prank(auction.owner());
        auction.unpause();

        address bidder = makeAddr("bidder");

        auction.createBid{ value: 1 ether }(0, bidder, address(0));

        vm.warp(block.timestamp + auction.duration()); // Fast forward time to end the auction

        auction.settleCurrentAndCreateNewAuction();

        // Verify the acceptance speech for the new member
        string memory acceptanceSpeech = "Change is the end result of all true learning.";
        vm.prank(bidder);
        auction.updateManifesto(tokenId, acceptanceSpeech);
        (address manifestoMember, string memory manifestoSpeech) = auction.manifestos(tokenId);
        assertEq(manifestoSpeech, acceptanceSpeech, "Acceptance speech should match");
        assertEq(manifestoMember, bidder, "Manifesto member should be the new owner");
    }
}
