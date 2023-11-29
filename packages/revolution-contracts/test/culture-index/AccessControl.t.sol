// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { VerbsToken } from "../../src/VerbsToken.sol";
import { IVerbsToken } from "../../src/interfaces/IVerbsToken.sol";
import { IVerbsDescriptorMinimal } from "../../src/interfaces/IVerbsDescriptorMinimal.sol";
import { IProxyRegistry } from "../../src/external/opensea/IProxyRegistry.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { CultureIndex } from "../../src/CultureIndex.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { VerbsDescriptor } from "../../src/VerbsDescriptor.sol";
import "../utils/Base64Decode.sol";
import "../utils/JsmnSolLib.sol";
import { CultureIndexTestSuite } from "./CultureIndex.t.sol";

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
        } catch {
        }

        assertTrue(cultureIndex.isERC721VotingTokenLocked(), "ERC721VotingToken should be locked");
    }

}

contract ProxyRegistry is IProxyRegistry {
    mapping(address => address) public proxies;
}
