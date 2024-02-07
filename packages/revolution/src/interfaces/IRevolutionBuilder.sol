// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { RevolutionDAOStorageV1 } from "../governance/RevolutionDAOInterfaces.sol";
import { IUUPS } from "./IUUPS.sol";
import { RevolutionBuilderTypesV1 } from "../builder/types/RevolutionBuilderTypesV1.sol";
import { ICultureIndex } from "./ICultureIndex.sol";

/// @title IRevolutionBuilder
/// @notice The external RevolutionBuilder events, errors, structs and functions
interface IRevolutionBuilder is IUUPS {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when a DAO is deployed
    /// @param revolutionToken The ERC-721 token address
    /// @param descriptor The descriptor renderer address
    /// @param auction The auction address
    /// @param executor The executor address
    /// @param dao The dao address
    /// @param cultureIndex The cultureIndex address
    /// @param revolutionPointsEmitter The RevolutionPointsEmitter address
    /// @param revolutionPoints The dao address
    /// @param maxHeap The maxHeap address
    /// @param revolutionVotingPower The revolutionVotingPower address
    /// @param vrgda The VRGDA address
    event RevolutionDeployed(
        address revolutionToken,
        address descriptor,
        address auction,
        address executor,
        address dao,
        address cultureIndex,
        address revolutionPointsEmitter,
        address revolutionPoints,
        address maxHeap,
        address revolutionVotingPower,
        address vrgda
    );

    /// @notice Emitted when an upgrade is registered by the Builder DAO
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    event UpgradeRegistered(address baseImpl, address upgradeImpl);

    /// @notice Emitted when an upgrade is unregistered by the Builder DAO
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    event UpgradeRemoved(address baseImpl, address upgradeImpl);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @notice The error message when invalid address zero is passed
    error INVALID_ZERO_ADDRESS();

    ///                                                          ///
    ///                            STRUCTS                       ///
    ///                                                          ///

    /// @notice DAO Version Information information struct
    struct DAOVersionInfo {
        string revolutionToken;
        string descriptor;
        string auction;
        string executor;
        string dao;
        string cultureIndex;
        string revolutionPoints;
        string revolutionPointsEmitter;
        string maxHeap;
        string revolutionVotingPower;
        string vrgda;
    }

    /// @notice The ERC-721 token parameters
    /// @param name The token name
    /// @param symbol The token symbol
    /// @param contractURIHash The IPFS content hash of the contract-level metadata
    /// @param tokenNamePrefix The token name prefix
    struct RevolutionTokenParams {
        string name;
        string symbol;
        string contractURIHash;
        string tokenNamePrefix;
    }

    /// @notice The auction parameters
    /// @param timeBuffer The time buffer of each auction
    /// @param reservePrice The reserve price of each auction
    /// @param duration The duration of each auction
    /// @param minBidIncrementPercentage The minimum bid increment percentage of each auction
    /// @param creatorRateBps The creator rate basis points of each auction - the share of the winning bid that is reserved for the creator
    /// @param entropyRateBps The entropy rate basis points of each auction - the portion of the creator's share that is directly sent to the creator in ETH
    /// @param minCreatorRateBps The minimum creator rate basis points of each auction
    struct AuctionParams {
        uint256 timeBuffer;
        uint256 reservePrice;
        uint256 duration;
        uint8 minBidIncrementPercentage;
        uint256 creatorRateBps;
        uint256 entropyRateBps;
        uint256 minCreatorRateBps;
    }

    /// @notice The governance parameters
    /// @param timelockDelay The time delay to execute a queued transaction
    /// @param votingDelay The time delay to vote on a created proposal
    /// @param votingPeriod The time period to vote on a proposal
    /// @param proposalThresholdBPS The basis points of the token supply required to create a proposal
    /// @param vetoer The address authorized to veto proposals (address(0) if none desired)
    /// @param name The name of the DAO
    /// @param purpose The purpose of the DAO
    /// @param flag The symbol of the DAO ⌐◨-◨
    /// @param dynamicQuorumParams The dynamic quorum parameters
    struct GovParams {
        uint256 timelockDelay;
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 proposalThresholdBPS;
        address vetoer;
        string name;
        string purpose;
        string flag;
        RevolutionDAOStorageV1.DynamicQuorumParams dynamicQuorumParams;
    }

