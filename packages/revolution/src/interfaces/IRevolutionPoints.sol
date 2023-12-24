// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IRevolutionBuilder } from "./IRevolutionBuilder.sol";

interface IRevolutionPoints {
    /// @notice Initializes a DAO's ERC-20 governance token contract
    /// @param initialOwner The address of the initial owner
    /// @param revolutionPointsParams The params of the token
    function initialize(address initialOwner, IRevolutionBuilder.PointsParams calldata revolutionPointsParams) external;
}
