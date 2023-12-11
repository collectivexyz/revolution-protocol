// SPDX-License-Identifier: GPL-3.0

/// @title Common interface for Descriptor versions, as used by VerbsToken

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

import { ICultureIndex } from "./ICultureIndex.sol";

interface IDescriptorMinimal {
    ///
    /// USED BY TOKEN
    ///

    function tokenURI(
        uint256 tokenId,
        ICultureIndex.ArtPieceMetadata memory metadata
    ) external view returns (string memory);

    function dataURI(
        uint256 tokenId,
        ICultureIndex.ArtPieceMetadata memory metadata
    ) external view returns (string memory);
}
