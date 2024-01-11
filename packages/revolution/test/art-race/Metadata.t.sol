// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ArtRace } from "../../src/art-race/ArtRace.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { IArtRace } from "../../src/interfaces/IArtRace.sol";
import { ArtRaceTestSuite } from "./ArtRace.t.sol";

/**
 * @title ArtRaceArtMetadataTest
 * @dev Test contract for ArtRace art metadata
 */
contract ArtRaceArtMetadataTest is ArtRaceTestSuite {
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
        string memory longName = createLongString(artRace.MAX_NAME_LENGTH() + 1);
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            longName,
            "Valid Description",
            IArtRace.MediaType.IMAGE,
            "ipfs://lajdslkajsdlkjaslkdj",
            "",
            "",
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    // Test for exceeding the maximum description length
    function test__ExceedingDescriptionLength() public {
        string memory longDescription = createLongString(artRace.MAX_DESCRIPTION_LENGTH() + 1);
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            longDescription,
            IArtRace.MediaType.IMAGE,
            "valid_image_link",
            "",
            "",
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__ExceedingImageLength() public {
        string memory longImageUrl = createLongString(artRace.MAX_IMAGE_LENGTH() + 1);
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.IMAGE,
            longImageUrl,
            "",
            "",
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__ExceedingAnimationLength() public {
        string memory longAnimationUrl = createLongString(artRace.MAX_ANIMATION_URL_LENGTH() + 1);
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.ANIMATION,
            "",
            "",
            longAnimationUrl,
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__ExceedingAudioLength() public {
        string memory longAudioUrl = createLongString(artRace.MAX_ANIMATION_URL_LENGTH() + 1);
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.AUDIO,
            "",
            "",
            longAudioUrl,
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__ExceedingTextLength() public {
        string memory longText = createLongString(artRace.MAX_TEXT_LENGTH() + 1);
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.TEXT,
            "",
            longText,
            "",
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__MissingMediaDataAudio() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.AUDIO,
            "",
            "",
            "", // Missing animation URL
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__InvalidImagePrefix() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.IMAGE,
            "ipfz://alksjdalskdjalksjdlakjsd",
            "",
            "", //invalid animation URL
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__ValidImagePrefixIpfs() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.IMAGE,
            "ipfs://",
            "",
            "", //invalid animation URL
            address(0x1),
            10000
        );

        artRace.createPiece(metadata, creators);
    }

    function test__ValidImagePrefixSvg() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.IMAGE,
            "data:image/svg+xml;base64,",
            "",
            "", //invalid animation URL
            address(0x1),
            10000
        );

        artRace.createPiece(metadata, creators);
    }

    function test__InvalidBothHashesAnimation() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.ANIMATION,
            "ipfz://bafybeigofz5ao63vehylvbgx5ikcjfualns4xpx5gmibdojeaydq7khviy", //invalid animation URL
            "",
            "ipfz://bafybeigofz5ao63vehylvbgx5ikcjfualns4xpx5gmibdojeaydq7khviy", //invalid animation URL
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__InvalidBothHashesImage() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.IMAGE,
            "ipfz://bafybeigofz5ao63vehylvbgx5ikcjfualns4xpx5gmibdojeaydq7khviy", //invalid animation URL
            "",
            "ipfz://bafybeigofz5ao63vehylvbgx5ikcjfualns4xpx5gmibdojeaydq7khviy", //invalid animation URL
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__ValidHashesAnimation_SVG() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.ANIMATION,
            "data:image/svg+xml;base64,", //invalid animation URL
            "",
            "ipfs://bafybeigofz5ao63vehylvbgx5ikcjfualns4xpx5gmibdojeaydq7khviy", //invalid animation URL
            address(0x1),
            10000
        );

        artRace.createPiece(metadata, creators);
    }

    function test__InvalidOneHashImage_1() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.IMAGE,
            "ipfz://bafybeigofz5ao63vehylvbgx5ikcjfualns4xpx5gmibdojeaydq7khviy", //invalid animation URL
            "",
            "ipfs://bafybeigofz5ao63vehylvbgx5ikcjfualns4xpx5gmibdojeaydq7khviy", //invalid animation URL
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__InvalidOneHashImage_2() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.IMAGE,
            "ipfs://bafybeigofz5ao63vehylvbgx5ikcjfualns4xpx5gmibdojeaydq7khviy", //invalid animation URL
            "",
            "ipfz://bafybeigofz5ao63vehylvbgx5ikcjfualns4xpx5gmibdojeaydq7khviy", //invalid animation URL
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__InvalidOneHashAnimation_1() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.ANIMATION,
            "ipfz://bafybeigofz5ao63vehylvbgx5ikcjfualns4xpx5gmibdojeaydq7khviy", //invalid animation URL
            "",
            "ipfs://bafybeigofz5ao63vehylvbgx5ikcjfualns4xpx5gmibdojeaydq7khviy", //invalid animation URL
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__InvalidOneHashAnimation_2() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.ANIMATION,
            "ipfs://bafybeigofz5ao63vehylvbgx5ikcjfualns4xpx5gmibdojeaydq7khviy", //invalid animation URL
            "",
            "ipfz://bafybeigofz5ao63vehylvbgx5ikcjfualns4xpx5gmibdojeaydq7khviy", //invalid animation URL
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__InvalidImagePrefixFullHash() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.ANIMATION,
            "ipfz://bafybeigofz5ao63vehylvbgx5ikcjfualns4xpx5gmibdojeaydq7khviy", //invalid animation URL
            "",
            "",
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__InvalidAnimationPrefixFullHash() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.ANIMATION,
            "",
            "",
            "ipfz://bafybeigofz5ao63vehylvbgx5ikcjfualns4xpx5gmibdojeaydq7khviy", //invalid animation URL
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__InvalidAnimationPrefix() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.ANIMATION,
            "",
            "",
            "ipfz://", //invalid animation URL
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }

    function test__MissingMediaDataText() public {
        (ArtRace.ArtPieceMetadata memory metadata, IArtRace.CreatorBps[] memory creators) = createArtPieceTuple(
            "Valid Name",
            "Valid Description",
            IArtRace.MediaType.TEXT,
            "",
            "", // Missing text content
            "",
            address(0x1),
            10000
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_METADATA()"));
        artRace.createPiece(metadata, creators);
    }
}
