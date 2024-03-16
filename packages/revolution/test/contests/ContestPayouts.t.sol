// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { ContestBuilderTest } from "./ContestBuilder.t.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { IBaseContest } from "../../src/culture-index/extensions/contests/IBaseContest.sol";
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

    function test__ContestPayoutRevertIfNotOver() public {
        vm.stopPrank();

        uint256 pieceId = createDefaultSubmission();

        // Attempt to pay out winners before contest ends by a non-owner
        vm.expectRevert();
        baseContest.payOutWinners(1);

        // Fast forward time to just before the contest ends
        vm.warp(baseContest.endTime() - 1);

        // expect EnforcedPause() error
        vm.prank(founder);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        baseContest.payOutWinners(1);

        // unpause as owner
        vm.prank(founder);
        baseContest.unpause();

        // Attempt to pay out winners just before contest ends by the owner
        vm.prank(founder);
        vm.expectRevert(IBaseContest.CONTEST_NOT_ENDED.selector);
        baseContest.payOutWinners(1);

        // Fast forward time to exactly when the contest ends
        vm.warp(baseContest.endTime());

        // Now pay out winners by the owner after contest ends
        vm.prank(founder);
        baseContest.payOutWinners(1);
    }

    function test__WinnerSplitReceivesCorrectETHAmount() public {
        vm.stopPrank();

        // Create a default submission and set it as the winner
        uint256 pieceId = createDefaultSubmission();

        // Allocate ETH to the contest contract to simulate prize pool using vm.deal
        uint256 prizePoolAmount = 1 ether;
        vm.deal(address(baseContest), prizePoolAmount);

        // Fast forward time to after the contest ends
        vm.warp(baseContest.endTime() + 1);

        // unpause
        vm.prank(founder);
        baseContest.unpause();

        // Pay out winners by the owner after contest ends
        vm.prank(founder);
        // expect event ReceiveETH
        vm.expectEmit(false, true, false, true);
        emit ReceiveETH(address(0), 1 ether);
        baseContest.payOutWinners(1);

        // Check the winner's balance after payout
        uint256 winnerBalanceAfter = address(0x1).balance;

        // Assert that contest balance is empty
        assertEq(address(baseContest).balance, 0, "Contest balance should be empty");

        // assert contest paid out and expect revert if trying to pay out again
        assertEq(baseContest.paidOut(), true, "Contest should be paid out");

        vm.prank(founder);
        vm.expectRevert(IBaseContest.CONTEST_ALREADY_PAID_OUT.selector);
        baseContest.payOutWinners(1);
    }

    event ReceiveETH(address indexed sender, uint256 amount);
}
