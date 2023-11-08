// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../packages/revolution-contracts/VerbsDescriptor.sol";

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
}
