// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {VerbsToken} from "../packages/revolution-contracts/VerbsToken.sol";
import {IVerbsToken} from "../packages/revolution-contracts/interfaces/IVerbsToken.sol";
import { IVerbsDescriptorMinimal } from "../packages/revolution-contracts/interfaces/IVerbsDescriptorMinimal.sol";
import { IProxyRegistry } from "../packages/revolution-contracts/external/opensea/IProxyRegistry.sol";
import { ICultureIndex } from "../packages/revolution-contracts/interfaces/ICultureIndex.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import {CultureIndex} from "../packages/revolution-contracts/CultureIndex.sol";
import {MockERC20} from "./MockERC20.sol";
import {VerbsDescriptor} from "../packages/revolution-contracts/VerbsDescriptor.sol";
import "./Base64Decode.sol";
import "./JsmnSolLib.sol";

/// @title VerbsTokenTest
/// @dev The test suite for the VerbsToken contract
contract VerbsTokenTest is Test {
    VerbsToken public verbsToken;
    CultureIndex public cultureIndex;
    MockERC20 public mockVotingToken;
    VerbsDescriptor public descriptor;

    /// @dev Sets up a new VerbsToken instance before each test
    function setUp() public {
        // Create a new mock ERC20 token for voting
        mockVotingToken = new MockERC20();

        // Deploy a new proxy registry for OpenSea
        ProxyRegistry _proxyRegistry = new ProxyRegistry();

        // Create a new VerbsToken contract, passing address(this) as both the minter and the initial owner
        verbsToken = new VerbsToken(address(this), address(this), IVerbsDescriptorMinimal(address(0)), _proxyRegistry, ICultureIndex(address(0)), "Vrbs", "VRBS");

        // Deploy CultureIndex with the VerbsToken's address as the initial owner
        cultureIndex = new CultureIndex(address(mockVotingToken), address(verbsToken));
        ICultureIndex _cultureIndex = cultureIndex;

        // Now that CultureIndex is deployed, set it in VerbsToken
        verbsToken.setCultureIndex(_cultureIndex);

        // Deploy a new VerbsDescriptor, which will be used by VerbsToken
        descriptor = new VerbsDescriptor(address(verbsToken), "Verb");
        IVerbsDescriptorMinimal _descriptor = descriptor;

        // Now that VerbsDescriptor is deployed, set it in VerbsToken
        verbsToken.setDescriptor(_descriptor);
    }

    /// @dev Ensures the dropped art piece is equivalent to the top-voted piece
    function testDroppedArtPieceMatchesTopVoted() public {
        setUp();

        // Create a new art piece and simulate it being the top voted piece
        uint256 pieceId = createDefaultArtPiece();
        mockVotingToken._mint(address(this), 10);
        cultureIndex.vote(pieceId); // Simulate voting for the piece to make it top-voted

        // Fetch the top voted piece before minting
        ICultureIndex.ArtPiece memory topVotedPieceBeforeMint = cultureIndex.getTopVotedPiece();

        // Mint a token
        uint256 tokenId = verbsToken.mint();

        // Fetch the dropped art piece associated with the minted token
        ICultureIndex.ArtPiece memory droppedArtPiece = verbsToken.getArtPieceById(tokenId);

        // Now compare the relevant fields of topVotedPieceBeforeMint and droppedArtPiece
        assertEq(droppedArtPiece.pieceId, topVotedPieceBeforeMint.pieceId, "Piece ID should match");
        assertEq(droppedArtPiece.dropper, topVotedPieceBeforeMint.dropper, "Dropper address should match");
        //ensure isDropped is now true
        assertTrue(droppedArtPiece.isDropped, "isDropped should be true");
        assertTrue(areArraysEqual(droppedArtPiece.creators, topVotedPieceBeforeMint.creators), "Creators array should match");
        assertTrue(areArtPieceMetadataEqual(droppedArtPiece.metadata, topVotedPieceBeforeMint.metadata), "Metadata should match");
    }

    // Helper function to compare ArtPieceMetadata structs
    function areArtPieceMetadataEqual(
        ICultureIndex.ArtPieceMetadata memory metadata1,
        ICultureIndex.ArtPieceMetadata memory metadata2
    ) internal pure returns (bool) {
        return (
            keccak256(bytes(metadata1.name)) == keccak256(bytes(metadata2.name)) &&
            keccak256(bytes(metadata1.description)) == keccak256(bytes(metadata2.description)) &&
            metadata1.mediaType == metadata2.mediaType &&
            keccak256(bytes(metadata1.image)) == keccak256(bytes(metadata2.image)) &&
            keccak256(bytes(metadata1.text)) == keccak256(bytes(metadata2.text)) &&
            keccak256(bytes(metadata1.animationUrl)) == keccak256(bytes(metadata2.animationUrl))
        );
    }


    // Helper function to compare arrays of creators
    function areArraysEqual(ICultureIndex.CreatorBps[] memory arr1, ICultureIndex.CreatorBps[] memory arr2) internal pure returns (bool) {
        if (arr1.length != arr2.length) {
            return false;
        }
        for (uint i = 0; i < arr1.length; i++) {
            if (arr1[i].creator != arr2[i].creator || arr1[i].bps != arr2[i].bps) {
                return false;
            }
        }
        return true;
    }

    /// @dev Tests the minting with no pieces added
    function testMintWithNoPieces() public {
          // Try to remove max and expect to fail
        try verbsToken.mint() {
            fail("Should revert on removing max from empty heap");
        } catch Error(string memory reason) {
            assertEq(reason, "Heap is empty");
        }
    }

    /// @dev Tests basic minting
    function testMint() public {
        setUp();

        // Add a piece to the CultureIndex
        createDefaultArtPiece();

        // Mint a token
        uint256 tokenId = verbsToken.mint();

        // Validate the token
        uint256 totalSupply = verbsToken.totalSupply();
        assertEq(verbsToken.ownerOf(tokenId), address(this), "The contract should own the newly minted token");
        assertEq(tokenId, 0, "First token ID should be 1");
        assertEq(totalSupply, 1, "Total supply should be 1");
    }

    /// @dev Tests minting a verb token to itself
    function testMintToItself() public {
        setUp();
        createDefaultArtPiece();

        uint256 initialTotalSupply = verbsToken.totalSupply();
        uint256 newTokenId = verbsToken.mint();
        assertEq(verbsToken.totalSupply(), initialTotalSupply + 1, "One new token should have been minted");
        assertEq(verbsToken.ownerOf(newTokenId), address(this), "The contract should own the newly minted token");
    }

    /// @dev Tests burning a verb token
    function testBurn() public {
        setUp();

        createDefaultArtPiece();

        uint256 tokenId = verbsToken.mint();
        uint256 initialTotalSupply = verbsToken.totalSupply();
        verbsToken.burn(tokenId);
        uint256 newTotalSupply = verbsToken.totalSupply();
        assertEq(newTotalSupply, initialTotalSupply - 1, "Total supply should decrease by 1 after burning");
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
        ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex
            .ArtPieceMetadata({
                name: name,
                description: description,
                mediaType: mediaType,
                image: image,
                text: text,
                animationUrl: animationUrl
            });

        ICultureIndex.CreatorBps[]
            memory creators = new ICultureIndex.CreatorBps[](1);
        creators[0] = ICultureIndex.CreatorBps({
            creator: creatorAddress,
            bps: creatorBps
        });

        return cultureIndex.createPiece(metadata, creators);
    }

    //Utility function to create default art piece
    function createDefaultArtPiece() public returns (uint256) {
        return createArtPiece(
            "Mona Lisa",
            "A masterpiece",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://legends",
            "",
            "",
            address(0x1),
            10000
        );
    }


/// @dev Ensures _currentVerbId increments correctly after each mint
function testMintingIncrement() public {
    setUp();
    createDefaultArtPiece();
    createDefaultArtPiece();

    uint256 tokenId1 = verbsToken.mint();
    assertEq(verbsToken.totalSupply(), tokenId1 + 1, "CurrentVerbId should increment after first mint");

    uint256 tokenId2 = verbsToken.mint();
    assertEq(verbsToken.totalSupply(), tokenId2 + 1, "CurrentVerbId should increment after second mint");
}

/// @dev Checks if the VerbCreated event is emitted with correct parameters on minting
function testMintingEvent() public {
    setUp();
    createDefaultArtPiece();

    (uint256 pieceId,ICultureIndex.ArtPieceMetadata memory metadata,,) = cultureIndex.pieces(0);

    emit log_uint(pieceId);

    ICultureIndex.CreatorBps[] memory creators = new ICultureIndex.CreatorBps[](1);
    creators[0] = ICultureIndex.CreatorBps({
        creator: address(0x1),
        bps: 10000
    });

    ICultureIndex.ArtPiece memory expectedArtPiece = ICultureIndex.ArtPiece({
        pieceId: 0,
        metadata: metadata,
        creators: creators,
        dropper: address(this),
        isDropped: true
    });

    vm.expectEmit(true, true, true, true);

    emit IVerbsToken.VerbCreated(0, expectedArtPiece);

    verbsToken.mint();
}

/// @dev Tests the burn function.
function testBurnFunction() public {
    setUp();

    //create piece
    createDefaultArtPiece();
    uint256 tokenId = verbsToken.mint();
    
    vm.expectEmit(true, true, true, true);
    emit IVerbsToken.VerbBurned(tokenId);
    
    verbsToken.burn(tokenId);
    vm.expectRevert("ERC721: owner query for nonexistent token");
    verbsToken.ownerOf(tokenId); // This should fail because the token was burned
}


/// @dev Validates that the token URI is correctly set and retrieved
function testTokenURI() public {
    setUp();
    uint256 artPieceId = createDefaultArtPiece();
    uint256 tokenId = verbsToken.mint();
    (,ICultureIndex.ArtPieceMetadata memory metadata,,) = cultureIndex.pieces(artPieceId);
    // Assuming the descriptor returns a fixed URI for the given tokenId
    string memory expectedTokenURI = descriptor.tokenURI(tokenId, metadata);
    assertEq(verbsToken.tokenURI(tokenId), expectedTokenURI, "Token URI should be correctly set and retrieved");
}

/// @dev Ensures minting fetches and associates the top-voted piece from CultureIndex
function testTopVotedPieceMinting() public {
    setUp();

    // Create a new piece and simulate it being the top voted piece
    uint256 pieceId = createDefaultArtPiece(); // This function should exist within the test contract
    mockVotingToken._mint(address(this), 10);
    cultureIndex.vote(pieceId); // Assuming vote function exists and we cast 10 votes

    // Mint a token
    uint256 tokenId = verbsToken.mint();

    // Validate the token is associated with the top voted piece
    (uint256 mintedPieceId,,,) = verbsToken.artPieces(tokenId);
    assertEq(mintedPieceId, pieceId, "Minted token should be associated with the top voted piece");
}

}


contract ProxyRegistry is IProxyRegistry {
    mapping(address => address) public proxies;
}