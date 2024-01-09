// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC721CheckpointableUpgradeable } from "../base/ERC721CheckpointableUpgradeable.sol";
import { IRevolutionBuilder } from "./IRevolutionBuilder.sol";
import { ERC20VotesUpgradeable } from "../base/erc20/ERC20VotesUpgradeable.sol";

/**
 * @title IRevolutionVotingPowerEvents
 * @dev This interface defines the events for the RevolutionVotingPower contract.
 */
interface IRevolutionVotingPowerEvents {
    event ERC721VotingTokenUpdated(ERC721CheckpointableUpgradeable ERC721VotingToken);

    event ERC721VotingPowerUpdated(uint256 oldERC721VotingPower, uint256 newERC721VotingPower);

    event ERC20VotingTokenUpdated(ERC20VotesUpgradeable ERC20VotingToken);

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
}
