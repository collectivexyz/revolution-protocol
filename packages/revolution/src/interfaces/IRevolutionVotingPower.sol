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
     * @param pointsVoteWeight The vote weight of the ERC20 token
     * @param revolutionToken The address of the ERC721 token used for voting
     * @param tokenVoteWeight The vote weight of the ERC721 token
     */
    function initialize(
        address initialOwner,
        address revolutionPoints,
        uint256 pointsVoteWeight,
        address revolutionToken,
        uint256 tokenVoteWeight
    ) external;

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  POINTS
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    function points() external returns (IRevolutionPoints);

    function getPointsMinter() external view returns (address);

    function getPointsVotes(address account) external view returns (uint256);

    function getPastPointsVotes(address account, uint256 blockNumber) external view returns (uint256);

    function getPointsSupply() external view returns (uint256);

    function getPastPointsSupply(uint256 blockNumber) external view returns (uint256);

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  TOKEN
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    function token() external returns (IRevolutionToken);

    function getTokenMinter() external view returns (address);

    function getTokenVotes(address account) external view returns (uint256);

    function getPastTokenVotes(address account, uint256 blockNumber) external view returns (uint256);

    function getTokenSupply() external view returns (uint256);

    function getPastTokenSupply(uint256 blockNumber) external view returns (uint256);

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  VOTES
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    function getVotes(address account) external view returns (uint256);

    function getVotesWithWeights(
        address account,
        uint256 erc20PointsVoteWeight,
        uint256 erc721TokenVoteWeight
    ) external view returns (uint256);

    function getTotalVotesSupply() external view returns (uint256);

    function getTotalVotesSupplyWithWeights(
        uint256 erc20PointsVoteWeight,
        uint256 erc721TokenVoteWeight
    ) external view returns (uint256);

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  PAST VOTES
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);

    function getPastVotesWithWeights(
        address account,
        uint256 blockNumber,
        uint256 erc20PointsVoteWeight,
        uint256 erc721TokenVoteWeight
    ) external view returns (uint256);

    function getPastTotalVotesSupply(uint256 blockNumber) external view returns (uint256);

    function getPastTotalVotesSupplyWithWeights(
        uint256 blockNumber,
        uint256 erc20PointsVoteWeight,
        uint256 erc721TokenVoteWeight
    ) external view returns (uint256);

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  CALCULATE VOTES
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    struct BalanceAndWeight {
        uint256 balance;
        uint256 voteWeight;
    }

    function calculateVotesWithWeights(
        BalanceAndWeight calldata points,
        BalanceAndWeight calldata token
    ) external pure returns (uint256);

    function calculateVotes(uint256 pointsBalance, uint256 tokenBalance) external view returns (uint256);
}
