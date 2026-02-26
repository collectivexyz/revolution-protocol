// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { ICultureIndex, ICultureIndexEvents } from "../../src/interfaces/ICultureIndex.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { CultureIndexTestSuite } from "./CultureIndex.t.sol";
import { IMaxHeap } from "../../src/interfaces/IMaxHeap.sol";
import { ERC721CheckpointableUpgradeable } from "../../src/base/ERC721CheckpointableUpgradeable.sol";

/**
 * @title CultureIndex Deploy Test
 * @dev Test contract for CultureIndex
 */
contract CultureIndexDeployTest is CultureIndexTestSuite {
    // Utility function to create a new art piece and return its ID
    function createArtPieceOnIndex(
        address cultureIndex,
        string memory name,
        string memory description,
        ICultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl,
        address creatorAddress,
        uint256 creatorBps
    ) internal returns (uint256) {
        ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex.ArtPieceMetadata({
            name: name,
            description: description,
            mediaType: mediaType,
            image: image,
            text: text,
            animationUrl: animationUrl
        });

        ICultureIndex.CreatorBps[] memory creators = new ICultureIndex.CreatorBps[](1);
        creators[0] = ICultureIndex.CreatorBps({ creator: creatorAddress, bps: creatorBps });

        return ICultureIndex(cultureIndex).createPiece(metadata, creators);
    }

    function deployCultureIndex() public returns (address, address) {
        vm.stopPrank();

        setCultureIndexParams(
            "Vrbs Memes Contest",
            "Our community memes contest.",
            "- [ ] Must be original. - [ ] Must be spicy.",
            "ipfs://",
            100 * 1e18,
            1,
            1000,
            0,
            0,
            ICultureIndex.PieceMaximums({ name: 100, description: 2100, image: 64_000, text: 256, animationUrl: 100 }),
            ICultureIndex.MediaType.NONE,
            ICultureIndex.RequiredMediaPrefix.MIXED
        );

        return
            manager.deployCultureIndex(
                address(revolutionVotingPower),
                address(this),
                address(this),
                cultureIndexParams
            );
    }

    function test__DeployCultureIndex() public {
        (address cultureIndexAddr, address maxHeapAddr) = deployCultureIndex();

        ICultureIndex.CreatorBps[] memory creators = new ICultureIndex.CreatorBps[](1);
        creators[0] = ICultureIndex.CreatorBps({ creator: address(this), bps: 1e4 });

        vm.expectEmit(true, true, true, true);
        emit ICultureIndexEvents.PieceCreated(
            0,
            address(this),
            ICultureIndex.ArtPieceMetadata({
                name: "Vrbs",
                description: "Our community Vrbs.",
                image: "ipfs://QmQzDwaZ7yQxHHs7sQQenJVB89riTSacSGcJRv9jtHPuz5",
                animationUrl: "",
                text: "Vrb",
                mediaType: ICultureIndex.MediaType.IMAGE
            }),
            creators
        );

        createArtPieceOnIndex(
            cultureIndexAddr,
            "Vrbs",
            "Our community Vrbs.",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://QmQzDwaZ7yQxHHs7sQQenJVB89riTSacSGcJRv9jtHPuz5",
            "Vrb",
            "",
            address(this),
            1e4
        );

        // ensure max heap size is 1
        uint256 maxHeapSize = IMaxHeap(maxHeapAddr).size();
        assertEq(maxHeapSize, 1, "Max heap size should be 1");

        //ensure culture index name and description are set correctly
        assertEq(CultureIndex(cultureIndexAddr).name(), "Vrbs Memes Contest");
        assertEq(CultureIndex(cultureIndexAddr).description(), "Our community memes contest.");
    }
}
