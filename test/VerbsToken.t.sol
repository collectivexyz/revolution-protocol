// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {VerbsToken} from "../packages/revolution-contracts/VerbsToken.sol";  // Update this path
import { IVerbsDescriptorMinimal } from "../packages/revolution-contracts/interfaces/IVerbsDescriptorMinimal.sol";
import { IProxyRegistry } from "../packages/revolution-contracts/external/opensea/IProxyRegistry.sol";
import { ICultureIndex } from "../packages/revolution-contracts/interfaces/ICultureIndex.sol";
import { NFTDescriptor } from "../packages/revolution-contracts/libs/NFTDescriptor.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import {CultureIndex} from "../packages/revolution-contracts/CultureIndex.sol";
import {MockERC20} from "./MockERC20.sol";
import {VerbsDescriptor} from "../packages/revolution-contracts/VerbsDescriptor.sol";

/// @title VerbsTokenTest
/// @dev The test suite for the VerbsToken contract
contract VerbsTokenTest is Test {
    VerbsToken public verbsToken;
    CultureIndex public cultureIndex;
    MockERC20 public mockVotingToken;
    VerbsDescriptor public descriptor;

    /// @dev Sets up a new VerbsToken instance before each test
    function setUp() public {
        // Create a new CultureIndex contract
        mockVotingToken = new MockERC20();
        cultureIndex = new CultureIndex(address(mockVotingToken));
        descriptor = new VerbsDescriptor(address(this));

        IVerbsDescriptorMinimal _descriptor = descriptor;
        IProxyRegistry _proxyRegistry = IProxyRegistry(address(0x2));
        ICultureIndex _cultureIndex = cultureIndex;

        verbsToken = new VerbsToken(address(this), address(this), _descriptor, _proxyRegistry, _cultureIndex);
    }


    /// @dev Tests the minting with no pieces added
    function testMintWithNoPieces() public {
          // Try to remove max and expect to fail
        try verbsToken.mint() {
            fail("Should revert on removing max from empty heap");
        } catch Error(string memory reason) {
            assertEq(reason, "No pieces available to drop");
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
        assertEq(tokenId, 1, "First token ID should be 1");
        assertEq(totalSupply, 1, "Total supply should be 1");
    }

    /// @dev Tests the symbol of the VerbsToken
    function testSymbol() public {
        setUp();
        assertEq(verbsToken.symbol(), "VERB", "Symbol should be VERB");
    }

    /// @dev Tests the name of the VerbsToken
    function testName() public {
        setUp();
        assertEq(verbsToken.name(), "Verbs", "Name should be Verbs");
    }

    /// @dev Tests minting a verb token to itself
    function testMintToItself() public {
        setUp();
        createDefaultArtPiece();

        uint256 initialTotalSupply = verbsToken.totalSupply();
        verbsToken.mint();
        uint256 newTokenId = verbsToken.totalSupply();
        assertEq(newTokenId, initialTotalSupply + 1, "One new token should have been minted");
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


    /// @dev Tests minting by non-minter should revert
    function testRevertOnNonMinterMint() public {
        setUp();

        address nonMinter = address(0xABC); // This is an arbitrary address
        vm.startPrank(nonMinter); 

        try verbsToken.mint() {
            fail("Should revert on non-minter mint");
        } catch Error(string memory reason) {
            assertEq(reason, "Sender is not the minter");
        }

        vm.stopPrank();
    }

    /// @dev Tests the contract URI of the VerbsToken
    function testContractURI() public {
        setUp();
        assertEq(verbsToken.contractURI(), "ipfs://QmQzDwaZ7yQxHHs7sQQenJVB89riTSacSGcJRv9jtHPuz5", "Contract URI should match");
    }

    /// @dev Tests that only the owner can set the contract URI
    function testSetContractURIByOwner() public {
        setUp();
        verbsToken.setContractURIHash("NewHashHere");
        assertEq(verbsToken.contractURI(), "ipfs://NewHashHere", "Contract URI should be updated");
    }

    /// @dev Tests that non-owners cannot set the contract URI
    // function testRevertOnNonOwnerSettingContractURI() public {
    //     setUp();

    //     address nonOwner = address(0x1); // Non-owner address
    //     vm.startPrank(nonOwner);

    //     bool hasErrorOccurred = false;
    //     try verbsToken.setContractURIHash("NewHashHere") {
    //         fail("Should revert on non-owner setting contract URI");
    //     } catch Error(string memory reason) {
    //         hasErrorOccurred = true;
    //     }

    //     vm.stopPrank();

    //     // assertEq(hasErrorOccurred, true, "Expected an error but none was thrown.");
    // }


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
}

/// @title VerbsTokenTest
/// @dev The test suite for the VerbsToken contract
contract VerbsTokenSetup is Test {
    VerbsToken public verbsToken;
    CultureIndex public cultureIndex;
    VerbsDescriptor public descriptor;

    constructor(address _cultureIndex, address _owner) {
        cultureIndex = CultureIndex(_cultureIndex);
        descriptor = VerbsDescriptor(_owner);
    }
}