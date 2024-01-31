// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionToken } from "../../src/RevolutionToken.sol";
import { IDescriptorMinimal } from "../../src/interfaces/IDescriptorMinimal.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";

/**
 * @title CultureIndexTest
 * @dev Test contract for CultureIndex
 */
contract CultureIndexTestSuite is RevolutionBuilderTest {
    CultureIndexVotingTest public voter1Test;
    CultureIndexVotingTest public voter2Test;

    /**
     * @dev Setup function for each test case
     */
    function setUp() public virtual override {
        super.setUp();
        super.setMockParams();

        super.setPointsParams("Revolution Governance", "GOV");

        super.setCultureIndexParams(
            "Vrbs",
            "Our community Vrbs. Must be 32x32.",
            10,
            1,
            200,
            0,
            0,
            ICultureIndex.PieceMaximums({ name: 100, description: 2100, image: 64_000, text: 256, animationUrl: 100 }),
            ICultureIndex.RequiredMediaType.NONE,
            ICultureIndex.RequiredMediaPrefix.NONE
        );

        super.setRevolutionTokenParams("Vrbs", "VRBS", "QmQzDwaZ7yQxHHs7sQQenJVB89riTSacSGcJRv9jtHPuz5", "Vrb");

        super.deployMock();

        //start prank to be cultureindex's owner
        vm.startPrank(address(executor));

        // // Create new test instances acting as different voters
        voter1Test = new CultureIndexVotingTest(address(cultureIndex), address(revolutionPoints));
        voter2Test = new CultureIndexVotingTest(address(cultureIndex), address(revolutionPoints));
    }

    function voteForPiece(uint256 pieceId) public {
        cultureIndex.vote(pieceId);
    }
}

contract CultureIndexVotingTest is Test {
    CultureIndex public cultureIndex;
    RevolutionPoints public govToken;

    constructor(address _cultureIndex, address _votingToken) {
        cultureIndex = CultureIndex(_cultureIndex);
        govToken = RevolutionPoints(_votingToken);
    }

    // Utility function to create a new art piece and return its ID
    function createArtPiece(
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

        return cultureIndex.createPiece(metadata, creators);
    }

    //Utility function to create default art piece
    function createDefaultArtPiece() public returns (uint256) {
        return
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

    function voteForPiece(uint256 pieceId) public {
        cultureIndex.vote(pieceId);
    }
}
