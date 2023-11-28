// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { CultureIndex } from "../../src/CultureIndex.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { NontransferableERC20Votes } from "../../src/NontransferableERC20Votes.sol";
import { CultureIndexTestSuite } from "./CultureIndex.t.sol";

/**
 * @title CultureIndexTest
 * @dev Test contract for CultureIndex
 */
contract CultureIndexVotingBasicTest is CultureIndexTestSuite {

    /**
     * @dev Test case to validate voting functionality
     *
     * We create a new art piece and cast a vote for it.
     * Then we validate the recorded vote and total voting weight.
     */
    function testVoting() public {
        setUp();
        uint256 newPieceId = createArtPiece("Mona Lisa", "A masterpiece", ICultureIndex.MediaType.IMAGE, "ipfs://legends", "", "", address(0x1), 10000);

        // Mint some tokens to the voter
        govToken.mint(address(this), 100);

        vm.roll(block.number + 1); // Roll forward to ensure votes are snapshotted

        // Cast a vote
        cultureIndex.vote(newPieceId);

        // Validate the vote
        ICultureIndex.Vote memory pieceVotes = cultureIndex.getVote(newPieceId, address(this));
        uint256 totalVoteWeight = cultureIndex.totalVoteWeights(newPieceId);

        assertEq(pieceVotes.voterAddress, address(this), "Voter address should match");
        assertEq(pieceVotes.weight, 100, "Voting weight should be 100");
        assertEq(totalVoteWeight, 100, "Total voting weight should be 100");
    }

    function testBatchVotingSuccess() public {
        // Preconditions setup
        uint256[] memory pieceIds = new uint256[](2);
        pieceIds[0] = createDefaultArtPiece();
        pieceIds[1] = createDefaultArtPiece();
        govToken.mint(address(this), 200);
        vm.roll(block.number + 1); // Roll forward to ensure votes are snapshotted

        // Perform batch voting
        cultureIndex.batchVote(pieceIds);

        // Assertions
        for (uint256 i = 0; i < pieceIds.length; i++) {
            ICultureIndex.Vote memory vote = cultureIndex.getVote(pieceIds[i], address(this));
            assertEq(vote.voterAddress, address(this), "Voter address should match");
            assertEq(vote.weight, 200, "Vote weight should be correct");
        }
    }

    function testBatchVotingFailsForInvalidPieceIds() public {
        uint256[] memory pieceIds = new uint256[](2);
        pieceIds[0] = 999; // Invalid pieceId
        pieceIds[1] = createDefaultArtPiece(); // Valid pieceId
        govToken.mint(address(this), 200);
        vm.roll(block.number + 1); // Roll forward to ensure votes are snapshotted

        // This should revert because one of the pieceIds is invalid
        try cultureIndex.batchVote(pieceIds) {
            fail("Batch voting with an invalid pieceId should fail");
        } catch Error(string memory reason) {
            assertEq(reason, "Invalid piece ID", "Should revert with invalid piece ID error");
        }
    }

    function testBatchVotingFailsIfAlreadyVoted() public {
        uint256 pieceId = createDefaultArtPiece();
        govToken.mint(address(this), 100);
        vm.roll(block.number + 1); // Roll forward to ensure votes are snapshotted

        cultureIndex.vote(pieceId); // Vote for the pieceId

        uint256[] memory pieceIds = new uint256[](1);
        pieceIds[0] = pieceId;

        // This should revert because the voter has already voted for this pieceId
        try cultureIndex.batchVote(pieceIds) {
            fail("Batch voting for an already voted pieceId should fail");
        } catch Error(string memory reason) {
            assertEq(reason, "Already voted", "Should revert with already voted error");
        }
    }

    function testBatchVotingFailsIfPieceDropped() public {
        uint256 pieceId = createDefaultArtPiece();
        govToken.mint(address(this), 100);
        vm.roll(block.number + 1); // Roll forward to ensure votes are snapshotted

        cultureIndex.dropTopVotedPiece(); // Drop the piece

        uint256[] memory pieceIds = new uint256[](1);
        pieceIds[0] = pieceId;

        // This should revert because the piece has been dropped
        try cultureIndex.batchVote(pieceIds) {
            fail("Batch voting for a dropped pieceId should fail");
        } catch Error(string memory reason) {
            assertEq(reason, "Piece has already been dropped", "Should revert with piece dropped error");
        }
    }

    function testBatchVotingFailsForZeroWeight() public {
        uint256[] memory pieceIds = new uint256[](1);
        pieceIds[0] = createDefaultArtPiece();
        vm.roll(block.number + 1); // Roll forward to ensure votes are snapshotted
        // Do not mint any tokens to ensure weight is zero

        // This should revert because the voter weight is zero
        try cultureIndex.batchVote(pieceIds) {
            fail("Batch voting with zero weight should fail");
        } catch Error(string memory reason) {
            assertEq(reason, "Weight must be greater than zero", "Should revert with weight zero error");
        }
    }

    function testGasUsage() public {
        // Assume createArtPiece() is a function that sets up an art piece and returns its ID
        uint256[] memory pieceIds = new uint256[](100);
        for (uint256 i = 0; i < 100; i++) {
            pieceIds[i] = createDefaultArtPiece(); // Setup each art piece
        }

        // Mint enough tokens for voting
        govToken.mint(address(this), 100 * 100); // Mint enough tokens (e.g., 100 tokens per vote)
        vm.roll(block.number + 1); // Roll forward to ensure votes are snapshotted

        // Measure gas for individual voting
        uint256 startGasIndividual = gasleft();
        for (uint256 i = 0; i < 100; i++) {
            cultureIndex.vote(pieceIds[i]);
        }
        uint256 gasUsedIndividual = startGasIndividual - gasleft();
        emit log_uint(gasUsedIndividual); // Log gas used for individual votes

        // Resetting state for a fair comparison
        setUp(); // Reset contract state (this would need to be implemented to revert to initial state)
        uint256[] memory batchPieceIds = new uint256[](100);
        for (uint256 i = 0; i < 100; i++) {
            batchPieceIds[i] = createDefaultArtPiece(); // Setup each art piece
        }

        govToken.mint(address(this), 100 * 100); // Mint enough tokens (e.g., 100 tokens per vote)
        vm.roll(block.number + 1); // Roll forward to ensure votes are snapshotted

        // Measure gas for batch voting
        uint256 startGasBatch = gasleft();
        cultureIndex.batchVote(batchPieceIds);
        uint256 gasUsedBatch = startGasBatch - gasleft();
        emit log_uint(gasUsedBatch); // Log gas used for batch votes

        // Log the difference in gas usage
        emit log_uint(gasUsedIndividual - gasUsedBatch); // This will log the saved gas
    }

    /**
     * @dev Test case to validate the "one vote per address" rule
     *
     * We create a new art piece and cast a vote for it.
     * Then we try to vote again and expect it to fail.
     */
    function testCannotVoteTwice() public {
        setUp();
        uint256 newPieceId = createArtPiece("Mona Lisa", "A masterpiece", ICultureIndex.MediaType.IMAGE, "ipfs://legends", "", "", address(0x1), 10000);

        // Mint some tokens to the voter
        govToken.mint(address(this), 100);
        vm.roll(block.number + 1); // Roll forward to ensure votes are snapshotted

        // Cast a vote
        cultureIndex.vote(newPieceId);

        // Try to vote again and expect to fail
        try cultureIndex.vote(newPieceId) {
            fail("Should not be able to vote twice");
        } catch Error(string memory reason) {
            assertEq(reason, "Already voted");
        }
    }

    /**
     * @dev Test case to validate that an address with no tokens cannot vote
     *
     * We create a new art piece and try to cast a vote without any tokens.
     * We expect the vote to fail.
     */
    function testCannotVoteWithoutTokens() public {
        setUp();
        uint256 newPieceId = createArtPiece("Starry Night", "A masterpiece", ICultureIndex.MediaType.IMAGE, "ipfs://legends", "", "", address(0x1), 10000);

        vm.roll(block.number + 1); // Roll forward to ensure votes are snapshotted

        // Try to vote and expect to fail
        try cultureIndex.vote(newPieceId) {
            fail("Should not be able to vote without tokens");
        } catch Error(string memory reason) {
            assertEq(reason, "Weight must be greater than zero");
        }
    }

    /**
     * @dev Test case to validate that a single address cannot vote twice on multiple pieces
     *
     * We create two new art pieces and cast a vote for each.
     * Then we try to vote again for both and expect both to fail.
     */
    function testCannotVoteOnMultiplePiecesTwice() public {
        setUp();
        uint256 firstPieceId = createArtPiece("Mona Lisa", "A masterpiece", ICultureIndex.MediaType.IMAGE, "ipfs://legends", "", "", address(0x1), 10000);

        uint256 secondPieceId = createArtPiece("Starry Night", "Another masterpiece", ICultureIndex.MediaType.IMAGE, "ipfs://starrynight", "", "", address(0x2), 10000);

        // Mint some tokens to the voter
        govToken.mint(address(this), 200);
        vm.roll(block.number + 1); // Roll forward to ensure votes are snapshotted

        // Cast a vote for the first piece
        cultureIndex.vote(firstPieceId);

        // Cast a vote for the second piece
        cultureIndex.vote(secondPieceId);

        // Try to vote again for the first piece and expect to fail
        try cultureIndex.vote(firstPieceId) {
            fail("Should not be able to vote twice on the first piece");
        } catch Error(string memory reason) {
            assertEq(reason, "Already voted");
        }

        // Try to vote again for the second piece and expect to fail
        try cultureIndex.vote(secondPieceId) {
            fail("Should not be able to vote twice on the second piece");
        } catch Error(string memory reason) {
            assertEq(reason, "Already voted");
        }
    }

    /**
     * @dev Test case to validate that an address with no tokens cannot vote on multiple pieces
     *
     * We create two new art pieces and try to cast a vote for each without any tokens.
     * We expect both votes to fail.
     */
    function testCannotVoteWithoutTokensMultiplePieces() public {
        setUp();
        uint256 firstPieceId = createArtPiece("Mona Lisa", "A masterpiece", ICultureIndex.MediaType.IMAGE, "ipfs://legends", "", "", address(0x1), 10000);

        uint256 secondPieceId = createArtPiece("Starry Night", "Another masterpiece", ICultureIndex.MediaType.IMAGE, "ipfs://starrynight", "", "", address(0x2), 10000);
        vm.roll(block.number + 1); // Roll forward to ensure votes are snapshotted

        // Try to vote for the first piece and expect to fail
        try cultureIndex.vote(firstPieceId) {
            fail("Should not be able to vote without tokens on the first piece");
        } catch Error(string memory reason) {
            assertEq(reason, "Weight must be greater than zero");
        }

        // Try to vote for the second piece and expect to fail
        try cultureIndex.vote(secondPieceId) {
            fail("Should not be able to vote without tokens on the second piece");
        } catch Error(string memory reason) {
            assertEq(reason, "Weight must be greater than zero");
        }
    }

    function testVoteAfterTransferringTokens() public {
        setUp();
        uint256 newPieceId = createDefaultArtPiece();

        // Mint tokens and vote
        govToken.mint(address(this), 100);
        vm.roll(block.number + 1); // Roll forward to ensure votes are snapshotted

        cultureIndex.vote(newPieceId);

        // Transfer all tokens to another account
        address anotherAccount = address(0x4);
        govToken.transfer(anotherAccount, 100);

        vm.prank(anotherAccount);

        // Try to vote again and expect to fail
        try cultureIndex.vote(newPieceId) {
            fail("Should not be able to vote without tokens");
        } catch Error(string memory reason) {
            emit log_string(reason);
            assertEq(reason, "Weight must be greater than zero");
        }
    }

    function testInvalidPieceID() public {
        setUp();

        // Mint some tokens to the voter
        govToken.mint(address(this), 100);
        vm.roll(block.number + 1); // Roll forward to ensure votes are snapshotted

        // Attempt to vote for an invalid piece ID
        try cultureIndex.vote(9999) {
            // Assuming 9999 is an invalid ID
            fail("Should not be able to vote for an invalid piece ID");
        } catch Error(string memory reason) {
            assertEq(reason, "Invalid piece ID");
        }
    }

    /**
     * @dev Test case to validate that voting on a dropped piece fails.
     *
     * We create a new art piece, drop it, and then try to cast a vote for it.
     * We expect the vote to fail since the piece has been dropped.
     */
    function testCannotVoteOnDroppedPiece() public {
        setUp();

        uint256 newPieceId = createDefaultArtPiece();
        govToken.mint(address(this), 100);
        vm.roll(block.number + 1); // Roll forward to ensure votes are snapshotted

        // Drop the top-voted piece (which should be the new piece)
        cultureIndex.dropTopVotedPiece();

        // Try to vote for the dropped piece and expect to fail
        try cultureIndex.vote(newPieceId) {
            fail("Should not be able to vote on a dropped piece");
        } catch Error(string memory reason) {
            assertEq(reason, "Piece has already been dropped");
        }
    }
}

