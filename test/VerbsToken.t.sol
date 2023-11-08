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
        assertEq(tokenId, 0, "First token ID should be 1");
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
    function testRevertOnNonOwnerSettingContractURI() public {
        setUp();

        address nonOwner = address(0x1); // Non-owner address
        vm.startPrank(nonOwner);

        bool hasErrorOccurred = false;
        try verbsToken.setContractURIHash("NewHashHere") {
            fail("Should revert on non-owner setting contract URI");
        } catch {
            hasErrorOccurred = true;
        }

        vm.stopPrank();

        assertEq(hasErrorOccurred, true, "Expected an error but none was thrown.");
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

    /// @dev Tests the locking of admin functions
function testLockAdminFunctions() public {
    setUp();

    // Lock the minter, descriptor, and cultureIndex to prevent changes
    verbsToken.lockMinter();
    verbsToken.lockDescriptor();
    verbsToken.lockCultureIndex();

    // Attempt to change minter, descriptor, or cultureIndex and expect to fail
    address newMinter = address(0xABC);
    address newDescriptor = address(0xDEF);
    address newCultureIndex = address(0x123);

    bool minterLocked = false;
    bool descriptorLocked = false;
    bool cultureIndexLocked = false;

    try verbsToken.setMinter(newMinter) {
        fail("Should fail: minter is locked");
    } catch {
        minterLocked = true;
    }

    try verbsToken.setDescriptor(IVerbsDescriptorMinimal(newDescriptor)) {
        fail("Should fail: descriptor is locked");
    } catch {
        descriptorLocked = true;
    }

    try verbsToken.setCultureIndex(ICultureIndex(newCultureIndex)) {
        fail("Should fail: cultureIndex is locked");
    } catch {
        cultureIndexLocked = true;
    }

    assertTrue(minterLocked, "Minter should be locked");
    assertTrue(descriptorLocked, "Descriptor should be locked");
    assertTrue(cultureIndexLocked, "CultureIndex should be locked");
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

    /// @dev Tests the initial state of the contract variables
    function testInitialVariablesState() public {
        setUp();

        address minter = verbsToken.minter();
        address descriptorAddress = address(verbsToken.descriptor());
        address cultureIndexAddress = address(verbsToken.cultureIndex());

        assertEq(minter, address(this), "Initial minter should be the contract deployer");
        assertEq(descriptorAddress, address(descriptor), "Initial descriptor should be set correctly");
        assertEq(cultureIndexAddress, address(cultureIndex), "Initial cultureIndex should be set correctly");

    }

    /// @dev Tests that only the owner can call owner-specific functions
function testOwnerPrivileges() public {
    setUp();

    // Test only owner can change contract URI
    verbsToken.setContractURIHash("NewHashHere");
    assertEq(verbsToken.contractURI(), "ipfs://NewHashHere", "Owner should be able to change contract URI");

    // Test that non-owner cannot change contract URI
    address nonOwner = address(0x1);
    bool nonOwnerCantChangeContractURI = false;
    vm.startPrank(nonOwner);
    try verbsToken.setContractURIHash("FakeHash") {
        fail("Non-owner should not be able to change contract URI");
    } catch {
        nonOwnerCantChangeContractURI = true;
    }
    vm.stopPrank();

    assertTrue(nonOwnerCantChangeContractURI, "Non-owner should not be able to change contract URI");
}

/// @dev Tests setting and updating the minter address
function testMinterAssignment() public {
    setUp();

    // Test only owner can change minter
    address newMinter = address(0xABC);
    verbsToken.setMinter(newMinter);
    assertEq(verbsToken.minter(), newMinter, "Owner should be able to change minter");

    // Test that non-owner cannot change minter
    address nonOwner = address(0x1);
    vm.startPrank(nonOwner);
    bool nonOwnerCantChangeMinter = false;
    try verbsToken.setMinter(nonOwner) {
        fail("Non-owner should not be able to change minter");
    } catch {
        nonOwnerCantChangeMinter = true;
    }
    vm.stopPrank();

    assertTrue(nonOwnerCantChangeMinter, "Non-owner should not be able to change minter");
}

/// @dev Tests that minted tokens are correctly associated with the art piece from CultureIndex
function testCorrectArtAssociation() public {
    setUp();
    uint256 artPieceId = createDefaultArtPiece();
    uint256 tokenId = verbsToken.mint();

    (uint256 recordedPieceId,,,) = verbsToken.artPieces(tokenId);

    // Validate the token's associated art piece
    assertEq(recordedPieceId, artPieceId, "Minted token should be associated with the correct art piece");
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

/// @dev Tests that only the minter can burn tokens
function testBurningPermission() public {
    setUp();
    createDefaultArtPiece();
    uint256 tokenId = verbsToken.mint();

    // Try to burn token as a minter
    verbsToken.burn(tokenId);

    // Try to burn token as a non-minter
    address nonMinter = address(0xABC);
    vm.startPrank(nonMinter);
    try verbsToken.burn(tokenId) {
        fail("Non-minter should not be able to burn tokens");
    } catch Error(string memory reason) {
        assertEq(reason, "Sender is not the minter");
    }
    vm.stopPrank();
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

/// @dev Tests token metadata integrity after minting
function testTokenMetadataIntegrity() public {
    setUp();

    // Create an art piece and mint a token
    uint256 artPieceId = createDefaultArtPiece();
    uint256 tokenId = verbsToken.mint();

    // Retrieve the token metadata URI
    string memory tokenURI = verbsToken.tokenURI(tokenId);

    emit log_string(tokenURI);

    // Extract the base64 encoded part of the tokenURI
    string memory base64Metadata = substring(tokenURI, 29, bytes(tokenURI).length);
    emit log_string(base64Metadata);

    // Decode the base64 encoded metadata
    string memory metadataJson = decodeMetadata(base64Metadata);
    emit log_string(metadataJson);

    // Parse the JSON to get metadata fields
    (string memory name, string memory description, string memory image) = parseJson(metadataJson);

    // Retrieve the expected metadata directly from the art piece for comparison
    (,ICultureIndex.ArtPieceMetadata memory metadata,,) = cultureIndex.pieces(artPieceId);

    // Assert that the token metadata matches the expected metadata from the art piece
    assertEq(name, metadata.name, "Token name does not match expected name");
    assertEq(description, metadata.description, "Token description does not match expected description");
    assertEq(image, metadata.image, "Token image does not match expected image URL");
}

// Helper function to decode base64 encoded metadata
function decodeMetadata(string memory base64Metadata) internal pure returns (string memory) {
    // Decode the base64 string
    return string(Base64Decode.decode(base64Metadata));
}

// Helper function to extract a substring from a string
function substring(string memory str, uint256 startIndex, uint256 endIndex) internal pure returns (string memory) {
    bytes memory strBytes = bytes(str);
    bytes memory result = new bytes(endIndex - startIndex);
    for(uint256 i = startIndex; i < endIndex; i++) {
        result[i-startIndex] = strBytes[i];
    }
    return string(result);
}

// Helper function to parse JSON strings into components
function parseJson(string memory _json) internal returns (string memory name, string memory description, string memory image) {
    uint returnValue;
    JsmnSolLib.Token[] memory tokens;
    uint actualNum;

    // Number of tokens to be parsed in the JSON (could be estimated or exactly known)
    uint256 numTokens = 20; // Increase if necessary to accommodate all fields in the JSON

    // Parse the JSON
    (returnValue, tokens, actualNum) = JsmnSolLib.parse(_json, numTokens);

    emit log_uint(returnValue);
    emit log_uint(actualNum);
    emit log_uint(tokens.length);

    // Extract values from JSON by token indices
    for(uint256 i = 0; i < actualNum; i++) {
        JsmnSolLib.Token memory t = tokens[i];

        // Check if the token is a key
        if (t.jsmnType == JsmnSolLib.JsmnType.STRING && (i+1) < actualNum) {
            string memory key = JsmnSolLib.getBytes(_json, t.start, t.end);
            string memory value = JsmnSolLib.getBytes(_json, tokens[i+1].start, tokens[i+1].end);
            
            // Compare the key with expected fields
            if (keccak256(bytes(key)) == keccak256(bytes("name"))) {
                name = value;
            } else if (keccak256(bytes(key)) == keccak256(bytes("description"))) {
                description = value;
            } else if (keccak256(bytes(key)) == keccak256(bytes("image"))) {
                image = value;
            }
            // Skip the value token, as the key's value is always the next token
            i++;
        }
    }

    return (name, description, image);
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
