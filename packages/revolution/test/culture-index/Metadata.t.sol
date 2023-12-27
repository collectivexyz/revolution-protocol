// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { CultureIndexTestSuite } from "./CultureIndex.t.sol";

/**
 * @title CultureIndexArtMetadataTest
 * @dev Test contract for CultureIndex art metadata
 */
contract CultureIndexArtMetadataTest is CultureIndexTestSuite {
    // Helper function to create a string of a specified length
    function createLongString(uint length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(length);
        for (uint i = 0; i < length; i++) {
            buffer[i] = bytes1(uint8(65 + (i % 26))); // Fills the string with a repeating pattern of letters
        }
        return string(buffer);
    }

    // Test for exceeding the maximum name length
    function test__ExceedingNameLength() public {
        string memory longName = createLongString(cultureIndex.MAX_NAME_LENGTH() + 1);
        (
            CultureIndex.ArtPieceMetadata memory metadata,
            ICultureIndex.CreatorBps[] memory creators
        ) = createArtPieceTuple(
                longName,
                "Valid Description",
                ICultureIndex.MediaType.IMAGE,
                "valid_image_link",
                "",
                "",
                address(0x1),
                10000
            );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        cultureIndex.createPiece(metadata, creators);
    }

    // Test for exceeding the maximum description length
    function test__ExceedingDescriptionLength() public {
        string memory longDescription = createLongString(cultureIndex.MAX_DESCRIPTION_LENGTH() + 1);
        (
            CultureIndex.ArtPieceMetadata memory metadata,
            ICultureIndex.CreatorBps[] memory creators
        ) = createArtPieceTuple(
                "Valid Name",
                longDescription,
                ICultureIndex.MediaType.IMAGE,
                "valid_image_link",
                "",
                "",
                address(0x1),
                10000
            );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        cultureIndex.createPiece(metadata, creators);
    }

    function test__ExceedingImageLength() public {
        string memory longImageUrl = createLongString(cultureIndex.MAX_IMAGE_LENGTH() + 1);
        (
            CultureIndex.ArtPieceMetadata memory metadata,
            ICultureIndex.CreatorBps[] memory creators
        ) = createArtPieceTuple(
                "Valid Name",
                "Valid Description",
                ICultureIndex.MediaType.IMAGE,
                longImageUrl,
                "",
                "",
                address(0x1),
                10000
            );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        cultureIndex.createPiece(metadata, creators);
    }

    function test__ExceedingAnimationLength() public {
        string memory longAnimationUrl = createLongString(cultureIndex.MAX_ANIMATION_URL_LENGTH() + 1);
        (
            CultureIndex.ArtPieceMetadata memory metadata,
            ICultureIndex.CreatorBps[] memory creators
        ) = createArtPieceTuple(
                "Valid Name",
                "Valid Description",
                ICultureIndex.MediaType.ANIMATION,
                "",
                "",
                longAnimationUrl,
                address(0x1),
                10000
            );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        cultureIndex.createPiece(metadata, creators);
    }

    function test__ExceedingAudioLength() public {
        string memory longAudioUrl = createLongString(cultureIndex.MAX_ANIMATION_URL_LENGTH() + 1);
        (
            CultureIndex.ArtPieceMetadata memory metadata,
            ICultureIndex.CreatorBps[] memory creators
        ) = createArtPieceTuple(
                "Valid Name",
                "Valid Description",
                ICultureIndex.MediaType.AUDIO,
                "",
                "",
                longAudioUrl,
                address(0x1),
                10000
            );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        cultureIndex.createPiece(metadata, creators);
    }

    function test__ExceedingTextLength() public {
        string memory longText = createLongString(cultureIndex.MAX_TEXT_LENGTH() + 1);
        (
            CultureIndex.ArtPieceMetadata memory metadata,
            ICultureIndex.CreatorBps[] memory creators
        ) = createArtPieceTuple(
                "Valid Name",
                "Valid Description",
                ICultureIndex.MediaType.TEXT,
                "",
                longText,
                "",
                address(0x1),
                10000
            );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        cultureIndex.createPiece(metadata, creators);
    }

    function test__MissingMediaDataAudio() public {
        (
            CultureIndex.ArtPieceMetadata memory metadata,
            ICultureIndex.CreatorBps[] memory creators
        ) = createArtPieceTuple(
                "Valid Name",
                "Valid Description",
                ICultureIndex.MediaType.AUDIO,
                "",
                "",
                "", // Missing animation URL
                address(0x1),
                10000
            );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        cultureIndex.createPiece(metadata, creators);
    }

    function test__MissingMediaDataText() public {
        (
            CultureIndex.ArtPieceMetadata memory metadata,
            ICultureIndex.CreatorBps[] memory creators
        ) = createArtPieceTuple(
                "Valid Name",
                "Valid Description",
                ICultureIndex.MediaType.TEXT,
                "",
                "", // Missing text content
                "",
                address(0x1),
                10000
            );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        cultureIndex.createPiece(metadata, creators);
    }
}
