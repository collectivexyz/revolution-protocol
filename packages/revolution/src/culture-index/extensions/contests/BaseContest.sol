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

import { ISplitMain } from "@cobuild/splits/src/interfaces/ISplitMain.sol";

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

    // Whether the contest has been fully paid out
    bool public paidOut;

    // The current index of the payout splits. This is used to track which payout split is next to be paid out.
    uint256 public payoutIndex;

    // The balance of the contract at the time the first winner is paid out
    uint256 public initialPayoutBalance;

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
     * @notice Initialize the contest and base contracts,
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

        uint256 numPayoutSplits = _baseContestParams.payoutSplits.length;

        // check payout splits sum to PERCENTAGE_SCALE and ensure descending order
        uint256 sum;
        uint256 previousSplit = type(uint256).max;
        for (uint256 i = 0; i < numPayoutSplits; i++) {
            uint256 currentSplit = _baseContestParams.payoutSplits[i];
            sum += currentSplit;
            if (currentSplit > previousSplit) revert PAYOUT_SPLITS_NOT_DESCENDING();
            previousSplit = currentSplit;
        }
        if (sum != PERCENTAGE_SCALE) revert INVALID_PAYOUT_SPLITS();

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

    /**
     * @notice Unpause the BaseContest
     * @dev This function can only be called by the owner when the
     * contract is paused.
     */
    function unpause() external override onlyOwner {
        _unpause();
    }

    /**
     * @notice Pause the contest to prevent payouts.
     * @dev This function can only be called by the owner when the
     * contract is unpaused.
     */
    function pause() external override onlyOwner {
        _pause();
    }

    /**
     * @notice Pays out the next up contest winner, the top voted submission in the CultureIndex
     * @dev Only callable by the owner.
     */
    function payoutNextSubmission() internal {
        try cultureIndex.dropTopVotedPiece() returns (ICultureIndex.ArtPieceCondensed memory artPiece) {
            // get index to pay out
            uint256 currentPayoutIndex = payoutIndex;
            // increment payout index for next iteration
            payoutIndex++;

            // if we have reached the end of the payoutSplits, set paidOut to true
            // effectively the same as currentPayoutIndex == payoutSplits.length - 1
            // (payoutIndex starts at 0)
            if (payoutIndex == payoutSplits.length) {
                paidOut = true;
            }

            uint256 numCreators = artPiece.creators.length;

            address[] memory accounts = new address[](numCreators);
            uint32[] memory percentAllocations = new uint32[](numCreators);

            // iterate over numCreators and populate accounts and percentAllocations
            for (uint256 i = 0; i < numCreators; i++) {
                accounts[i] = artPiece.creators[i].creator;
                // PERCENTAGE_SCALE is 1e6, art piece scale is 1e4, so we multiply by 1e2
                percentAllocations[i] = uint32(artPiece.creators[i].bps * 1e2);
            }

            // Create split contract
            address splitToPay = splitMain.createSplit(
                ISplitMain.PointsData({
                    pointsPercent: uint32(PERCENTAGE_SCALE - entropyRate),
                    accounts: accounts,
                    percentAllocations: percentAllocations
                }),
                accounts,
                percentAllocations,
                0,
                // no controller on the split
                address(0)
            );

            // calculate payout based on currentPayoutIndex
            uint256 payout = (initialPayoutBalance * payoutSplits[currentPayoutIndex]) / PERCENTAGE_SCALE;

            // Send protocol rewards
            uint256 payoutMinusFee = _handleRewardsAndGetValueToSend(
                payout,
                builderReward,
                address(0),
                cultureIndex.getPieceById(artPiece.pieceId).sponsor
            );

            emit WinnerPaid(
                artPiece.pieceId,
                accounts,
                payoutMinusFee,
                payout - payoutMinusFee,
                payoutSplits[currentPayoutIndex],
                currentPayoutIndex
            );

            // transfer ETH to split contract based on currentPayoutIndex
            _safeTransferETHWithFallback(splitToPay, payoutMinusFee);
        } catch {
            revert("dropTopVotedPiece failed");
        }
    }

    /**
     * @notice Fetch an art piece by its ID.
     * @param pieceId The ID of the art piece.
     * @return The ArtPiece struct associated with the given ID.
     */
    function getArtPieceById(uint256 pieceId) external view returns (ICultureIndex.ArtPiece memory) {
        return cultureIndex.getPieceById(pieceId);
    }

    /**
     * @notice Returns true or false depending on whether the top voted piece in the culture index meets quorum
     * @return True if the top voted piece meets quorum, false otherwise
     */
    function topVotedPieceMeetsQuorum() external view returns (bool) {
        return cultureIndex.topVotedPieceMeetsQuorum();
    }

    /**
     * @notice Pay out the contest winners
     * @param _payoutCount The number of winners to pay out. Needs to be adjusted based on gas requirements.
     */
    function payOutWinners(uint256 _payoutCount) external nonReentrant whenNotPaused {
        // Ensure the contest has not already paid out fully
        if (paidOut) revert CONTEST_ALREADY_PAID_OUT();

        // Ensure the contest has ended
        //slither-disable-next-line timestamp
        if (block.timestamp < endTime) revert CONTEST_NOT_ENDED();

        // Set initial balance if not already set
        if (initialPayoutBalance == 0) {
            uint256 contractBalance = address(this).balance;

            // if there's no balance to pay, don't let contest payout go through
            if (contractBalance == 0) revert NO_BALANCE_TO_PAYOUT();

            // store balance to pay out
            initialPayoutBalance = contractBalance;
        }

        // pay out _payoutCount winners
        for (uint256 i = 0; i < _payoutCount; i++) {
            // if the contest is paid out - break
            if (paidOut) break;
            // while the contract has balance and the contest has not been fully paid out
            payoutNextSubmission();
        }
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
    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner whenPaused {
        // Ensure the new implementation is registered by the Builder DAO
        if (!manager.isRegisteredUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
