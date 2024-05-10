// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { ICultureIndex } from "../../interfaces/ICultureIndex.sol";
import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";
import { IRevolutionVotingPower } from "../../interfaces/IRevolutionVotingPower.sol";
import { ISuperToken, ISuperfluidPool, PoolConfig } from "../superfluid/SuperTokenV1Library.sol";

/// @notice RevolutionGrants Storage V1
/// @author rocketman
/// @notice The RevolutionGrants storage contract
contract RevolutionGrantsStorageV1 {
    /// The snapshot block number for voting
    uint256 public snapshotBlock;

    /// The mapping of approved recipients
    mapping(address => bool) public approvedRecipients;

    /// The SuperToken used to pay out the grantees
    ISuperToken internal immutable superToken;

    /// The Superfluid pool used to distribute the SuperToken
    ISuperfluidPool internal immutable pool;

    /// The Superfluid pool configuration
    PoolConfig internal poolConfig =
        PoolConfig({ transferabilityForUnitsOwner: false, distributionFromAnyAddress: false });

    /// The upgrade manager
    IUpgradeManager public manager;

    /// @notice An account's nonce for gasless votes
    mapping(address => uint256) public nonces;

    // The RevolutionVotingPower contract used to get the voting power of an account
    IRevolutionVotingPower public votingPower;

    /// @notice The minimum vote power required to vote on an art piece
    uint256 public minVotingPowerToVote;

    /// @notice The minimum voting power required to create an art piece
    uint256 public minVotingPowerToCreate;

    /// @notice The basis point number of votes in support of a art piece required in order for a quorum to be reached and for an art piece to be dropped.
    uint256 public quorumVotesBPS;

    // The weight of the 721 voting token
    uint256 public tokenVoteWeight;

    // The weight of the 20 voting token
    uint256 public pointsVoteWeight;

    // The list of all pieces
    mapping(uint256 => ICultureIndex.ArtPiece) public pieces;

    // The mapping of all votes for a piece
    mapping(uint256 => mapping(address => ICultureIndex.Vote)) public votes;

    // The total voting weight for a piece
    mapping(uint256 => uint256) public totalVoteWeights;
}
