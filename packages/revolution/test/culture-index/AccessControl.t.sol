// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { RevolutionToken } from "../../src/RevolutionToken.sol";
import { IRevolutionToken } from "../../src/interfaces/IRevolutionToken.sol";
import { IDescriptorMinimal } from "../../src/interfaces/IDescriptorMinimal.sol";
import { ICultureIndex, ICultureIndexEvents } from "../../src/interfaces/ICultureIndex.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { Descriptor } from "../../src/Descriptor.sol";
import "../utils/Base64Decode.sol";
import "../utils/JsmnSolLib.sol";
import { CultureIndexTestSuite } from "./CultureIndex.t.sol";
import { ERC721CheckpointableUpgradeable } from "../../src/base/ERC721CheckpointableUpgradeable.sol";

/// @title RevolutionTokenTest
/// @dev The test suite for the RevolutionToken contract
contract CultureIndexAccessControlTest is CultureIndexTestSuite {
    function testSetQuorumVotesBPSWithinRange(uint256 newQuorumBPS) public {
        newQuorumBPS = bound(newQuorumBPS, 0, cultureIndex.MAX_QUORUM_VOTES_BPS());

        // Set new quorum BPS by owner
        cultureIndex._setQuorumVotesBPS(newQuorumBPS);
        vm.stopPrank();

        // Check if the quorum BPS is updated correctly
        uint256 currentQuorumBPS = cultureIndex.quorumVotesBPS();
        assertEq(currentQuorumBPS, newQuorumBPS, "Quorum BPS should be updated within valid range");
    }

    function testSetMinVotingPowerToVoteOnlyOwnerCanCall() public {
        vm.stopPrank();
        uint256 newMinVotingPowerToVote = 5000;
        uint256 initialMinVotingPowerToVote = cultureIndex.minVotingPowerToVote();
        assertEq(initialMinVotingPowerToVote, 0, "Initial min voting power to vote should be 0");

        // Set new min voting power to vote by owner
        //expect emit
        vm.expectEmit(true, true, true, true);
        emit ICultureIndexEvents.MinVotingPowerToVoteSet(initialMinVotingPowerToVote, newMinVotingPowerToVote);
        vm.prank(address(executor));
        cultureIndex._setMinVotingPowerToVote(newMinVotingPowerToVote);

        // Check if the min voting power to vote is updated correctly
        uint256 currentMinVotingPowerToVote = cultureIndex.minVotingPowerToVote();
        assertEq(
            currentMinVotingPowerToVote,
            newMinVotingPowerToVote,
            "Min voting power to vote should be updated by owner"
        );
    }

    function testRevertNonOwnerSetMinVotingPowerToVote() public {
        vm.stopPrank();
        uint256 newMinVotingPowerToVote = 5000;
        address nonOwner = address(0x123); // An arbitrary non-owner address

        // Attempt to set new min voting power to vote by non-owner and expect revert
        vm.startPrank(nonOwner);
        vm.expectRevert();
        cultureIndex._setMinVotingPowerToVote(newMinVotingPowerToVote);
        vm.stopPrank();
    }

    function testSetMinVotingPowerToCreateOnlyOwnerCanCall() public {
        vm.stopPrank();
        uint256 newMinVotingPowerToCreate = 10000;
        uint256 initialMinVotingPowerToCreate = cultureIndex.minVotingPowerToCreate();
        assertEq(initialMinVotingPowerToCreate, 0, "Initial min voting power to create should be 0");

        // Expect the MinVotingPowerToCreateSet event to be emitted with the new and old values
        vm.expectEmit(true, true, true, true);
        emit ICultureIndexEvents.MinVotingPowerToCreateSet(initialMinVotingPowerToCreate, newMinVotingPowerToCreate);

        // Set new min voting power to create by owner
        vm.prank(address(executor));
        cultureIndex._setMinVotingPowerToCreate(newMinVotingPowerToCreate);

        // Check if the min voting power to create is updated correctly
        uint256 currentMinVotingPowerToCreate = cultureIndex.minVotingPowerToCreate();
        assertEq(
            currentMinVotingPowerToCreate,
            newMinVotingPowerToCreate,
            "Min voting power to create should be updated by owner"
        );
    }

    function testRevertNonOwnerSetMinVotingPowerToCreate() public {
        vm.stopPrank();
        uint256 newMinVotingPowerToCreate = 10000;
        address nonOwner = address(0x123); // An arbitrary non-owner address

        // Attempt to set new min voting power to create by non-owner and expect revert
        vm.startPrank(nonOwner);
        vm.expectRevert();
        cultureIndex._setMinVotingPowerToCreate(newMinVotingPowerToCreate);
        vm.stopPrank();
    }

    function testRevertVotingWithWeightTooLow() public {
        vm.stopPrank();
        uint256 newMinVotingPowerToVote = 5000;
        vm.prank(address(executor));
        cultureIndex._setMinVotingPowerToVote(newMinVotingPowerToVote);
        uint256 insufficientVotingPower = newMinVotingPowerToVote - 1;
        address voter = address(0x456); // An arbitrary voter address

        // Attempt to vote with insufficient voting power and expect revert
        vm.prank(address(revolutionPointsEmitter));
        revolutionPoints.mint(voter, insufficientVotingPower);

        vm.roll(vm.getBlockNumber() + 2);

        createDefaultArtPiece();

        vm.expectRevert(abi.encodeWithSignature("WEIGHT_TOO_LOW()"));
        vm.prank(voter);
        cultureIndex.vote(0); // Assuming 1 is a valid pieceId for simplicity
        vm.stopPrank();
    }

    function testRevertCreatingWithWeightTooLow() public {
        vm.stopPrank();
        uint256 newMinVotingPowerToCreate = 10000;
        vm.prank(address(executor));
        cultureIndex._setMinVotingPowerToCreate(newMinVotingPowerToCreate);
        uint256 insufficientVotingPower = newMinVotingPowerToCreate - 1;
        address creator = address(0x789); // An arbitrary creator address

        // Attempt to create with insufficient voting power and expect revert
        vm.prank(address(revolutionPointsEmitter));
        revolutionPoints.mint(creator, insufficientVotingPower);
        vm.prank(creator);
        vm.expectRevert(abi.encodeWithSignature("WEIGHT_TOO_LOW()"));
        createDefaultArtPiece();
        vm.stopPrank();
    }

    function testSetQuorumVotesBPSOutsideRange(uint256 newQuorumBPS) public {
        uint256 currentQuorumBPS = cultureIndex.quorumVotesBPS();
        newQuorumBPS = bound(newQuorumBPS, cultureIndex.MAX_QUORUM_VOTES_BPS() + 1, type(uint256).max - 1);

        // Set new quorum BPS by owner
        vm.expectRevert(abi.encodeWithSignature("INVALID_QUORUM_BPS()"));
        cultureIndex._setQuorumVotesBPS(newQuorumBPS);
        vm.stopPrank();

        // Check if the quorum BPS is updated correctly
        assertEq(cultureIndex.quorumVotesBPS(), currentQuorumBPS, "Quorum BPS should be updated within valid range");
    }

    function testRevertNonOwnerSetQuorumVotesBPS() public {
        vm.stopPrank();
        address nonOwner = address(0x123); // An arbitrary non-owner address
        uint256 newQuorumBPS = 3000; // A valid quorum BPS value

        // Attempt to set new quorum BPS by non-owner and expect revert
        vm.startPrank(nonOwner);
        vm.expectRevert();
        cultureIndex._setQuorumVotesBPS(newQuorumBPS);
        vm.stopPrank();
    }

    function testDropTopVotedPieceOnlyIfQuorumIsMet(uint256 quorumBps) public {
        quorumBps = bound(quorumBps, 201, cultureIndex.MAX_QUORUM_VOTES_BPS());

        // Set quorum BPS
        cultureIndex._setQuorumVotesBPS(quorumBps);
        vm.stopPrank();

        vm.startPrank(address(revolutionPointsEmitter));
        revolutionPoints.mint(address(0x21), quorumBps * 10);
        revolutionPoints.mint(address(this), ((quorumBps / 2) * (quorumBps)) / 10_000);

        vm.roll(vm.getBlockNumber() + 2);

        // Create an art piece
        uint256 pieceId = createDefaultArtPiece();

        vm.roll(vm.getBlockNumber() + 2);

        // Vote for the piece, but do not meet the quorum
        vm.startPrank(address(this));
        cultureIndex.vote(pieceId);

        // Attempt to drop the top-voted piece and expect it to fail
        vm.expectRevert(abi.encodeWithSignature("DOES_NOT_MEET_QUORUM()"));
        vm.startPrank(address(revolutionToken));
        cultureIndex.dropTopVotedPiece();

        // Additional votes to meet/exceed the quorum
        vm.startPrank(address(0x21));
        cultureIndex.vote(pieceId);
        vm.stopPrank();

        // Attempt to drop the top-voted piece, should succeed
        vm.startPrank(address(revolutionToken));
        ICultureIndex.ArtPieceCondensed memory droppedPiece = cultureIndex.dropTopVotedPiece();
        assertTrue(cultureIndex.getPieceById(droppedPiece.pieceId).isDropped, "Top voted piece should be dropped");
    }
}
