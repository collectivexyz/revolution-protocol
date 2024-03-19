// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { ContestBuilderTest } from "./ContestBuilder.t.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { BaseContest } from "../../src/culture-index/extensions/contests/BaseContest.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ISplitMain } from "@cobuild/splits/src/interfaces/ISplitMain.sol";
import { IBaseContest } from "../../src/culture-index/extensions/contests/IBaseContest.sol";

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
     * @dev Test to ensure only the owner can call pause
     */
    function test__PauseByOwnerOnly() public {
        // Ensure non-owner cannot pause
        address nonOwner = address(0x123);
        vm.prank(nonOwner);
        vm.expectRevert();
        baseContest.pause();

        // Ensure owner can pause
        vm.prank(founder);
        vm.expectEmit(true, false, false, true);
        emit Paused(founder);
        baseContest.pause();
    }

    /**
     * @dev Test to ensure only the owner can call unpause
     */
    function test__UnpauseByOwnerOnly() public {
        //pause first
        vm.prank(founder);
        baseContest.pause();

        // Ensure non-owner cannot unpause
        address nonOwner = address(0x123);
        vm.prank(nonOwner);
        vm.expectRevert();
        baseContest.unpause();

        // ensure contest cannot be paid out when paused
        vm.expectRevert();
        baseContest.payOutWinners(1);

        // Ensure owner can unpause
        vm.prank(founder);
        vm.expectEmit(true, false, false, true);
        emit Unpaused(founder);
        baseContest.unpause();
    }

    event Paused(address account);

    event Unpaused(address account);

    // tests that the owner can call emergencyWithdraw and that the funds are sent to the owner
    /**
     * @dev Test to ensure the emergencyWithdraw function can only be called by the owner and transfers the correct balance
     */
    function test__EmergencyWithdrawByOwnerOnly() public {
        // Setup: Pause the contest to simulate emergency conditions
        vm.prank(founder);
        baseContest.pause();

        // Ensure non-owner cannot call emergencyWithdraw
        address nonOwner = address(0x123);
        vm.prank(nonOwner);
        vm.expectRevert();
        baseContest.emergencyWithdraw();

        // Simulate contract having balance
        address payable contractAddress = payable(address(baseContest));
        vm.deal(contractAddress, 10 ether);

        // Ensure the balance of the contract is 10 ether
        assertEq(contractAddress.balance, 10 ether, "Contract balance should be 10 ether");

        // Capture the initial balance of the owner
        uint256 initialOwnerBalance = Ownable2StepUpgradeable(address(ISplitMain(splitMain).pointsEmitter()))
            .owner()
            .balance;

        // Ensure owner can call emergencyWithdraw
        vm.prank(founder);
        baseContest.emergencyWithdraw();

        // Ensure the balance of the contract is 0 after withdrawal
        assertEq(contractAddress.balance, 0, "Contract balance should be 0 after emergencyWithdraw");

        // Ensure the balance of the owner has increased by 10 ether
        assertEq(
            Ownable2StepUpgradeable(address(ISplitMain(splitMain).pointsEmitter())).owner().balance,
            initialOwnerBalance + 10 ether,
            "Owner balance should increase by 10 ether"
        );
    }

    /**
     * @dev Test to ensure withdrawToPointsEmitterOwner function can only be called post contest and transfers the correct balance
     */
    function test__WithdrawToPointsEmitterOwnerPostContest() public {
        // Setup: End the contest, create submissions, and ensure they are paid out
        createThreeSubmissions();

        // Simulate contract having balance
        address payable contractAddress = payable(address(baseContest));
        vm.deal(contractAddress, 5 ether);

        // Ensure the balance of the contract is 5 ether
        assertEq(contractAddress.balance, 5 ether, "Contract balance should be 5 ether");

        // expect revert trying to withdraw before contest end
        vm.expectRevert(abi.encodeWithSelector(IBaseContest.CONTEST_NOT_ENDED.selector));
        baseContest.withdrawToPointsEmitterOwner();

        vm.warp(baseContest.endTime() + 1);
        baseContest.payOutWinners(3);

        // deal another 21 ether to the contract
        vm.deal(contractAddress, 21 ether);

        // Capture the initial balance of the points emitter owner
        address pointsEmitterOwner = Ownable2StepUpgradeable(address(ISplitMain(splitMain).pointsEmitter())).owner();
        uint256 initialPointsEmitterOwnerBalance = pointsEmitterOwner.balance;

        // Call withdrawToPointsEmitterOwner
        baseContest.withdrawToPointsEmitterOwner();

        // Ensure the balance of the contract is 0 after withdrawal
        assertEq(contractAddress.balance, 0, "Contract balance should be 0 after withdrawToPointsEmitterOwner");

        // Ensure the balance of the points emitter owner has increased by 5 ether
        assertEq(
            pointsEmitterOwner.balance,
            initialPointsEmitterOwnerBalance + 21 ether,
            "Points emitter owner balance should increase by 5 ether"
        );
    }
}