    /// @notice The RevolutionPoints ERC-20 params
    /// @param tokenParams // The token parameters
    /// @param emitterParams // The emitter parameters
    struct RevolutionPointsParams {
        PointsTokenParams tokenParams;
        PointsEmitterParams emitterParams;
    }

    /// @notice The RevolutionPoints ERC-20 token parameters
    /// @param name The token name
    /// @param symbol The token symbol
    struct PointsTokenParams {
        string name;
        string symbol;
    }

    /// @notice The RevolutionPoints ERC-20 emitter VRGDA parameters
    /// @param vrgdaParams // The VRGDA parameters
    /// @param founderParams // The params to dictate payments to the founder
    /// @param grantsParams // The params to dictate payments to the grants program
    struct PointsEmitterParams {
        VRGDAParams vrgdaParams;
        FounderParams founderParams;
        GrantsParams grantsParams;
    }

    /// @notice The ERC-20 points emitter VRGDA parameters
    /// @param targetPrice // The target price for a token if sold on pace, scaled by 1e18.
    /// @param priceDecayPercent // The percent the price decays per unit of time with no sales, scaled by 1e18.
    /// @param tokensPerTimeUnit // The number of tokens to target selling in 1 full unit of time, scaled by 1e18.
    struct VRGDAParams {
        int256 targetPrice;
        int256 priceDecayPercent;
        int256 tokensPerTimeUnit;
    }

    /// @notice The ERC-20 points emitter creator parameters
    /// @param totalRateBps The founder rate in basis points - how much of each purchase to the points emitter is reserved for the founders
    /// @param entropyRateBps The entropy of the founder rate in basis points - how much ether out of the total rate is sent to founders directly
    /// @param founderAddress the address to send founder rewards to
    /// @param rewardsExpirationDate The timestamp in seconds from the initialization block after which the founders reward stops
    struct FounderParams {
        uint256 totalRateBps;
        uint256 entropyRateBps;
        address founderAddress;
        uint256 rewardsExpirationDate;
    }

    /// @notice Grants program params that detail payments to the grants program
    /// @param totalRateBps The grants rate in basis points - how much of each purchase to the points emitter is reserved for the grants program
    /// @param founderAddress the grants program address to send ether to
    struct GrantsParams {
        uint256 totalRateBps;
        address grantsAddress;
    }

    /// @notice The CultureIndex parameters
    /// @param name The name of the culture index
    /// @param description A description for the culture index
    /// @param checklist A checklist for the culture index, can include rules for uploads etc.
    /// @param template A template for the culture index, an ipfs file that artists can download and use to create art pieces
    /// @param tokenVoteWeight The voting weight of the individual Revolution ERC721 tokens. Normally a large multiple to match up with daily emission of ERC20 points to match up with daily emission of ERC20 points (which normally have 18 decimals)
    /// @param pointsVoteWeight The voting weight of the individual Revolution ERC20 points tokens.
    /// @param quorumVotesBPS The initial quorum votes threshold in basis points
    /// @param minVotingPowerToVote The minimum vote weight that a voter must have to be able to vote.
    /// @param minVotingPowerToCreate The minimum vote weight that a voter must have to be able to create an art piece.
    /// @param pieceMaximums The maxium length for each field in an art piece
    /// @param requiredMediaType The required media type for each art piece eg: image only
    /// @param requiredMediaPrefix The required media prefix for each art piece eg: ipfs://
    struct CultureIndexParams {
        string name;
        string description;
        string checklist;
        string template;
        uint256 tokenVoteWeight;
        uint256 pointsVoteWeight;
        uint256 quorumVotesBPS;
        uint256 minVotingPowerToVote;
        uint256 minVotingPowerToCreate;
        ICultureIndex.PieceMaximums pieceMaximums;
        ICultureIndex.MediaType requiredMediaType;
        ICultureIndex.RequiredMediaPrefix requiredMediaPrefix;
    }

