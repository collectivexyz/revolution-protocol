// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { RevolutionToken } from "../../src/RevolutionToken.sol";
import { IRevolutionToken } from "../../src/interfaces/IRevolutionToken.sol";
import { IDescriptorMinimal } from "../../src/interfaces/IDescriptorMinimal.sol";

import { IArtRace } from "../../src/interfaces/IArtRace.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ArtRace } from "../../src/art-race/ArtRace.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { Descriptor } from "../../src/Descriptor.sol";
import "../utils/Base64Decode.sol";
import "../utils/JsmnSolLib.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";

/// @title RevolutionTokenTestSuite
/// @dev The base test suite for the RevolutionToken contract
contract RevolutionTokenTestSuite is RevolutionBuilderTest {
    string public tokenNamePrefix = "Vrb";
    string public tokenName = "Vrbs";
    string public tokenSymbol = "VRBS";

    /// @dev Sets up a new RevolutionToken instance before each test
    function setUp() public override {
        super.setUp();
        super.setMockParams();

        super.setRevolutionTokenParams(tokenName, tokenSymbol, "https://example.com/token/", tokenNamePrefix);

        super.setCultureIndexParams("Vrbs", "Our community Vrbs. Must be 32x32.", 10, 200, 0);

        super.deployMock();

        vm.startPrank(address(executor));
    }

    // Utility function to create a new art piece and return its ID
    function createArtPiece(
        string memory name,
        string memory description,
        IArtRace.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl,
        address creatorAddress,
        uint256 creatorBps
    ) internal returns (uint256) {
        IArtRace.ArtPieceMetadata memory metadata = IArtRace.ArtPieceMetadata({
            name: name,
            description: description,
            mediaType: mediaType,
            image: image,
            text: text,
            animationUrl: animationUrl
        });

        IArtRace.CreatorBps[] memory creators = new IArtRace.CreatorBps[](1);
        creators[0] = IArtRace.CreatorBps({ creator: creatorAddress, bps: creatorBps });

        return cultureIndex.createPiece(metadata, creators);
    }

    //Utility function to create default art piece
    function createDefaultArtPiece() public returns (uint256) {
        return
            createArtPiece(
                "Mona Lisa",
                "A masterpiece",
                IArtRace.MediaType.IMAGE,
                "ipfs://legends",
                "",
                "",
                address(0x1),
                10000
            );
    }

    //function to create basic metadata
    function createDefaultMetadata() internal pure returns (IArtRace.ArtPieceMetadata memory) {
        return
            IArtRace.ArtPieceMetadata({
                name: "Mona Lisa",
                description: "A masterpiece",
                mediaType: IArtRace.MediaType.IMAGE,
                image: "ipfs://legends",
                text: "",
                animationUrl: ""
            });
    }
}
