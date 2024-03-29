// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";

import { IRevolutionVotingPower } from "../../src/interfaces/IRevolutionVotingPower.sol";
import { IRevolutionToken } from "../../src/interfaces/IRevolutionToken.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";

contract VotingPowerTest is RevolutionBuilderTest {
    function setUp() public override {
        super.setUp();
        super.setMockParams();

        super.deployMock();

        vm.prank(founder);
        // transfer ownership to executor
        cultureIndex.transferOwnership(address(executor));

        //start prank to be cultureindex's owner
        vm.startPrank(address(executor));
        // accept ownership
        cultureIndex.acceptOwnership();
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

    function mintVotesToVoter(address voter, uint256 pointsBalance, uint256 tokenBalance) public {
        vm.prank(address(executor));
        // set culture index quorum to 0
        cultureIndex._setQuorumVotesBPS(0);

        //mint points and token to address voter
        vm.prank(address(revolutionPointsEmitter));
        revolutionPoints.mint(voter, pointsBalance);

        for (uint256 i = 0; i < tokenBalance; i++) {
            uint256 pieceId = createDefaultArtPiece();
        }

        vm.roll(vm.getBlockNumber() + 1);

        for (uint256 i = 0; i < tokenBalance; i++) {
            vm.prank(address(auction));
            revolutionToken.mint();

            //transfer to voter
            vm.prank(address(auction));
            revolutionToken.transferFrom(address(auction), voter, i);
        }
    }

    function testGetPointsVotes() public {
        address voter = address(this);

        uint256 pointsBalance = 1e18;

        mintVotesToVoter(voter, pointsBalance, 0);

        uint256 expectedPointsVotes = revolutionVotingPower.getPointsVotes(address(voter));
        uint256 actualPointsVotes = revolutionPoints.getVotes(address(voter));
        assertEq(expectedPointsVotes, actualPointsVotes, "Points votes do not match");
    }

    function testGetPastPointsVotes() public {
        address voter = address(this);
        uint256 blockNumber = vm.getBlockNumber();

        uint256 pointsBalance = 1e18;

        mintVotesToVoter(voter, pointsBalance, 0);

        vm.roll(blockNumber + 1);

        uint256 expectedPastPointsVotes = revolutionVotingPower.getPastPointsVotes((voter), blockNumber);
        uint256 actualPastPointsVotes = revolutionPoints.getPastVotes((voter), blockNumber);
        assertEq(expectedPastPointsVotes, actualPastPointsVotes, "Past points votes do not match");
    }

    function testGetTokenVotes() public {
        address voter = address(this);

        uint256 tokenBalance = 10;

        mintVotesToVoter(voter, 0, tokenBalance);

        uint256 expectedTokenVotes = revolutionVotingPower.getTokenVotes((voter));
        uint256 actualTokenVotes = revolutionToken.getVotes((voter));
        assertEq(expectedTokenVotes, actualTokenVotes, "Token votes do not match");
    }

    function testGetPastTokenVotes() public {
        address voter = address(this);
        uint256 blockNumber = vm.getBlockNumber();

        uint256 tokenBalance = 10;

        mintVotesToVoter(voter, 0, tokenBalance);

        vm.roll(blockNumber + 1);

        uint256 expectedPastTokenVotes = revolutionVotingPower.getPastTokenVotes((voter), blockNumber);
        uint256 actualPastTokenVotes = revolutionToken.getPastVotes((voter), blockNumber);
        assertEq(expectedPastTokenVotes, actualPastTokenVotes, "Past token votes do not match");
    }

    function testGetPointsSupply() public {
        mintVotesToVoter(address(this), 1e18, 10);
        uint256 expectedPointsSupply = revolutionVotingPower.getPointsSupply();
        uint256 actualPointsSupply = revolutionPoints.totalSupply();
        assertEq(expectedPointsSupply, actualPointsSupply, "Points supply does not match");
    }

    function testGetTokenSupply() public {
        mintVotesToVoter(address(this), 1e18, 10);

        uint256 expectedTokenSupply = revolutionVotingPower.getTokenSupply();
        uint256 actualTokenSupply = revolutionToken.totalSupply();
        assertEq(expectedTokenSupply, actualTokenSupply, "Token supply does not match");
    }

    function testGetPastPointsSupply() public {
        mintVotesToVoter(address(this), 1e18, 10);

        uint256 blockNumber = vm.getBlockNumber();

        vm.roll(blockNumber + 1);

        uint256 expectedPastPointsSupply = revolutionVotingPower.getPastPointsSupply(blockNumber);
        uint256 actualPastPointsSupply = revolutionPoints.getPastTotalSupply(blockNumber);
        assertEq(expectedPastPointsSupply, actualPastPointsSupply, "Past points supply does not match");
    }

    function testGetPastTokenSupply() public {
        mintVotesToVoter(address(this), 1e18, 10);

        uint256 blockNumber = vm.getBlockNumber();

        vm.roll(blockNumber + 1);

        uint256 expectedPastTokenSupply = revolutionVotingPower.getPastTokenSupply(blockNumber);
        uint256 actualPastTokenSupply = revolutionToken.getPastTotalSupply(blockNumber);
        assertEq(expectedPastTokenSupply, actualPastTokenSupply, "Past token supply does not match");
    }

    function testCalculateVotes() public {
        uint256 pointsBalance = 500;
        uint256 tokenBalance = 10;

        uint256 expectedVotingPower = (pointsBalance * revolutionVotingPower.pointsVoteWeight()) +
            (tokenBalance * revolutionVotingPower.tokenVoteWeight());

        uint256 actualVotingPower = revolutionVotingPower.calculateVotes(pointsBalance, tokenBalance);

        assertEq(expectedVotingPower, actualVotingPower, "Calculated voting power does not match expected");
    }

    function testCalculateVotesWithWeights() public {
        IRevolutionVotingPower.BalanceAndWeight memory pointsVotes = IRevolutionVotingPower.BalanceAndWeight({
            balance: 500,
            voteWeight: 2e18 // 2 times the default weight
        });
        IRevolutionVotingPower.BalanceAndWeight memory tokenVotes = IRevolutionVotingPower.BalanceAndWeight({
            balance: 10,
            voteWeight: 3e18 // 3 times the default weight
        });

        uint256 expectedVotingPower = (pointsVotes.balance * pointsVotes.voteWeight) +
            (tokenVotes.balance * tokenVotes.voteWeight);

        uint256 actualVotingPower = revolutionVotingPower.calculateVotesWithWeights(pointsVotes, tokenVotes);

        assertEq(
            expectedVotingPower,
            actualVotingPower,
            "Calculated voting power with weights does not match expected"
        );
    }
}
