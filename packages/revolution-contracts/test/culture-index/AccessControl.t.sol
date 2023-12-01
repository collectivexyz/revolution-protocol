// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";
import { VerbsToken } from "../../src/VerbsToken.sol";
import { IVerbsToken } from "../../src/interfaces/IVerbsToken.sol";
import { IVerbsDescriptorMinimal } from "../../src/interfaces/IVerbsDescriptorMinimal.sol";
import { IProxyRegistry } from "../../src/external/opensea/IProxyRegistry.sol";
import { ICultureIndex, ICultureIndexEvents } from "../../src/interfaces/ICultureIndex.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { CultureIndex } from "../../src/CultureIndex.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { VerbsDescriptor } from "../../src/VerbsDescriptor.sol";
import "../utils/Base64Decode.sol";
import "../utils/JsmnSolLib.sol";
import { CultureIndexTestSuite } from "./CultureIndex.t.sol";
import { ERC721Checkpointable } from "../../src/base/ERC721Checkpointable.sol";

/// @title VerbsTokenTest
/// @dev The test suite for the VerbsToken contract
contract CultureIndexAccessControlTest is CultureIndexTestSuite {
    /// @dev Tests minting by non-minter should revert
    function testRevertOnNonOwnerUpdateVotingToken() public {
        setUp();

        address nonMinter = address(0xABC); // This is an arbitrary address
        vm.startPrank(nonMinter);

        vm.expectRevert();
        cultureIndex.setERC721VotingToken(verbs);

        vm.stopPrank();
    }

    /// @dev Tests the locking of admin functions
    function testLockAdminFunctions() public {
        setUp();

        // Lock the ERC721VotingToken
        cultureIndex.lockERC721VotingToken();

        // Attempt to change minter, descriptor, or cultureIndex and expect to fail

        try cultureIndex.setERC721VotingToken(verbs) {
            fail("Should fail: ERC721VotingToken is locked");
        } catch {}

        assertTrue(cultureIndex.isERC721VotingTokenLocked(), "ERC721VotingToken should be locked");
    }

    /// @dev Tests that only the owner can lock the ERC721 voting token
    function testOnlyOwnerCanLockERC721VotingToken() public {
        setUp();
        address nonOwner = address(0x123); // This is an arbitrary address
        vm.startPrank(nonOwner);

        vm.expectRevert();
        cultureIndex.lockERC721VotingToken();

        vm.stopPrank();

        vm.startPrank(address(this));
        vm.expectEmit(true, true, true, true);
        emit ICultureIndexEvents.ERC721VotingTokenLocked();
        cultureIndex.lockERC721VotingToken();
        vm.stopPrank();

        assertTrue(cultureIndex.isERC721VotingTokenLocked(), "ERC721VotingToken should be locked by owner only");
    }

    /// @dev Tests only the owner can update the ERC721 voting token
    function testSetERC721VotingToken() public {
        setUp();
        address newTokenAddress = address(0x123); // New ERC721 token address
        ERC721Checkpointable newToken = ERC721Checkpointable(newTokenAddress);

        // Attempting update by a non-owner should revert
        address nonOwner = address(0xABC);
        vm.startPrank(nonOwner);
        vm.expectRevert();
        cultureIndex.setERC721VotingToken(newToken);
        vm.stopPrank();

        // Update by owner should succeed
        vm.startPrank(address(this));
        cultureIndex.setERC721VotingToken(newToken);
        assertEq(address(cultureIndex.erc721VotingToken()), newTokenAddress);
        vm.stopPrank();
    }
}

contract ProxyRegistry is IProxyRegistry {
    mapping(address => address) public proxies;
}
