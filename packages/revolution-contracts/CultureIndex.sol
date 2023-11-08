// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.22;

import { IERC20 } from "./IERC20.sol";
import { MaxHeap } from "./MaxHeap.sol";
import { ICultureIndex } from "./interfaces/ICultureIndex.sol";

contract CultureIndex is ICultureIndex {
    // The MaxHeap data structure used to keep track of the top-voted piece
    MaxHeap public maxHeap;

    // The ERC20 token used for voting
    IERC20 public votingToken;

    // Initialize ERC20 Token in the constructor
    constructor(address _votingToken) {
        votingToken = IERC20(_votingToken);
        maxHeap = new MaxHeap(21_000_000_000);
    }

    // The list of all pieces
    mapping(uint256 => ArtPiece) public pieces;

    // The total number of pieces
    uint256 public pieceCount;

    // The list of all votes for a piece
    mapping(uint256 => Vote[]) public votes;

    // The total voting weight for a piece
    mapping(uint256 => uint256) public totalVoteWeights;

    // A mapping to keep track of whether the voter voted for the piece
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    /**
     *  Validates the media type and associated data.
     * @param metadata The metadata associated with the art piece.
     *
     * Requirements:
     * - The media type must be one of the defined types in the MediaType enum.
     * - The corresponding media data must not be empty.
     */
    function validateMediaType(ArtPieceMetadata memory metadata) internal pure {
        require(uint8(metadata.mediaType) > 0 && uint8(metadata.mediaType) <= 5, "Invalid media type");

        if (metadata.mediaType == MediaType.IMAGE) {
            require(bytes(metadata.image).length > 0, "Image URL must be provided");
        } else if (metadata.mediaType == MediaType.ANIMATION) {
            require(bytes(metadata.animationUrl).length > 0, "Video URL must be provided");
        } else if (metadata.mediaType == MediaType.TEXT) {
            require(bytes(metadata.text).length > 0, "Text must be provided");
        }
    }

    /**
     * @notice Gets the total basis points from an array of creators.
     * @param creatorArray An array of Creator structs containing address and basis points.
     * @return Returns the total basis points calculated from the array of creators.
     *
     * Requirements:
     * - The `creatorArray` must not contain any zero addresses.
     * - The function will return the total basis points which must be checked to be exactly 10,000.
     */
    function getTotalBpsFromCreators(CreatorBps[] memory creatorArray) internal pure returns (uint256) {
        uint256 totalBps = 0;
        for (uint i = 0; i < creatorArray.length; i++) {
            require(creatorArray[i].creator != address(0), "Invalid creator address");
            totalBps += creatorArray[i].bps;
        }
        return totalBps;
    }

    /**
     * @notice Creates a new piece of art with associated metadata and creators.
     * @param metadata The metadata associated with the art piece, including name, description, image, and optional animation URL.
     * @param creatorArray An array of creators who contributed to the piece, along with their respective basis points that must sum up to 10,000.
     * @return Returns the unique ID of the newly created art piece.
     *
     * Emits a {PieceCreated} event for the newly created piece.
     * Emits a {PieceCreatorAdded} event for each creator added to the piece.
     *
     * Requirements:
     * - `metadata` must include name, description, and image. Animation URL is optional.
     * - `creatorArray` must not contain any zero addresses.
     * - The sum of basis points in `creatorArray` must be exactly 10,000.
     */
    function createPiece(ArtPieceMetadata memory metadata, CreatorBps[] memory creatorArray) public returns (uint256) {
        //Require that creatorArray is not more than 100 to prevent gas limit issues
        require(creatorArray.length <= 100, "Creator array must not be > 100");

        uint256 totalBps = getTotalBpsFromCreators(creatorArray);
        require(totalBps == 10_000, "Total BPS must sum up to 10,000");

        // Validate the media type and associated data
        validateMediaType(metadata);

        uint256 pieceId = pieceCount++;

        ArtPiece storage newPiece = pieces[pieceId];

        newPiece.pieceId = pieceId;
        newPiece.metadata = metadata;
        newPiece.dropper = msg.sender;

        for (uint i = 0; i < creatorArray.length; i++) {
            newPiece.creators.push(creatorArray[i]);
        }

        /// @dev Insert the new piece into the max heap
        maxHeap.insert(pieceId, 0);

        emit PieceCreated(pieceId, msg.sender, metadata.name, metadata.description, metadata.image, metadata.animationUrl, metadata.text, uint8(metadata.mediaType));

        // Emit an event for each creator
        for (uint i = 0; i < creatorArray.length; i++) {
            emit PieceCreatorAdded(pieceId, creatorArray[i].creator, msg.sender, creatorArray[i].bps);
        }
        return newPiece.pieceId;
    }

    /**
     * @notice Cast a vote for a specific ArtPiece.
     * @param pieceId The ID of the ArtPiece to vote for.
     * @dev Requires that the pieceId is valid, the voter has not already voted on this piece, and the weight is greater than zero.
     * Emits a VoteCast event upon successful execution.
     */
    function vote(uint256 pieceId) public {
        // Most likely to fail should go first
        uint256 weight = votingToken.balanceOf(msg.sender);
        require(weight > 0, "Weight must be greater than zero");

        require(pieceId <= pieceCount, "Invalid piece ID");
        require(!hasVoted[pieceId][msg.sender], "Already voted");
        require(!pieces[pieceId].isDropped, "Piece has already been dropped");

        // Directly update state variables without reading them into local variables
        hasVoted[pieceId][msg.sender] = true;
        votes[pieceId].push(Vote(msg.sender, weight));
        totalVoteWeights[pieceId] += weight;

        // Insert the new vote weight into the max heap
        maxHeap.updateValue(pieceId, totalVoteWeights[pieceId]);

        emit VoteCast(pieceId, msg.sender, weight, totalVoteWeights[pieceId]);
    }

    /**
     * @notice Fetch an art piece by its ID.
     * @param pieceId The ID of the art piece.
     * @return The ArtPiece struct associated with the given ID.
     */
    function getPieceById(uint256 pieceId) public view returns (ArtPiece memory) {
        require(pieceId <= pieceCount, "Invalid piece ID");
        return pieces[pieceId];
    }

    /**
     * @notice Fetch the list of votes for a given art piece.
     * @param pieceId The ID of the art piece.
     * @return An array of Vote structs for the given art piece ID.
     */
    function getVotes(uint256 pieceId) public view returns (Vote[] memory) {
        require(pieceId <= pieceCount, "Invalid piece ID");
        return votes[pieceId];
    }

    /**
     * @notice Fetch the top-voted art piece.
     * @return The ArtPiece struct of the top-voted art piece.
     */
    function getTopVotedPiece() public view returns (ArtPiece memory) {
        (uint256 pieceId, ) = maxHeap.getMax();
        return pieces[pieceId];
    }

    /**
     * @notice Fetch the top-voted pieceId
     * @return The top-voted pieceId
     */
    function topVotedPieceId() external view returns (uint256) {
        (uint256 pieceId, ) = maxHeap.getMax();
        return pieceId;
    }

    /**
     * @notice Get the number of votes for a piece
     * @param pieceId The ID of the art piece.
     * @return The number of votes for a piece
     */
    function getVoteCount(uint256 pieceId) external view returns (uint256) {
        return votes[pieceId].length;
    }

    /**
     * @notice Pulls and drops the top-voted piece.
     * @return The top voted piece
     */
    function dropTopVotedPiece() public returns (ArtPiece memory) {
        uint256 pieceId;
        try maxHeap.extractMax() returns (uint256 _pieceId, uint256 _value) {
            pieceId = _pieceId;
        } catch Error(
            string memory reason // Catch known revert reason
        ) {
            if (keccak256(abi.encodePacked(reason)) == keccak256(abi.encodePacked("Heap is empty"))) {
                revert("No pieces available to drop");
            }
            revert(reason); // Revert with the original error if not matched
        } catch (
            bytes memory /*lowLevelData*/ // Catch any other low-level failures
        ) {
            revert("Unknown error extracting top piece");
        }

        pieces[pieceId].isDropped = true;

        emit PieceDropped(pieceId, msg.sender);

        //for each creator, emit an event
        for (uint i = 0; i < pieces[pieceId].creators.length; i++) {
            emit PieceDroppedCreator(pieceId, pieces[pieceId].creators[i].creator, pieces[pieceId].dropper, pieces[pieceId].creators[i].bps);
        }

        return pieces[pieceId];
    }
}
