// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.22;

import { ERC20Votes } from "./base/erc20/ERC20Votes.sol";
import { MaxHeap } from "./MaxHeap.sol";
import { ICultureIndex } from "./interfaces/ICultureIndex.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ERC721Checkpointable } from "./base/ERC721Checkpointable.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract CultureIndex is ICultureIndex, Ownable, ReentrancyGuard, EIP712 {
    /// @notice The EIP-712 typehash for gasless votes
    bytes32 public constant VOTE_TYPEHASH =
        keccak256("Vote(address from,uint256 pieceId,uint256 nonce,uint256 deadline)");

    /// @notice An account's nonce for gasless votes
    mapping(address => uint256) public nonces;

    // The MaxHeap data structure used to keep track of the top-voted piece
    MaxHeap public immutable maxHeap;

    // The ERC20 token used for voting
    ERC20Votes public immutable erc20VotingToken;

    // The ERC721 token used for voting
    ERC721Checkpointable public erc721VotingToken;

    // Whether the 721 voting token can be updated
    bool public isERC721VotingTokenLocked;

    // The weight of the 721 voting token
    uint256 public immutable erc721VotingTokenWeight;

    /// @notice The minimum settable quorum votes basis points
    uint256 public constant MIN_QUORUM_VOTES_BPS = 200; // 200 basis points or 2%

    /// @notice The maximum settable quorum votes basis points
    uint256 public constant MAX_QUORUM_VOTES_BPS = 4_000; // 4,000 basis points or 40%

    /// @notice The basis point number of votes in support of a art piece required in order for a quorum to be reached and for an art piece to be dropped.
    uint256 public quorumVotesBPS;

    string public name;

    string public description;

    // The list of all pieces
    mapping(uint256 => ArtPiece) public pieces;

    // The internal piece ID tracker
    uint256 public _currentPieceId;

    // The mapping of all votes for a piece
    mapping(uint256 => mapping(address => Vote)) public votes;

    // The total voting weight for a piece
    mapping(uint256 => uint256) public totalVoteWeights;

    // Constant for max number of creators
    uint256 public constant MAX_NUM_CREATORS = 100;

    /**
     * @notice Constructor
     * @param name_ The name of the culture index
     * @param description_ A description for the culture index, can include rules for uploads etc.
     * @param erc20VotingToken_ The address of the ERC20 voting token, commonly referred to as "points"
     * @param erc721VotingToken_ The address of the ERC721 voting token, commonly the dropped art pieces
     * @param initialOwner_ The owner of the contract, allowed to drop pieces. Commonly updated to the AuctionHouse
     * @param erc721VotingTokenWeight_ The voting weight of the individual ERC721 tokens. Normally a large multiple to match up with daily emission of ERC20 points
     * @param quorumVotesBPS_ The initial quorum votes threshold in basis points
     */
    constructor(
        string memory name_,
        string memory description_,
        address erc20VotingToken_,
        address erc721VotingToken_,
        address initialOwner_,
        uint256 erc721VotingTokenWeight_,
        uint256 quorumVotesBPS_
    ) Ownable(initialOwner_) EIP712("CultureIndex", "1") {
        require(
            quorumVotesBPS_ >= MIN_QUORUM_VOTES_BPS && quorumVotesBPS_ <= MAX_QUORUM_VOTES_BPS,
            "invalid quorum bps"
        );
        require(erc721VotingTokenWeight_ > 0, "invalid erc721 voting token weight");
        require(erc721VotingToken_ != address(0), "invalid erc721 voting token");
        require(erc20VotingToken_ != address(0), "invalid erc20 voting token");

        erc20VotingToken = ERC20Votes(erc20VotingToken_);
        erc721VotingToken = ERC721Checkpointable(erc721VotingToken_);
        erc721VotingTokenWeight = erc721VotingTokenWeight_;
        name = name_;
        description = description_;
        quorumVotesBPS = quorumVotesBPS_;

        emit QuorumVotesBPSSet(quorumVotesBPS, quorumVotesBPS_);

        maxHeap = new MaxHeap(address(this));
    }

    /**
     * @notice Require that the 721VotingToken has not been locked.
     */
    modifier whenERC721VotingTokenNotLocked() {
        require(!isERC721VotingTokenLocked, "ERC721VotingToken is locked");
        _;
    }

    /**
     * @notice Set the ERC721 voting token.
     * @dev Only callable by the owner when not locked.
     */
    function setERC721VotingToken(
        ERC721Checkpointable _ERC721VotingToken
    ) external override onlyOwner nonReentrant whenERC721VotingTokenNotLocked {
        erc721VotingToken = _ERC721VotingToken;

        emit ERC721VotingTokenUpdated(_ERC721VotingToken);
    }

    /**
     * @notice Lock the ERC721 voting token.
     * @dev This cannot be reversed and is only callable by the owner when not locked.
     */
    function lockERC721VotingToken() external override onlyOwner whenERC721VotingTokenNotLocked {
        isERC721VotingTokenLocked = true;

        emit ERC721VotingTokenLocked();
    }

    /**
     *  Validates the media type and associated data.
     * @param metadata The metadata associated with the art piece.
     *
     * Requirements:
     * - The media type must be one of the defined types in the MediaType enum.
     * - The corresponding media data must not be empty.
     */
    function validateMediaType(ArtPieceMetadata calldata metadata) internal pure {
        require(uint8(metadata.mediaType) > 0 && uint8(metadata.mediaType) <= 5, "Invalid media type");

        if (metadata.mediaType == MediaType.IMAGE)
            require(bytes(metadata.image).length > 0, "Image URL must be provided");
        else if (metadata.mediaType == MediaType.ANIMATION)
            require(bytes(metadata.animationUrl).length > 0, "Animation URL must be provided");
        else if (metadata.mediaType == MediaType.TEXT)
            require(bytes(metadata.text).length > 0, "Text must be provided");
    }

    /**
     * @notice Checks the total basis points from an array of creators and returns the length
     * @param creatorArray An array of Creator structs containing address and basis points.
     * @return Returns the total basis points calculated from the array of creators.
     *
     * Requirements:
     * - The `creatorArray` must not contain any zero addresses.
     * - The function will return the length of the `creatorArray`.
     */
    function validateCreatorsArray(CreatorBps[] calldata creatorArray) internal pure returns (uint256) {
        uint256 creatorArrayLength = creatorArray.length;
        //Require that creatorArray is not more than MAX_NUM_CREATORS to prevent gas limit issues
        require(creatorArrayLength <= MAX_NUM_CREATORS, "Creator array must not be > MAX_NUM_CREATORS");

        uint256 totalBps;
        for (uint i; i < creatorArrayLength; ) {
            require(creatorArray[i].creator != address(0), "Invalid creator address");
            totalBps += creatorArray[i].bps;

            unchecked {
                ++i;
            }
        }

        require(totalBps == 10_000, "Total BPS must sum up to 10,000");

        return creatorArrayLength;
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
    function createPiece(
        ArtPieceMetadata calldata metadata,
        CreatorBps[] calldata creatorArray
    ) public returns (uint256) {
        uint256 creatorArrayLength = validateCreatorsArray(creatorArray);

        // Validate the media type and associated data
        validateMediaType(metadata);

        uint256 pieceId = _currentPieceId++;

        /// @dev Insert the new piece into the max heap
        maxHeap.insert(pieceId, 0);

        ArtPiece storage newPiece = pieces[pieceId];

        newPiece.pieceId = pieceId;
        newPiece.totalVotesSupply = _calculateVoteWeight(
            erc20VotingToken.totalSupply(),
            erc721VotingToken.totalSupply()
        );
        newPiece.totalERC20Supply = erc20VotingToken.totalSupply();
        newPiece.metadata = metadata;
        newPiece.dropper = msg.sender;
        newPiece.creationBlock = block.number;
        newPiece.quorumVotes = (quorumVotesBPS * newPiece.totalVotesSupply) / 10_000;

        for (uint i; i < creatorArrayLength; ) {
            newPiece.creators.push(creatorArray[i]);

            unchecked {
                ++i;
            }
        }

        _emitPieceCreatedEvents(
            pieceId,
            msg.sender,
            metadata,
            creatorArray,
            creatorArrayLength,
            newPiece.quorumVotes,
            newPiece.totalVotesSupply
        );

        return newPiece.pieceId;
    }

    /**
     * @notice Emits events for created art piece
     * @param pieceId The ID of the art piece.
     * @param sender The address of the sender.
     * @param metadata The metadata associated with the art piece, including name, description, image, and optional animation URL.
     * @param creatorArray An array of creators who contributed to the piece, along with their respective basis points that must sum up to 10,000.
     * @param quorum The quorum votes required for the art piece to be dropped.
     * @param totalVotesSupply The total votes supply at the time of creation.
     */
    function _emitPieceCreatedEvents(
        uint256 pieceId,
        address sender,
        ArtPieceMetadata calldata metadata,
        CreatorBps[] calldata creatorArray,
        uint256 creatorArrayLength,
        uint256 quorum,
        uint256 totalVotesSupply
    ) internal {
        emit PieceCreated(
            pieceId,
            sender,
            metadata,
            quorum,
            totalVotesSupply
        );

        // Emit an event for each creator
        for (uint i; i < creatorArrayLength; ) {
            emit PieceCreatorAdded(pieceId, creatorArray[i].creator, msg.sender, creatorArray[i].bps);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Checks if a specific voter has already voted for a given art piece.
     * @param pieceId The ID of the art piece.
     * @param voter The address of the voter.
     * @return A boolean indicating if the voter has voted for the art piece.
     */
    function hasVoted(uint256 pieceId, address voter) external view returns (bool) {
        return votes[pieceId][voter].voterAddress != address(0);
    }

    /**
     * @notice Returns the voting power of a voter at the current block.
     * @param account The address of the voter.
     * @return The voting power of the voter.
     */
    function getCurrentVotes(address account) external view override returns (uint256) {
        return _getCurrentVotes(account);
    }

    /**
     * @notice Returns the voting power of a voter at the current block.
     * @param account The address of the voter.
     * @return The voting power of the voter.
     */
    function getPriorVotes(address account, uint256 blockNumber) external view override returns (uint256) {
        return _getPriorVotes(account, blockNumber);
    }

    /**
     * @notice Calculates the vote weight of a voter.
     * @param erc20Balance The ERC20 balance of the voter.
     * @param erc721Balance The ERC721 balance of the voter.
     * @return The vote weight of the voter.
     */
    function _calculateVoteWeight(
        uint256 erc20Balance,
        uint256 erc721Balance
    ) internal view returns (uint256) {
        return erc20Balance + (erc721Balance * erc721VotingTokenWeight * 1e18);
    }

    function _getCurrentVotes(address account) internal view returns (uint256) {
        return
            _calculateVoteWeight(
                erc20VotingToken.getVotes(account),
                erc721VotingToken.getCurrentVotes(account)
            );
    }

    function _getPriorVotes(address account, uint256 blockNumber) internal view returns (uint256) {
        return
            _calculateVoteWeight(
                erc20VotingToken.getPastVotes(account, blockNumber),
                erc721VotingToken.getPriorVotes(account, blockNumber)
            );
    }

    /**
     * @notice Cast a vote for a specific ArtPiece.
     * @param pieceId The ID of the ArtPiece to vote for.
     * @param voter The address of the voter.
     * @dev Requires that the pieceId is valid, the voter has not already voted on this piece, and the weight is greater than zero.
     * Emits a VoteCast event upon successful execution.
     */
    function _vote(uint256 pieceId, address voter) internal {
        require(pieceId < _currentPieceId, "Invalid piece ID");
        require(voter != address(0), "Invalid voter address");
        require(!pieces[pieceId].isDropped, "Piece has already been dropped");
        require(!(votes[pieceId][voter].voterAddress != address(0)), "Already voted");

        uint256 weight = _getPriorVotes(voter, pieces[pieceId].creationBlock);
        require(weight > 0, "Weight must be greater than zero");

        votes[pieceId][voter] = Vote(voter, weight);
        totalVoteWeights[pieceId] += weight;

        uint256 totalWeight = totalVoteWeights[pieceId];

        // TODO add security consideration here based on block created to prevent flash attacks on drops?
        maxHeap.updateValue(pieceId, totalWeight);
        emit VoteCast(pieceId, voter, weight, totalWeight);
    }

    /**
     * @notice Cast a vote for a specific ArtPiece.
     * @param pieceId The ID of the ArtPiece to vote for.
     * @dev Requires that the pieceId is valid, the voter has not already voted on this piece, and the weight is greater than zero.
     * Emits a VoteCast event upon successful execution.
     */
    function vote(uint256 pieceId) public nonReentrant {
        _vote(pieceId, msg.sender);
    }

    /**
     * @notice Cast a vote for a list of ArtPieces.
     * @param pieceIds The IDs of the ArtPieces to vote for.
     * @dev Requires that the pieceIds are valid, the voter has not already voted on this piece, and the weight is greater than zero.
     * Emits a series of VoteCast event upon successful execution.
     */
    function batchVote(uint256[] memory pieceIds) public nonReentrant {
        uint256 len = pieceIds.length;
        for (uint256 i; i < len; ++i) {
            _vote(pieceIds[i], msg.sender);
        }
    }

    /// @notice Execute a vote via signature
    /// @param from Vote from this address
    /// @param pieceId Vote on this pieceId
    /// @param deadline Deadline for the signature to be valid
    /// @param v V component of signature
    /// @param r R component of signature
    /// @param s S component of signature
    function voteWithSig(
        address from,
        uint256 pieceId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        bool success = _verifyVoteSignature(from, pieceId, deadline, v, r, s);

        if (!success) revert INVALID_SIGNATURE();

        _vote(pieceId, from);
    }

    /// @notice Execute a batch of votes via signature
    /// @param from Vote from these addresses
    /// @param pieceId Vote on these pieceIds
    /// @param deadline Deadlines for the signature to be valid
    /// @param v V component of signatures
    /// @param r R component of signatures
    /// @param s S component of signatures
    function batchVoteWithSig(
        address[] memory from,
        uint256[] memory pieceId,
        uint256[] memory deadline,
        uint8[] memory v,
        bytes32[] memory r,
        bytes32[] memory s
    ) external nonReentrant {
        uint256 len = from.length;
        require(
            len == pieceId.length &&
                len == deadline.length &&
                len == v.length &&
                len == r.length &&
                len == s.length,
            "Array lengths must match"
        );

        for (uint256 i; i < len; ) {
            bool success = _verifyVoteSignature(from[i], pieceId[i], deadline[i], v[i], r[i], s[i]);

            if (!success) revert INVALID_SIGNATURE();

            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < len; ) {
            _vote(pieceId[i], from[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Utility function to verify a signature for a specific vote
    /// @param from Vote from this address
    /// @param pieceId Vote on this pieceId
    /// @param deadline Deadline for the signature to be valid
    /// @param v V component of signature
    /// @param r R component of signature
    /// @param s S component of signature
    function _verifyVoteSignature(
        address from,
        uint256 pieceId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal returns (bool success) {
        require(deadline >= block.timestamp, "Signature expired");

        bytes32 voteHash;

        voteHash = keccak256(abi.encode(VOTE_TYPEHASH, from, pieceId, nonces[from]++, deadline));

        bytes32 digest = _hashTypedDataV4(voteHash);

        address recoveredAddress = ecrecover(digest, v, r, s);

        // Ensure to address is not 0
        if (from == address(0)) revert ADDRESS_ZERO();

        // Ensure signature is valid
        if (recoveredAddress == address(0) || recoveredAddress != from) revert INVALID_SIGNATURE();

        return true;
    }

    /**
     * @notice Fetch an art piece by its ID.
     * @param pieceId The ID of the art piece.
     * @return The ArtPiece struct associated with the given ID.
     */
    function getPieceById(uint256 pieceId) public view returns (ArtPiece memory) {
        require(pieceId < _currentPieceId, "Invalid piece ID");
        return pieces[pieceId];
    }

    /**
     * @notice Fetch the list of votes for a given art piece.
     * @param pieceId The ID of the art piece.
     * @return An array of Vote structs for the given art piece ID.
     */
    function getVote(uint256 pieceId, address voter) public view returns (Vote memory) {
        require(pieceId < _currentPieceId, "Invalid piece ID");
        return votes[pieceId][voter];
    }

    /**
     * @notice Fetch the top-voted art piece.
     * @return The ArtPiece struct of the top-voted art piece.
     */
    function getTopVotedPiece() public view returns (ArtPiece memory) {
        return pieces[topVotedPieceId()];
    }

    /**
     * @notice Fetch the number of pieces
     * @return The number of pieces
     */
    function pieceCount() external view returns (uint256) {
        return _currentPieceId;
    }

    /**
     * @notice Fetch the top-voted pieceId
     * @return The top-voted pieceId
     */
    function topVotedPieceId() public view returns (uint256) {
        require(maxHeap.size() > 0, "Culture index is empty");
        //slither-disable-next-line unused-return
        (uint256 pieceId, ) = maxHeap.getMax();
        return pieceId;
    }

    /**
     * @notice Admin function for setting the quorum votes basis points
     * @dev newQuorumVotesBPS must be greater than the hardcoded min
     * @param newQuorumVotesBPS new art piece drop threshold
     */
    function _setQuorumVotesBPS(uint256 newQuorumVotesBPS) external onlyOwner {
        require(
            newQuorumVotesBPS >= MIN_QUORUM_VOTES_BPS && newQuorumVotesBPS <= MAX_QUORUM_VOTES_BPS,
            "CultureIndex::_setQuorumVotesBPS: invalid quorum bps"
        );
        emit QuorumVotesBPSSet(quorumVotesBPS, newQuorumVotesBPS);

        quorumVotesBPS = newQuorumVotesBPS;
    }

    /**
     * @notice Current quorum votes using ERC721 Total Supply, ERC721 Vote Weight, and ERC20 Total Supply
     * Differs from `GovernerBravo` which uses fixed amount
     */
    function quorumVotes() public view returns (uint256) {
        return
            (quorumVotesBPS *
                _calculateVoteWeight(erc20VotingToken.totalSupply(), erc721VotingToken.totalSupply())) /
            10_000;
    }

    /**
     * @notice Pulls and drops the top-voted piece.
     * @return The top voted piece
     */
    function dropTopVotedPiece() public nonReentrant onlyOwner returns (ArtPiece memory) {
        ICultureIndex.ArtPiece memory piece = getTopVotedPiece();
        require(
            totalVoteWeights[piece.pieceId] >= piece.quorumVotes,
            "Does not meet quorum votes to be dropped."
        );

        //set the piece as dropped
        pieces[piece.pieceId].isDropped = true;

        //slither-disable-next-line unused-return
        maxHeap.extractMax();

        emit PieceDropped(piece.pieceId, msg.sender);

        return pieces[piece.pieceId];
    }
}
