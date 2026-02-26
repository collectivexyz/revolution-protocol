// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { RevolutionBuilderTypesV1 } from "../types/RevolutionBuilderTypesV1.sol";

/// @notice RevolutionBuilder Storage V1
/// @author Rohan Kulkarni
/// @notice The Manager storage contract
contract RevolutionBuilderStorageV1 is RevolutionBuilderTypesV1 {
    /// @notice If a contract has been registered as an upgrade
    /// @dev Base impl => Upgrade impl
    mapping(address => mapping(address => bool)) internal isUpgrade;

    /// @notice Registers deployed addresses
    /// @dev Token deployed address => Struct of all other DAO addresses
    mapping(address => DAOAddresses) internal daoAddressesByToken;

    ///                                                          ///
    ///                   EXTENSION IMPLEMENTATIONS              ///
    ///                                                          ///

    /// @notice Registered implementations for extensions
    /// @dev Extension name => Implementation type => Implementation address
    mapping(string => mapping(ImplementationType => address)) internal extensionImpls;

    /// @notice Registered builder rewards addresses
    /// @dev Extension name => Builder rewards address
    mapping(string => address) internal builderRewards;

    /// @notice Registered extensions by token
    /// @dev Token address => Extension name
    mapping(address => string) internal extensionByToken;

    /// @notice Is the extension registered
    /// @dev Extension name => Validity
    mapping(string => bool) internal isExtension;
}
