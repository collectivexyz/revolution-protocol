// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.22;

/**
 * @title IRevolutionGrantsEvents
 * @dev This interface defines the events for the RevolutionGrants contract.
 */
interface IRevolutionGrantsEvents {
    /**
     * @dev Emitted when a vote is cast for a piece.
     * @param pieceId Unique identifier for the piece being voted for.
     * @param voter Address of the voter.
     * @param weight Weight of the vote.
     * @param totalWeight Total weight of votes for the piece after the new vote.
     */
    event VoteCast(uint256 indexed pieceId, address indexed voter, uint256 weight, uint256 totalWeight);

    /// @notice Emitted when quorum votes basis points is set
    event QuorumVotesBPSSet(uint256 oldQuorumVotesBPS, uint256 newQuorumVotesBPS);

    /// @notice Emitted when min voting power to vote is set
    event MinVotingPowerToVoteSet(uint256 oldMinVotingPowerToVote, uint256 newMinVotingPowerToVote);

    /// @notice Emitted when min voting power to create is set
    event MinVotingPowerToCreateSet(uint256 oldMinVotingPowerToCreate, uint256 newMinVotingPowerToCreate);
}

/**
 * @title IRevolutionGrants
 * @dev This interface defines the methods for the RevolutionGrants contract for grants.
 */
interface IRevolutionGrants is IRevolutionGrantsEvents {
    ///                                                          ///
    ///                           ERRORS                         ///
    ///                                                          ///

    /// @dev Reverts if the lengths of the provided arrays do not match.
    error ARRAY_LENGTH_MISMATCH();

    /// @dev Reverts if the art piece has already been dropped.
    error ALREADY_DROPPED();

    /// @dev Reverts if the voter has already voted for this piece.
    error ALREADY_VOTED();

    /// @dev Reverts if the voter's weight is below the minimum required vote weight.
    error WEIGHT_TOO_LOW();

    /// @dev Reverts if the voting signature is invalid
    error INVALID_SIGNATURE();

    /// @dev Reverts if the function caller is not the manager.
    error NOT_MANAGER();

    /// @dev Reverts if the quorum votes basis points exceed the maximum allowed value.
    error INVALID_QUORUM_BPS();

    /// @dev Reverts if the ERC721 voting token weight is invalid (i.e., 0).
    error INVALID_ERC721_VOTING_WEIGHT();

    /// @dev Reverts if the ERC20 voting token weight is invalid (i.e., 0).
    error INVALID_ERC20_VOTING_WEIGHT();

    /// @dev Reverts if the total vote weights do not meet the required quorum votes for a piece to be dropped.
    error DOES_NOT_MEET_QUORUM();

    /// @dev Reverts if the voting signature has expired
    error SIGNATURE_EXPIRED();

    /// @dev Reverts if address 0 is passed but not allowed
    error ADDRESS_ZERO();

    /// @dev Reverts if bps does not sum to 10000
    error INVALID_BPS_SUM();

    /// @dev Reverts if sender is not manager
    error SENDER_NOT_MANAGER();

    ///                                                          ///
    ///                         STRUCTS                          ///
    ///                                                          ///

    // Struct representing a voter and their weight for a specific art piece.
    struct Vote {
        address voterAddress;
        uint256 weight;
    }

    // /**
    //  * @notice Checks if a specific voter has already voted for a given art piece.
    //  * @param pieceId The ID of the art piece.
    //  * @param voter The address of the voter.
    //  * @return A boolean indicating if the voter has voted for the art piece.
    //  */
    // function hasVoted(uint256 pieceId, address voter) external view returns (bool);

    // /**
    //  * @notice Allows a user to vote for a specific art piece.
    //  * @param pieceId The ID of the art piece.
    //  */
    // function vote(uint256 pieceId) external;

    // /**
    //  * @notice Allows a user to vote for many art pieces.
    //  * @param pieceIds The ID of the art pieces.
    //  */
    // function voteForMany(uint256[] calldata pieceIds) external;

    // /**
    //  * @notice Allows a user to vote for a specific art piece using a signature.
    //  * @param from The address of the voter.
    //  * @param pieceIds The ID of the art piece.
    //  * @param deadline The deadline for the vote.
    //  * @param v The v component of the signature.
    //  * @param r The r component of the signature.
    //  * @param s The s component of the signature.
    //  */
    // function voteForManyWithSig(
    //     address from,
    //     uint256[] calldata pieceIds,
    //     uint256 deadline,
    //     uint8 v,
    //     bytes32 r,
    //     bytes32 s
    // ) external;

    // /**
    //  * @notice Allows users to vote for a specific art piece using a signature.
    //  * @param from The address of the voter.
    //  * @param pieceIds The ID of the art piece.
    //  * @param deadline The deadline for the vote.
    //  * @param v The v component of the signature.
    //  * @param r The r component of the signature.
    //  * @param s The s component of the signature.
    //  */
    // function batchVoteForManyWithSig(
    //     address[] memory from,
    //     uint256[][] memory pieceIds,
    //     uint256[] memory deadline,
    //     uint8[] memory v,
    //     bytes32[] memory r,
    //     bytes32[] memory s
    // ) external;

    // /**
    //  * @notice Fetch the list of voters for a given art piece.
    //  * @param pieceId The ID of the art piece.
    //  * @param voter The address of the voter.
    //  * @return An Voter structs associated with the given art piece ID.
    //  */
    // function getVote(uint256 pieceId, address voter) external view returns (Vote memory);

    // /**
    //  * @notice Returns true or false depending on whether the top voted piece meets quorum
    //  * @return True if the top voted piece meets quorum, false otherwise
    //  */
    // function grantMeetsQuorum() external view returns (bool);

    /**
     * @notice Structure to hold the parameters for initializing grants.
     * @param tokenVoteWeight The voting weight of the individual Revolution ERC721 tokens.
     * @param pointsVoteWeight The voting weight of the individual Revolution ERC20 points tokens.
     * @param quorumVotesBPS The initial quorum votes threshold in basis points.
     * @param minVotingPowerToVote The minimum vote weight that a voter must have to be able to vote.
     * @param minVotingPowerToCreate The minimum vote weight that a voter must have to be able to create an art piece.
     */
    struct GrantsParams {
        uint256 tokenVoteWeight;
        uint256 pointsVoteWeight;
        uint256 quorumVotesBPS;
        uint256 minVotingPowerToVote;
        uint256 minVotingPowerToCreate;
    }

    /**
     * @notice Initializes a token's metadata descriptor
     * @param votingPower The address of the revolution voting power contract
     * @param initialOwner The owner of the contract, allowed to drop pieces. Commonly updated to the AuctionHouse
     * @param grantsParams The parameters for the grants contract
     */
    function initialize(address votingPower, address initialOwner, GrantsParams memory grantsParams) external;
}
