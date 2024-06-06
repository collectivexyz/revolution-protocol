// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { IUUPS } from "../interfaces/IUUPS.sol";

/// @title IUpgradeManager
/// @notice The external manager of upgrades for Revolution DAOs
interface IUpgradeManager is IUUPS {
    /// @notice If an implementation is registered by the DAO as an optional upgrade
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    function isRegisteredUpgrade(address baseImpl, address upgradeImpl) external view returns (bool);

    /// @notice Called by the DAO to offer opt-in implementation upgrades for all other DAOs
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    function registerUpgrade(address baseImpl, address upgradeImpl) external;

    /// @notice Called by the DAO to remove an upgrade
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    function removeUpgrade(address baseImpl, address upgradeImpl) external;
}
