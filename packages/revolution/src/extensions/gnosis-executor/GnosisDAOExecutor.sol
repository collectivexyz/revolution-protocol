// SPDX-License-Identifier: BSD-3-Clause

/// @title The Revolution DAO executor

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

// LICENSE
// DAOExecutor.sol is a modified version of Compound Lab's Timelock.sol:
// https://github.com/compound-finance/compound-protocol/blob/20abad28055a2f91df48a90f8bb6009279a4cb35/contracts/Timelock.sol
//
// Timelock.sol source code Copyright 2020 Compound Labs, Inc. licensed under the BSD-3-Clause license.
// With modifications by Nounders DAO.
//
// Additional conditions of BSD-3-Clause can be found here: https://opensource.org/licenses/BSD-3-Clause
//
// MODIFICATIONS
// DAOExecutor.sol modifies Timelock to use Solidity 0.8.x receive(), fallback(), and built-in over/underflow protection
// This contract forwards all transactions on to an Avatar contract (like a Safe).

pragma solidity ^0.8.22;

import { UUPS } from "@cobuild/utility-contracts/src/proxy/UUPS.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IAvatar } from "@gnosis.pm/zodiac/contracts/interfaces/IAvatar.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { RevolutionVersion } from "../../version/RevolutionVersion.sol";
import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";
import { RevolutionExtension } from "../../version/RevolutionExtension.sol";
import { IDAOExecutor } from "../../interfaces/IDAOExecutor.sol";

contract GnosisDAOExecutor is IDAOExecutor, Initializable, RevolutionVersion, UUPS, RevolutionExtension {
    event NewAdmin(address indexed newAdmin);
    event NewAvatar(address indexed avatar);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    address public admin;
    address public avatar;
    address public pendingAdmin;
    uint256 public delay;

    mapping(bytes32 => bool) public queuedTransactions;

    // @notice Struct to hold the init params for the executor extension
    struct InitializeData {
        address avatar;
    }

    ///                                                          ///
    ///                         IMMUTABLES                       ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IUpgradeManager public immutable manager;

    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MINIMUM_DELAY = 2 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;

    ///                                                          ///
    ///                          MODIFIERS                       ///
    ///                                                          ///

    modifier onlyAvatar() {
        require(msg.sender == avatar, "DAOExecutor::onlyAvatar: Only avatar may call this function.");
        _;
    }

    ///                                                          ///
    ///                         CONSTRUCTOR                      ///
    ///                                                          ///

    /// @param _manager The contract upgrade manager address
    constructor(address _manager) payable RevolutionExtension("gnosis.guild.executor.1") initializer {
        manager = IUpgradeManager(_manager);
    }

    ///                                                          ///
    ///                         INITIALIZER                      ///
    ///                                                          ///

    /// @notice Initializes an instance of a DAO's treasury
    /// @param _admin The DAO's address
    /// @param _timelockDelay The time delay to execute a queued transaction
    /// @param _data The data to be decoded
    /// @custom:data (_avatar address)
    function initialize(address _admin, uint256 _timelockDelay, bytes memory _data) external initializer {
        InitializeData memory initData = abi.decode(_data, (InitializeData));

        require(_timelockDelay >= MINIMUM_DELAY, "DAOExecutor::constructor: Delay must exceed minimum delay.");
        require(_timelockDelay <= MAXIMUM_DELAY, "DAOExecutor::setDelay: Delay must not exceed maximum delay.");

        require(msg.sender == address(manager), "Only manager can initialize");

        // ensure the avatar is not the zero address
        require(initData.avatar != address(0), "DAOExecutor::initialize: Avatar cannot be zero address");

        // Ensure a governor address was provided
        require(_admin != address(0), "DAOExecutor::initialize: Governor cannot be zero address");

        admin = _admin;
        delay = _timelockDelay;
        avatar = initData.avatar;
    }

    function setDelay(uint256 delay_) public {
        require(msg.sender == address(this), "DAOExecutor::setDelay: Call must come from DAOExecutor.");
        require(delay_ >= MINIMUM_DELAY, "DAOExecutor::setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "DAOExecutor::setDelay: Delay must not exceed maximum delay.");
        delay = delay_;

        emit NewDelay(delay);
    }

    function acceptAdmin() public {
        require(msg.sender == pendingAdmin, "DAOExecutor::acceptAdmin: Call must come from pendingAdmin.");
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    function setPendingAdmin(address pendingAdmin_) public {
        require(msg.sender == address(this), "DAOExecutor::setPendingAdmin: Call must come from DAOExecutor.");
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

    function setAvatar(address _avatar) public onlyAvatar {
        avatar = _avatar;

        emit NewAvatar(_avatar);
    }

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public returns (bytes32) {
        require(msg.sender == admin, "DAOExecutor::queueTransaction: Call must come from admin.");
        require(
            eta >= getBlockTimestamp() + delay,
            "DAOExecutor::queueTransaction: Estimated execution block must satisfy delay."
        );

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public {
        require(msg.sender == admin, "DAOExecutor::cancelTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public returns (bytes memory) {
        require(msg.sender == admin, "DAOExecutor::executeTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "DAOExecutor::executeTransaction: Transaction hasn't been queued.");
        require(getBlockTimestamp() >= eta, "DAOExecutor::executeTransaction: Transaction hasn't surpassed time lock.");
        require(getBlockTimestamp() <= eta + GRACE_PERIOD, "DAOExecutor::executeTransaction: Transaction is stale.");

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = IAvatar(avatar).execTransactionFromModuleReturnData(
            target,
            value,
            callData,
            Enum.Operation.Call
        );
        require(success, "DAOExecutor::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    function getBlockTimestamp() internal view returns (uint256) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }

    ///                                                          ///
    ///                       EXECUTOR UPGRADE                   ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract and that the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal view override {
        // Ensure the caller is the treasury itself
        require(msg.sender == address(this), "DAOExecutor::_authorizeUpgrade: Caller must be the DAOExecutor");

        // Ensure the new implementation is a registered upgrade
        if (!manager.isRegisteredUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
