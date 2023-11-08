// SPDX-License-Identifier: GPL-3.0

/// @title The Verbs NFT descriptor

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IVerbsDescriptor } from "./interfaces/IVerbsDescriptor.sol";
import { NFTDescriptor } from "./libs/NFTDescriptor.sol";
import { ICultureIndex } from "./interfaces/ICultureIndex.sol";

contract VerbsDescriptor is IVerbsDescriptor, Ownable {
    using Strings for uint256;

    // prettier-ignore
    // https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt
    bytes32 constant COPYRIGHT_CC0_1_0_UNIVERSAL_LICENSE = 0xa2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499;

    // Whether or not `tokenURI` should be returned as a data URI (Default: true)
    bool public override isDataURIEnabled = true;

    // Base URI
    string public override baseURI;

    constructor(address _initialOwner) Ownable(_initialOwner) {}

    /**
     * @notice Toggle a boolean value which determines if `tokenURI` returns a data URI
     * or an HTTP URL.
     * @dev This can only be called by the owner.
     */
    function toggleDataURIEnabled() external override onlyOwner {
        bool enabled = !isDataURIEnabled;

        isDataURIEnabled = enabled;
        emit DataURIToggled(enabled);
    }

    /**
     * @notice Set the base URI for all token IDs. It is automatically
     * added as a prefix to the value returned in {tokenURI}, or to the
     * token ID if {tokenURI} is empty.
     * @dev This can only be called by the owner.
     */
    function setBaseURI(string calldata _baseURI) external override onlyOwner {
        baseURI = _baseURI;

        emit BaseURIUpdated(_baseURI);
    }

    /**
     * @notice Given a token ID, construct a token URI for an official Vrbs DAO verb.
     * @dev The returned value may be a base64 encoded data URI or an API URL.
     */
    function tokenURI(uint256 tokenId, ICultureIndex.ArtPieceMetadata memory metadata) external view returns (string memory) {
        if (isDataURIEnabled) {
            return dataURI(tokenId, metadata);
        }
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    /**
     * @notice Given a token ID, construct a base64 encoded data URI for an official Vrbs DAO verb.
     */
    function dataURI(uint256 tokenId, ICultureIndex.ArtPieceMetadata memory metadata) public pure returns (string memory) {
        // string memory verbId = tokenId.toString();
        // string memory name = string(abi.encodePacked("Verb ", verbId));

        return genericDataURI(metadata.name, metadata);
    }

    /**
     * @notice Given a name, and metadata, construct a base64 encoded data URI.
     */
    function genericDataURI(string memory name, ICultureIndex.ArtPieceMetadata memory metadata) public pure returns (string memory) {
        /// @dev Get name description image and animation_url from CultureIndex

        NFTDescriptor.TokenURIParams memory params = NFTDescriptor.TokenURIParams({
            name: name,
            description: metadata.description,
            image: metadata.image,
            animation_url: metadata.animationUrl
        });
        return NFTDescriptor.constructTokenURI(params);
    }
}
