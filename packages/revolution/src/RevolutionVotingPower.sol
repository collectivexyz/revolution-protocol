// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.22;

import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IRevolutionBuilder } from "./interfaces/IRevolutionBuilder.sol";

import { UUPS } from "./libs/proxy/UUPS.sol";
import { VersionedContract } from "./version/VersionedContract.sol";

import { ERC20VotesUpgradeable } from "./base/erc20/ERC20VotesUpgradeable.sol";
import { ERC721CheckpointableUpgradeable } from "./base/ERC721CheckpointableUpgradeable.sol";

import { IRevolutionVotingPower } from "./interfaces/IRevolutionVotingPower.sol";

/// @title RevolutionVotingPower
/// @dev This contract implements the voting power calculations for Revolution DAOs
/// @author rocketman
contract RevolutionVotingPower is
    IRevolutionVotingPower,
    VersionedContract,
    UUPS,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable
{
    ///                                                          ///
    ///                         IMMUTABLES                       ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IRevolutionBuilder private immutable manager;

    ///                                                          ///
    ///                           STORAGE                        ///
    ///                                                          ///

    // The ERC20 token used for voting
    ERC20VotesUpgradeable public points;

    // The ERC721 token used for voting
    ERC721CheckpointableUpgradeable public token;

    // The vote weight of the ERC20 token
    uint256 public pointsVoteWeight;

    // The vote weight of the ERC721 token
    uint256 public tokenVoteWeight;

    ///                                                          ///
    ///                         CONSTRUCTOR                      ///
    ///                                                          ///

    /// @param _manager The contract upgrade manager address
    constructor(address _manager) payable initializer {
        manager = IRevolutionBuilder(_manager);
    }

    ///                                                          ///
    ///                           ERRORS                         ///
    ///                                                          ///

    /// @notice Reverts for address zero
    error INVALID_ADDRESS_ZERO();

    /// @notice Reverts for invalid manager initialization
    error SENDER_NOT_MANAGER();

    ///                                                          ///
    ///                         INITIALIZER                      ///
    ///                                                          ///

    /**
     * @notice Initializes the RevolutionVotingPower contract
     * @param _initialOwner The initial owner of the contract
     * @param _revolutionPoints The address of the ERC20 token used for voting
     * @param _revolutionPointsVoteWeight The vote weight of the ERC20 token
     * @param _revolutionToken The address of the ERC721 token used for voting
     * @param _revolutionTokenVoteWeight The vote weight of the ERC721 token
     */
    function initialize(
        address _initialOwner,
        address _revolutionPoints,
        uint256 _revolutionPointsVoteWeight,
        address _revolutionToken,
        uint256 _revolutionTokenVoteWeight
    ) public initializer {
        if (msg.sender != address(manager)) revert SENDER_NOT_MANAGER();
        if (_initialOwner == address(0)) revert INVALID_ADDRESS_ZERO();
        if (_revolutionPoints == address(0)) revert INVALID_ADDRESS_ZERO();
        if (_revolutionToken == address(0)) revert INVALID_ADDRESS_ZERO();

        // Initialize the ERC20 & ERC721 tokens
        points = ERC20VotesUpgradeable(_revolutionPoints);
        token = ERC721CheckpointableUpgradeable(_revolutionToken);

        // Initialize the vote weights
        pointsVoteWeight = _revolutionPointsVoteWeight;
        tokenVoteWeight = _revolutionTokenVoteWeight;

        __Ownable_init(_initialOwner);
        __ReentrancyGuard_init();

        emit ERC721VotingTokenUpdated(token);
        emit ERC20VotingTokenUpdated(points);

        emit ERC721VotingPowerUpdated(tokenVoteWeight, _revolutionTokenVoteWeight);
        emit ERC20VotingPowerUpdated(pointsVoteWeight, _revolutionPointsVoteWeight);
    }

    ///                                                          ///
    ///                          FUNCTIONS                       ///
    ///                                                          ///

    /**
     * @notice Calculates the vote weight of a voter.
     * @param erc20PointsBalance The ERC20 RevolutionPoints balance of the voter.
     * @param erc20PointsVoteWeight The ERC20 RevolutionPoints vote weight.
     * @param erc721TokenBalance The ERC721 token balance of the voter.
     * @param erc721TokenVoteWeight The ERC721 token vote weight.
     * @return The vote weight of the voter.
     */
    function _calculateVoteWeight(
        uint256 erc20PointsBalance,
        uint256 erc20PointsVoteWeight,
        uint256 erc721TokenBalance,
        uint256 erc721TokenVoteWeight
    ) internal pure returns (uint256) {
        return (erc20PointsBalance * erc20PointsVoteWeight) + (erc721TokenBalance * erc721TokenVoteWeight);
    }

    /**
     * @notice Returns the voting power of a voter at the current block with the default vote weights.
     * @param account The address of the voter.
     * @return The voting power of the voter.
     */
    function getVotes(address account) external view override returns (uint256) {
        return _getVotes(account, pointsVoteWeight, tokenVoteWeight);
    }

    /**
     * @notice Returns the voting power of a voter at the current block with given vote weights.
     * @param account The address of the voter.
     * @param erc20PointsVoteWeight The ERC20 RevolutionPoints vote weight.
     * @param erc721TokenVoteWeight The ERC721 token vote weight.
     * @return The voting power of the voter.
     */
    function getVotesWithWeights(
        address account,
        uint256 erc20PointsVoteWeight,
        uint256 erc721TokenVoteWeight
    ) external view override returns (uint256) {
        return _getVotes(account, erc20PointsVoteWeight, erc721TokenVoteWeight);
    }

    /**
     * @notice Returns the voting power of a voter at the current block with the default vote weights.
     * @return The total voting power.
     */
    function getTotalVotes() external view override returns (uint256) {
        return _calculateVoteWeight(points.totalSupply(), pointsVoteWeight, token.totalSupply(), tokenVoteWeight);
    }

    /**
     * @notice Returns the voting power of a voter at the current block with the default vote weights.
     * @param erc20PointsVoteWeight The ERC20 RevolutionPoints vote weight.
     * @param erc721TokenVoteWeight The ERC721 token vote weight.
     * @return The total voting power.
     */
    function getTotalVotesWithWeights(
        uint256 erc20PointsVoteWeight,
        uint256 erc721TokenVoteWeight
    ) external view override returns (uint256) {
        return
            _calculateVoteWeight(
                points.totalSupply(),
                erc20PointsVoteWeight,
                token.totalSupply(),
                erc721TokenVoteWeight
            );
    }

    /**
     * @notice Returns the voting power of a voter at the current block.
     * @param account The address of the voter.
     * @param erc20PointsVoteWeight The ERC20 RevolutionPoints vote weight.
     * @param erc721TokenVoteWeight The ERC721 token vote weight.
     * @return The voting power of the voter.
     */
    function _getVotes(
        address account,
        uint256 erc20PointsVoteWeight,
        uint256 erc721TokenVoteWeight
    ) internal view returns (uint256) {
        return
            _calculateVoteWeight(
                points.getVotes(account),
                erc20PointsVoteWeight,
                token.getVotes(account),
                erc721TokenVoteWeight
            );
    }

    /**
     * @notice Returns the voting power of a voter at the given blockNumber.
     * @param account The address of the voter.
     * @param blockNumber The block number at which to calculate the voting power.
     * @return The voting power of the voter.
     */
    function getPastVotes(address account, uint256 blockNumber) external view override returns (uint256) {
        return _getPastVotes(account, blockNumber, pointsVoteWeight, tokenVoteWeight);
    }

    /**
     * @notice Returns the voting power of a voter at the given blockNumber with given vote weights.
     * @param account The address of the voter.
     * @param blockNumber The block number at which to calculate the voting power.
     * @param erc20PointsVoteWeight The ERC20 RevolutionPoints vote weight.
     * @param erc721TokenVoteWeight The ERC721 token vote weight.
     * @return The voting power of the voter.
     */
    function getPastVotesWithWeights(
        address account,
        uint256 blockNumber,
        uint256 erc20PointsVoteWeight,
        uint256 erc721TokenVoteWeight
    ) external view override returns (uint256) {
        return _getPastVotes(account, blockNumber, erc20PointsVoteWeight, erc721TokenVoteWeight);
    }

    /**
     * @notice Get total voting power at the given blockNumber.
     * @param blockNumber The block number at which to calculate the voting power.
     * @return The total voting power.
     */
    function getPastTotalVotes(uint256 blockNumber) external view override returns (uint256) {
        return
            _calculateVoteWeight(
                points.getPastTotalSupply(blockNumber),
                pointsVoteWeight,
                token.getPastTotalSupply(blockNumber),
                tokenVoteWeight
            );
    }

    /**
     * @notice Get total voting power at the given blockNumber with given vote weights.
     * @param blockNumber The block number at which to calculate the voting power.
     * @param erc20PointsVoteWeight The ERC20 RevolutionPoints vote weight.
     * @param erc721TokenVoteWeight The ERC721 token vote weight.
     * @return The total voting power given weights at a previous block.
     */
    function getPastTotalVotesWithWeights(
        uint256 blockNumber,
        uint256 erc20PointsVoteWeight,
        uint256 erc721TokenVoteWeight
    ) external view override returns (uint256) {
        return
            _calculateVoteWeight(
                points.getPastTotalSupply(blockNumber),
                erc20PointsVoteWeight,
                token.getPastTotalSupply(blockNumber),
                erc721TokenVoteWeight
            );
    }

    /**
     * @notice Returns the voting power of a voter at the given blockNumber.
     * @param account The address of the voter.
     * @param erc20PointsVoteWeight The ERC20 RevolutionPoints vote weight.
     * @param erc721TokenVoteWeight The ERC721 token vote weight.
     * @return The voting power of the voter.
     */
    function _getPastVotes(
        address account,
        uint256 blockNumber,
        uint256 erc20PointsVoteWeight,
        uint256 erc721TokenVoteWeight
    ) internal view returns (uint256) {
        return
            _calculateVoteWeight(
                points.getPastVotes(account, blockNumber),
                erc20PointsVoteWeight,
                token.getPastVotes(account, blockNumber),
                erc721TokenVoteWeight
            );
    }

    ///                                                          ///
    ///             REVOLUTION VOTING POWER UPGRADE              ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract and that the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner {
        // Ensure the new implementation is a registered upgrade
        if (!manager.isRegisteredUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
