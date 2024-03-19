// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { ContestBuilderTest } from "./ContestBuilder.t.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { MaxHeap } from "../../src/culture-index/MaxHeap.sol";
import { IBaseContest } from "../../src/culture-index/extensions/contests/IBaseContest.sol";
import { BaseContest } from "../../src/culture-index/extensions/contests/BaseContest.sol";
import { ISplitMain } from "@cobuild/splits/src/interfaces/ISplitMain.sol";

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
    }

    function test__ContestPayoutRevertIfNotOver() public {
        super.setMockContestParams();

        super.deployContestMock();
        vm.stopPrank();

        uint256 pieceId = createDefaultSubmission();

        vm.deal(address(baseContest), 1 ether);

        // Attempt to pay out winners before contest ends by a non-owner
        vm.expectRevert();
        baseContest.payOutWinners(1);

        // Fast forward time to just before the contest ends
        vm.warp(baseContest.endTime() - 1);

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

    function test__WinnerSplit() public {
        super.setMockContestParams();

        super.deployContestMock();

        vm.stopPrank();

        // Create a default submission and set it as the winner
        uint256 pieceId = createDefaultSubmission();

        // Allocate ETH to the contest contract to simulate prize pool using vm.deal
        uint256 prizePoolAmount = 1 ether;
        vm.deal(address(baseContest), prizePoolAmount);

        uint256 payoutMinusFee = prizePoolAmount - baseContest.computeTotalReward(prizePoolAmount);

        // Fast forward time to after the contest ends
        vm.warp(baseContest.endTime() + 1);

        // Pay out winners by the owner after contest ends
        vm.prank(founder);
        // expect event ReceiveETH
        vm.expectEmit(false, true, false, true);
        emit ReceiveETH(address(0), payoutMinusFee);
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

        // check that cultureindex maxheap.size is 0 after paying out
        CultureIndex contestIndex = CultureIndex(address(baseContest.cultureIndex()));
        MaxHeap maxHeap = MaxHeap(address(contestIndex.maxHeap()));

        // ensure baseContest payoutBalance is 1 ether
        assertEq(baseContest.initialPayoutBalance(), 1 ether, "Initial balance should be 1 ether");

        // ensure payoutIndex is 1
        assertEq(baseContest.payoutIndex(), 1, "Payout index should be 1");
    }

    function test__MultiWinnerSplit() public {
        uint256 prizePoolAmount = 1.2 ether;
        super.setMockContestParams();

        uint256[] memory payoutSplits = new uint256[](3);
        // Scaled by 1e6
        payoutSplits[0] = 500000; // 50%
        payoutSplits[1] = 300000; // 30%
        payoutSplits[2] = 200000; // 20%

        super.setBaseContestParams(500000, block.timestamp + 60 * 60 * 24 * 7, payoutSplits);

        super.deployContestMock();
        vm.stopPrank();

        // Create three default submissions and set them as the winners
        createThreeSubmissions();

        // Allocate ETH to the contest contract to simulate prize pool using vm.deal
        vm.deal(address(baseContest), prizePoolAmount);

        uint256 payoutMinusFee = prizePoolAmount - baseContest.computeTotalReward(prizePoolAmount);

        // Fast forward time to after the contest ends
        vm.warp(baseContest.endTime() + 1);

        // Calculate expected balances based on payout splits
        uint256 expectedWinner1Balance = (payoutMinusFee * payoutSplits[0]) / 1e6;
        uint256 expectedWinner2Balance = (payoutMinusFee * payoutSplits[1]) / 1e6;
        uint256 expectedWinner3Balance = (payoutMinusFee * payoutSplits[2]) / 1e6;

        // Pay out winners by the owner after contest ends
        vm.prank(founder);
        vm.expectEmit(false, true, false, true);
        emit ReceiveETH(address(baseContest), expectedWinner1Balance);
        vm.expectEmit(false, true, false, true);
        emit ReceiveETH(address(baseContest), expectedWinner2Balance);
        vm.expectEmit(false, true, false, true);
        emit ReceiveETH(address(baseContest), expectedWinner3Balance);
        baseContest.payOutWinners(3);

        // Assert that contest balance is empty
        assertLt(address(baseContest).balance, 10, "Contest balance should be empty");

        // assert contest paid out and expect revert if trying to pay out again
        assertEq(baseContest.paidOut(), true, "Contest should be paid out");

        vm.prank(founder);
        vm.expectRevert(IBaseContest.CONTEST_ALREADY_PAID_OUT.selector);
        baseContest.payOutWinners(1);

        // check that cultureindex maxheap.size is 0 after paying out
        CultureIndex contestIndex = CultureIndex(address(baseContest.cultureIndex()));
        MaxHeap maxHeap = MaxHeap(address(contestIndex.maxHeap()));

        // ensure baseContest payoutBalance is prizePoolAmount
        assertEq(baseContest.initialPayoutBalance(), prizePoolAmount, "Initial balance should be prizePoolAmount");

        // ensure payoutIndex is 3
        assertEq(baseContest.payoutIndex(), 3, "Payout index should be 3");
    }

    function test__MultiWinnerMultiCreatorSplit() public {
        uint256 prizePoolAmount = 1.2 ether;

        super.setMockContestParams();

        uint256[] memory payoutSplits = new uint256[](3);
        // Scaled by 1e6
        payoutSplits[0] = 500000; // 50%
        payoutSplits[1] = 300000; // 30%
        payoutSplits[2] = 200000; // 20%

        super.setBaseContestParams(500000, block.timestamp + 60 * 60 * 24 * 7, payoutSplits);

        super.deployContestMock();
        vm.stopPrank();

        // Create a multi-creator submission and set it as the winner
        address[] memory creatorAddresses = new address[](3);
        creatorAddresses[0] = address(0x1);
        creatorAddresses[1] = address(0x2);
        creatorAddresses[2] = address(0x3);

        uint256[] memory creatorBps = new uint256[](3);
        creatorBps[0] = 5000; // 50%
        creatorBps[1] = 3000; // 30%
        creatorBps[2] = 2000; // 20%

        createContestSubmissionMultiCreator(
            "Multi-Creator Submission",
            "A collaborative masterpiece",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://multi",
            "",
            "",
            creatorAddresses,
            creatorBps
        );
        // create 2 more pieces
        createContestSubmission(
            "Second Submission",
            "Second masterpiece",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://second",
            "",
            "",
            address(0x2),
            10000
        );
        createContestSubmission(
            "Third Submission",
            "Third masterpiece",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://third",
            "",
            "",
            address(0x3),
            10000
        );

        // Allocate ETH to the contest contract to simulate prize pool using vm.deal
        vm.deal(address(baseContest), prizePoolAmount);

        uint256 payoutMinusFee = prizePoolAmount - baseContest.computeTotalReward(prizePoolAmount);

        // Fast forward time to after the contest ends
        vm.warp(baseContest.endTime() + 1);

        // Calculate expected balances based on payout splits
        uint256 expectedWinner1Balance = (payoutMinusFee * payoutSplits[0]) / 1e6;
        uint256 expectedWinner2Balance = (payoutMinusFee * payoutSplits[1]) / 1e6;
        uint256 expectedWinner3Balance = (payoutMinusFee * payoutSplits[2]) / 1e6;

        // Pay out winners by the owner after contest ends
        vm.prank(founder);
        vm.expectEmit(false, true, false, true);
        emit ReceiveETH(creatorAddresses[0], expectedWinner1Balance);

        baseContest.payOutWinners(1);

        vm.expectEmit(false, true, false, true);
        emit ReceiveETH(creatorAddresses[1], expectedWinner2Balance);
        vm.expectEmit(false, true, false, true);
        emit ReceiveETH(creatorAddresses[2], expectedWinner3Balance);
        baseContest.payOutWinners(3);

        // Assert that contest balance is empty
        assertLt(address(baseContest).balance, 10, "Contest balance should be empty");

        // assert contest paid out and expect revert if trying to pay out again
        assertEq(baseContest.paidOut(), true, "Contest should be paid out");

        vm.prank(founder);
        vm.expectRevert(IBaseContest.CONTEST_ALREADY_PAID_OUT.selector);
        baseContest.payOutWinners(3);

        // check that cultureindex maxheap.size is 0 after paying out
        CultureIndex contestIndex = CultureIndex(address(baseContest.cultureIndex()));
        MaxHeap maxHeap = MaxHeap(address(contestIndex.maxHeap()));

        // ensure baseContest payoutBalance
        assertEq(baseContest.initialPayoutBalance(), prizePoolAmount, "Initial balance should be correct");

        // ensure payoutIndex is 3
        assertEq(baseContest.payoutIndex(), 3, "Payout index should be 3");
    }

    function test__payOutWinners_NoCountSpecified() public {
        super.setMockContestParams();
        super.deployContestMock();

        // add submission
        createDefaultSubmission();

        // Attempt to pay out winners with a count of 0, expecting a revert with NO_COUNT_SPECIFIED error
        vm.prank(founder);
        vm.expectRevert(IBaseContest.NO_COUNT_SPECIFIED.selector);
        baseContest.payOutWinners(0);

        // Further setup to ensure the contest can normally pay out
        // Allocate ETH to the contest contract to simulate prize pool
        uint256 prizePoolAmount = 10 ether;
        vm.deal(address(baseContest), prizePoolAmount);

        // Fast forward time to after the contest ends to meet contest end condition
        vm.warp(baseContest.endTime() + 1);

        // Attempt to pay out with a valid count after meeting conditions to ensure only the count check is causing revert
        vm.prank(founder);
        // Expecting not to revert here, but using try/catch to capture if it incorrectly reverts with NO_COUNT_SPECIFIED
        baseContest.payOutWinners(1);
    }

    // test to ensure contest payout reverts if no balance
    function test__payOutWinners_RevertIfNoBalance() public {
        super.setMockContestParams();
        super.deployContestMock();

        // Ensure the contest has no balance
        assertEq(address(baseContest).balance, 0, "Contest should have no balance");

        // Fast forward time to after the contest ends to meet contest end condition
        vm.warp(baseContest.endTime() + 1);

        // Attempt to pay out winners when there is no balance, expecting a revert with NO_BALANCE_TO_PAYOUT error
        vm.prank(founder);
        vm.expectRevert(IBaseContest.NO_BALANCE_TO_PAYOUT.selector);
        baseContest.payOutWinners(1);
    }

    function test__payoutSplitAccounts_SetCorrectly() public {
        uint256 prizePoolAmount = 1.2 ether;

        super.setMockContestParams();

        uint256[] memory payoutSplits = new uint256[](3);
        // Scaled by 1e6
        payoutSplits[0] = 500000; // 50%
        payoutSplits[1] = 300000; // 30%
        payoutSplits[2] = 200000; // 20%

        super.setBaseContestParams(500000, block.timestamp + 60 * 60 * 24 * 7, payoutSplits);

        super.deployContestMock();
        vm.stopPrank();

        createThreeSubmissions();

        // Allocate ETH to the contest contract to simulate prize pool
        vm.deal(address(baseContest), prizePoolAmount);

        // Fast forward time to after the contest ends
        vm.warp(baseContest.endTime() + 1);

        // Pay out winners by the owner after contest ends
        vm.prank(founder);
        baseContest.payOutWinners(3);

        // Check that payoutSplitAccounts mapping is set correctly for each winner
        for (uint256 i = 0; i < payoutSplits.length; i++) {
            address splitAccount = baseContest.payoutSplitAccounts(i);
            assertTrue(splitAccount != address(0), "Split account should be set");
            // Further checks can be added here to validate the split configuration if needed
        }
    }

    // create a split on split main, and then create a submission with the same split, and ensure payout works for the contest
    function test__payoutSplitAccounts_SetCorrectlyWithSplitMain() public {
        uint256 prizePoolAmount = 1.2 ether;

        super.setMockContestParams();

        uint256[] memory payoutSplits = new uint256[](1);
        // Scaled by 1e6
        payoutSplits[0] = 1e6; // 50%

        super.setBaseContestParams(500000, block.timestamp + 60 * 60 * 24 * 7, payoutSplits);

        super.deployContestMock();
        vm.stopPrank();

        // set entropy rate to 1e6 / 2
        vm.prank(founder);
        baseContest.setEntropyRate(500000);

        (
            address[] memory accounts,
            uint32[] memory percentAllocations,
            uint32 distributorFee,
            address controller,
            uint32[] memory pointsAllocations,
            ISplitMain.PointsData memory pointsData
        ) = setupBasicSplit();

        // create a split on split main
        splitMain.createSplit(pointsData, accounts, percentAllocations, distributorFee, controller);

        // create a submission with the split
        createContestSubmission(
            "Third Submission",
            "Third masterpiece",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://third",
            "",
            "",
            address(0x3),
            10000
        );

        // Allocate ETH to the contest contract to simulate prize pool
        vm.deal(address(baseContest), prizePoolAmount);

        // Fast forward time to after the contest ends
        vm.warp(baseContest.endTime() + 1);

        // Pay out winners by the owner after contest ends
        vm.prank(founder);
        baseContest.payOutWinners(1);

        // Check that payoutSplitAccounts mapping is set correctly for each winner
        for (uint256 i = 0; i < payoutSplits.length; i++) {
            address splitAccount = baseContest.payoutSplitAccounts(i);
            assertTrue(splitAccount != address(0), "Split account should be set");
            // Further checks can be added here to validate the split configuration if needed
        }
    }

    // ensures that if there are eg: 10 payoutSplits but only 3 submissions, the 3 submissions can still be paid out
    // and the owner can withdraw the remaining funds
    function test__payOutWinners_WithRemainingFunds() public {
        uint256 prizePoolAmount = 1 ether;
        super.setMockContestParams();

        uint256[] memory payoutSplits = new uint256[](10);
        // Scaled by 1e6
        for (uint256 i = 0; i < payoutSplits.length; i++) {
            payoutSplits[i] = 100000; // 10% for each
        }

        super.setBaseContestParams(500000, block.timestamp + 60 * 60 * 24 * 7, payoutSplits);

        super.deployContestMock();

        // Create three submissions
        createThreeSubmissions();

        // Allocate ETH to the contest contract to simulate prize pool
        vm.deal(address(baseContest), prizePoolAmount);

        // Fast forward time to after the contest ends
        vm.warp(baseContest.endTime() + 1);

        // Pay out winners by the owner after contest ends
        vm.prank(founder);
        baseContest.payOutWinners(3);

        // Assert that contest has remaining funds
        assertTrue(address(baseContest).balance > 0, "Contest should have remaining funds");

        // Withdraw remaining funds to the owner
        vm.prank(founder);
        baseContest.emergencyWithdraw();

        // Assert that contest balance is now 0
        assertEq(address(baseContest).balance, 0, "Contest balance should be 0 after withdrawal");
    }

    event ReceiveETH(address indexed sender, uint256 amount);
}
