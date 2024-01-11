// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { ArtRace } from "../../src/art-race/ArtRace.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { IArtRace } from "../../src/interfaces/IArtRace.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionToken } from "../../src/RevolutionToken.sol";
import { IDescriptorMinimal } from "../../src/interfaces/IDescriptorMinimal.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";

/**
 * @title ArtRaceTest
 * @dev Test contract for ArtRace
 */
contract ArtRaceTestSuite is RevolutionBuilderTest {
    ArtRaceVotingTest public voter1Test;
    ArtRaceVotingTest public voter2Test;

    /**
     * @dev Setup function for each test case
     */
    function setUp() public virtual override {
        super.setUp();
        super.setMockParams();

        super.setPointsParams("Revolution Governance", "GOV");

        super.setArtRaceParams("Vrbs", "Our community Vrbs. Must be 32x32.", 10, 200, 0);

        super.setRevolutionTokenParams("Vrbs", "VRBS", "QmQzDwaZ7yQxHHs7sQQenJVB89riTSacSGcJRv9jtHPuz5", "Vrb");

        super.deployMock();

        //start prank to be cultureindex's owner
        vm.startPrank(address(executor));

        // // Create new test instances acting as different voters
        voter1Test = new ArtRaceVotingTest(address(cultureIndex), address(revolutionPoints));
        voter2Test = new ArtRaceVotingTest(address(cultureIndex), address(revolutionPoints));
    }

    //returns metadata and creators in a tuple
    function createArtPieceTuple(
        string memory name,
        string memory description,
        IArtRace.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl,
        address creatorAddress,
        uint256 creatorBps
    ) public pure returns (ArtRace.ArtPieceMetadata memory, IArtRace.CreatorBps[] memory) {
        // <-- Change here
        IArtRace.ArtPieceMetadata memory metadata = createArtPieceMetadata(
            name,
            description,
            mediaType,
            image,
            text,
            animationUrl
        );
        IArtRace.CreatorBps[] memory creators = createArtPieceCreators(creatorAddress, creatorBps);
        return (metadata, creators);
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

    // Function to create ArtPieceMetadata
    function createArtPieceMetadata(
        string memory name,
        string memory description,
        IArtRace.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl
    ) public pure returns (ArtRace.ArtPieceMetadata memory) {
        // <-- Change visibility and mutability as needed
        IArtRace.ArtPieceMetadata memory metadata = IArtRace.ArtPieceMetadata({
            name: name,
            description: description,
            mediaType: mediaType,
            image: image,
            text: text,
            animationUrl: animationUrl
        });
        return metadata;
    }

    // Function to create CreatorBps array
    function createArtPieceCreators(
        address creatorAddress,
        uint256 creatorBps
    ) public pure returns (ArtRace.CreatorBps[] memory) {
        // <-- Change visibility and mutability as needed
        IArtRace.CreatorBps[] memory creators = new IArtRace.CreatorBps[](1);
        creators[0] = IArtRace.CreatorBps({ creator: creatorAddress, bps: creatorBps });
        return creators;
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

    function voteForPiece(uint256 pieceId) public {
        cultureIndex.vote(pieceId);
    }
}

contract ArtRaceVotingTest is Test {
    ArtRace public cultureIndex;
    RevolutionPoints public govToken;

    constructor(address _cultureIndex, address _votingToken) {
        cultureIndex = ArtRace(_cultureIndex);
        govToken = RevolutionPoints(_votingToken);
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

    function voteForPiece(uint256 pieceId) public {
        cultureIndex.vote(pieceId);
    }
}
