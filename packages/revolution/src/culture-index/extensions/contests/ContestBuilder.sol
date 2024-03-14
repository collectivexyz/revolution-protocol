// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

/// @title The Revolution builder contract

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
// RevolutionBuilder.sol is a modified version of Nouns Builder's Manager.sol:
// https://github.com/ourzora/nouns-protocol/blob/82e00ed34dd9b7c9e1ac5eea29f7f713d1084e68/src/manager/Manager.sol
//
// Manager.sol source code under the MIT license.

import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import { ICultureIndex } from "../../../interfaces/ICultureIndex.sol";
import { IMaxHeap } from "../../../interfaces/IMaxHeap.sol";
import { IRevolutionBuilder } from "../../../interfaces/IRevolutionBuilder.sol";
import { IContestBuilder } from "./IContestBuilder.sol";
import { IBaseContest } from "./IBaseContest.sol";

import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { UUPS } from "@cobuild/utility-contracts/src/proxy/UUPS.sol";
import { IVersionedContract } from "@cobuild/utility-contracts/src/interfaces/IVersionedContract.sol";
import { ISplitMain } from "@cobuild/splits/src/interfaces/ISplitMain.sol";
import { RevolutionVersion } from "../../../version/RevolutionVersion.sol";

/// @title ContestBuilder
/// @notice The Contest deployer and upgrade manager
contract ContestBuilder is IContestBuilder, RevolutionVersion, UUPS, Ownable2StepUpgradeable {
    /// @notice If a contract has been registered as an upgrade
    /// @dev Base impl => Upgrade impl
    mapping(address => mapping(address => bool)) internal isUpgrade;

    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The cultureIndex implementation address
    address public immutable cultureIndexImpl;

    /// @notice The maxHeap implementation address
    address public immutable maxHeapImpl;

    /// @notice The base contest implementation address
    address public immutable baseContestImpl;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    constructor(
        address _baseContestImpl,
        CultureIndexImplementations memory _cultureIndexImplementations
    ) payable initializer {
        cultureIndexImpl = _cultureIndexImplementations.cultureIndex;
        maxHeapImpl = _cultureIndexImplementations.maxHeap;
        baseContestImpl = _baseContestImpl;
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Initializes ownership of the manager contract
    /// @param _newOwner The owner address to set (will be transferred to the Revolution DAO once its deployed)
    function initialize(address _newOwner) external initializer {
        // Ensure an owner is specified
        if (_newOwner == address(0)) revert INVALID_ZERO_ADDRESS();

        // Set the contract owner
        __Ownable_init(_newOwner);
    }

    ///                                                          ///
    ///                        CONTEST DEPLOY                    ///
    ///                                                          ///

    /// @notice Deploys a culture index for a given token
    /// @param initialOwner The initial owner address
    /// @param weth The WETH address
    /// @param votingPower The voting power address
    /// @param splitMain The split main address
    /// @param builderReward The builder reward address
    /// @param cultureIndexParams The CultureIndex settings
    /// @param baseContestParams The BaseContest settings
    /// @return baseContest The deployed contest address
    /// @return cultureIndex The deployed culture index address
    /// @return maxHeap The deployed max heap address
    function deployBaseContest(
        address initialOwner,
        address weth,
        address votingPower,
        address splitMain,
        address builderReward,
        IRevolutionBuilder.CultureIndexParams calldata cultureIndexParams,
        IBaseContest.BaseContestParams calldata baseContestParams
    ) external override returns (address baseContest, address cultureIndex, address maxHeap) {
        cultureIndex = address(new ERC1967Proxy(cultureIndexImpl, ""));
        maxHeap = address(new ERC1967Proxy(maxHeapImpl, ""));
        baseContest = address(new ERC1967Proxy(baseContestImpl, ""));

        IBaseContest(baseContest).initialize({
            initialOwner: initialOwner,
            splitMain: splitMain,
            cultureIndex: cultureIndex,
            builderReward: builderReward,
            weth: weth,
            contestParams: baseContestParams
        });

        // ICultureIndex(cultureIndex).initialize({
        //     votingPower: votingPower,
        //     initialOwner: initialOwner,
        //     // ensure the contest can drop pieces from the culture index
        //     dropperAdmin: baseContest,
        //     cultureIndexParams: cultureIndexParams,
        //     maxHeap: maxHeap
        // });

        // IMaxHeap(maxHeap).initialize({ initialOwner: initialOwner, admin: cultureIndex });

        emit BaseContestDeployed(baseContest, cultureIndex, maxHeap, votingPower);

        return (baseContest, cultureIndex, maxHeap);
    }

    ///                                                          ///
    ///                         CULTURE INDEX                    ///
    ///                                                          ///

    /// @notice Deploys a culture index for a given token
    /// @param votingPower The voting power address
    /// @param initialOwner The initial owner address
    /// @param dropperAdmin The dropper admin address
    /// @param cultureIndexParams The CultureIndex settings
    /// @return cultureIndex The deployed culture index address
    /// @return maxHeap The deployed max heap address
    function deployCultureIndex(
        address votingPower,
        address initialOwner,
        address dropperAdmin,
        IRevolutionBuilder.CultureIndexParams calldata cultureIndexParams
    ) external override returns (address cultureIndex, address maxHeap) {
        cultureIndex = address(new ERC1967Proxy(cultureIndexImpl, ""));
        maxHeap = address(new ERC1967Proxy(maxHeapImpl, ""));

        ICultureIndex(cultureIndex).initialize({
            votingPower: votingPower,
            initialOwner: initialOwner,
            dropperAdmin: dropperAdmin,
            cultureIndexParams: cultureIndexParams,
            maxHeap: maxHeap
        });

        IMaxHeap(maxHeap).initialize({ initialOwner: initialOwner, admin: cultureIndex });

        emit CultureIndexDeployed(cultureIndex, maxHeap, votingPower);

        return (cultureIndex, maxHeap);
    }

    ///                                                          ///
    ///                          DAO UPGRADES                    ///
    ///                                                          ///

    /// @notice If an implementation is registered by the Revolution DAO as an optional upgrade
    /// @param _baseImpl The base implementation address
    /// @param _upgradeImpl The upgrade implementation address
    function isRegisteredUpgrade(address _baseImpl, address _upgradeImpl) external view returns (bool) {
        return isUpgrade[_baseImpl][_upgradeImpl];
    }

    /// @notice Called by the Revolution DAO to offer implementation upgrades for created DAOs
    /// @param _baseImpl The base implementation address
    /// @param _upgradeImpl The upgrade implementation address
    function registerUpgrade(address _baseImpl, address _upgradeImpl) external onlyOwner {
        isUpgrade[_baseImpl][_upgradeImpl] = true;

        emit UpgradeRegistered(_baseImpl, _upgradeImpl);
    }

    /// @notice Called by the Revolution DAO to remove an upgrade
    /// @param _baseImpl The base implementation address
    /// @param _upgradeImpl The upgrade implementation address
    function removeUpgrade(address _baseImpl, address _upgradeImpl) external onlyOwner {
        delete isUpgrade[_baseImpl][_upgradeImpl];

        emit UpgradeRemoved(_baseImpl, _upgradeImpl);
    }

    /// @notice Safely get the contract version of a target contract.
    /// @dev Assume `target` is a contract
    /// @return Contract version if found, empty string if not.
    function _safeGetVersion(address target) internal view returns (string memory) {
        try IVersionedContract(target).contractVersion() returns (string memory version) {
            return version;
        } catch {
            return "";
        }
    }

    ///                                                          ///
    ///                         MANAGER UPGRADE                  ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {}
}
