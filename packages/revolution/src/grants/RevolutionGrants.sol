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

import { SuperTokenV1Library, ISuperToken } from "./superfluid/SuperTokenV1Library.sol";

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
     * @param _superToken The address of the SuperToken used to pay out the grantees
     */
    constructor(address _manager, ISuperToken _superToken) payable initializer {
        if (_manager == address(0)) revert ADDRESS_ZERO();
        manager = IUpgradeManager(_manager);

        superToken = _superToken;
        pool = superToken.createPool(address(this), poolConfig);
    }

    /**
     * @notice Initializes the RevolutionGrants contract
     * @param _votingPower The address of the RevolutionVotingPower contract
     * @param _initialOwner The owner of the contract, allowed to drop pieces. Commonly updated to the AuctionHouse
     * @param _grantsParams The parameters for the grants contract
     */
    function initialize(
        address _votingPower,
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
    }

    /**
     * @notice Adds an address to the list of approved recipients
     * @param recipient The address to be added as an approved recipient
     */
    function addApprovedRecipient(address recipient) public onlyOwner {
        if (recipient == address(0)) revert ADDRESS_ZERO();
        approvedRecipients[recipient] = true;
    }

    function updateMemberUnits(address member, uint128 units) public {
        superToken.updateMemberUnits(pool, member, units);
    }

    function distributeFlow(int96 flowRate) public {
        superToken.distributeFlow(address(this), pool, flowRate);
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
