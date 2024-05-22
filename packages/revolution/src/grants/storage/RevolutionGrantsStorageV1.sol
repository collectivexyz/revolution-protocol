// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { IRevolutionGrants } from "../../interfaces/IRevolutionGrants.sol";
import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";
import { IRevolutionVotingPower } from "../../interfaces/IRevolutionVotingPower.sol";
import { ISuperToken, ISuperfluidPool, PoolConfig } from "../superfluid/SuperTokenV1Library.sol";

/// @notice RevolutionGrants Storage V1
/// @author rocketman
/// @notice The RevolutionGrants storage contract
contract RevolutionGrantsStorageV1 {
    /// @notice constant to scale uints into percentages (1e6 == 100%)
    uint256 public constant PERCENTAGE_SCALE = 1e6;

    /// The snapshot block number for voting
    uint256 public snapshotBlock;

    /// The grants implementation
    address public grantsImpl;

    /// The mapping of approved recipients
    mapping(address => bool) public approvedRecipients;

    /// The SuperToken used to pay out the grantees
    ISuperToken public superToken;

    /// The Superfluid pool used to distribute the SuperToken
    ISuperfluidPool public pool;

    /// The sub-grant pools, mapping of child to parent RevolutionGrants contract address
    mapping(address => address) public subGrantPools;

    /// The Superfluid pool configuration
    PoolConfig public poolConfig =
        PoolConfig({ transferabilityForUnitsOwner: false, distributionFromAnyAddress: false });

    /// @notice An account's nonce for gasless votes
    mapping(address => uint256) public nonces;

    // The RevolutionVotingPower contract used to get the voting power of an account
    IRevolutionVotingPower public votingPower;

    /// @notice The minimum vote power required to vote on a grant
    uint256 public minVotingPowerToVote;

    /// @notice The minimum voting power required to create a grant
    uint256 public minVotingPowerToCreate;

    /// @notice The basis point number of votes in support of a grant required in order for a quorum to be reached and for a grant to be funded.
    uint256 public quorumVotesBPS;

    // The weight of the 721 voting token
    uint256 public tokenVoteWeight;

    // The weight of the 20 voting token
    uint256 public pointsVoteWeight;

    // The mapping of a voter to a list of votes allocations (recipient, BPS)
    mapping(address => VoteAllocation[]) public votes;

    // Struct to hold the recipient and their corresponding BPS for a vote
    struct VoteAllocation {
        address recipient;
        uint32 bps;
        uint128 memberUnitsDelta;
    }
}
