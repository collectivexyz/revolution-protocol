// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.22;

import { IERC20 } from "../IERC20.sol";

/**
 * @title ICultureIndex
 * @dev This interface defines the methods for the CultureIndex contract for art piece management and voting.
 */
interface ICultureIndex {
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
    }

    // Struct representing a voter and their weight for a specific art piece.
    struct Voter {
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
     * @notice Returns the index of the next piece to be dropped.
     * @return The index for the next drop.
     */
    function nextDropIndex() external view returns (uint256);

    /**
     * @notice Returns the piece ID of a dropped piece based on its index.
     * @param index The index of the dropped piece.
     * @return The ID of the dropped piece.
     */
    function droppedPiecesMapping(uint256 index) external view returns (uint256);

    /**
     * @notice Allows a user to create a new art piece.
     * @param metadata The metadata associated with the art piece.
     * @param creatorArray An array of creators and their associated basis points.
     * @return The ID of the newly created art piece.
     */
    function createPiece(ArtPieceMetadata memory metadata, CreatorBps[] memory creatorArray) external returns (uint256);

    /**
     * @notice Allows a user to vote for a specific art piece.
     * @param pieceId The ID of the art piece.
     */
    function vote(uint256 pieceId) external;

    /**
     * @notice Fetch an art piece by its ID.
     * @param pieceId The ID of the art piece.
     * @return The ArtPiece struct associated with the given ID.
     */
    function getPieceById(uint256 pieceId) external view returns (ArtPiece memory);

    /**
     * @notice Fetch the list of voters for a given art piece.
     * @param pieceId The ID of the art piece.
     * @return An array of Voter structs associated with the given art piece ID.
     */
    function getVotes(uint256 pieceId) external view returns (Voter[] memory);

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
     * @notice Get the total number of votes cast for a specific art piece.
     * @param pieceId The ID of the art piece.
     * @return The total count of votes for the specified art piece.
     */
    function getVoteCount(uint256 pieceId) external view returns (uint256);

    /**
     * @notice Retrieve the total number of art pieces that have been officially released or "dropped".
     * @return The count of all dropped art pieces.
     */
    function getTotalDroppedPieces() external view returns (uint256);

    /**
     * @notice Fetch a specific art piece that has been dropped by its sequential index.
     * @param index The index (in order of being dropped) of the art piece.
     * @return The ArtPiece struct of the specified dropped piece.
     */
    function getDroppedPieceByIndex(uint256 index) external view returns (ArtPiece memory);

    /**
     * @notice Retrieve the most recently dropped art piece.
     * @return The ArtPiece struct of the latest dropped piece.
     */
    function getLatestDroppedPiece() external view returns (ArtPiece memory);

    /**
     * @notice Officially release or "drop" the art piece with the most votes.
     * @dev This function also updates internal state to reflect the piece's dropped status.
     * @return The ArtPiece struct of the top voted piece that was just dropped.
     */
    function dropTopVotedPiece() external returns (ArtPiece memory);
}
