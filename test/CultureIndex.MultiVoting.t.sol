// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {CultureIndex} from "../packages/revolution-contracts/CultureIndex.sol";
import {CultureIndexVotingTest} from "./CultureIndex.Voting.t.sol";
import {MockERC20} from "./MockERC20.sol";



contract CultureIndexVotingTestManager is Test {
    CultureIndexVotingTest public voter1Test;
    CultureIndexVotingTest public voter2Test;
    CultureIndex public cultureIndex;
    MockERC20 public mockVotingToken;
    

    function setUp() public {
        mockVotingToken = new MockERC20();
        cultureIndex = new CultureIndex(address(mockVotingToken), address(this));

        // Create new test instances acting as different voters
        voter1Test = new CultureIndexVotingTest(address(cultureIndex), address(mockVotingToken));
        voter2Test = new CultureIndexVotingTest(address(cultureIndex), address(mockVotingToken));
    }

    function testVotingWithDifferentWeights() public {
        uint256 newPieceId = voter1Test.createDefaultArtPiece();

        // Mint tokens to the test contracts (acting as voters)
        mockVotingToken._mint(address(voter1Test), 100);
        mockVotingToken._mint(address(voter2Test), 200);

        // Call vote from both test instances
        voter1Test.voteForPiece(newPieceId);
        voter2Test.voteForPiece(newPieceId);

        // Validate the weights
        CultureIndex.Vote memory pieceVotes1 = cultureIndex.getVote(
            newPieceId, address(voter1Test)
        );
        CultureIndex.Vote memory pieceVotes2 = cultureIndex.getVote(
            newPieceId, address(voter2Test)
        );
        uint256 totalVoteWeight = cultureIndex.totalVoteWeights(newPieceId);

        assertEq(
            pieceVotes1.voterAddress,
            address(voter1Test),
            "Voter address should match"
        );
        assertEq(pieceVotes1.weight, 100, "Voting weight should be 100");

        assertEq(
            pieceVotes2.voterAddress,
            address(voter2Test),
            "Voter address should match"
        );
        assertEq(pieceVotes2.weight, 200, "Voting weight should be 200");
        assertEq(totalVoteWeight, 300, "Total voting weight should be 300");
    }

    function testVoteOnMultiplePieces() public {
        setUp();
        uint256 firstPieceId = voter1Test.createDefaultArtPiece();
        uint256 secondPieceId = voter2Test.createDefaultArtPiece();

        // Mint tokens to a test contract (acting as a voter)
        mockVotingToken._mint(address(voter1Test), 100);

        // Call vote from the same test instance for both pieces
        voter1Test.voteForPiece(firstPieceId);
        voter1Test.voteForPiece(secondPieceId);

        // Validate the weights for the first piece
        CultureIndex.Vote memory firstPieceVote = cultureIndex.getVote(
            firstPieceId, address(voter1Test)
        );
        assertEq(
            firstPieceVote.voterAddress,
            address(voter1Test),
            "Voter address should match"
        );
        assertEq(firstPieceVote.weight, 100, "Voting weight for the first piece should be 100");

        // Validate the weights for the second piece
        CultureIndex.Vote memory secondPieceVote = cultureIndex.getVote(
            secondPieceId, address(voter1Test)
        );
        assertEq(
            secondPieceVote.voterAddress,
            address(voter1Test),
            "Voter address should match"
        );
        assertEq(secondPieceVote.weight, 100, "Voting weight for the second piece should be 100");
    }

}

