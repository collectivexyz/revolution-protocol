// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { ContestBuilderTest } from "./ContestBuilder.t.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { BaseContest } from "../../src/culture-index/contests/BaseContest.sol";

/**
 * @title ContestSubmissions
 * @dev Test contract for Contest creation
 */
contract ContestSubmissions is ContestBuilderTest {
    /**
     * @dev Setup function for each test case
     */
    function setUp() public virtual override {
        super.setUp();

        super.setMockContestParams();

        super.deployContestMock();
    }

    /**
     * @dev Use the builder to create a contest and test the fields
     */
    function test__ContestSubmission() public {
        // Deploy a contest to test the builder fields
        (address contest, , ) = contestBuilder.deployBaseContest(
            founder,
            weth,
            address(revolutionVotingPower),
            address(splitMain),
            founder,
            contest_CultureIndexParams,
            baseContestParams
        );
        // assert the cultureIndex of the baseContest's votingPower field is the same as the one in the contestBuilder
        CultureIndex contestIndex = CultureIndex(address(baseContest.cultureIndex()));

        // ensure piece was added to culture index
        uint256 pieceId = createDefaultSubmission();
        CultureIndex.ArtPiece memory createdPiece = contest_CultureIndex.getPieceById(pieceId);

        // Assert that the piece was created with the correct data
        assertEq(createdPiece.metadata.name, "Vrbs Legend", "Piece name should match");
        assertEq(createdPiece.metadata.description, "A vrbish masterpiece", "Piece description should match");
        assertEq(createdPiece.metadata.image, "ipfs://vrbs", "Piece image should match");
        assertEq(createdPiece.creators[0].creator, address(0x1), "Creator address should match");
        assertEq(createdPiece.creators[0].bps, 10000, "Creator bps should match");
    }
}
