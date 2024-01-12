// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IRevolutionToken } from "./IRevolutionToken.sol";
import { IRevolutionBuilder } from "./IRevolutionBuilder.sol";
import { IRevolutionPoints } from "./IRevolutionPoints.sol";

/**
 * @title IRevolutionVotingPowerEvents
 * @dev This interface defines the events for the RevolutionVotingPower contract.
 */
interface IRevolutionVotingPowerEvents {
    event ERC721VotingTokenUpdated(address erc721VotingToken);

    event ERC721VotingPowerUpdated(uint256 oldERC721VotingPower, uint256 newERC721VotingPower);

    event ERC20VotingTokenUpdated(address erc20VotingToken);

    event ERC20VotingPowerUpdated(uint256 oldERC20VotingPower, uint256 newERC20VotingPower);
}

/**
 * @title IRevolutionVotingPower
 * @dev This interface defines the methods for the RevolutionVotingPower contract for art piece management and voting.
 */
interface IRevolutionVotingPower is IRevolutionVotingPowerEvents {
    /**
     * @notice Initializes the RevolutionVotingPower contract
     * @param initialOwner The initial owner of the contract
     * @param revolutionPoints The address of the ERC20 token used for voting
     * @param revolutionPointsVoteWeight The vote weight of the ERC20 token
     * @param revolutionToken The address of the ERC721 token used for voting
     * @param revolutionTokenVoteWeight The vote weight of the ERC721 token
     */
    function initialize(
        address initialOwner,
        address revolutionPoints,
        uint256 revolutionPointsVoteWeight,
        address revolutionToken,
        uint256 revolutionTokenVoteWeight
    ) external;

    function points() external returns (IRevolutionPoints);

    function token() external returns (IRevolutionToken);

    /// @notice useful in the CultureIndex to subtract weight of the AuctionHouse from quorum
    function _getTokenMinter__TokenVotes() external view returns (uint256);
    function _getTokenMinter__PastTokenVotes(uint256 blockNumber) external view returns (uint256);
    function _getTokenMinter__TokenVotes__WithWeight(uint256 erc721TokenVoteWeight) external view returns (uint256);
    function _getTokenMinter__PastTokenVotes__WithWeight(
        uint256 blockNumber,
        uint256 erc721TokenVoteWeight
    ) external view returns (uint256);

    function getVotes(address account) external view returns (uint256);

    function getVotesWithWeights(
        address account,
        uint256 erc20PointsVoteWeight,
        uint256 erc721TokenVoteWeight
    ) external view returns (uint256);

    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);

    function getPastVotesWithWeights(
        address account,
        uint256 blockNumber,
        uint256 erc20PointsVoteWeight,
        uint256 erc721TokenVoteWeight
    ) external view returns (uint256);

    function getTotalVotesSupply() external view returns (uint256);

    function getTotalVotesSupplyWithWeights(
        uint256 erc20PointsVoteWeight,
        uint256 erc721TokenVoteWeight
    ) external view returns (uint256);

    function getPastTotalVotesSupply(uint256 blockNumber) external view returns (uint256);

    function getPastTotalVotesSupplyWithWeights(
        uint256 blockNumber,
        uint256 erc20PointsVoteWeight,
        uint256 erc721TokenVoteWeight
    ) external view returns (uint256);
}
