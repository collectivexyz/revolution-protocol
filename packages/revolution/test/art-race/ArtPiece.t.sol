// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ArtRace } from "../../src/art-race/ArtRace.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { IArtRace } from "../../src/interfaces/IArtRace.sol";
import { CultureIndexTestSuite } from "./ArtRace.t.sol";

/**
 * @title CultureIndexArtPieceTest
 * @dev Test contract for ArtRace art piece creation
 */
contract CultureIndexArtPieceTest is CultureIndexTestSuite {
    //test that creating the first piece the pieceId is 0
    function testFirstPieceId() public {
        uint256 newPieceId = createArtPiece(
            "Mona Lisa",
            "A masterpiece",
            IArtRace.MediaType.IMAGE,
            "ipfs://legends",
            "",
            "",
            address(0x1),
            10000
        );

        assertEq(newPieceId, 0);
    }

    /**
     * @dev Test case to validate basic art piece creation functionality
     *
     * We create a new art piece with given metadata and creators.
     * Then we fetch the created art piece by its ID and assert
     * its properties to ensure they match what was set.
     */
    function testCreatePiece() public {
        uint256 newPieceId = createArtPiece(
            "Mona Lisa",
            "A masterpiece",
            IArtRace.MediaType.IMAGE,
            "ipfs://legends",
            "",
            "",
            address(0x1),
            10000
        );

        // Validate that the piece was created with correct data
        IArtRace.ArtPiece memory createdPiece = cultureIndex.getPieceById(newPieceId);

        assertEq(createdPiece.pieceId, newPieceId);
        assertEq(createdPiece.metadata.name, "Mona Lisa");
        assertEq(createdPiece.metadata.description, "A masterpiece");
        assertEq(createdPiece.metadata.image, "ipfs://legends");
        assertEq(createdPiece.creators[0].creator, address(0x1));
        assertEq(createdPiece.creators[0].bps, 10000);
    }

    /**
     * @dev Test case to validate art piece creation with multiple creators
     */
    function testCreatePieceWithMultipleCreators() public {
        IArtRace.ArtPieceMetadata memory metadata = IArtRace.ArtPieceMetadata({
            name: "Collaborative Work",
            description: "A joint masterpiece",
            mediaType: IArtRace.MediaType.IMAGE,
            image: "ipfs://collab",
            text: "",
            animationUrl: ""
        });

        IArtRace.CreatorBps[] memory creators = new IArtRace.CreatorBps[](2);
        creators[0] = IArtRace.CreatorBps({ creator: address(0x1), bps: 5000 });
        creators[1] = IArtRace.CreatorBps({ creator: address(0x2), bps: 5000 });

        uint256 newPieceId = cultureIndex.createPiece(metadata, creators);

        // Validate that the piece was created with correct data
        IArtRace.ArtPiece memory createdPiece = cultureIndex.getPieceById(newPieceId);

        assertEq(createdPiece.pieceId, newPieceId);
        assertEq(createdPiece.metadata.name, "Collaborative Work");
        assertEq(createdPiece.creators[0].creator, address(0x1));
        assertEq(createdPiece.creators[0].bps, 5000);
        assertEq(createdPiece.creators[1].creator, address(0x2));
        assertEq(createdPiece.creators[1].bps, 5000);
    }

    /**
     * @dev Test case to validate art piece creation with multiple creators
     */
    function testCreatePieceWithMultipleCreatorsInvalidBPS() public {
        IArtRace.ArtPieceMetadata memory metadata = IArtRace.ArtPieceMetadata({
            name: "Collaborative Work",
            description: "A joint masterpiece",
            mediaType: IArtRace.MediaType.IMAGE,
            image: "ipfs://collab",
            text: "",
            animationUrl: ""
        });

        IArtRace.CreatorBps[] memory creators = new IArtRace.CreatorBps[](2);
        creators[0] = IArtRace.CreatorBps({ creator: address(0x1), bps: 5000 });
        creators[1] = IArtRace.CreatorBps({ creator: address(0x2), bps: 500 });

        // Validate that the piece was created with correct data
        vm.expectRevert(abi.encodeWithSignature("INVALID_BPS_SUM()"));
        cultureIndex.createPiece(metadata, creators);
    }

    // /**
    //  * @dev Test case to validate the art piece creation with an invalid zero address for the creator
    //  */
    function testInvalidCreatorAddress() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Invalid Creator",
            "Invalid Piece",
            IArtRace.MediaType.IMAGE,
            "ipfs://invalid",
            "",
            "",
            address(0),
            10000
        );

        vm.expectRevert(abi.encodeWithSignature("ADDRESS_ZERO()"));
        cultureIndex.createPiece(metadata, creators);
    }

    /**
     * @dev Test case to validate the art piece creation with incorrect total basis points
     */
    function testExcessiveTotalBasisPoints() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Invalid Creator",
            "Invalid Piece",
            IArtRace.MediaType.IMAGE,
            "ipfs://invalid",
            "",
            "",
            address(0x1),
            21_000_000
        );

        vm.expectRevert(abi.encodeWithSignature("INVALID_BPS_SUM()"));
        cultureIndex.createPiece(metadata, creators);
    }

    // /**
    //  * @dev Test case to validate the art piece creation with incorrect total basis points
    //  */
    function testTooFewTotalBasisPoints() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Invalid Creator",
            "Invalid Piece",
            IArtRace.MediaType.IMAGE,
            "ipfs://invalid",
            "",
            "",
            address(0x1),
            21
        );

        vm.expectRevert(abi.encodeWithSignature("INVALID_BPS_SUM()"));
        cultureIndex.createPiece(metadata, creators);
    }

    /**
     * @dev Test case to validate art piece creation with missing media data
     */
    function testMissingMediaDataImage() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Missing Media Data",
            "Invalid Piece",
            IArtRace.MediaType.IMAGE,
            "",
            "",
            "",
            address(0x1),
            10000
        );

        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        cultureIndex.createPiece(metadata, creators);
    }

    /**
     * @dev Test case to validate art piece creation with missing media data
     */
    function testMissingMediaDataAnimation() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Missing Media Data",
            "Invalid Piece",
            IArtRace.MediaType.ANIMATION,
            "",
            "",
            "",
            address(0x1),
            10000
        );

        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        cultureIndex.createPiece(metadata, creators);
    }

    /**
     * @dev Test case to validate art piece creation with missing media data
     */
    function testMissingMediaDataText() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Missing Media Data",
            "Invalid Piece",
            IArtRace.MediaType.TEXT,
            "",
            "",
            "",
            address(0x1),
            10000
        );

        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        cultureIndex.createPiece(metadata, creators);
    }

    /**
     * @dev Test case to validate art piece creation with missing name
     */
    function testMissingName() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "",
            "Invalid Piece",
            IArtRace.MediaType.TEXT,
            "",
            "",
            "",
            address(0x1),
            10000
        );

        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        cultureIndex.createPiece(metadata, creators);
    }

    /**
     * @dev Test case to validate that piece IDs are incremented correctly
     */
    function testPieceIDIncrement() public {
        uint256 firstPieceId = createArtPiece(
            "First Piece",
            "Valid Piece",
            IArtRace.MediaType.IMAGE,
            "ipfs://first",
            "",
            "",
            address(0x1),
            10000
        );

        uint256 secondPieceId = createArtPiece(
            "Second Piece",
            "Valid Piece",
            IArtRace.MediaType.IMAGE,
            "ipfs://second",
            "",
            "",
            address(0x1),
            10000
        );

        assertEq(firstPieceId + 1, secondPieceId, "Piece IDs should be incremented correctly");
    }

    /**
     * @dev Test case to validate that creatorArray does not exceed 50 in length
     */
    function testCreatorArrayLengthConstraint() public {
        IArtRace.ArtPieceMetadata memory metadata = IArtRace.ArtPieceMetadata({
            name: "Constraint Test",
            description: "Test Piece",
            mediaType: IArtRace.MediaType.IMAGE,
            image: "ipfs://constraint",
            text: "",
            animationUrl: ""
        });

        // Create a creatorArray with 51 entries
        IArtRace.CreatorBps[] memory creators = new IArtRace.CreatorBps[](101);
        for (uint i = 0; i < 101; i++) {
            creators[i] = IArtRace.CreatorBps({
                creator: address(0x1), // Unique address for each creator
                bps: 100 // This doesn't sum up to 10,000 but the test is for array length
            });
        }

        vm.expectRevert(abi.encodeWithSignature("MAX_NUM_CREATORS_EXCEEDED()"));
        cultureIndex.createPiece(metadata, creators);
    }

    function testArtPieceCreationAndVoting(uint256 pointsSupply, uint256 quorumVotesBPS) public {
        vm.assume(pointsSupply > 0 && pointsSupply < 2 ** 200);
        vm.assume(quorumVotesBPS <= cultureIndex.MAX_QUORUM_VOTES_BPS());

        // Set the quorum BPS
        cultureIndex._setQuorumVotesBPS(quorumVotesBPS);

        cultureIndex.transferOwnership(address(revolutionToken));

        vm.startPrank(address(revolutionToken));
        cultureIndex.acceptOwnership();

        vm.startPrank(address(revolutionPointsEmitter));
        revolutionPoints.mint(address(this), pointsSupply);

        vm.roll(vm.getBlockNumber() + 1);

        // Create an art piece
        uint256 pieceId = createDefaultArtPiece();
        ArtRace.ArtPiece memory piece = cultureIndex.getPieceById(pieceId);

        // Check initial values
        uint256 expectedTotalVotesSupply = pointsSupply;
        uint256 expectedQuorumVotes = (quorumVotesBPS * expectedTotalVotesSupply) / 10_000;
        vm.roll(vm.getBlockNumber() + 1);

        assertEq(
            cultureIndex.quorumVotesForPiece(piece.pieceId),
            expectedQuorumVotes,
            "Quorum votes should be set correctly on creation"
        );

        vm.roll(vm.getBlockNumber() + 1);
        // Cast votes
        vm.startPrank(address(this));
        voteForPiece(pieceId);

        // Mint token and govTokens, create a new piece and check fields
        vm.startPrank(address(auction));
        vm.roll(vm.getBlockNumber() + 1);

        revolutionToken.mint();

        vm.startPrank(address(revolutionPointsEmitter));
        revolutionPoints.mint(address(this), pointsSupply);

        vm.roll(vm.getBlockNumber() + 1);

        ArtRace.ArtPiece memory newPiece = cultureIndex.getPieceById(createDefaultArtPiece());
        vm.roll(vm.getBlockNumber() + 1);

        uint256 expectedTotalVotesSupply2 = pointsSupply * 2 + cultureIndex.revolutionTokenVoteWeight();

        uint256 expectedQuorumVotes2 = (quorumVotesBPS * (expectedTotalVotesSupply2)) / 10_000;
        assertEq(
            cultureIndex.quorumVotesForPiece(newPiece.pieceId),
            expectedQuorumVotes2,
            "Quorum votes should be set correctly on second creation"
        );
    }
}
