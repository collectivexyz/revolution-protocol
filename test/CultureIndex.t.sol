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
}
