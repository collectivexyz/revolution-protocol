// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {CultureIndex} from "../packages/revolution-contracts/CultureIndex.sol";
import {MockERC20} from "./MockERC20.sol";

/**
 * @title CultureIndexTest
 * @dev Test contract for CultureIndex
 */
contract CultureIndexTest is Test {
    CultureIndex public cultureIndex;
    MockERC20 public mockVotingToken;

    /**
     * @dev Setup function for each test case
     */
    function setUp() public {
        // Initialize your mock ERC20 token here, if needed
        mockVotingToken = new MockERC20();

        // Initialize your CultureIndex contract
        cultureIndex = new CultureIndex(address(mockVotingToken));
    }

    /**
     * @dev Test case to validate art piece creation functionality
     *
     * We create a new art piece with given metadata and creators.
     * Then we fetch the created art piece by its ID and assert
     * its properties to ensure they match what was set.
     */
    function testCreatePiece() public {
        setUp();

        CultureIndex.ArtPieceMetadata memory metadata = CultureIndex
            .ArtPieceMetadata({
                name: "Mona Lisa",
                description: "A masterpiece",
                mediaType: CultureIndex.MediaType.IMAGE,
                image: "ipfs://legends",
                text: "",
                animationUrl: ""
            });

        CultureIndex.CreatorBps[]
            memory creators = new CultureIndex.CreatorBps[](1);
        creators[0] = CultureIndex.CreatorBps({
            creator: address(0x1),
            bps: 10000
        });

        uint256 newPieceId = cultureIndex.createPiece(metadata, creators);

        // Validate that the piece was created with correct data
        CultureIndex.ArtPiece memory createdPiece = cultureIndex.getPieceById(
            newPieceId
        );

        assertEq(createdPiece.id, newPieceId);
        assertEq(createdPiece.metadata.name, "Mona Lisa");
        assertEq(createdPiece.metadata.description, "A masterpiece");
        assertEq(createdPiece.metadata.image, "ipfs://legends");
        assertEq(createdPiece.creators[0].creator, address(0x1));
        assertEq(createdPiece.creators[0].bps, 10000);
    }

    /**
     * @dev Test case to validate voting functionality
     *
     * We create a new art piece and cast a vote for it.
     * Then we validate the recorded vote and total voting weight.
     */
    function testVoting() public {
        setUp();
        uint256 newPieceId = createArtPiece(
            "Mona Lisa",
            "A masterpiece",
            CultureIndex.MediaType.IMAGE,
            "ipfs://legends",
            "",
            "",
            address(0x1),
            10000
        );

        // Mint some tokens to the voter
        mockVotingToken._mint(address(this), 100);

        // Cast a vote
        cultureIndex.vote(newPieceId);

        // Validate the vote
        CultureIndex.Voter[] memory pieceVotes = cultureIndex.getVotes(
            newPieceId
        );
        uint256 totalVoteWeight = cultureIndex.totalVoteWeights(newPieceId);

        assertEq(pieceVotes.length, 1, "Should have one vote");
        assertEq(
            pieceVotes[0].voterAddress,
            address(this),
            "Voter address should match"
        );
        assertEq(pieceVotes[0].weight, 100, "Voting weight should be 100");
        assertEq(totalVoteWeight, 100, "Total voting weight should be 100");
    }

    /**
     * @dev Test case to validate the "one vote per address" rule
     *
     * We create a new art piece and cast a vote for it.
     * Then we try to vote again and expect it to fail.
     */
    function testCannotVoteTwice() public {
        setUp();
        uint256 newPieceId = createArtPiece(
            "Mona Lisa",
            "A masterpiece",
            CultureIndex.MediaType.IMAGE,
            "ipfs://legends",
            "",
            "",
            address(0x1),
            10000
        );

        // Mint some tokens to the voter
        mockVotingToken._mint(address(this), 100);

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
        uint256 newPieceId = createArtPiece(
            "Starry Night",
            "A masterpiece",
            CultureIndex.MediaType.IMAGE,
            "ipfs://legends",
            "",
            "",
            address(0x1),
            10000
        );

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
        uint256 firstPieceId = createArtPiece(
            "Mona Lisa",
            "A masterpiece",
            CultureIndex.MediaType.IMAGE,
            "ipfs://legends",
            "",
            "",
            address(0x1),
            10000
        );

        uint256 secondPieceId = createArtPiece(
            "Starry Night",
            "Another masterpiece",
            CultureIndex.MediaType.IMAGE,
            "ipfs://starrynight",
            "",
            "",
            address(0x2),
            10000
        );

        // Mint some tokens to the voter
        mockVotingToken._mint(address(this), 200);

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
        uint256 firstPieceId = createArtPiece(
            "Mona Lisa",
            "A masterpiece",
            CultureIndex.MediaType.IMAGE,
            "ipfs://legends",
            "",
            "",
            address(0x1),
            10000
        );

        uint256 secondPieceId = createArtPiece(
            "Starry Night",
            "Another masterpiece",
            CultureIndex.MediaType.IMAGE,
            "ipfs://starrynight",
            "",
            "",
            address(0x2),
            10000
        );

        // Try to vote for the first piece and expect to fail
        try cultureIndex.vote(firstPieceId) {
            fail(
                "Should not be able to vote without tokens on the first piece"
            );
        } catch Error(string memory reason) {
            assertEq(reason, "Weight must be greater than zero");
        }

        // Try to vote for the second piece and expect to fail
        try cultureIndex.vote(secondPieceId) {
            fail(
                "Should not be able to vote without tokens on the second piece"
            );
        } catch Error(string memory reason) {
            assertEq(reason, "Weight must be greater than zero");
        }
    }

    // Utility function to create a new art piece and return its ID
    function createArtPiece(
        string memory name,
        string memory description,
        CultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl,
        address creatorAddress,
        uint256 creatorBps
    ) internal returns (uint256) {
        CultureIndex.ArtPieceMetadata memory metadata = CultureIndex
            .ArtPieceMetadata({
                name: name,
                description: description,
                mediaType: mediaType,
                image: image,
                text: text,
                animationUrl: animationUrl
            });

        CultureIndex.CreatorBps[]
            memory creators = new CultureIndex.CreatorBps[](1);
        creators[0] = CultureIndex.CreatorBps({
            creator: creatorAddress,
            bps: creatorBps
        });

        return cultureIndex.createPiece(metadata, creators);
    }
}