    /// @notice The RevolutionVotingPower parameters
    /// @param tokenVoteWeight The voting weight of the individual Revolution ERC721 tokens. Normally a large multiple to match up with daily emission of ERC20 points to match up with daily emission of ERC20 points (which normally have 18 decimals)
    /// @param pointsVoteWeight The voting weight of the individual Revolution ERC20 points tokens. (usually 1 because of 18 decimals on the ERC20 contract)
    struct RevolutionVotingPowerParams {
        uint256 tokenVoteWeight;
        uint256 pointsVoteWeight;
    }

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    /// @notice The token implementation address
    function revolutionTokenImpl() external view returns (address);

    /// @notice The descriptor renderer implementation address
    function descriptorImpl() external view returns (address);

    /// @notice The auction house implementation address
    function auctionImpl() external view returns (address);

    /// @notice The executor implementation address
    function executorImpl() external view returns (address);

    /// @notice The dao implementation address
    function daoImpl() external view returns (address);

    /// @notice The revolutionPointsEmitter implementation address
    function revolutionPointsEmitterImpl() external view returns (address);

    /// @notice The cultureIndex implementation address
    function cultureIndexImpl() external view returns (address);

    /// @notice The revolutionPoints implementation address
    function revolutionPointsImpl() external view returns (address);

    /// @notice The maxHeap implementation address
    function maxHeapImpl() external view returns (address);

    /// @notice The revolutionVotingPower implementation address
    function revolutionVotingPowerImpl() external view returns (address);

    /// @notice Deploys a DAO with custom token, auction, and governance settings
    /// @param initialOwner The initial owner address
    /// @param weth The WETH address
    /// @param revolutionTokenParams The Revolution ERC-721 token settings
    /// @param auctionParams The auction settings
    /// @param govParams The governance settings
    /// @param cultureIndexParams The CultureIndex settings
    /// @param revolutionPointsParams The RevolutionPoints settings
    /// @param revolutionVotingPowerParams The RevolutionVotingPower settings
    function deploy(
        address initialOwner,
        address weth,
        RevolutionTokenParams calldata revolutionTokenParams,
        AuctionParams calldata auctionParams,
        GovParams calldata govParams,
        CultureIndexParams calldata cultureIndexParams,
        RevolutionPointsParams calldata revolutionPointsParams,
        RevolutionVotingPowerParams calldata revolutionVotingPowerParams
    ) external returns (RevolutionBuilderTypesV1.DAOAddresses memory);

    /// @notice A DAO's remaining contract addresses from its token address
    /// @param token The ERC-721 token address
    function getAddresses(
        address token
    )
        external
        returns (
            address revolutionToken,
            address descriptor,
            address auction,
            address executor,
            address dao,
            address cultureIndex,
            address revolutionPoints,
            address revolutionPointsEmitter,
            address maxHeap,
            address revolutionVotingPower,
            address vrgda
        );

    /// @notice If an implementation is registered by the Builder DAO as an optional upgrade
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    function isRegisteredUpgrade(address baseImpl, address upgradeImpl) external view returns (bool);

    /// @notice Called by the Builder DAO to offer opt-in implementation upgrades for all other DAOs
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    function registerUpgrade(address baseImpl, address upgradeImpl) external;

    /// @notice Called by the Builder DAO to remove an upgrade
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    function removeUpgrade(address baseImpl, address upgradeImpl) external;

    function getDAOVersions(address token) external view returns (DAOVersionInfo memory);

    function getLatestVersions() external view returns (DAOVersionInfo memory);

    /// @notice Initializes the Revolution builder contract
    /// @param initialOwner The address of the initial owner
    function initialize(address initialOwner) external;
}
