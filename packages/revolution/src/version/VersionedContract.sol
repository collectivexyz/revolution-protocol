// This file is automatically generated by code; do not manually update
// Last updated on 2024-01-12T01:46:22.308Z
// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { IVersionedContract } from "../interfaces/IVersionedContract.sol";

/// @title VersionedContract
/// @notice Base contract for versioning contracts
contract VersionedContract is IVersionedContract {
    /// @notice The version of the contract
    function contractVersion() external pure override returns (string memory) {
        return "0.3.4";
    }
}
