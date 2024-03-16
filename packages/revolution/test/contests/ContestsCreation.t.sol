// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { ContestBuilderTest } from "./ContestBuilder.t.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { BaseContest } from "../../src/culture-index/extensions/contests/BaseContest.sol";

/**
 * @title ContestsCreationTest
 * @dev Test contract for Contest creation
 */
contract ContestsCreationTest is ContestBuilderTest {
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
    function test__ContestBuilderFields() public {
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

        // verify contest fields
        BaseContest baseContest = BaseContest(contest);
        assertEq(baseContest.owner(), founder, "Owner mismatch");
        assertEq(baseContest.WETH(), weth, "WETH mismatch");
        assertEq(address(baseContest.splitMain()), address(splitMain), "Split main mismatch");

        // assert the cultureIndex of the baseContest's votingPower field is the same as the one in the contestBuilder
        CultureIndex contestIndex = CultureIndex(address(baseContest.cultureIndex()));
        assertEq(address(contestIndex.votingPower()), address(revolutionVotingPower), "CultureIndex mismatch");
        // assert other culture index fields
        assertEq(
            contestIndex.quorumVotesBPS(),
            contest_CultureIndexParams.quorumVotesBPS,
            "CultureIndex quorumVotesBPS mismatch"
        );
        assertEq(
            contestIndex.tokenVoteWeight(),
            contest_CultureIndexParams.tokenVoteWeight,
            "CultureIndex tokenVoteWeight mismatch"
        );
        assertEq(
            contestIndex.pointsVoteWeight(),
            contest_CultureIndexParams.pointsVoteWeight,
            "CultureIndex pointsVoteWeight mismatch"
        );
        assertEq(
            contestIndex.minVotingPowerToVote(),
            contest_CultureIndexParams.minVotingPowerToVote,
            "CultureIndex minVotingPowerToVote mismatch"
        );
        assertEq(
            contestIndex.minVotingPowerToCreate(),
            contest_CultureIndexParams.minVotingPowerToCreate,
            "CultureIndex minVotingPowerToCreate mismatch"
        );

        // test the other cultureIndex fields
        assertEq(contestIndex.owner(), founder, "CultureIndex owner mismatch");
        // assert name and description vs. the contest_CultureIndexParams
        assertEq(contestIndex.name(), contest_CultureIndexParams.name, "CultureIndex name mismatch");
        assertEq(
            contestIndex.description(),
            contest_CultureIndexParams.description,
            "CultureIndex description mismatch"
        );
    }

    /**
     * @dev Test to create a contest by deploying a base contest and verifying its deployment
     */
    function test__CreateContest() public {
        // Set mock parameters for the contest creation
        setMockContestParams();

        // Deploy the contest with the mock parameters
        deployContestMock();

        // Assert that the base contest has been deployed
        assertTrue(address(baseContest) != address(0), "Base contest was not deployed");

        // Further assertions can be added here to verify the properties of the deployed contest
        // Verify the entropyRate of the deployed contest
        uint256 expectedEntropyRate = baseContestParams.entropyRate;
        uint256 actualEntropyRate = baseContest.entropyRate();
        assertTrue(actualEntropyRate == expectedEntropyRate, "Entropy rate mismatch");

        // Verify the endTime of the deployed contest
        uint256 expectedEndTime = baseContestParams.endTime;
        uint256 actualEndTime = baseContest.endTime();
        assertTrue(actualEndTime == expectedEndTime, "End time mismatch");
        // Verify the payoutSplits of the deployed contest
        uint256[] memory expectedPayoutSplits = baseContestParams.payoutSplits;
        for (uint256 i = 0; i < expectedPayoutSplits.length; i++) {
            uint256 actualPayoutSplit = baseContest.payoutSplits(i);
            assertTrue(actualPayoutSplit == expectedPayoutSplits[i], "Payout splits mismatch at index");
        }

        // Verify the contest has not been paid out yet
        bool expectedPaidOut = false;
        bool actualPaidOut = baseContest.paidOut();
        assertTrue(actualPaidOut == expectedPaidOut, "Contest should not be paid out yet");

        // Verify the initial balance of the contest is 0
        uint256 expectedInitialBalance = 0;
        uint256 actualInitialBalance = baseContest.initialBalance();
        assertTrue(actualInitialBalance == expectedInitialBalance, "Initial balance should be 0");
    }
}
