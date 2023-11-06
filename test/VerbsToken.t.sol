// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {VerbsToken} from "../packages/revolution-contracts/VerbsToken.sol";  // Update this path
import { IVerbsDescriptorMinimal } from "../packages/revolution-contracts/interfaces/IVerbsDescriptorMinimal.sol";
import { IProxyRegistry } from "../packages/revolution-contracts/external/opensea/IProxyRegistry.sol";
import { ICultureIndex } from "../packages/revolution-contracts/interfaces/ICultureIndex.sol";
import { NFTDescriptor } from "../packages/revolution-contracts/libs/NFTDescriptor.sol";

/// @title VerbsTokenTest
/// @dev The test suite for the VerbsToken contract
contract VerbsTokenTest is Test {
    VerbsToken public verbsToken;

    /// @dev Sets up a new VerbsToken instance before each test
    function setUp() public {
        IVerbsDescriptorMinimal _descriptor = new MockVerbsDescriptor();
        IProxyRegistry _proxyRegistry = IProxyRegistry(address(0x2));
        ICultureIndex _cultureIndex = ICultureIndex(address(0x1));
        
        verbsToken = new VerbsToken(address(this), _descriptor, _proxyRegistry, _cultureIndex);
    }


    /// @dev Tests the minting of a new verb token
    function testMint() public {
        // Assume the mint function mints a token and returns its ID
        uint256 tokenId = verbsToken.mint();

        assertEq(tokenId, 1, "First token ID should be 1");
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

    // /// @dev Tests minting a verb token to itself
    // function testMintToItself() public {
    //     setUp();
    //     uint256 initialTotalSupply = verbsToken.totalSupply();
    //     verbsToken.mint();
    //     uint256 newTokenId = verbsToken.totalSupply();
    //     assertEq(newTokenId, initialTotalSupply + 1, "One new token should have been minted");
    //     assertEq(verbsToken.ownerOf(newTokenId), address(this), "The contract should own the newly minted token");
    // }

    // /// @dev Tests burning a verb token
    // function testBurn() public {
    //     setUp();
    //     uint256 tokenId = verbsToken.mint();
    //     uint256 initialTotalSupply = verbsToken.totalSupply();
    //     verbsToken.burn(tokenId);
    //     uint256 newTotalSupply = verbsToken.totalSupply();
    //     assertEq(newTotalSupply, initialTotalSupply - 1, "Total supply should decrease by 1 after burning");
    // }


    // /// @dev Tests minting by non-minter should revert
    // function testRevertOnNonMinterMint() public {
    //     setUp();
    //     try verbsToken.mint() {
    //         fail("Should revert on non-minter mint");
    //     } catch Error(string memory reason) {
    //         assertEq(reason, "Only minter can mint");
    //     }
    // }

    // /// @dev Tests the contract URI of the VerbsToken
    // function testContractURI() public {
    //     setUp();
    //     assertEq(verbsToken.contractURI(), "ipfs://QmQzDwaZ7yQxHHs7sQQenJVB89riTSacSGcJRv9jtHPuz5", "Contract URI should match");
    // }

    // /// @dev Tests that only the owner can set the contract URI
    // function testSetContractURIByOwner() public {
    //     setUp();
    //     verbsToken.setContractURIHash("NewHashHere");
    //     assertEq(verbsToken.contractURI(), "ipfs://NewHashHere", "Contract URI should be updated");
    // }

    // /// @dev Tests that non-owners cannot set the contract URI
    // function testRevertOnNonOwnerSettingContractURI() public {
    //     setUp();
    //     try verbsToken.setContractURIHash("NewHashHere") {
    //         // Assuming a function setContractURIByNonOwner in VerbsToken
    //         fail("Should revert on non-owner setting contract URI");
    //     } catch Error(string memory reason) {
    //         assertEq(reason, "Ownable: caller is not the owner");
    //     }
    // }
}


contract MockVerbsDescriptor is IVerbsDescriptorMinimal {
    // ... implementation, maybe some hard-coded return values or setters for testing

    /**
     * @notice Given a token ID, construct a token URI for an official Vrbs DAO verb.
     * @dev The returned value may be a base64 encoded data URI or an API URL.
     */
    function tokenURI(uint256 tokenId) external view override returns (string memory) {
        return string(abi.encodePacked("ipfs://", tokenId.toString()));
    }

        /**
     * @notice Given a token ID, construct a base64 encoded data URI for an official Vrbs DAO verb.
     */
    function dataURI(uint256 tokenId) public view override returns (string memory) {
        string memory verbId = tokenId.toString();
        string memory name = string(abi.encodePacked("Verb ", verbId));

        return genericDataURI(name);
    }

    /**
     * @notice Given a name, and description, construct a base64 encoded data URI.
     */
    function genericDataURI(string memory name) public view override returns (string memory) {
        /// @dev Get name description image and animation_url from CultureIndex

        NFTDescriptor.TokenURIParams memory params = NFTDescriptor.TokenURIParams({ name: name, description: description, image: image, animation_url: animation_url });
        return NFTDescriptor.constructTokenURI(params);
    }

}

contract MockCultureIndex is ICultureIndex {
    // ... implementation, maybe some hard-coded return values or setters for testing
}