contract CultureIndexVotingTest is Test {
    CultureIndex public cultureIndex;
    MockERC20 public mockVotingToken;

    constructor(address _cultureIndex, address _mockVotingToken) {
        cultureIndex = CultureIndex(_cultureIndex);
        mockVotingToken = MockERC20(_mockVotingToken);
    }

    // Utility function to create a new art piece and return its ID
    function createArtPiece(
        string memory name,
        string memory description,
        ICultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl,
        address creatorAddress,
        uint256 creatorBps
    ) internal returns (uint256) {
        ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex.ArtPieceMetadata({
            name: name,
            description: description,
            mediaType: mediaType,
            image: image,
            text: text,
            animationUrl: animationUrl
        });

        ICultureIndex.CreatorBps[] memory creators = new ICultureIndex.CreatorBps[](1);
        creators[0] = ICultureIndex.CreatorBps({ creator: creatorAddress, bps: creatorBps });

        return cultureIndex.createPiece(metadata, creators);
    }

    //Utility function to create default art piece
    function createDefaultArtPiece() public returns (uint256) {
        return createArtPiece("Mona Lisa", "A masterpiece", ICultureIndex.MediaType.IMAGE, "ipfs://legends", "", "", address(0x1), 10000);
    }

    function voteForPiece(uint256 pieceId) public {
        cultureIndex.vote(pieceId);
    }
}
