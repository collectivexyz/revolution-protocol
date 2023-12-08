// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC721Checkpointable } from "../base/ERC721Checkpointable.sol";

/**
 * @title ICultureIndexEvents
 * @dev This interface defines the events for the CultureIndex contract.
 */
interface ICultureIndexEvents {
    event ERC721VotingTokenUpdated(ERC721Checkpointable ERC721VotingToken);

    event ERC721VotingTokenLocked();

    /**
     * @dev Emitted when a new piece is created.
     * @param pieceId Unique identifier for the newly created piece.
     * @param dropper Address that created the piece.
     * @param metadata Metadata associated with the art piece.
     * @param quorumVotes The quorum votes for the piece.
     * @param totalVotesSupply The total votes supply for the piece.
     */
    event PieceCreated(
        uint256 indexed pieceId,
        address indexed dropper,
        ICultureIndex.ArtPieceMetadata metadata,
        uint256 quorumVotes,
        uint256 totalVotesSupply
    );

    /**
     * @dev Emitted when a top-voted piece is dropped or released.
     * @param pieceId Unique identifier for the dropped piece.
     * @param remover Address that initiated the drop.
     */
    event PieceDropped(uint256 indexed pieceId, address indexed remover);

    /**
     * @dev Emitted when a vote is cast for a piece.
     * @param pieceId Unique identifier for the piece being voted for.
     * @param voter Address of the voter.
     * @param weight Weight of the vote.
     * @param totalWeight Total weight of votes for the piece after the new vote.
     */
    event VoteCast(uint256 indexed pieceId, address indexed voter, uint256 weight, uint256 totalWeight);

    // The events emitted for the respective creators of a piece
    event PieceCreatorAdded(
        uint256 indexed pieceId,
        address indexed creatorAddress,
        address indexed dropper,
        uint256 bps
    );

    // @notice Emitted when quorum votes basis points is set
    event QuorumVotesBPSSet(uint256 oldQuorumVotesBPS, uint256 newQuorumVotesBPS);
}

/**
 * @title ICultureIndex
 * @dev This interface defines the methods for the CultureIndex contract for art piece management and voting.
 */
interface ICultureIndex is ICultureIndexEvents {
    error INVALID_SIGNATURE();

    error ADDRESS_ZERO();

    // Enum representing different media types for art pieces.
    enum MediaType {
        NONE,
        IMAGE,
        ANIMATION,
        AUDIO,
        TEXT,
        OTHER
    }

    // Struct defining metadata for an art piece.
    struct ArtPieceMetadata {
        string name;
        string description;
        MediaType mediaType;
        string image;
        string text;
        string animationUrl;
    }

    // Struct representing a creator of an art piece and their basis points.
    struct CreatorBps {
        address creator;
        uint256 bps;
    }

    // Struct defining an art piece.
    struct ArtPiece {
        uint256 pieceId;
        ArtPieceMetadata metadata;
        CreatorBps[] creators;
        address dropper;
        bool isDropped;
        uint256 creationBlock;
        uint256 quorumVotes;
        uint256 totalERC20Supply;
        uint256 totalVotesSupply;
    }

    // Constant for max number of creators
    function MAX_NUM_CREATORS() external view returns (uint256);

    // Struct representing a voter and their weight for a specific art piece.
    struct Vote {
        address voterAddress;
        uint256 weight;
    }

    /**
     * @notice Returns the total number of art pieces.
     * @return The total count of art pieces.
     */
    function pieceCount() external view returns (uint256);

    /**
     * @notice Returns the total voting weight for a specific art piece.
     * @param pieceId The ID of the art piece.
     * @return The total vote weight for the art piece.
     */
    function totalVoteWeights(uint256 pieceId) external view returns (uint256);

    /**
     * @notice Checks if a specific voter has already voted for a given art piece.
     * @param pieceId The ID of the art piece.
     * @param voter The address of the voter.
     * @return A boolean indicating if the voter has voted for the art piece.
     */
    function hasVoted(uint256 pieceId, address voter) external view returns (bool);

    /**
     * @notice Allows a user to create a new art piece.
     * @param metadata The metadata associated with the art piece.
     * @param creatorArray An array of creators and their associated basis points.
     * @return The ID of the newly created art piece.
     */
    function createPiece(
        ArtPieceMetadata memory metadata,
        CreatorBps[] memory creatorArray
    ) external returns (uint256);

    /**
     * @notice Allows a user to vote for a specific art piece.
     * @param pieceId The ID of the art piece.
     */
    function vote(uint256 pieceId) external;

    /**
     * @notice Allows a user to vote for a specific art piece using a signature.
     * @param from The address of the voter.
     * @param pieceId The ID of the art piece.
     * @param deadline The deadline for the vote.
     * @param v The v component of the signature.
     * @param r The r component of the signature.
     * @param s The s component of the signature.
     */
    function voteWithSig(
        address from,
        uint256 pieceId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @notice Allows users to vote for a specific art piece using a signature.
     * @param from The address of the voter.
     * @param pieceId The ID of the art piece.
     * @param deadline The deadline for the vote.
     * @param v The v component of the signature.
     * @param r The r component of the signature.
     * @param s The s component of the signature.
     */
    function batchVoteWithSig(
        address[] memory from,
        uint256[] memory pieceId,
        uint256[] memory deadline,
        uint8[] memory v,
        bytes32[] memory r,
        bytes32[] memory s
    ) external;

    /**
     * @notice Fetch an art piece by its ID.
     * @param pieceId The ID of the art piece.
     * @return The ArtPiece struct associated with the given ID.
     */
    function getPieceById(uint256 pieceId) external view returns (ArtPiece memory);

    /**
     * @notice Fetch the list of voters for a given art piece.
     * @param pieceId The ID of the art piece.
     * @param voter The address of the voter.
     * @return An Voter structs associated with the given art piece ID.
     */
    function getVote(uint256 pieceId, address voter) external view returns (Vote memory);

    /**
     * @notice Retrieve the top-voted art piece based on the accumulated votes.
     * @return The ArtPiece struct representing the piece with the most votes.
     */
    function getTopVotedPiece() external view returns (ArtPiece memory);

    /**
     * @notice Fetch the ID of the top-voted art piece.
     * @return The ID of the art piece with the most votes.
     */
    function topVotedPieceId() external view returns (uint256);

    /**
     * @notice Officially release or "drop" the art piece with the most votes.
     * @dev This function also updates internal state to reflect the piece's dropped status.
     * @return The ArtPiece struct of the top voted piece that was just dropped.
     */
    function dropTopVotedPiece() external returns (ArtPiece memory);

    function setERC721VotingToken(ERC721Checkpointable _ERC721VotingToken) external;

    function lockERC721VotingToken() external;

    function getCurrentVotes(address account) external view returns (uint256);

    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256);
}
