// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { ICultureIndex } from "../../interfaces/ICultureIndex.sol";
import { IRevolutionVotingPower } from "../../interfaces/IRevolutionVotingPower.sol";
import { MaxHeap } from "../MaxHeap.sol";

/// @notice CultureIndex Storage V1
/// @author rocketman
/// @notice The CultureIndex storage contract
contract CultureIndexStorageV1 {
    /// @notice An account's nonce for gasless votes
    mapping(address => uint256) public nonces;

    // The MaxHeap data structure used to keep track of the top-voted piece
    MaxHeap public maxHeap;

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

    /// @notice The name of the culture index
    string public name;

    /// @notice A description of the culture index - can include rules or guidelines
    string public description;

    /// @notice Rules or guidelines for the art piece
    string public checklist;

    /// @notice A template for the art piece
    string public template;

    // The list of all pieces
    mapping(uint256 => ICultureIndex.ArtPiece) public pieces;

    // The internal piece ID tracker
    uint256 public _currentPieceId;

    // The mapping of all votes for a piece
    mapping(uint256 => mapping(address => ICultureIndex.Vote)) public votes;

    // The total voting weight for a piece
    mapping(uint256 => uint256) public totalVoteWeights;

    // The address that is allowed to drop art pieces
    address public dropperAdmin;

    // The maximum length for art piece data
    ICultureIndex.PieceMaximums public PIECE_DATA_MAXIMUMS;

    // The required media types for art pieces
    ICultureIndex.MediaType public requiredMediaType;

    // The required file prefixes for art pieces
    ICultureIndex.RequiredMediaPrefix public requiredMediaPrefix;
}
