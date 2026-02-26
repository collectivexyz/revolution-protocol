// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { IRevolutionBuilder } from "./IRevolutionBuilder.sol";

interface IGrantsRevenueStream {
    ///                                                          ///
    ///                       FUNCTIONS                          ///
    ///                                                          ///

    function setGrantsRateBps(uint256 grantsRateBps) external;

    function grantsRateBps() external view returns (uint256);

    function grantsAddress() external view returns (address);

    function setGrantsAddress(address grants) external;

    event GrantsAddressUpdated(address grants);

    event GrantsRateBpsUpdated(uint256 rateBps);
}
