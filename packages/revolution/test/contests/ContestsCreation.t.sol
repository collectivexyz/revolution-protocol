// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { ContestBuilderTest } from "./ContestBuilder.t.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";

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

        //start prank to be cultureindex's owner
        vm.startPrank(address(executor));

        super.setMockContestParams();

        super.deployContestMock();
    }

    /**
     * @dev Test to create a contest by deploying a base contest and verifying its deployment
     */
    function testCreateContest() public {
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
