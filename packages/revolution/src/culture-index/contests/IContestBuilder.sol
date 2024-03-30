// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";
import { IRevolutionBuilder } from "../../interfaces/IRevolutionBuilder.sol";
import { IBaseContest } from "./IBaseContest.sol";

/// @title IContestBUilder
/// @notice The external ContestBuilder events, errors, structs and functions
interface IContestBuilder is IUpgradeManager {
    struct CultureIndexImplementations {
        address cultureIndex;
        address maxHeap;
    }

    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when an upgrade is registered by the Builder DAO
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    event UpgradeRegistered(address baseImpl, address upgradeImpl);

    /// @notice Emitted when an upgrade is unregistered by the Builder DAO
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    event UpgradeRemoved(address baseImpl, address upgradeImpl);

    /// @notice Emitted when a culture index is deployed
    /// @param cultureIndex The culture index address
    /// @param maxHeap The max heap address
    /// @param votingPower The voting power address
    event CultureIndexDeployed(address cultureIndex, address maxHeap, address votingPower);

    /// @notice Emitted when a contest is deployed
    /// @param contest The contest address
    /// @param cultureIndex The culture index address
    /// @param maxHeap The max heap address
    /// @param votingPower The voting power address
    event BaseContestDeployed(address contest, address cultureIndex, address maxHeap, address votingPower);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @notice The error message when invalid address zero is passed
    error INVALID_ZERO_ADDRESS();

    ///                                                          ///
    ///                            STRUCTS                       ///
    ///                                                          ///

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    /// @notice The cultureIndex implementation address
    function cultureIndexImpl() external view returns (address);

    /// @notice The maxHeap implementation address
    function maxHeapImpl() external view returns (address);

    /// @notice Deploys a culture index
    /// @param votingPower The voting power contract
    /// @param initialOwner The initial owner address
    /// @param dropperAdmin The address who can remove pieces from the culture index
    /// @param cultureIndexParams The CultureIndex settings
    function deployCultureIndex(
        address votingPower,
        address initialOwner,
        address dropperAdmin,
        IRevolutionBuilder.CultureIndexParams calldata cultureIndexParams
    ) external returns (address, address);

    /// @notice Deploys a contest
    /// @param initialOwner The initial owner address
    /// @param weth The WETH address
    /// @param votingPower The voting power contract
    /// @param splitMain The SplitMain contract
    /// @param builderReward The builder reward address
    /// @param cultureIndexParams The CultureIndex settings
    /// @param baseContestParams The BaseContest settings
    function deployBaseContest(
        address initialOwner,
        address weth,
        address votingPower,
        address splitMain,
        address builderReward,
        IRevolutionBuilder.CultureIndexParams calldata cultureIndexParams,
        IBaseContest.BaseContestParams calldata baseContestParams
    ) external returns (address, address, address);

    /// @notice Initializes the Revolution builder contract
    /// @param initialOwner The address of the initial owner
    function initialize(address initialOwner) external;
}
