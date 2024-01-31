// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { ICultureIndex, ICultureIndexEvents } from "../../src/interfaces/ICultureIndex.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { CultureIndexTestSuite } from "./CultureIndex.t.sol";
import { ERC721CheckpointableUpgradeable } from "../../src/base/ERC721CheckpointableUpgradeable.sol";

/**
 * @title CultureIndex Required Data Test
 * @dev Test contract for CultureIndex
 */
contract CultureIndexRequiredTest is CultureIndexTestSuite {
    /**
     * @dev Setup function for each test case
     */
    function setUp() public virtual override {
        super.setMockParams();

        super.setPointsParams("Revolution Governance", "GOV");
    }

    function createImage() public {
        createArtPiece(
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

    function createAnimation() public {
        createArtPiece(
            "Mona Lisa",
            "A masterpiece",
            ICultureIndex.MediaType.ANIMATION,
            "",
            "ipfs://legends",
            "",
            address(0x1),
            10000
        );
    }

    function createText() public {
        createArtPiece(
            "Mona Lisa",
            "A masterpiece",
            ICultureIndex.MediaType.TEXT,
            "",
            "",
            "ipfs://legends",
            address(0x1),
            10000
        );
    }

    function createAudio() public {
        createArtPiece("Mona Lisa", "A masterpiece", ICultureIndex.MediaType.AUDIO, "", "", "", address(0x1), 10000);
    }

    function test__requiredMediaType_NONE() public {
        super.setCultureIndexParams(
            "Vrbs",
            "Our community Vrbs. Must be 32x32.",
            10,
            1,
            200,
            0,
            0,
            ICultureIndex.PieceMaximums({ name: 100, description: 2100, image: 64_000, text: 256, animationUrl: 100 }),
            ICultureIndex.MediaType.NONE,
            ICultureIndex.RequiredMediaPrefix.NONE
        );

        super.deployMock();

        // ensure you can add any media type
        // image
        createImage();

        // animation
        createAnimation();

        // text
        createText();

        //audio
        createAudio();

        // expect revert on NONE
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_TYPE()"));
        createArtPiece("Mona Lisa", "A masterpiece", ICultureIndex.MediaType.NONE, "", "", "", address(0x1), 10000);
    }

    //now initialize with a required media type
    function test__requiredMediaType_IMAGE() public {
        super.setCultureIndexParams(
            "Vrbs",
            "Our community Vrbs. Must be 32x32.",
            10,
            1,
            200,
            0,
            0,
            ICultureIndex.PieceMaximums({ name: 100, description: 2100, image: 64_000, text: 256, animationUrl: 100 }),
            ICultureIndex.MediaType.IMAGE,
            ICultureIndex.RequiredMediaPrefix.NONE
        );

        super.deployMock();

        // ensure you can add only images
        // image
        createImage();

        // expect revert on animation
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_TYPE()"));
        createAnimation();

        // expect revert on text
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_TYPE()"));
        createText();

        // expect revert on audio
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_TYPE()"));
        createAudio();
    }

    // test animation
    function test__requiredMediaType_ANIMATION() public {
        super.setCultureIndexParams(
            "Vrbs",
            "Our community Vrbs. Must be 32x32.",
            10,
            1,
            200,
            0,
            0,
            ICultureIndex.PieceMaximums({ name: 100, description: 2100, image: 64_000, text: 256, animationUrl: 100 }),
            ICultureIndex.MediaType.ANIMATION,
            ICultureIndex.RequiredMediaPrefix.NONE
        );

        super.deployMock();

        // ensure you can add only animations
        // animation
        createAnimation();

        // expect revert on image
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_TYPE()"));
        createImage();

        // expect revert on text
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_TYPE()"));
        createText();

        // expect revert on audio
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_TYPE()"));
        createAudio();
    }

    //test text
    function test__requiredMediaType_TEXT() public {
        super.setCultureIndexParams(
            "Vrbs",
            "Our community Vrbs. Must be 32x32.",
            10,
            1,
            200,
            0,
            0,
            ICultureIndex.PieceMaximums({ name: 100, description: 2100, image: 64_000, text: 256, animationUrl: 100 }),
            ICultureIndex.MediaType.TEXT,
            ICultureIndex.RequiredMediaPrefix.NONE
        );

        super.deployMock();

        // ensure you can add only text
        // text
        createText();

        // expect revert on image
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_TYPE()"));
        createImage();

        // expect revert on animation
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_TYPE()"));
        createAnimation();

        // expect revert on audio
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_TYPE()"));
        createAudio();
    }

    //test audio
    function test__requiredMediaType_AUDIO() public {
        super.setCultureIndexParams(
            "Vrbs",
            "Our community Vrbs. Must be 32x32.",
            10,
            1,
            200,
            0,
            0,
            ICultureIndex.PieceMaximums({ name: 100, description: 2100, image: 64_000, text: 256, animationUrl: 100 }),
            ICultureIndex.MediaType.AUDIO,
            ICultureIndex.RequiredMediaPrefix.NONE
        );

        super.deployMock();

        // ensure you can add only audio
        // audio
        createAudio();

        // expect revert on image
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_TYPE()"));
        createImage();

        // expect revert on text
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_TYPE()"));
        createText();

        // expect revert on animation
        vm.expectRevert(abi.encodeWithSignature("INVALID_MEDIA_TYPE()"));
        createAnimation();
    }
}
