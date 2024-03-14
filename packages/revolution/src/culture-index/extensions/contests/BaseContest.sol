// SPDX-License-Identifier: GPL-3.0

/// @title A Revolution contest

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

pragma solidity ^0.8.22;

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { IBaseContest } from "./IBaseContest.sol";
import { IWETH } from "../../../interfaces/IWETH.sol";
import { ICultureIndex } from "../../../interfaces/ICultureIndex.sol";
import { RevolutionVersion } from "../../../version/RevolutionVersion.sol";

import { UUPS } from "@cobuild/utility-contracts/src/proxy/UUPS.sol";
import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";
import { RevolutionRewards } from "@cobuild/protocol-rewards/src/abstract/RevolutionRewards.sol";

import { ISplitMain } from "@cobuild/splits/src/interfaces";

contract BaseContest is
    IBaseContest,
    RevolutionVersion,
    UUPS,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    RevolutionRewards
{
    /// @notice constant to scale uints into percentages (1e6 == 100%)
    uint256 public constant PERCENTAGE_SCALE = 1e6;

    // The address of the WETH contract
    address public WETH;

    // The split of winning proceeds that is sent to winners
    uint256 public entropyRate;

    // The address of th account to receive builder rewards
    address public builderReward;

    // The end time of the contest
    uint256 public endTime;

    // The SplitMain contract
    ISplitMain public splitMain;

    // The CultureIndex contract holding submissions
    ICultureIndex public cultureIndex;

    // The contest payout splits
    uint256[] public payoutSplits;
    ///                         IMMUTABLES                       ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IUpgradeManager public immutable manager;

    ///                                                          ///
    ///                         CONSTRUCTOR                      ///
    ///                                                          ///

    /// @param _manager The contract upgrade manager address
    /// @param _protocolRewards The protocol rewards contract address
    /// @param _protocolFeeRecipient The protocol fee recipient addres
    constructor(
        address _manager,
        address _protocolRewards,
        address _protocolFeeRecipient
    ) payable RevolutionRewards(_protocolRewards, _protocolFeeRecipient) initializer {
        if (_manager == address(0)) revert ADDRESS_ZERO();
        if (_protocolRewards == address(0)) revert ADDRESS_ZERO();
        if (_protocolFeeRecipient == address(0)) revert ADDRESS_ZERO();

        manager = IUpgradeManager(_manager);
    }

    ///                                                          ///
    ///                         INITIALIZER                      ///
    ///                                                          ///

    /**
     * @notice Initialize the contst and base contracts,
     * populate configuration values, and pause the contract.
     * @dev This function can only be called once.
     * @param _initialOwner The address of the owner.
     * @param _splitMain The address of the SplitMain splits creator contract.
     * @param _cultureIndex The address of the CultureIndex contract holding submissions.
     * @param _builderReward The address of the account to receive builder rewards.
     * @param _weth The address of the WETH contract
     * @param _baseContestParams The contest params for the contest.
     */
    function initialize(
        address _initialOwner,
        address _splitMain,
        address _cultureIndex,
        address _builderReward,
        address _weth,
        IBaseContest.BaseContestParams calldata _baseContestParams
    ) external initializer {
        if (msg.sender != address(manager)) revert NOT_MANAGER();
        if (_weth == address(0)) revert ADDRESS_ZERO();

        __Pausable_init();
        __ReentrancyGuard_init();
        __Ownable_init(_initialOwner);

        _pause();

        // set contracts
        WETH = _weth;
        builderReward = _builderReward;
        splitMain = ISplitMain(_splitMain);
        cultureIndex = ICultureIndex(_cultureIndex);

        // set creator payout params
        entropyRate = _baseContestParams.entropyRate;
        endTime = _baseContestParams.endTime;
        payoutSplits = _baseContestParams.payoutSplits;
    }

    /**
     * @notice Set the split of that is sent to the creator as ether
     * @dev Only callable by the owner.
     * @param _entropyRate New entropy rate, scaled by PERCENTAGE_SCALE.
     */
    function setEntropyRate(uint256 _entropyRate) external onlyOwner {
        if (_entropyRate > PERCENTAGE_SCALE) revert INVALID_ENTROPY_RATE();

        entropyRate = _entropyRate;
        emit EntropyRateUpdated(_entropyRate);
    }

    /// @notice Transfer ETH/WETH from the contract
    /// @param _to The recipient address
    /// @param _amount The amount transferring
    function _safeTransferETHWithFallback(address _to, uint256 _amount) private {
        // Ensure the contract has enough ETH to transfer
        if (address(this).balance < _amount) revert("Insufficient balance");

        // Used to store if the transfer succeeded
        bool success;

        assembly {
            // Transfer ETH to the recipient
            // Limit the call to 30,000 gas
            success := call(30000, _to, _amount, 0, 0, 0, 0)
        }

        // If the transfer failed:
        if (!success) {
            // Wrap as WETH
            IWETH(WETH).deposit{ value: _amount }();

            // Transfer WETH instead
            bool wethSuccess = IWETH(WETH).transfer(_to, _amount);

            // Ensure successful transfer
            if (!wethSuccess) revert("WETH transfer failed");
        }
    }

    ///                                                          ///
    ///                    BASE CONTEST UPGRADE                  ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract and the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner whenPaused {}
}
