// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.22;

import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { UUPS } from "../libs/proxy/UUPS.sol";
import { VersionedContract } from "../version/VersionedContract.sol";

import { IRevolutionBuilder } from "../interfaces/IRevolutionBuilder.sol";
import { IRevolutionVotingPower } from "../interfaces/IRevolutionVotingPower.sol";

import { ERC20VotesUpgradeable } from "../base/erc20/ERC20VotesUpgradeable.sol";
import { MaxHeap } from "./MaxHeap.sol";
import { ICultureIndex } from "../interfaces/ICultureIndex.sol";
import { CultureIndexStorageV1 } from "./storage/CultureIndexStorageV1.sol";

import { ERC721CheckpointableUpgradeable } from "../base/ERC721CheckpointableUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract CultureIndex is
    ICultureIndex,
    VersionedContract,
    UUPS,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable,
    CultureIndexStorageV1
{
    using Strings for uint256;

    ///                                                          ///
    ///                         IMMUTABLES                       ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IRevolutionBuilder private immutable manager;

    /// @notice The EIP-712 typehash for gasless votes
    bytes32 public constant VOTE_TYPEHASH =
        keccak256("Vote(address from,uint256[] pieceIds,uint256 nonce,uint256 deadline)");

    // Constant for max number of creators
    uint256 public constant MAX_NUM_CREATORS = 21;

    /// @notice The maximum settable quorum votes basis points
    uint256 public constant MAX_QUORUM_VOTES_BPS = 6_000; // 6,000 basis points or 60%

    ///                                                          ///
    ///                         CONSTRUCTOR                      ///
    ///                                                          ///

    /// @param _manager The contract upgrade manager address
    constructor(address _manager) payable initializer {
        if (_manager == address(0)) revert ADDRESS_ZERO();
        manager = IRevolutionBuilder(_manager);
    }

    ///                                                          ///
    ///                         INITIALIZER                      ///
    ///                                                          ///

    /**
     * @notice Initializes a token's metadata descriptor
     * @param _votingPower The address of the RevolutionVotingPower contract
     * @param _initialOwner The owner of the contract, allowed to drop pieces. Commonly updated to the AuctionHouse
     * @param _maxHeap The address of the max heap contract
     * @param _dropperAdmin The address that can drop new art pieces
     * @param _cultureIndexParams The CultureIndex settings
     */
    function initialize(
        address _votingPower,
        address _initialOwner,
        address _maxHeap,
        address _dropperAdmin,
        IRevolutionBuilder.CultureIndexParams calldata _cultureIndexParams
    ) external initializer {
        if (msg.sender != address(manager)) revert NOT_MANAGER();

        if (_cultureIndexParams.quorumVotesBPS > MAX_QUORUM_VOTES_BPS) revert INVALID_QUORUM_BPS();
        if (_cultureIndexParams.tokenVoteWeight <= 0) revert INVALID_ERC721_VOTING_WEIGHT();
        if (_cultureIndexParams.pointsVoteWeight <= 0) revert INVALID_ERC20_VOTING_WEIGHT();
        if (_votingPower == address(0)) revert ADDRESS_ZERO();
        if (_initialOwner == address(0)) revert ADDRESS_ZERO();

        // Setup ownable
        __Ownable_init(_initialOwner);

        // Initialize EIP-712 support
        __EIP712_init(string.concat(_cultureIndexParams.name, " CultureIndex"), "1");

        __ReentrancyGuard_init();

        votingPower = IRevolutionVotingPower(_votingPower);
        tokenVoteWeight = _cultureIndexParams.tokenVoteWeight;
        pointsVoteWeight = _cultureIndexParams.pointsVoteWeight;

        name = _cultureIndexParams.name;
        description = _cultureIndexParams.description;
        quorumVotesBPS = _cultureIndexParams.quorumVotesBPS;
        minVotingPowerToVote = _cultureIndexParams.minVotingPowerToVote;
        minVotingPowerToCreate = _cultureIndexParams.minVotingPowerToCreate;
        dropperAdmin = _dropperAdmin;

        PIECE_DATA_MAXIMUMS = PieceMaximums({
            name: _cultureIndexParams.pieceMaximums.name,
            description: _cultureIndexParams.pieceMaximums.description,
            image: _cultureIndexParams.pieceMaximums.image,
            animationUrl: _cultureIndexParams.pieceMaximums.animationUrl,
            text: _cultureIndexParams.pieceMaximums.text
        });

        requiredMediaType = _cultureIndexParams.requiredMediaType;
        requiredMediaPrefix = _cultureIndexParams.requiredMediaPrefix;

        emit QuorumVotesBPSSet(quorumVotesBPS, _cultureIndexParams.quorumVotesBPS);

        // Create maxHeap
        maxHeap = MaxHeap(_maxHeap);
    }

    ///                                                          ///
    ///                         FUNCTIONS                        ///
    ///                                                          ///

    /**
     *  Returns the substring of a string.
     * @param str The string to substring.
     * @param startIndex The starting index of the substring.
     * @param endIndex The ending index of the substring.
     *
     * Requirements:
     * - The `startIndex` must be less than the `endIndex`.
     * - The `endIndex` must be less than the length of the string.
     */
    function _substring(string memory str, uint256 startIndex, uint256 endIndex) internal pure returns (string memory) {
        //verify lengths are valid
        if (startIndex >= endIndex) revert INVALID_SUBSTRING();
        if (endIndex > bytes(str).length) revert INVALID_SUBSTRING();

        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    /**
     *  Validates the media type and associated data.
     * @param metadata The metadata associated with the art piece.
     *
     * Requirements:
     * - The media type must be one of the defined types in the MediaType enum.
     * - The corresponding media data must not be empty.
     */
    function validateMediaType(ArtPieceMetadata calldata metadata) internal view {
        if (
            //invalid media type
            uint8(metadata.mediaType) > 3 ||
            // or specific required media type is not adhered to
            (requiredMediaType != MediaType.NONE && metadata.mediaType != requiredMediaType)
        ) revert INVALID_MEDIA_TYPE();

        uint256 imageLength = bytes(metadata.image).length;
        uint256 animationUrlLength = bytes(metadata.animationUrl).length;
        uint256 textLength = bytes(metadata.text).length;
        uint256 nameLength = bytes(metadata.name).length;

        if (metadata.mediaType == MediaType.IMAGE) {
            if (imageLength == 0) revert INVALID_IMAGE();
        } else if (metadata.mediaType == MediaType.ANIMATION || metadata.mediaType == MediaType.AUDIO) {
            if (animationUrlLength == 0) revert INVALID_ANIMATION_URL();
        } else if (metadata.mediaType == MediaType.TEXT) {
            if (textLength == 0) revert INVALID_TEXT();
        }

        // ensure all fields of metadata are within reasonable bounds
        if (bytes(metadata.description).length > PIECE_DATA_MAXIMUMS.description) revert INVALID_DESCRIPTION();

        if (imageLength > PIECE_DATA_MAXIMUMS.image) revert INVALID_IMAGE();

        if (animationUrlLength > PIECE_DATA_MAXIMUMS.animationUrl) revert INVALID_ANIMATION_URL();

        if (textLength > PIECE_DATA_MAXIMUMS.text) revert INVALID_TEXT();

        //ensure name is not too large
        if (nameLength > PIECE_DATA_MAXIMUMS.name) revert INVALID_NAME();

        string memory ipfsPrefix = "ipfs://";

        // ensure animation url starts with ipfs://
        if (animationUrlLength > 0 && !Strings.equal(_substring(metadata.animationUrl, 0, 7), (ipfsPrefix)))
            revert INVALID_ANIMATION_URL();

        // ensure image url starts with ipfs:// or data:image/svg+xml;base64,
        if (imageLength > 0) {
            string memory svgPrefix = "data:image/svg+xml;base64,";

            bool startsWithSvg = imageLength > 25 && Strings.equal(_substring(metadata.image, 0, 26), (svgPrefix));
            bool startsWithIpfs = imageLength > 6 && Strings.equal(_substring(metadata.image, 0, 7), (ipfsPrefix));

            if (requiredMediaPrefix == RequiredMediaPrefix.IPFS && !startsWithIpfs) {
                revert INVALID_IMAGE();
            } else if (requiredMediaPrefix == RequiredMediaPrefix.SVG && !startsWithSvg) {
                revert INVALID_IMAGE();
            } else if (!startsWithIpfs && !startsWithSvg) {
                // if no required prefix, ensure it starts with ipfs:// or data:image/svg+xml;base64,
                revert INVALID_IMAGE();
            }
        }
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
        if (creatorArrayLength > MAX_NUM_CREATORS) revert MAX_NUM_CREATORS_EXCEEDED();

        uint256 totalBps;
        for (uint i; i < creatorArrayLength; i++) {
            if (creatorArray[i].creator == address(0)) revert ADDRESS_ZERO();
            totalBps += creatorArray[i].bps;
        }

        if (totalBps != 10_000) revert INVALID_BPS_SUM();

        return creatorArrayLength;
    }

    /**
     * @notice Creates a new piece of art with associated metadata and creators.
     * @param metadata The metadata associated with the art piece, including name, description, image, and optional animation URL.
     * @param creatorArray An array of creators who contributed to the piece, along with their respective basis points that must sum up to 10,000.
     * @return Returns the unique ID of the newly created art piece.
     *
     * Emits a {PieceCreated} event for the newly created piece.
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
        if (votingPower.getVotes(msg.sender) < minVotingPowerToCreate) revert WEIGHT_TOO_LOW();

        uint256 creatorArrayLength = validateCreatorsArray(creatorArray);

        // Validate the media type and associated data
        validateMediaType(metadata);

        uint256 pieceId = _currentPieceId++;

        /// @dev Insert the new piece into the max heap with 0 vote weight
        maxHeap.insert(pieceId, 0);

        // Save art piece to storage mapping
        ArtPiece storage newPiece = pieces[pieceId];

        newPiece.pieceId = pieceId;
        newPiece.metadata = metadata;
        newPiece.sponsor = msg.sender;
        newPiece.creationBlock = block.number;

        for (uint i; i < creatorArrayLength; i++) {
            newPiece.creators.push(creatorArray[i]);
        }

        emit PieceCreated(pieceId, msg.sender, metadata, creatorArray);

        return pieceId;
    }

    /**
     * @notice Checks if a specific voter has already voted for a given art piece.
     * @param pieceId The ID of the art piece.
     * @param voter The address of the voter.
     * @return A boolean indicating if the voter has voted for the art piece.
     */
    function hasVoted(uint256 pieceId, address voter) external view returns (bool) {
        if (pieceId >= _currentPieceId) revert INVALID_PIECE_ID();
        return votes[pieceId][voter].voterAddress != address(0);
    }

    /**
     * @notice Get account voting power for a specific piece
     * @param pieceId The ID of the art piece.
     * @param account The address of the voter.
     */
    function getAccountVotingPowerForPiece(uint256 pieceId, address account) public view returns (uint256) {
        if (pieceId >= _currentPieceId) revert INVALID_PIECE_ID();
        return
            votingPower.calculateVotesWithWeights(
                IRevolutionVotingPower.BalanceAndWeight({
                    balance: votingPower.getPastPointsVotes(account, block.number - 1),
                    voteWeight: pointsVoteWeight
                }),
                IRevolutionVotingPower.BalanceAndWeight({
                    balance: votingPower.getPastTokenVotes(account, pieces[pieceId].creationBlock - 1),
                    voteWeight: tokenVoteWeight
                })
            );
    }

    /**
     * @notice Cast a vote for a specific ArtPiece.
     * @param pieceId The ID of the ArtPiece to vote for.
     * @param voter The address of the voter.
     * @dev Requires that the pieceId is valid, the voter has not already voted on this piece, and the weight is greater than the minimum vote weight.
     * Emits a VoteCast event upon successful execution.
     */
    function _vote(uint256 pieceId, address voter) internal {
        if (pieceId >= _currentPieceId) revert INVALID_PIECE_ID();
        if (voter == address(0)) revert ADDRESS_ZERO();
        if (pieces[pieceId].isDropped) revert ALREADY_DROPPED();
        if (votes[pieceId][voter].voterAddress != address(0)) revert ALREADY_VOTED();

        uint256 weight = getAccountVotingPowerForPiece(pieceId, voter);
        if (weight <= minVotingPowerToVote) revert WEIGHT_TOO_LOW();

        votes[pieceId][voter] = Vote(voter, weight);
        totalVoteWeights[pieceId] += weight;

        uint256 totalWeight = totalVoteWeights[pieceId];

        maxHeap.updateValue(pieceId, totalWeight);
        emit VoteCast(pieceId, voter, weight, totalWeight);
    }

    /**
     * @notice Cast a vote for a specific ArtPiece.
     * @param pieceId The ID of the ArtPiece to vote for.
     * @dev Requires that the pieceId is valid, the voter has not already voted on this piece, and the weight is greater than the minimum vote weight.
     * Emits a VoteCast event upon successful execution.
     */
    function vote(uint256 pieceId) public nonReentrant {
        _vote(pieceId, msg.sender);
    }

    /**
     * @notice Cast a vote for a list of ArtPieces.
     * @param pieceIds The IDs of the ArtPieces to vote for.
     * @dev Requires that the pieceIds are valid, the voter has not already voted on this piece, and the weight is greater than the minimum vote weight.
     * Emits a series of VoteCast event upon successful execution.
     */
    function voteForMany(uint256[] calldata pieceIds) public nonReentrant {
        _voteForMany(pieceIds, msg.sender);
    }

    /**
     * @notice Cast a vote for a list of ArtPieces pieceIds.
     * @param pieceIds The IDs of the ArtPieces to vote for.
     * @param from The address of the voter.
     * @dev Requires that the pieceIds are valid, the voter has not already voted on this piece, and the weight is greater than the minimum vote weight.
     * Emits a series of VoteCast event upon successful execution.
     */
    function _voteForMany(uint256[] calldata pieceIds, address from) internal {
        uint256 len = pieceIds.length;
        for (uint256 i; i < len; i++) {
            _vote(pieceIds[i], from);
        }
    }

    /// @notice Execute a vote via signature
    /// @param from Vote from this address
    /// @param pieceIds Vote on this list of pieceIds
    /// @param deadline Deadline for the signature to be valid
    /// @param v V component of signature
    /// @param r R component of signature
    /// @param s S component of signature
    function voteForManyWithSig(
        address from,
        uint256[] calldata pieceIds,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        bool success = _verifyVoteSignature(from, pieceIds, deadline, v, r, s);

        if (!success) revert INVALID_SIGNATURE();

        _voteForMany(pieceIds, from);
    }

    /// @notice Execute a batch of votes via signature, each with their own signature
    /// @param from Vote from these addresses
    /// @param pieceIds Vote on these lists of pieceIds
    /// @param deadline Deadlines for the signature to be valid
    /// @param v V component of signatures
    /// @param r R component of signatures
    /// @param s S component of signatures
    function batchVoteForManyWithSig(
        address[] calldata from,
        uint256[][] calldata pieceIds,
        uint256[] calldata deadline,
        uint8[] calldata v,
        bytes32[] calldata r,
        bytes32[] memory s
    ) external nonReentrant {
        uint256 len = from.length;
        if (len != pieceIds.length || len != deadline.length || len != v.length || len != r.length || len != s.length)
            revert ARRAY_LENGTH_MISMATCH();

        for (uint256 i; i < len; i++) {
            if (!_verifyVoteSignature(from[i], pieceIds[i], deadline[i], v[i], r[i], s[i])) revert INVALID_SIGNATURE();
        }

        for (uint256 i; i < len; i++) {
            _voteForMany(pieceIds[i], from[i]);
        }
    }

    /// @notice Utility function to verify a signature for a specific vote
    /// @param from Vote from this address
    /// @param pieceIds Vote on this pieceId
    /// @param deadline Deadline for the signature to be valid
    /// @param v V component of signature
    /// @param r R component of signature
    /// @param s S component of signature
    function _verifyVoteSignature(
        address from,
        uint256[] calldata pieceIds,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal returns (bool success) {
        if (deadline < block.timestamp) revert SIGNATURE_EXPIRED();

        bytes32 voteHash;

        // Derive and return the vote hash as specified by EIP-712.

        voteHash = keccak256(
            abi.encode(VOTE_TYPEHASH, from, keccak256(abi.encodePacked(pieceIds)), nonces[from]++, deadline)
        );

        bytes32 digest = _hashTypedDataV4(voteHash);

        address recoveredAddress = ecrecover(digest, v, r, s);

        // Ensure from address is not 0
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
        if (pieceId >= _currentPieceId) revert INVALID_PIECE_ID();
        return pieces[pieceId];
    }

    /**
     * @notice Fetch the list of votes for a given art piece.
     * @param pieceId The ID of the art piece.
     * @return An array of Vote structs for the given art piece ID.
     */
    function getVote(uint256 pieceId, address voter) public view returns (Vote memory) {
        if (pieceId >= _currentPieceId) revert INVALID_PIECE_ID();
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
        if (maxHeap.size() == 0) revert CULTURE_INDEX_EMPTY();
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
        if (newQuorumVotesBPS > MAX_QUORUM_VOTES_BPS) revert INVALID_QUORUM_BPS();
        emit QuorumVotesBPSSet(quorumVotesBPS, newQuorumVotesBPS);

        quorumVotesBPS = newQuorumVotesBPS;
    }

    /**
     * @notice Admin function for setting the min voting power required to vote
     * @param newMinVotingPowerToVote new min voting power required to vote
     */
    function _setMinVotingPowerToVote(uint256 newMinVotingPowerToVote) external onlyOwner {
        emit MinVotingPowerToVoteSet(minVotingPowerToVote, newMinVotingPowerToVote);

        minVotingPowerToVote = newMinVotingPowerToVote;
    }

    /**
     * @notice Admin function for setting the min voting power required to create
     * @param newMinVotingPowerToCreate new min voting power required to create
     */
    function _setMinVotingPowerToCreate(uint256 newMinVotingPowerToCreate) external onlyOwner {
        emit MinVotingPowerToCreateSet(minVotingPowerToCreate, newMinVotingPowerToCreate);

        minVotingPowerToCreate = newMinVotingPowerToCreate;
    }

    /**
     * @notice Current quorum votes using ERC721 Total Supply, ERC721 Vote Weight, and RevolutionPoints Total Supply
     * Differs from `GovernerBravo` which uses fixed amount
     */
    function quorumVotes() public view returns (uint256) {
        return
            (quorumVotesBPS * votingPower.getTotalVotesSupplyWithWeights(pointsVoteWeight, tokenVoteWeight)) / 10_000;
    }

    /**
     * @notice Current quorum votes for a specific piece using ERC721 Total Supply, ERC721 Vote Weight, and RevolutionPoints Total Supply
     * @param pieceId The ID of the art piece.
     */
    function quorumVotesForPiece(uint256 pieceId) public view returns (uint256) {
        uint256 creationBlock = pieces[pieceId].creationBlock;

        /// @notice Points are assumed to be nontransferable and thus we do not need snapshotting for them
        /// @notice Tokens are assumed to be transferable and thus we need snapshotting for them
        uint256 totalVotesSupply = votingPower.calculateVotesWithWeights(
            IRevolutionVotingPower.BalanceAndWeight({
                /// @notice Use previous block number to prevent auction
                /// from minting points and throwing off the quorum in the same block
                balance: votingPower.getPastPointsSupply(block.number - 1),
                voteWeight: pointsVoteWeight
            }),
            IRevolutionVotingPower.BalanceAndWeight({
                balance: votingPower.getPastTokenSupply(creationBlock),
                voteWeight: tokenVoteWeight
            })
        );

        /// @notice We want to subtract the balance of tokens held by the auction since no one can vote with those tokens
        uint256 tokenMinterVotes = votingPower.calculateVotesWithWeights(
            //ignore points for token minter
            IRevolutionVotingPower.BalanceAndWeight({ balance: 0, voteWeight: 0 }),
            IRevolutionVotingPower.BalanceAndWeight({
                balance: votingPower.getPastTokenVotes(votingPower.getTokenMinter(), creationBlock),
                voteWeight: tokenVoteWeight
            })
        );

        return
            (quorumVotesBPS *
                (totalVotesSupply -
                    // Subtract the votes for the tokens held by the minter
                    tokenMinterVotes)) / 10_000;
    }

    /**
     * @notice Returns true or false depending on whether the top voted piece meets quorum
     * @return True if the top voted piece meets quorum, false otherwise
     */
    function topVotedPieceMeetsQuorum() public view returns (bool) {
        // If the heap is empty, return false so we don't brick the AuctionHouse
        if (maxHeap.size() == 0) return false;

        uint256 pieceId = topVotedPieceId();
        return totalVoteWeights[pieceId] >= quorumVotesForPiece(pieceId);
    }

    /**
     * @notice Pulls and drops the top-voted piece.
     * @return The top voted piece
     */
    function dropTopVotedPiece() public nonReentrant returns (ArtPieceCondensed memory) {
        if (msg.sender != dropperAdmin) revert NOT_DROPPER_ADMIN();

        uint256 pieceId = topVotedPieceId();

        if (totalVoteWeights[pieceId] < quorumVotesForPiece(pieceId)) revert DOES_NOT_MEET_QUORUM();

        //set the piece as dropped
        pieces[pieceId].isDropped = true;

        //slither-disable-next-line unused-return
        maxHeap.extractMax();

        emit PieceDropped(pieceId, msg.sender);

        return
            ICultureIndex.ArtPieceCondensed({
                pieceId: pieceId,
                creators: pieces[pieceId].creators,
                sponsor: pieces[pieceId].sponsor
            });
    }

    function maxNameLength() external view returns (uint256) {
        return PIECE_DATA_MAXIMUMS.name;
    }

    function maxDescriptionLength() external view returns (uint256) {
        return PIECE_DATA_MAXIMUMS.description;
    }

    function maxImageLength() external view returns (uint256) {
        return PIECE_DATA_MAXIMUMS.image;
    }

    function maxTextLength() external view returns (uint256) {
        return PIECE_DATA_MAXIMUMS.text;
    }

    function maxAnimationUrlLength() external view returns (uint256) {
        return PIECE_DATA_MAXIMUMS.animationUrl;
    }

    ///                                                          ///
    ///                   CULTURE INDEX UPGRADE                  ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract and that the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner {
        // Ensure the new implementation is a registered upgrade
        if (!manager.isRegisteredUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
