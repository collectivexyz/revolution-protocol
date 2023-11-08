// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {VerbsToken} from "../packages/revolution-contracts/VerbsToken.sol";
import {IVerbsToken} from "../packages/revolution-contracts/interfaces/IVerbsToken.sol";
import { IVerbsDescriptorMinimal } from "../packages/revolution-contracts/interfaces/IVerbsDescriptorMinimal.sol";
import { IProxyRegistry } from "../packages/revolution-contracts/external/opensea/IProxyRegistry.sol";
import { ICultureIndex } from "../packages/revolution-contracts/interfaces/ICultureIndex.sol";
import { NFTDescriptor } from "../packages/revolution-contracts/libs/NFTDescriptor.sol";
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
        // Create a new CultureIndex contract
        mockVotingToken = new MockERC20();
        cultureIndex = new CultureIndex(address(mockVotingToken));
        descriptor = new VerbsDescriptor(address(this));

        IVerbsDescriptorMinimal _descriptor = descriptor;
        ProxyRegistry _proxyRegistry = new ProxyRegistry();
        ICultureIndex _cultureIndex = cultureIndex;

        verbsToken = new VerbsToken(address(this), address(this), _descriptor, _proxyRegistry, _cultureIndex);
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

/// @dev Tests the creator array limit for minting
function testCreatorArrayLimit() public {
    setUp();

    // Create an art piece with creators more than the limit (assuming the limit is 100)
    ICultureIndex.CreatorBps[] memory creators = new ICultureIndex.CreatorBps[](101);
    for(uint i = 0; i < 101; i++) {
        creators[i] = ICultureIndex.CreatorBps({
            creator: address(uint160(i + 1)), // Just a series of different addresses
            bps: 10 // Arbitrary basis points for each creator
        });
    }

    ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex.ArtPieceMetadata({
        name: "Overpopulated",
        description: "An art piece with too many creators",
        mediaType: ICultureIndex.MediaType.IMAGE,
        image: "ipfs://overpopulated",
        text: "",
        animationUrl: ""
    });

    // Attempt to create the piece and expect it to fail due to too many creators
    bool exceededCreatorLimit = false;
    try cultureIndex.createPiece(metadata, creators) {
        fail("Should fail: creator array exceeds the limit");
    } catch {
        exceededCreatorLimit = true;
    }

    assertTrue(exceededCreatorLimit, "Should not allow creation of a piece with too many creators");
}
/// @dev Tests the reentrancy guard on the mint function
function testReentrancyOnMint() public {
    setUp();

    createDefaultArtPiece();

    // Simulate a reentrancy attack by calling mint within a call to mint
    address attacker = address(new ReentrancyAttackContract(address(verbsToken)));
    vm.startPrank(attacker);

    bool reentrancyOccurred = false;
    try ReentrancyAttackContract(attacker).attack() {
        fail("Should fail: reentrancy should be guarded");
    } catch {
        reentrancyOccurred = true;
    }

    vm.stopPrank();

    assertTrue(reentrancyOccurred, "Reentrancy guard should prevent minting in the same call stack");
}

/// @dev Tests approval checks for transfer functions
function testApprovalChecks() public {
    setUp();

    createDefaultArtPiece();

    uint256 tokenId = verbsToken.mint();

    address spender = address(0xABC);
    address to = address(0xDEF);

    // Attempt to transfer without approval as owner
    verbsToken.transferFrom(address(this), to, tokenId);

    vm.startPrank(to);

    // Approve spender and attempt to transfer as spender
    verbsToken.approve(spender, tokenId);
    vm.stopPrank();

    vm.startPrank(spender);

    bool transferWithApprovalFailed = false;
    try verbsToken.transferFrom(to, address(this), tokenId) {
        // Transfer should succeed
    } catch {
        transferWithApprovalFailed = true;
    }
    vm.stopPrank();

    assertFalse(transferWithApprovalFailed, "Transfer with approval should succeed");
}

}

// Helper mock contract to simulate reentrancy attack
contract ReentrancyAttackContract {
    VerbsToken private verbsToken;

    constructor(address _verbsToken) {
        verbsToken = VerbsToken(_verbsToken);
    }

    function attack() public {
        verbsToken.mint();
        verbsToken.mint(); // This should fail if reentrancy guard is in place
    }
}

contract ProxyRegistry is IProxyRegistry {
    mapping(address => address) public proxies;
}