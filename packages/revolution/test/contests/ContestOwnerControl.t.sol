// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { ContestBuilderTest } from "./ContestBuilder.t.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { BaseContest } from "../../src/culture-index/extensions/contests/BaseContest.sol";

/**
 * @title ContestOwnerControl
 * @dev Test contract for Contest creation
 */
contract ContestOwnerControl is ContestBuilderTest {
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
    function test__EntropyRateUpdate() public {
        vm.stopPrank();
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

        // ensure founder can set entropyRateBps and that it is updated
        BaseContest baseContest = BaseContest(contest);
        uint256 newEntropyRate = 51000; // Example new entropy rate to test with

        // Ensure only the owner can set the entropy rate
        vm.expectRevert();
        baseContest.setEntropyRate(newEntropyRate);

        // Change to the owner to set the entropy rate
        vm.prank(address(founder));
        baseContest.setEntropyRate(newEntropyRate);

        // Check that the entropy rate was successfully updated
        uint256 actualEntropyRate = baseContest.entropyRate();
        assertEq(actualEntropyRate, newEntropyRate, "Entropy rate was not updated correctly");
    }

    /**
     * @dev Test to ensure only the owner can call unpause
     */
    function test__UnpauseByOwnerOnly() public {
        // Ensure non-owner cannot unpause
        address nonOwner = address(0x123);
        vm.prank(nonOwner);
        vm.expectRevert();
        baseContest.unpause();

        // Ensure owner can unpause
        vm.prank(founder);
        vm.expectEmit(true, false, false, true);
        emit Unpaused(founder);
        baseContest.unpause();
    }

    event Unpaused(address account);
}
