// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { CultureIndex } from "../packages/revolution-contracts/CultureIndex.sol";
import { IERC20 } from "../packages/revolution-contracts/IERC20.sol";

contract CultureIndexTest is Test {
    CultureIndex public cultureIndex;
    IERC20 public mockVotingToken;

    function setUp() public {
        // Initialize your mock ERC20 token here, if needed
        // mockVotingToken = new MockIERC20();
        // Initialize your CultureIndex contract
        cultureIndex = new CultureIndex(address(mockVotingToken));
    }

    function testCreatePiece() public {
        CultureIndex.ArtPieceMetadata memory metadata = CultureIndex.ArtPieceMetadata({
            name: "Mona Lisa",
            description: "A masterpiece",
            mediaType: CultureIndex.MediaType.IMAGE,
            image: "ipfs://legend",
            text: "",
            animationUrl: ""
        });

        CultureIndex.CreatorBps[] memory creators = new CultureIndex.CreatorBps[](1);
        creators[0] = CultureIndex.CreatorBps({ creator: address(0x1), bps: 10000 });

        uint256 newPieceId = cultureIndex.createPiece(metadata, creators);

        // Validate that the piece was created with correct data
        CultureIndex.ArtPiece memory createdPiece = cultureIndex.getPieceById(newPieceId);


        assertEq(createdPiece.id, newPieceId);
        assertEq(createdPiece.metadata.name, "Mona Lisa");
        assertEq(createdPiece.metadata.description, "A masterpiece");
        assertEq(createdPiece.metadata.mediaType, CultureIndex.MediaType.IMAGE);
        assertEq(createdPiece.metadata.image, "ipfs://legend");
        assertEq(createdPiece.creators[0].creator, address(0x1));
        assertEq(createdPiece.creators[0].bps, 10000);
    }
}
