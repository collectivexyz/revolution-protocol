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

    address onchainVoter;
    uint256 onchainVoterPk;

    function setUp() public override {
        super.setUp();

        (address offchainVoter0, uint256 offchainVoterPk0) = makeAddrAndKey("offchainVoter");

        offchainVoter = offchainVoter0;
        offchainVoterPk = offchainVoterPk0;

        (address onchainVoter, uint256 onchainVoterPk) = makeAddrAndKey("onchainVoter");

        onchainVoter = onchainVoter;
        onchainVoterPk = onchainVoterPk;
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

        bytes32 withdrawHash = keccak256(
            abi.encode(
                cultureIndex.VOTE_TYPEHASH(),
                address(0),
                // offchainVoter,
                pieceId,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), withdrawHash));

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

        bytes32 withdrawHash = keccak256(
            abi.encode(cultureIndex.VOTE_TYPEHASH(), offchainVoter, pieceId, nonce, deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), withdrawHash));

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
}
