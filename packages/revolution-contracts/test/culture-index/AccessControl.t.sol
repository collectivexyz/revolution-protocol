// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { VerbsToken } from "../../src/VerbsToken.sol";
import { IVerbsToken } from "../../src/interfaces/IVerbsToken.sol";
import { IVerbsDescriptorMinimal } from "../../src/interfaces/IVerbsDescriptorMinimal.sol";
import { IProxyRegistry } from "../../src/external/opensea/IProxyRegistry.sol";
import { ICultureIndex, ICultureIndexEvents } from "../../src/interfaces/ICultureIndex.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { CultureIndex } from "../../src/CultureIndex.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { VerbsDescriptor } from "../../src/VerbsDescriptor.sol";
import "../utils/Base64Decode.sol";
import "../utils/JsmnSolLib.sol";
import { CultureIndexTestSuite } from "./CultureIndex.t.sol";
import { ERC721Checkpointable } from "../../src/base/ERC721Checkpointable.sol";

/// @title VerbsTokenTest
/// @dev The test suite for the VerbsToken contract
contract CultureIndexAccessControlTest is CultureIndexTestSuite {
    /// @dev Tests minting by non-minter should revert
    function testRevertOnNonOwnerUpdateVotingToken() public {
        address nonMinter = address(0xABC); // This is an arbitrary address
        vm.startPrank(nonMinter);

        vm.expectRevert();
        cultureIndex.setERC721VotingToken(verbs);

        vm.stopPrank();
    }

    /// @dev Tests the locking of admin functions
    function testLockAdminFunctions() public {
        // Lock the ERC721VotingToken
        cultureIndex.lockERC721VotingToken();

        // Attempt to change minter, descriptor, or cultureIndex and expect to fail

        try cultureIndex.setERC721VotingToken(verbs) {
            fail("Should fail: ERC721VotingToken is locked");
        } catch {}

        assertTrue(cultureIndex.isERC721VotingTokenLocked(), "ERC721VotingToken should be locked");
    }

    /// @dev Tests that only the owner can lock the ERC721 voting token
    function testOnlyOwnerCanLockERC721VotingToken() public {
        address nonOwner = address(0x123); // This is an arbitrary address
        vm.startPrank(nonOwner);

        vm.expectRevert();
        cultureIndex.lockERC721VotingToken();

        vm.stopPrank();

        vm.startPrank(address(this));
        vm.expectEmit(true, true, true, true);
        emit ICultureIndexEvents.ERC721VotingTokenLocked();
        cultureIndex.lockERC721VotingToken();
        vm.stopPrank();

        assertTrue(cultureIndex.isERC721VotingTokenLocked(), "ERC721VotingToken should be locked by owner only");
    }

    /// @dev Tests only the owner can update the ERC721 voting token
    function testSetERC721VotingToken() public {
        address newTokenAddress = address(0x123); // New ERC721 token address
        ERC721Checkpointable newToken = ERC721Checkpointable(newTokenAddress);

        // Attempting update by a non-owner should revert
        address nonOwner = address(0xABC);
        vm.startPrank(nonOwner);
        vm.expectRevert();
        cultureIndex.setERC721VotingToken(newToken);
        vm.stopPrank();

        // Update by owner should succeed
        vm.startPrank(address(this));
        cultureIndex.setERC721VotingToken(newToken);
        assertEq(address(cultureIndex.erc721VotingToken()), newTokenAddress);
        vm.stopPrank();
    }

    function testSetQuorumVotesBPSWithinRange(uint104 newQuorumBPS) public {
        vm.assume(newQuorumBPS >= cultureIndex.MIN_QUORUM_VOTES_BPS() && newQuorumBPS <= cultureIndex.MAX_QUORUM_VOTES_BPS());

        // Set new quorum BPS by owner
        vm.startPrank(address(this));
        cultureIndex._setQuorumVotesBPS(newQuorumBPS);
        vm.stopPrank();

        // Check if the quorum BPS is updated correctly
        uint256 currentQuorumBPS = cultureIndex.quorumVotesBPS();
        assertEq(currentQuorumBPS, newQuorumBPS, "Quorum BPS should be updated within valid range");
    }
    function testSetQuorumVotesBPSOutsideRange(uint104 newQuorumBPS) public {
        uint256 currentQuorumBPS = cultureIndex.quorumVotesBPS();
        vm.assume(newQuorumBPS < cultureIndex.MIN_QUORUM_VOTES_BPS() || newQuorumBPS > cultureIndex.MAX_QUORUM_VOTES_BPS());

        // Set new quorum BPS by owner
        vm.startPrank(address(this));
        vm.expectRevert("CultureIndex::_setProposalThreshold: invalid proposal threshold");
        cultureIndex._setQuorumVotesBPS(newQuorumBPS);
        vm.stopPrank();

        // Check if the quorum BPS is updated correctly
        assertEq(cultureIndex.quorumVotesBPS(), currentQuorumBPS, "Quorum BPS should be updated within valid range");
    }
    function testRevertNonOwnerSetQuorumVotesBPS() public {
        address nonOwner = address(0x123); // An arbitrary non-owner address
        uint256 newQuorumBPS = 3000; // A valid quorum BPS value

        // Attempt to set new quorum BPS by non-owner and expect revert
        vm.startPrank(nonOwner);
        vm.expectRevert();
        cultureIndex._setQuorumVotesBPS(newQuorumBPS);
        vm.stopPrank();
    }

    function testDropTopVotedPieceOnlyIfQuorumIsMet(uint256 quorumBps) public {
        vm.assume(quorumBps >= cultureIndex.MIN_QUORUM_VOTES_BPS() && quorumBps <= cultureIndex.MAX_QUORUM_VOTES_BPS());

        // Set quorum BPS
        vm.startPrank(address(this));
        cultureIndex._setQuorumVotesBPS(quorumBps);
        vm.stopPrank();

        govToken.mint(address(0x21), quorumBps * 10);
        govToken.mint(address(this), (quorumBps / 2) * (quorumBps) / 10_000);

        vm.roll(block.number + 1);

        // Create an art piece
        uint256 pieceId = createDefaultArtPiece();

        vm.roll(block.number + 1);

        // Vote for the piece, but do not meet the quorum
        cultureIndex.vote(pieceId);

        // Attempt to drop the top-voted piece and expect it to fail
        vm.expectRevert("Piece must have quorum votes in order to be dropped.");
        cultureIndex.dropTopVotedPiece();

        // Additional votes to meet/exceed the quorum
        vm.startPrank(address(0x21));
        cultureIndex.vote(pieceId);
        vm.stopPrank();

        // Attempt to drop the top-voted piece, should succeed
        ICultureIndex.ArtPiece memory droppedPiece = cultureIndex.dropTopVotedPiece();
        assertTrue(droppedPiece.isDropped, "Top voted piece should be dropped");
    }

    function testCalculateVoteWeight(uint200 erc20Balance, uint40 erc721Balance) public {
        vm.assume(erc20Balance > 0);
        vm.assume(erc721Balance < 1_000);
        govToken.mint(address(this), erc20Balance);

        vm.roll(block.number + 1);

        cultureIndex.transferOwnership(address(verbs));

        // Create art pieces and drop them
        for (uint256 i = 0; i < erc721Balance; i++) {
            createDefaultArtPiece();
            vm.roll(block.number + 1);
            cultureIndex.vote(i);
            verbs.mint();
        }

        // Calculate expected vote weight
        uint256 expectedVoteWeight = erc20Balance + (erc721Balance * cultureIndex.erc721VotingTokenWeight() * 1e18);

        // Get the actual vote weight from the contract
        uint256 actualVoteWeight = cultureIndex.getCurrentVotes(address(this));

        // Assert that the actual vote weight matches the expected value
        assertEq(actualVoteWeight, expectedVoteWeight, "Vote weight calculation does not match expected value");
    }


    function testQuorumVotesCalculation(uint200 erc20TotalSupply, uint256 erc721TotalSupply) public {
        vm.assume(erc20TotalSupply > 0);
        vm.assume(erc721TotalSupply < 1_000);
        // Initial settings
        uint256 quorumBPS = cultureIndex.quorumVotesBPS();         // Example quorum BPS (20%)

        // Set the quorum BPS
        vm.startPrank(address(this));
        cultureIndex._setQuorumVotesBPS(quorumBPS);
        vm.stopPrank();


        cultureIndex.transferOwnership(address(verbs));

        // Set the ERC20 and ERC721 total supplies
        govToken.mint(address(this), erc20TotalSupply);

        vm.roll(block.number + 1);

        //for desired erc721 supply, loop create art pieces and drop them
        for (uint256 i = 0; i < erc721TotalSupply; i++) {
            createDefaultArtPiece();
            vm.roll(block.number + 1);
            cultureIndex.vote(i);
            verbs.mint();
        }

        // Calculate expected quorum votes
        uint256 expectedQuorumVotes = (quorumBPS * (erc20TotalSupply + erc721TotalSupply * 1e18 * cultureIndex.erc721VotingTokenWeight())) / 10_000;

        // Get the quorum votes from the contract
        uint256 actualQuorumVotes = cultureIndex.quorumVotes();

        // Assert that the actual quorum votes match the expected value
        assertEq(actualQuorumVotes, expectedQuorumVotes, "Quorum votes calculation does not match expected value");
    }
}

contract ProxyRegistry is IProxyRegistry {
    mapping(address => address) public proxies;
}
