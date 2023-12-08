// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { CultureIndex } from "../../src/CultureIndex.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { ICultureIndex, ICultureIndexEvents } from "../../src/interfaces/ICultureIndex.sol";
import { NontransferableERC20Votes } from "../../src/NontransferableERC20Votes.sol";
import { CultureIndexTestSuite } from "./CultureIndex.t.sol";
import { Votes } from "../../src/base/Votes.sol";
import { ERC721Checkpointable } from "../../src/base/ERC721Checkpointable.sol";

/**
 * @title CultureIndexTest
 * @dev Test contract for CultureIndex
 */
contract CultureIndexVotingSignaturesTest is CultureIndexTestSuite {
    address offchainVoter;
    uint256 offchainVoterPk;

    address funVoterGuy;
    uint256 funVoterGuyPk;

    function setUp() public override {
        super.setUp();

        (address offchainVoter0, uint256 offchainVoterPk0) = makeAddrAndKey("offchainVoter");

        offchainVoter = offchainVoter0;
        offchainVoterPk = offchainVoterPk0;

        (address funVoterGuy0, uint256 funVoterGuyPk0) = makeAddrAndKey("funVoterGuy");

        funVoterGuy = funVoterGuy0;
        funVoterGuyPk = funVoterGuyPk0;
    }

    function getDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes("CultureIndex")),
                    keccak256(bytes("1")),
                    block.chainid,
                    address(cultureIndex)
                )
            );
    }

    function testRevert_InvalidVoteWithSigToAddress() public {
        uint256 pieceId = createDefaultArtPiece();

        uint256 nonce = cultureIndex.nonces(offchainVoter);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 voteHash = keccak256(
            abi.encode(
                cultureIndex.VOTE_TYPEHASH(),
                address(0),
                // offchainVoter,
                pieceId,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), voteHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(offchainVoterPk, digest);

        vm.expectRevert(abi.encodeWithSignature("ADDRESS_ZERO()"));
        cultureIndex.voteWithSig(address(0), pieceId, deadline, v, r, s);
    }

    function testVoteWithSig() public {
        uint256 pieceId = createDefaultArtPiece();

        uint256 nonce = cultureIndex.nonces(offchainVoter);
        uint256 deadline = block.timestamp + 1 days;

        //mint offchainVoterWeight to offchainVoter
        uint256 offchainVoterWeight = 100;
        govToken.mint(offchainVoter, offchainVoterWeight);

        vm.roll(block.number + 1);

        bytes32 voteHash = keccak256(
            abi.encode(cultureIndex.VOTE_TYPEHASH(), offchainVoter, pieceId, nonce, deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), voteHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(offchainVoterPk, digest);

        uint256 beforeVoteWeight = cultureIndex.totalVoteWeights(pieceId);
        ICultureIndex.Vote memory voteBefore = cultureIndex.getVote(pieceId, offchainVoter);

        //ensure voteBefore is empty
        assertEq(voteBefore.voterAddress, address(0));
        assertEq(voteBefore.weight, 0);

        vm.expectEmit(true, true, true, true);
        emit ICultureIndexEvents.VoteCast(
            pieceId,
            offchainVoter,
            offchainVoterWeight,
            beforeVoteWeight + offchainVoterWeight
        );
        cultureIndex.voteWithSig(offchainVoter, pieceId, deadline, v, r, s);

        assertEq(cultureIndex.totalVoteWeights(pieceId), beforeVoteWeight + offchainVoterWeight);

        //make sure vote.voterAddress and vote.weight are set correctly
        ICultureIndex.Vote memory voteAfter = cultureIndex.getVote(pieceId, offchainVoter);
        assertEq(voteAfter.voterAddress, offchainVoter);
        assertEq(voteAfter.weight, offchainVoterWeight);
    }

    function testRevert_SigExpired() public {
        uint256 pieceId = createDefaultArtPiece();

        uint256 nonce = cultureIndex.nonces(offchainVoter);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 voteHash = keccak256(
            abi.encode(cultureIndex.VOTE_TYPEHASH(), offchainVoter, pieceId, nonce, deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), voteHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(offchainVoterPk, digest);

        vm.warp(deadline + 1);

        vm.expectRevert("Signature expired");
        cultureIndex.voteWithSig(offchainVoter, pieceId, deadline, v, r, s);
    }

    function testRevert_InvalidNonce() public {
        uint256 pieceId = createDefaultArtPiece();

        uint256 nonce = cultureIndex.nonces(offchainVoter) + 1;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 voteHash = keccak256(
            abi.encode(cultureIndex.VOTE_TYPEHASH(), offchainVoter, nonce, deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), voteHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(offchainVoterPk, digest);

        vm.expectRevert(abi.encodeWithSignature("INVALID_SIGNATURE()"));
        cultureIndex.voteWithSig(offchainVoter, pieceId, deadline, v, r, s);
    }

    function testRevert_InvalidReplay() public {
        uint pieceId = createDefaultArtPiece();

        uint256 nonce = cultureIndex.nonces(offchainVoter);
        uint256 deadline = block.timestamp + 1 days;

        // mint offchainVoterWeight to offchainVoter
        uint256 offchainVoterWeight = 100;
        govToken.mint(offchainVoter, offchainVoterWeight);

        vm.roll(block.number + 1);

        bytes32 voteHash = keccak256(
            abi.encode(cultureIndex.VOTE_TYPEHASH(), offchainVoter, pieceId, nonce, deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), voteHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(offchainVoterPk, digest);

        cultureIndex.voteWithSig(offchainVoter, pieceId, deadline, v, r, s);

        vm.expectRevert(abi.encodeWithSignature("INVALID_SIGNATURE()"));
        cultureIndex.voteWithSig(offchainVoter, pieceId, deadline, v, r, s);
    }

    function testRevert_InvalidSigner() public {
        uint256 pieceId = createDefaultArtPiece();

        (address notoffchainVoter, uint256 notoffchainVoterPk) = makeAddrAndKey("notBuilder");

        uint256 nonce = cultureIndex.nonces(offchainVoter);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 voteHash = keccak256(
            abi.encode(cultureIndex.VOTE_TYPEHASH(), notoffchainVoter, pieceId, nonce, deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), voteHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(notoffchainVoterPk, digest);

        vm.expectRevert(abi.encodeWithSignature("INVALID_SIGNATURE()"));
        cultureIndex.voteWithSig(offchainVoter, pieceId, deadline, v, r, s);
    }

    function testRevert_InvalidVotes() public {
        uint pieceId = createDefaultArtPiece();

        uint256 nonce = cultureIndex.nonces(offchainVoter);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 voteHash = keccak256(
            abi.encode(cultureIndex.VOTE_TYPEHASH(), offchainVoter, pieceId + 1, nonce, deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), voteHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(offchainVoterPk, digest);

        vm.expectRevert("Invalid piece ID");
        cultureIndex.voteWithSig(offchainVoter, pieceId + 1, deadline, v, r, s);

        //mint tokens finally
        govToken.mint(offchainVoter, 100);

        vm.roll(block.number + 1);

        // vote correctly but expect "Weight must be greater than zero"
        nonce = cultureIndex.nonces(funVoterGuy);
        deadline = block.timestamp + 1 days;

        voteHash = keccak256(abi.encode(cultureIndex.VOTE_TYPEHASH(), funVoterGuy, pieceId, nonce, deadline));

        digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), voteHash));

        (v, r, s) = vm.sign(funVoterGuyPk, digest);

        vm.expectRevert("Weight must be greater than zero");
        cultureIndex.voteWithSig(funVoterGuy, pieceId, deadline, v, r, s);

        //vote with offchainVoter
        nonce = cultureIndex.nonces(offchainVoter);
        deadline = block.timestamp + 1 days;

        voteHash = keccak256(
            abi.encode(cultureIndex.VOTE_TYPEHASH(), offchainVoter, pieceId, nonce, deadline)
        );

        digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), voteHash));

        (v, r, s) = vm.sign(offchainVoterPk, digest);

        cultureIndex.voteWithSig(offchainVoter, pieceId, deadline, v, r, s);

        //vote again with same address and expect "Already voted"
        nonce = cultureIndex.nonces(offchainVoter);
        deadline = block.timestamp + 1 days;

        voteHash = keccak256(
            abi.encode(cultureIndex.VOTE_TYPEHASH(), offchainVoter, pieceId, nonce, deadline)
        );

        digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), voteHash));

        (v, r, s) = vm.sign(offchainVoterPk, digest);

        vm.expectRevert("Already voted");
        cultureIndex.voteWithSig(offchainVoter, pieceId, deadline, v, r, s);

        // dropTopVotedPiece
        cultureIndex.dropTopVotedPiece();

        // vote again with different address and expect "Piece has already been dropped"
        (address notoffchainVoter, uint256 notoffchainVoterPk) = makeAddrAndKey("notBuilder");

        nonce = cultureIndex.nonces(notoffchainVoter);
        deadline = block.timestamp + 1 days;

        voteHash = keccak256(
            abi.encode(cultureIndex.VOTE_TYPEHASH(), notoffchainVoter, pieceId, nonce, deadline)
        );

        digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), voteHash));

        (v, r, s) = vm.sign(notoffchainVoterPk, digest);

        vm.expectRevert("Piece has already been dropped");
        cultureIndex.voteWithSig(notoffchainVoter, pieceId, deadline, v, r, s);
    }
}
