// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.22;

import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IRevolutionBuilder } from "./interfaces/IRevolutionBuilder.sol";

import { UUPS } from "./libs/proxy/UUPS.sol";
import { VersionedContract } from "./version/VersionedContract.sol";

import { IRevolutionToken } from "./interfaces/IRevolutionToken.sol";
import { IRevolutionPoints } from "./interfaces/IRevolutionPoints.sol";
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
    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  IMMUTABLES
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /// @notice The contract upgrade manager
    IRevolutionBuilder private immutable manager;

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  STORAGE
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    // The ERC20 token used for voting
    IRevolutionPoints public points;

    // The ERC721 token used for voting
    IRevolutionToken public token;

    // The vote weight of the ERC20 token
    uint256 public pointsVoteWeight;

    // The vote weight of the ERC721 token
    uint256 public tokenVoteWeight;

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  CONSTRUCTOR
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /// @param _manager The contract upgrade manager address
    constructor(address _manager) payable initializer {
        manager = IRevolutionBuilder(_manager);
    }

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  ERRORS
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /// @notice Reverts for address zero
    error INVALID_ADDRESS_ZERO();

    /// @notice Reverts for invalid manager initialization
    error SENDER_NOT_MANAGER();

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  INITIALIZER
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /**
     * @notice Initializes the RevolutionVotingPower contract
     * @param _initialOwner The initial owner of the contract
     * @param _revolutionPoints The address of the ERC20 token used for voting
     * @param _pointsVoteWeight The vote weight of the ERC20 token
     * @param _revolutionToken The address of the ERC721 token used for voting
     * @param _tokenVoteWeight The vote weight of the ERC721 token
     */
    function initialize(
        address _initialOwner,
        address _revolutionPoints,
        uint256 _pointsVoteWeight,
        address _revolutionToken,
        uint256 _tokenVoteWeight
    ) public initializer {
        if (msg.sender != address(manager)) revert SENDER_NOT_MANAGER();
        if (_initialOwner == address(0)) revert INVALID_ADDRESS_ZERO();
        if (_revolutionPoints == address(0)) revert INVALID_ADDRESS_ZERO();
        if (_revolutionToken == address(0)) revert INVALID_ADDRESS_ZERO();

        // Initialize the ERC20 & ERC721 tokens
        points = IRevolutionPoints(_revolutionPoints);
        token = IRevolutionToken(_revolutionToken);

        // Initialize the vote weights
        pointsVoteWeight = _pointsVoteWeight;
        tokenVoteWeight = _tokenVoteWeight;

        __Ownable_init(_initialOwner);
        __ReentrancyGuard_init();

        emit ERC721VotingTokenUpdated(address(token));
        emit ERC20VotingTokenUpdated(address(points));

        emit ERC721VotingPowerUpdated(tokenVoteWeight, _tokenVoteWeight);
        emit ERC20VotingPowerUpdated(pointsVoteWeight, _pointsVoteWeight);
    }

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  INTERNAL
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /**
     * @notice Calculates the vote weight of a voter.
     * @param _pointsBalance The ERC20 RevolutionPoints balance of the voter.
     * @param _pointsVoteWeight The ERC20 RevolutionPoints vote weight.
     * @param _tokenBalance The ERC721 token balance of the voter.
     * @param _tokenVoteWeight The ERC721 token vote weight.
     * @return The vote weight of the voter.
     */
    function _calculateVoteWeight(
        uint256 _pointsBalance,
        uint256 _pointsVoteWeight,
        uint256 _tokenBalance,
        uint256 _tokenVoteWeight
    ) internal pure returns (uint256) {
        return (_pointsBalance * _pointsVoteWeight) + (_tokenBalance * _tokenVoteWeight);
    }

    /**
     * @notice Returns the voting power of a voter at the current block.
     * @param _account The address of the voter.
     * @param _pointsVoteWeight The ERC20 RevolutionPoints vote weight.
     * @param _tokenVoteWeight The ERC721 token vote weight.
     * @return The voting power of the voter.
     */
    function _getVotes(
        address _account,
        uint256 _pointsVoteWeight,
        uint256 _tokenVoteWeight
    ) internal view returns (uint256) {
        return
            _calculateVoteWeight(
                points.getVotes(_account),
                _pointsVoteWeight,
                token.getVotes(_account),
                _tokenVoteWeight
            );
    }

    /**
     * @notice Returns the voting power of a voter at the given blockNumber.
     * @param _account The address of the voter.
     * @param _blockNumber The block number at which to calculate the voting power.
     * @param _pointsVoteWeight The ERC20 RevolutionPoints vote weight.
     * @param _tokenVoteWeight The ERC721 token vote weight.
     * @return The voting power of the voter.
     */
    function _getPastVotes(
        address _account,
        uint256 _blockNumber,
        uint256 _pointsVoteWeight,
        uint256 _tokenVoteWeight
    ) internal view returns (uint256) {
        return
            _calculateVoteWeight(
                points.getPastVotes(_account, _blockNumber),
                _pointsVoteWeight,
                token.getPastVotes(_account, _blockNumber),
                _tokenVoteWeight
            );
    }

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  BALANCES
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /**
     * @notice Returns the ERC20 RevolutionPoints votes balance of a voter.
     * @param account The address of the voter.
     * @return The ERC20 RevolutionPoints votes balance of the voter.
     */
    function getPointsVotes(address account) external view returns (uint256) {
        return points.getVotes(account);
    }

    /**
     * @notice Returns past ERC20 RevolutionPoints votes balance of a voter at a given block.
     * @param account The address of the voter.
     * @return The past ERC20 RevolutionPoints votes balance of the voter at the given block.
     */
    function getPastPointsVotes(address account, uint256 blockNumber) external view returns (uint256) {
        return points.getPastVotes(account, blockNumber);
    }

    /**
     * @notice Returns the ERC721 token votes balance of a voter.
     * @param account The address of the voter.
     * @return The ERC721 token votes balance of the voter.
     */
    function getTokenVotes(address account) external view returns (uint256) {
        return token.getVotes(account);
    }

    /**
     * @notice Returns past ERC721 token votes balance of a voter at a given block.
     * @param account The address of the voter.
     * @return The past ERC721 token votes balance of the voter at the given block.
     */
    function getPastTokenVotes(address account, uint256 blockNumber) external view returns (uint256) {
        return token.getPastVotes(account, blockNumber);
    }

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  SUPPLY
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /**
     * @notice Returns the total supply of points at the current block.
     */
    function getPointsSupply() public view override returns (uint256) {
        return points.totalSupply();
    }

    /**
     * @notice Returns the total supply of points at the current block.
     */
    function getTokenSupply() public view override returns (uint256) {
        return token.totalSupply();
    }

    /**
     * @notice Returns the total supply of points at the given block
     * @param _blockNumber The block number at which to calculate the supply.
     * @return The total supply of points at the given block.
     */
    function getPastPointsSupply(uint256 _blockNumber) public view override returns (uint256) {
        return points.getPastTotalSupply(_blockNumber);
    }

    /**
     * @notice Returns the total supply of tokens at the given block
     * @param _blockNumber The block number at which to calculate the supply
     * @return The total supply of tokens at the given block
     */
    function getPastTokenSupply(uint256 _blockNumber) public view override returns (uint256) {
        return token.getPastTotalSupply(_blockNumber);
    }

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  CALCULATE VOTES
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /**
     * @notice Calculates the voting power given the balances of points and tokens.
     * @param pointsBalance The ERC20 RevolutionPoints balance of the voter.
     * @param tokenBalance The ERC721 token balance of the voter.
     * @return The calculated voting power
     */
    function calculateVotes(uint256 pointsBalance, uint256 tokenBalance) external view override returns (uint256) {
        return _calculateVoteWeight(pointsBalance, pointsVoteWeight, tokenBalance, tokenVoteWeight);
    }

    /**
     * @notice Calculates the voting power given the balances and vote weights.
     * @param pointsVotes The ERC20 RevolutionPoints balance and vote weight of the voter.
     * @param tokenVotes The ERC721 token balance and vote weight of the voter.
     * @return The calculated voting power
     */
    function calculateVotesWithWeights(
        BalanceAndWeight calldata pointsVotes,
        BalanceAndWeight calldata tokenVotes
    ) external view override returns (uint256) {
        return
            _calculateVoteWeight(
                pointsVotes.balance,
                pointsVotes.voteWeight,
                tokenVotes.balance,
                tokenVotes.voteWeight
            );
    }

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  VOTES
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /**
     * @notice Returns the voting power of a voter at the current block with the default vote weights.
     * @param _account The address of the voter.
     * @return The voting power of the voter.
     */
    function getVotes(address _account) external view override returns (uint256) {
        return _getVotes(_account, pointsVoteWeight, tokenVoteWeight);
    }

    /**
     * @notice Returns the voting power of a voter at the current block with given vote weights.
     * @param _account The address of the voter.
     * @param _pointsVoteWeight The ERC20 RevolutionPoints vote weight.
     * @param _tokenVoteWeight The ERC721 token vote weight.
     * @return The voting power of the voter.
     */
    function getVotesWithWeights(
        address _account,
        uint256 _pointsVoteWeight,
        uint256 _tokenVoteWeight
    ) external view override returns (uint256) {
        return _getVotes(_account, _pointsVoteWeight, _tokenVoteWeight);
    }

    /**
     * @notice Returns the voting power of a voter at the current block with the default vote weights.
     * @return The total voting power.
     */
    function getTotalVotesSupply() external view override returns (uint256) {
        return _calculateVoteWeight(points.totalSupply(), pointsVoteWeight, token.totalSupply(), tokenVoteWeight);
    }

    /**
     * @notice Returns the voting power of a voter at the current block with the default vote weights.
     * @param _pointsVoteWeight The ERC20 RevolutionPoints vote weight.
     * @param _tokenVoteWeight The ERC721 token vote weight.
     * @return The total voting power.
     */
    function getTotalVotesSupplyWithWeights(
        uint256 _pointsVoteWeight,
        uint256 _tokenVoteWeight
    ) external view override returns (uint256) {
        return _calculateVoteWeight(points.totalSupply(), _pointsVoteWeight, token.totalSupply(), _tokenVoteWeight);
    }

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *  PAST VOTES
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /**
     * @notice Returns the voting power of a voter at the given blockNumber.
     * @param _account The address of the voter.
     * @param _blockNumber The block number at which to calculate the voting power.
     * @return The voting power of the voter.
     */
    function getPastVotes(address _account, uint256 _blockNumber) external view override returns (uint256) {
        return _getPastVotes(_account, _blockNumber, pointsVoteWeight, tokenVoteWeight);
    }

    /**
     * @notice Returns the voting power of a voter at the given blockNumber with given vote weights.
     * @param _account The address of the voter.
     * @param _blockNumber The block number at which to calculate the voting power.
     * @param _pointsVoteWeight The ERC20 RevolutionPoints vote weight.
     * @param _tokenVoteWeight The ERC721 token vote weight.
     * @return The voting power of the voter.
     */
    function getPastVotesWithWeights(
        address _account,
        uint256 _blockNumber,
        uint256 _pointsVoteWeight,
        uint256 _tokenVoteWeight
    ) external view override returns (uint256) {
        return _getPastVotes(_account, _blockNumber, _pointsVoteWeight, _tokenVoteWeight);
    }

    /**
     * @notice Get total voting power at the given blockNumber.
     * @param _blockNumber The block number at which to calculate the voting power.
     * @return The total voting power.
     */
    function getPastTotalVotesSupply(uint256 _blockNumber) external view override returns (uint256) {
        return
            _calculateVoteWeight(
                points.getPastTotalSupply(_blockNumber),
                pointsVoteWeight,
                token.getPastTotalSupply(_blockNumber),
                tokenVoteWeight
            );
    }

    /**
     * @notice Get total voting power at the given blockNumber with given vote weights.
     * @param _blockNumber The block number at which to calculate the voting power.
     * @param _pointsVoteWeight The ERC20 RevolutionPoints vote weight.
     * @param _tokenVoteWeight The ERC721 token vote weight.
     * @return The total voting power given weights at a previous block.
     */
    function getPastTotalVotesSupplyWithWeights(
        uint256 _blockNumber,
        uint256 _pointsVoteWeight,
        uint256 _tokenVoteWeight
    ) external view override returns (uint256) {
        return
            _calculateVoteWeight(
                points.getPastTotalSupply(_blockNumber),
                _pointsVoteWeight,
                token.getPastTotalSupply(_blockNumber),
                _tokenVoteWeight
            );
    }

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   TOKEN MINTER
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /**
     * @notice gets the balance of the minter of the ERC721 token
     * @dev useful to eg: subtract the AuctionHouse balance when calculating quorum
     */
    function _getTokenMinter__TokenVotes() external view override returns (uint256) {
        return token.getVotes(token.minter()) * tokenVoteWeight;
    }

    /**
     * @notice gets the balance of the minter of the ERC721 token
     * @dev useful to eg: subtract the AuctionHouse balance when calculating quorum
     * @param _blockNumber The block number at which to calculate the voting power.
     */
    function _getTokenMinter__PastTokenVotes(uint256 _blockNumber) external view override returns (uint256) {
        return token.getPastVotes(token.minter(), _blockNumber) * tokenVoteWeight;
    }

    /**
     * @notice gets the balance of the minter of the ERC721 token
     * @param _tokenVoteWeight The ERC721 token vote weight.
     */
    function _getTokenMinter__TokenVotes__WithWeight(
        uint256 _tokenVoteWeight
    ) external view override returns (uint256) {
        return token.getVotes(token.minter()) * _tokenVoteWeight;
    }

    /**
     * @notice gets the balance of the minter of the ERC721 token
     * @param _blockNumber The block number at which to calculate the voting power.
     * @param _tokenVoteWeight The ERC721 token vote weight.
     */
    function _getTokenMinter__PastTokenVotes__WithWeight(
        uint256 _blockNumber,
        uint256 _tokenVoteWeight
    ) external view override returns (uint256) {
        return token.getPastVotes(token.minter(), _blockNumber) * _tokenVoteWeight;
    }

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   REVOLUTION VOTING POWER UPGRADE
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /// @notice Ensures the caller is authorized to upgrade the contract and that the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner {
        // Ensure the new implementation is a registered upgrade
        if (!manager.isRegisteredUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
