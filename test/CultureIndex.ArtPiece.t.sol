// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {CultureIndex} from "../packages/revolution-contracts/CultureIndex.sol";
import {MockERC20} from "./MockERC20.sol";
import {ICultureIndex} from "../packages/revolution-contracts/interfaces/ICultureIndex.sol";

/**
 * @title CultureIndexArtPieceTest
 * @dev Test contract for CultureIndex art piece creation
 */
contract CultureIndexArtPieceTest is Test {
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

    // Function to create ArtPieceMetadata
    function createArtPieceMetadata(
        string memory name,
        string memory description,
        ICultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl
    ) public pure returns (CultureIndex.ArtPieceMetadata memory) { // <-- Change visibility and mutability as needed
        ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex
            .ArtPieceMetadata({
                name: name,
                description: description,
                mediaType: mediaType,
                image: image,
                text: text,
                animationUrl: animationUrl
            });

        return metadata;
    }

    // Function to create CreatorBps array
    function createArtPieceCreators(
        address creatorAddress,
        uint256 creatorBps
    ) public pure returns (CultureIndex.CreatorBps[] memory) { // <-- Change visibility and mutability as needed
        ICultureIndex.CreatorBps[]
            memory creators = new ICultureIndex.CreatorBps[](1);
        creators[0] = ICultureIndex.CreatorBps({
            creator: creatorAddress,
            bps: creatorBps
        });

        return creators;
    }

    //returns metadata and creators in a tuple
    function createArtPieceTuple(
        string memory name,
        string memory description,
        ICultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl,
        address creatorAddress,
        uint256 creatorBps
    ) public pure returns (CultureIndex.ArtPieceMetadata memory, ICultureIndex.CreatorBps[] memory) { // <-- Change here
        ICultureIndex.ArtPieceMetadata memory metadata = createArtPieceMetadata(
            name,
            description,
            mediaType,
            image,
            text,
            animationUrl
        );

        ICultureIndex.CreatorBps[] memory creators = createArtPieceCreators(
            creatorAddress,
            creatorBps
        );

        return (metadata, creators);
    }


    function createArtPiece(
        string memory name,
        string memory description,
        ICultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl,
        address creatorAddress,
        uint256 creatorBps
    ) public returns (uint256) { // <-- Change here
        //use createArtPieceTuple to create metadata and creators
        (CultureIndex.ArtPieceMetadata memory metadata, ICultureIndex.CreatorBps[] memory creators) = createArtPieceTuple(
            name,
            description,
            mediaType,
            image,
            text,
            animationUrl,
            creatorAddress,
            creatorBps
        );

        return cultureIndex.createPiece(metadata, creators);
    }



    /**
     * @dev Test case to validate basic art piece creation functionality
     *
     * We create a new art piece with given metadata and creators.
     * Then we fetch the created art piece by its ID and assert
     * its properties to ensure they match what was set.
     */
    function testCreatePiece() public {
        setUp();

        uint256 newPieceId = createArtPiece(
            "Mona Lisa",
            "A masterpiece",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://legends",
            "",
            "",
            address(0x1),
            10000
        );

        // Validate that the piece was created with correct data
        ICultureIndex.ArtPiece memory createdPiece = cultureIndex.getPieceById(
            newPieceId
        );

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
        setUp();

        ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex
            .ArtPieceMetadata({
                name: "Collaborative Work",
                description: "A joint masterpiece",
                mediaType: ICultureIndex.MediaType.IMAGE,
                image: "ipfs://collab",
                text: "",
                animationUrl: ""
            });

        ICultureIndex.CreatorBps[]
            memory creators = new ICultureIndex.CreatorBps[](2);
        creators[0] = ICultureIndex.CreatorBps({
            creator: address(0x1),
            bps: 5000
        });
        creators[1] = ICultureIndex.CreatorBps({
            creator: address(0x2),
            bps: 5000
        });

        uint256 newPieceId = cultureIndex.createPiece(metadata, creators);

        // Validate that the piece was created with correct data
        ICultureIndex.ArtPiece memory createdPiece = cultureIndex.getPieceById(
            newPieceId
        );

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
        setUp();

        ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex
            .ArtPieceMetadata({
                name: "Collaborative Work",
                description: "A joint masterpiece",
                mediaType: ICultureIndex.MediaType.IMAGE,
                image: "ipfs://collab",
                text: "",
                animationUrl: ""
            });

        ICultureIndex.CreatorBps[]
            memory creators = new ICultureIndex.CreatorBps[](2);
        creators[0] = ICultureIndex.CreatorBps({
            creator: address(0x1),
            bps: 5000
        });
        creators[1] = ICultureIndex.CreatorBps({
            creator: address(0x2),
            bps: 500
        });


        // Validate that the piece was created with correct data
        try 
            cultureIndex.createPiece(metadata, creators)
        {
            fail("Should not be able to create piece with invalid BPS");
        } catch Error(string memory reason) {
            assertEq(reason, "Total BPS must sum up to 10,000");
        }

    }

    // /**
    //  * @dev Test case to validate the art piece creation with an invalid zero address for the creator
    //  */
    function testInvalidCreatorAddress() public {
        setUp();

        (CultureIndex.ArtPieceMetadata memory metadata, ICultureIndex.CreatorBps[] memory creators) = createArtPieceTuple(
                "Invalid Creator",
                "Invalid Piece",
                ICultureIndex.MediaType.IMAGE,
                "ipfs://invalid",
                "",
                "",
                address(0),
                10000
        );

        try
            cultureIndex.createPiece(metadata, creators)
        {
            fail(
                "Should not be able to create piece with zero address for creator"
            );
        } catch Error(string memory reason) {
            assertEq(reason, "Invalid creator address");
        }
    }

    // /**
    //  * @dev Test case to validate the art piece creation with incorrect total basis points
    //  */
    function testExcessiveTotalBasisPoints() public {
        setUp();
        (CultureIndex.ArtPieceMetadata memory metadata, ICultureIndex.CreatorBps[] memory creators) = createArtPieceTuple(
                "Invalid Creator",
                "Invalid Piece",
                ICultureIndex.MediaType.IMAGE,
                "ipfs://invalid",
                "",
                "",
                address(0x1),
                21_000_000
        );

        try
            cultureIndex.createPiece(metadata, creators)
        {
            fail(
                "Should not be able to create piece with invalid total basis points"
            );
        } catch Error(string memory reason) {
            assertEq(reason, "Total BPS must sum up to 10,000");
        }
    }

        // /**
    //  * @dev Test case to validate the art piece creation with incorrect total basis points
    //  */
    function testTooFewTotalBasisPoints() public {
        setUp();
        (CultureIndex.ArtPieceMetadata memory metadata, ICultureIndex.CreatorBps[] memory creators) = createArtPieceTuple(
                "Invalid Creator",
                "Invalid Piece",
                ICultureIndex.MediaType.IMAGE,
                "ipfs://invalid",
                "",
                "",
                address(0x1),
                21
        );

        try
            cultureIndex.createPiece(metadata, creators)
        {
            fail(
                "Should not be able to create piece with invalid total basis points"
            );
        } catch Error(string memory reason) {
            assertEq(reason, "Total BPS must sum up to 10,000");
        }
    }

    /**
     * @dev Test case to validate art piece creation with an invalid media type
     */
    function testInvalidMediaType() public {
        setUp();
        ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex
            .ArtPieceMetadata({
                name: "Invalid Media Type",
                description: "Invalid Piece",
                mediaType: ICultureIndex.MediaType.NONE,
                image: "",
                text: "",
                animationUrl: ""
            });

        ICultureIndex.CreatorBps[]
            memory creators = new ICultureIndex.CreatorBps[](1);
        creators[0] = ICultureIndex.CreatorBps({
            creator: address(0x1),
            bps: 10000
        });

        try cultureIndex.createPiece(metadata, creators) {
            fail("Should not be able to create piece with invalid media type");
        } catch Error(string memory reason) {
            assertEq(reason, "Invalid media type");
        }
    }

    /**
     * @dev Test case to validate art piece creation with missing media data
     */
    function testMissingMediaData() public {
        setUp();

        (CultureIndex.ArtPieceMetadata memory metadata, ICultureIndex.CreatorBps[] memory creators) = createArtPieceTuple(
                "Missing Media Data",
                "Invalid Piece",
                ICultureIndex.MediaType.IMAGE,
                "",
                "",
                "",
                address(0x1),
                10000
        );

        try
            cultureIndex.createPiece(metadata, creators)
        {
            fail("Should not be able to create piece with missing media data");
        } catch Error(string memory reason) {
            assertEq(reason, "Image URL must be provided");
        }
    }

    /**
     * @dev Test case to validate that piece IDs are incremented correctly
     */
    function testPieceIDIncrement() public {
        setUp();
        uint256 firstPieceId = createArtPiece(
            "First Piece",
            "Valid Piece",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://first",
            "",
            "",
            address(0x1),
            10000
        );

        uint256 secondPieceId = createArtPiece(
            "Second Piece",
            "Valid Piece",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://second",
            "",
            "",
            address(0x1),
            10000
        );

        assertEq(
            firstPieceId + 1,
            secondPieceId,
            "Piece IDs should be incremented correctly"
        );
    }

    /**
    * @dev Test case to validate that creatorArray does not exceed 50 in length
    */
    function testCreatorArrayLengthConstraint() public {
        setUp();

        ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex
            .ArtPieceMetadata({
                name: "Constraint Test",
                description: "Test Piece",
                mediaType: ICultureIndex.MediaType.IMAGE,
                image: "ipfs://constraint",
                text: "",
                animationUrl: ""
            });

        // Create a creatorArray with 51 entries
        ICultureIndex.CreatorBps[] memory creators = new ICultureIndex.CreatorBps[](101);
        for (uint i = 0; i < 101; i++) {
            creators[i] = ICultureIndex.CreatorBps({
                creator: address(0x1), // Unique address for each creator
                bps: 100 // This doesn't sum up to 10,000 but the test is for array length
            });
        }

        try cultureIndex.createPiece(metadata, creators) {
            fail("Should not be able to create piece with creatorArray length > 100");
        } catch Error(string memory reason) {
            assertEq(reason, "Creator array must not be > 100");
        }
    }
}
