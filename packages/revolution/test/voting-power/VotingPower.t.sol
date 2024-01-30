// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ERC1967Proxy } from "../../src/libs/proxy/ERC1967Proxy.sol";

import { IRevolutionVotingPower } from "../../src/interfaces/IRevolutionVotingPower.sol";
import { IRevolutionToken } from "../../src/interfaces/IRevolutionToken.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";

contract VotingPowerTest is RevolutionBuilderTest {
    function setUp() public override {
        super.setUp();
        super.setMockParams();

        super.deployMock();
    }

    function test_initializeVotingPower() public {
        //ensure we can pull latest versions
        address revolutionToken = address(new ERC1967Proxy(revolutionTokenImpl, ""));

        bytes32 salt = bytes32(uint256(uint160(revolutionToken)) << 96);

        address revolutionVotingPower = address(new ERC1967Proxy{ salt: salt }(revolutionVotingPowerImpl, ""));

        vm.startPrank(address(manager));
        IRevolutionVotingPower(revolutionVotingPower).initialize({
            initialOwner: address(executor),
            revolutionPoints: address(revolutionPoints),
            pointsVoteWeight: revolutionVotingPowerParams.pointsVoteWeight,
            revolutionToken: revolutionToken,
            tokenVoteWeight: revolutionVotingPowerParams.tokenVoteWeight
        });
    }

    function test__DefaultVotingPowerCalculation(
        uint256 pointsBalance,
        uint256 pointsVoteWeight,
        uint256 tokenVoteWeight,
        uint256 tokenBalance
    ) public {
        pointsBalance = bound(pointsBalance, 1, 1e18);
        pointsVoteWeight = bound(pointsVoteWeight, 1 * 1e18, 1_000_000 * 1e18);
        tokenVoteWeight = bound(tokenVoteWeight, 1 * 1e18, 1_000_000 * 1e18);
        tokenBalance = bound(tokenBalance, 1, 1e3);

        //mint points and token to address voter
        address voter = address(this);

        for (uint256 i = 0; i < tokenBalance; i++) {
            createDefaultArtPiece();
        }

        vm.roll(vm.getBlockNumber() + 1);

        for (uint256 i = 0; i < tokenBalance; i++) {
            vm.prank(address(auction));
            revolutionToken.mint();

            //transfer to voter
            vm.prank(address(auction));
            revolutionToken.transferFrom(address(auction), voter, i);
        }

        //mint points and token to address voter
        vm.prank(address(revolutionPointsEmitter));
        revolutionPoints.mint(voter, pointsBalance);

        bytes32 salt = bytes32(uint256(uint160(address(revolutionToken))) << 96);

        address revolutionVotingPower = address(new ERC1967Proxy{ salt: salt }(revolutionVotingPowerImpl, ""));

        // Act: Calculate the expected and actual voting power
        uint256 expectedVotingPower = (pointsBalance * pointsVoteWeight) + (tokenBalance * tokenVoteWeight);

        vm.startPrank(address(manager));
        IRevolutionVotingPower(revolutionVotingPower).initialize({
            initialOwner: address(executor),
            revolutionPoints: address(revolutionPoints),
            pointsVoteWeight: pointsVoteWeight,
            revolutionToken: address(revolutionToken),
            tokenVoteWeight: tokenVoteWeight
        });

        uint256 actualVotingPower = IRevolutionVotingPower(revolutionVotingPower).getVotes(voter);

        // Assert: The actual voting power should match the expected voting power
        assertEq(actualVotingPower, expectedVotingPower);
    }

    function test__VotingPowerWithWeight(
        uint256 pointsBalance,
        uint256 pointsVoteWeight,
        uint256 tokenVoteWeight,
        uint256 tokenBalance
    ) public {
        pointsBalance = bound(pointsBalance, 1, 1e18);
        pointsVoteWeight = bound(pointsVoteWeight, 1 * 1e18, 1_000_000 * 1e18);
        tokenVoteWeight = bound(tokenVoteWeight, 1 * 1e18, 1_000_000 * 1e18);
        tokenBalance = bound(tokenBalance, 1, 1e3);

        //mint points and token to address voter
        address voter = address(this);

        for (uint256 i = 0; i < tokenBalance; i++) {
            createDefaultArtPiece();
        }

        vm.roll(vm.getBlockNumber() + 1);

        for (uint256 i = 0; i < tokenBalance; i++) {
            vm.prank(address(auction));
            revolutionToken.mint();

            //transfer to voter
            vm.prank(address(auction));
            revolutionToken.transferFrom(address(auction), voter, i);
        }

        //mint points and token to address voter
        vm.prank(address(revolutionPointsEmitter));
        revolutionPoints.mint(voter, pointsBalance);

        bytes32 salt = bytes32(uint256(uint160(address(revolutionToken))) << 96);

        address revolutionVotingPower = address(new ERC1967Proxy{ salt: salt }(revolutionVotingPowerImpl, ""));

        // Act: Calculate the expected and actual voting power
        uint256 expectedVotingPower = (pointsBalance * pointsVoteWeight) + (tokenBalance * tokenVoteWeight);

        vm.startPrank(address(manager));
        IRevolutionVotingPower(revolutionVotingPower).initialize({
            initialOwner: address(executor),
            revolutionPoints: address(revolutionPoints),
            pointsVoteWeight: 0,
            revolutionToken: address(revolutionToken),
            tokenVoteWeight: 0
        });

        uint256 actualVotingPower = IRevolutionVotingPower(revolutionVotingPower).getVotesWithWeights(
            voter,
            pointsVoteWeight,
            tokenVoteWeight
        );

        // Assert: The actual voting power should match the expected voting power
        assertEq(actualVotingPower, expectedVotingPower);
    }

    function testTotalSupplyMatches() public {
        uint256 totalPointsSupply = revolutionVotingPower.getPointsSupply();
        uint256 totalTokenSupply = revolutionVotingPower.getTokenSupply();

        uint256 actualPointsSupply = revolutionPoints.totalSupply();
        uint256 actualTokenSupply = revolutionToken.totalSupply();

        assertEq(totalTokenSupply, actualTokenSupply, "Total token supply does not match");
        assertEq(totalPointsSupply, actualPointsSupply, "Total points supply does not match");
    }
}
