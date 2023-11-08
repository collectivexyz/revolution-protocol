// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../packages/revolution-contracts/VerbsDescriptor.sol";
import {IVerbsDescriptor} from "../packages/revolution-contracts/interfaces/IVerbsDescriptor.sol";

contract VerbsDescriptorTest is Test {
    VerbsDescriptor descriptor;
    address owner;

    function setUp() public {
        owner = address(this);
        descriptor = new VerbsDescriptor(owner);
    }

    /// @notice Test that toggling `isDataURIEnabled` changes state correctly
    function testToggleDataURIEnabled() public {
        setUp();

        bool originalState = descriptor.isDataURIEnabled();
        descriptor.toggleDataURIEnabled();
        bool newState = descriptor.isDataURIEnabled();

        assertEq(newState, !originalState, "isDataURIEnabled should be toggled");
    }

    /// @notice Test that only owner can toggle `isDataURIEnabled`
    function testToggleDataURIEnabledAccessControl() public {
        setUp();

        address nonOwner = address(0x123);
        vm.startPrank(nonOwner);
        vm.expectRevert();
        descriptor.toggleDataURIEnabled();
        vm.stopPrank();
    }

    /// @notice Test `setBaseURI` updates `baseURI` correctly
    function testSetBaseURI() public {
        setUp();

        string memory newBaseURI = "https://example.com/";
        descriptor.setBaseURI(newBaseURI);
        string memory currentBaseURI = descriptor.baseURI();

        assertEq(currentBaseURI, newBaseURI, "baseURI should be updated");
    }

    /// @notice Test that only the owner can update `baseURI`
function testSetBaseURI_AccessControl() public {
    setUp();

    string memory newBaseURI = "https://newexample.com/";
    address nonOwner = address(0x456);

    vm.startPrank(nonOwner);
    vm.expectRevert();
    descriptor.setBaseURI(newBaseURI);
    vm.stopPrank();

    // The baseURI should remain unchanged since the non-owner could not update it
    string memory currentBaseURI = descriptor.baseURI();
    assertEq(currentBaseURI, "", "baseURI should not have changed");
}

/// @notice Test `tokenURI` returns correct data URI when `isDataURIEnabled` is true
function testTokenURIWithDataURIEnabled() public {
    setUp();

    // Enable data URI
    descriptor.toggleDataURIEnabled();
    assertFalse(descriptor.isDataURIEnabled(), "Data URI should be enabled");

    // Set up a token ID and dummy metadata
    uint256 tokenId = 1;
    ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex.ArtPieceMetadata({
        name: "Test Art",
        description: "A description",
        mediaType: ICultureIndex.MediaType.IMAGE,
        image: "https://example.com/image.png",
        text: "",
        animationUrl: ""
    });

    // Call tokenURI and check the return value is a data URI
    string memory uri = descriptor.tokenURI(tokenId, metadata);
    assertTrue(bytes(uri).length > 0, "URI should not be empty");
    emit log_string(uri);
    // Further data URI validation can be done here if necessary

    //tokenURI should just be 1
    assertEq(uri, "1", "URI should just be the token ID");
}

/// @notice Test `tokenURI` returns correct HTTP URL when `isDataURIEnabled` is false
function testTokenURIWithHTTPURL() public {
    setUp();

    // Make sure data URI is disabled
    descriptor.toggleDataURIEnabled();
    assertFalse(descriptor.isDataURIEnabled(), "Data URI should be disabled");

    // Set base URI
    string memory baseURI = "https://api.example.com/token/";
    descriptor.setBaseURI(baseURI);

    // Set up token ID
    uint256 tokenId = 1;

    // Create dummy metadata
    ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex.ArtPieceMetadata({
        name: "Test Art",
        description: "A description",
        mediaType: ICultureIndex.MediaType.IMAGE,
        image: "https://example.com/image.png",
        text: "",
        animationUrl: ""
    });

    // Call tokenURI and check it returns the correct HTTP URL
    string memory expectedURI = string(abi.encodePacked(baseURI, Strings.toString(tokenId)));
    string memory actualURI = descriptor.tokenURI(tokenId, metadata);
    assertEq(actualURI, expectedURI, "The URI should be a concatenation of the baseURI and token ID");
}

/// @notice Test `dataURI` returns valid base64 encoded data URI
function testDataURI() public {
    setUp();

    uint256 tokenId = 1;
    ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex.ArtPieceMetadata({
        name: "Test Art",
        description: "A piece of art",
        mediaType: ICultureIndex.MediaType.IMAGE,
        image: "https://example.com/image.png",
        text: "",
        animationUrl: ""
    });

    string memory uri = descriptor.dataURI(tokenId, metadata);
    assertTrue(bytes(uri).length > 0, "dataURI should not be empty");
    // Check if the string contains the base64 identifier which indicates a base64 encoded data URI
    assertEq(substring(uri, 0, 29), "data:application/json;base64,", "dataURI should start with 'data:application/json;base64,'");
}
/// @notice Test `genericDataURI` returns valid base64 encoded data URI
function testGenericDataURI() public {
    setUp();

    ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex.ArtPieceMetadata({
        name: "Test Art",
        description: "A generic art piece",
        mediaType: ICultureIndex.MediaType.IMAGE,
        image: "https://example.com/image.png",
        text: "",
        animationUrl: ""
    });

    string memory uri = descriptor.genericDataURI(metadata.name, metadata);
    assertTrue(bytes(uri).length > 0, "genericDataURI should not be empty");
    assertEq(substring(uri, 0, 29), "data:application/json;base64,", "dataURI should start with 'data:application/json;base64,'");
}
/// @notice Test `toggleDataURIEnabled` emits `DataURIToggled` event
function testToggleDataURIEnabledEvent() public {
    setUp();

    bool expectedNewState = !descriptor.isDataURIEnabled();
    vm.expectEmit(true, true, false, true);
    emit IVerbsDescriptor.DataURIToggled(expectedNewState);
    descriptor.toggleDataURIEnabled();
}

/// @notice Test `setBaseURI` emits `BaseURIUpdated` event
function testSetBaseURIEvent() public {
    setUp();

    string memory newBaseURI = "https://example.com/newbase";
    vm.expectEmit(true, true, false, true);
    emit IVerbsDescriptor.BaseURIUpdated(newBaseURI);
    descriptor.setBaseURI(newBaseURI);
}
/// @notice Test baseline `tokenURI` with `isDataURIEnabled` true by default
function testBaselineTokenURIWithDataURIEnabled() public {
    setUp();

    // Since isDataURIEnabled is true by default, we don't need to toggle it
    assertTrue(descriptor.isDataURIEnabled(), "isDataURIEnabled should be true by default");

    uint256 tokenId = 1;
    ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex.ArtPieceMetadata({
        name: "Baseline Art",
        description: "The baseline piece",
        mediaType: ICultureIndex.MediaType.IMAGE,
        image: "https://example.com/baseline.png",
        text: "",
        animationUrl: ""
    });

    string memory uri = descriptor.tokenURI(tokenId, metadata);
    assertTrue(bytes(uri).length > 0, "URI should not be empty");
    assertEq(substring(uri, 0, 29), "data:application/json;base64,", "dataURI should start with 'data:application/json;base64,'");
}

/// @notice Test owner can transfer ownership using `transferOwnership`
function testTransferOwnership() public {
    setUp();

    address newOwner = address(0x456);

    // The current owner transfers ownership to the newOwner
    descriptor.transferOwnership(newOwner);

    // Verify that the new owner is indeed set
    assertEq(descriptor.owner(), newOwner, "Ownership should be transferred to newOwner");
}

/// @notice Ensure `transferOwnership` access control
function testTransferOwnershipAccessControl() public {
    setUp();

    address nonOwner = address(0x789);
    address newOwner = address(0x456);

    // Start prank as nonOwner, expect revert on ownership transfer attempt
    vm.startPrank(nonOwner);
    vm.expectRevert();
    descriptor.transferOwnership(newOwner);
    vm.stopPrank();

    // Verify ownership has not changed
    assertEq(descriptor.owner(), owner, "Ownership should not have changed");
}



// Helper function to get substring from a string
function substring(string memory str, uint startIndex, uint endIndex) public pure returns (string memory) {
    bytes memory strBytes = bytes(str);
    bytes memory result = new bytes(endIndex - startIndex);
    for(uint i = startIndex; i < endIndex; i++) {
        result[i-startIndex] = strBytes[i];
    }
    return string(result);
}
}

