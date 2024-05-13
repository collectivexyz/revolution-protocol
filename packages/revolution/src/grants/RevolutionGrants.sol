// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.22;

import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import { UUPS } from "@cobuild/utility-contracts/src/proxy/UUPS.sol";
import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";
import { RevolutionVersion } from "../version/RevolutionVersion.sol";
import { RevolutionGrantsStorageV1 } from "./storage/RevolutionGrantsStorageV1.sol";
import { IRevolutionGrants } from "../interfaces/IRevolutionGrants.sol";
import { IRevolutionVotingPower } from "../interfaces/IRevolutionVotingPower.sol";

import { SuperTokenV1Library, ISuperToken, PoolConfig } from "./superfluid/SuperTokenV1Library.sol";

contract RevolutionGrants is
    IRevolutionGrants,
    RevolutionVersion,
    UUPS,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable,
    RevolutionGrantsStorageV1
{
    using SuperTokenV1Library for ISuperToken;

    /**
     * @notice Initializes a token's metadata descriptor
     * @param _manager The contract upgrade manager address
     */
    constructor(address _manager) payable initializer {
        if (_manager == address(0)) revert ADDRESS_ZERO();
        manager = IUpgradeManager(_manager);
    }

    /**
     * @notice Initializes the RevolutionGrants contract
     * @param _votingPower The address of the RevolutionVotingPower contract
     * @param _superToken The address of the SuperToken to be used for the pool
     * @param _initialOwner The owner of the contract, allowed to drop pieces. Commonly updated to the AuctionHouse
     * @param _grantsParams The parameters for the grants contract
     */
    function initialize(
        address _votingPower,
        address _superToken,
        address _initialOwner,
        GrantsParams memory _grantsParams
    ) public initializer {
        if (msg.sender != address(manager)) revert SENDER_NOT_MANAGER();
        if (_initialOwner == address(0)) revert ADDRESS_ZERO();
        if (_votingPower == address(0)) revert ADDRESS_ZERO();

        // Initialize EIP-712 support
        __EIP712_init("RevolutionGrants", "1");

        __Ownable_init(_initialOwner);
        __ReentrancyGuard_init();

        // Set the voting power info
        votingPower = IRevolutionVotingPower(_votingPower);
        tokenVoteWeight = _grantsParams.tokenVoteWeight;
        pointsVoteWeight = _grantsParams.pointsVoteWeight;

        quorumVotesBPS = _grantsParams.quorumVotesBPS;
        minVotingPowerToVote = _grantsParams.minVotingPowerToVote;
        minVotingPowerToCreate = _grantsParams.minVotingPowerToCreate;

        snapshotBlock = block.number;

        // Set the pool config
        setSuperTokenAndCreatePool(_superToken);
    }

    /**
     * @notice Sets the SuperToken and creates a pool from it, can only be called by the owner
     * @param _superToken The address of the SuperToken to be set and used for the pool
     */
    function setSuperTokenAndCreatePool(address _superToken) public onlyOwner {
        superToken = ISuperToken(_superToken);
        pool = superToken.createPool(address(this), poolConfig);
    }

    /**
     * @notice Sets the minimum voting power required to vote on a grant
     * @param _minVotingPowerToVote The new minimum voting power to vote
     */
    function setMinVotingPowerToVote(uint256 _minVotingPowerToVote) public onlyOwner {
        emit MinVotingPowerToVoteSet(minVotingPowerToVote, _minVotingPowerToVote);

        minVotingPowerToVote = _minVotingPowerToVote;
    }

    /**
     * @notice Sets the minimum voting power required to create a grant
     * @param _minVotingPowerToCreate The new minimum voting power to create a grant
     */
    function setMinVotingPowerToCreate(uint256 _minVotingPowerToCreate) public onlyOwner {
        emit MinVotingPowerToCreateSet(minVotingPowerToCreate, _minVotingPowerToCreate);

        minVotingPowerToCreate = _minVotingPowerToCreate;
    }

    /**
     * @notice Retrieves all vote allocations for a given account
     * @param account The address of the account to retrieve votes for
     * @return allocations An array of VoteAllocation structs representing each vote made by the account
     */
    function getVotesForAccount(address account) public view returns (VoteAllocation[] memory allocations) {
        if (account == address(0)) revert ADDRESS_ZERO();

        return votes[account];
    }

    /**
     * @notice Get account voting power
     * @param account The address of the voter.
     */
    function getAccountVotingPower(address account) public view returns (uint256) {
        return getVotingPowerForBlock(account, snapshotBlock);
    }

    /**
     * @notice Get account voting power for a specific block
     * @param account The address of the voter.
     * @param blockNumber The block number to get the voting power for.
     */
    function getVotingPowerForBlock(address account, uint256 blockNumber) public view returns (uint256) {
        return
            votingPower.calculateVotesWithWeights(
                IRevolutionVotingPower.BalanceAndWeight({
                    balance: votingPower.getPastPointsVotes(account, blockNumber),
                    voteWeight: pointsVoteWeight
                }),
                IRevolutionVotingPower.BalanceAndWeight({
                    balance: votingPower.getPastTokenVotes(account, blockNumber),
                    voteWeight: tokenVoteWeight
                })
            );
    }

    /**
     * @notice Cast a vote for a specific grant address.
     * @param recipient The address of the grant recipient.
     * @param bps The basis points of the vote to be split with the recipient.
     * @param voter The address of the voter.
     * @param totalWeight The voting power of the voter.
     * @dev Requires that the recipient is valid, and the weight is greater than the minimum vote weight.
     * Emits a VoteCast event upon successful execution.
     */
    function _vote(address recipient, uint32 bps, address voter, uint256 totalWeight) internal {
        if (recipient == address(0)) revert ADDRESS_ZERO();
        if (approvedRecipients[recipient] == false) revert NOT_APPROVED_RECIPIENT();

        // calculate new member units for recipient
        // make sure to add the current units to the new units
        uint128 currentUnits = pool.getUnits(recipient);

        // double check for overflow before casting
        uint256 scaledUnits = _scaleAmountByPercentage(totalWeight, bps);
        if (scaledUnits > type(uint128).max) revert OVERFLOW();
        uint128 newUnits = uint128(scaledUnits);

        uint128 memberUnits = currentUnits + newUnits;

        // update votes, track recipient, bps, and total member units assigned
        votes[voter].push(VoteAllocation({ recipient: recipient, bps: bps, memberUnitsDelta: newUnits }));

        // update member units
        bool success = updateMemberUnits(recipient, memberUnits);
        if (!success) revert UNITS_UPDATE_FAILED();

        emit VoteCast(recipient, voter, memberUnits, bps);
    }

    /**
     * @notice Clears out units from previous votes allocation for a specific voter.
     * @param voter The address of the voter whose previous votes are to be cleared.
     * @dev This function resets the member units for all recipients that the voter has previously voted for.
     * It should be called before setting new votes to ensure accurate vote allocations.
     */
    function _clearPreviousVotes(address voter) internal {
        VoteAllocation[] memory allocations = votes[voter];
        for (uint256 i = 0; i < allocations.length; i++) {
            address recipient = allocations[i].recipient;
            uint128 currentUnits = pool.getUnits(recipient);
            uint128 unitsDelta = allocations[i].memberUnitsDelta;

            // Calculate the new units by subtracting the delta from the current units
            // Update the member units in the pool
            updateMemberUnits(recipient, currentUnits - unitsDelta);
        }

        // Clear out the votes for the voter
        delete votes[voter];
    }

    /**
     * @notice Cast a vote for a set of grant addresses.
     * @param recipients The addresses of the grant recipients.
     * @param percentAllocations The basis points of the vote to be split with the recipients.
     */
    function setVotesAllocations(address[] memory recipients, uint32[] memory percentAllocations) public nonReentrant {
        address voter = msg.sender;
        uint256 weight = getAccountVotingPower(voter);

        // Ensure the voter has enough voting power to vote
        if (weight <= minVotingPowerToVote) revert WEIGHT_TOO_LOW();

        // _getSum should overflow if sum != PERCENTAGE_SCALE
        if (_getSum(percentAllocations) != PERCENTAGE_SCALE) revert INVALID_BPS_SUM();

        // update member units for previous votes
        _clearPreviousVotes(voter);

        // set new votes
        for (uint256 i = 0; i < recipients.length; i++) {
            _vote(recipients[i], percentAllocations[i], voter, weight);
        }
    }

    /**
     * @notice Adds an address to the list of approved recipients
     * @param recipient The address to be added as an approved recipient
     */
    function addApprovedRecipient(address recipient) public {
        if (recipient == address(0)) revert ADDRESS_ZERO();

        // check voting power of the caller
        uint256 weight = getVotingPowerForBlock(msg.sender, block.number - 1);
        if (weight <= minVotingPowerToCreate) revert WEIGHT_TOO_LOW();

        approvedRecipients[recipient] = true;
    }

    function updateMemberUnits(address member, uint128 units) internal {
        superToken.updateMemberUnits(pool, member, units);
    }

    function distributeFlow(int96 flowRate) public onlyOwner {
        superToken.distributeFlow(address(this), pool, flowRate);
    }

    /** @notice Sums array of uint32s
     *  @param numbers Array of uint32s to sum
     *  @return sum Sum of `numbers`.
     */
    function _getSum(uint32[] memory numbers) internal pure returns (uint32 sum) {
        // overflow should be impossible in for-loop index
        uint256 numbersLength = numbers.length;
        for (uint256 i = 0; i < numbersLength; ) {
            sum += numbers[i];
            unchecked {
                // overflow should be impossible in for-loop index
                ++i;
            }
        }
    }

    /** @notice Multiplies an amount by a scaled percentage
     *  @param amount Amount to get `scaledPercentage` of
     *  @param scaledPercent Percent scaled by PERCENTAGE_SCALE
     *  @return scaledAmount Percent of `amount`.
     */
    function _scaleAmountByPercentage(
        uint256 amount,
        uint256 scaledPercent
    ) internal pure returns (uint256 scaledAmount) {
        // use assembly to bypass checking for overflow & division by 0
        // scaledPercent has been validated to be < PERCENTAGE_SCALE)
        // & PERCENTAGE_SCALE will never be 0
        assembly {
            /* eg (100 * 2*1e4) / (1e6) */
            scaledAmount := div(mul(amount, scaledPercent), PERCENTAGE_SCALE)
        }
    }

    /**
     * @notice Ensures the caller is authorized to upgrade the contract and that the new implementation is valid
     * @dev This function is called in `upgradeTo` & `upgradeToAndCall`
     * @param _newImpl The new implementation address
     */
    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner {
        // Ensure the new implementation is a registered upgrade
        if (!manager.isRegisteredUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
