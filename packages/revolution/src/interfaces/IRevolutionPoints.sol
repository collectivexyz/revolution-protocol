// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { IRevolutionBuilder } from "./IRevolutionBuilder.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRevolutionPoints is IERC20, IVotes {
    ///                                                          ///
    ///                           EVENTS                         ///
    ///                                                          ///

    event MinterUpdated(address minter);

    event MinterLocked();

    ///                                                          ///
    ///                           ERRORS                         ///
    ///                                                          ///

    /// @dev Revert if transfer is attempted. This is a nontransferable token.
    error TRANSFER_NOT_ALLOWED();

    /// @dev Revert if not the manager
    error ONLY_MANAGER();

    /// @dev Revert if 0 address
    error INVALID_ADDRESS_ZERO();

    /// @dev Revert if minter is locked
    error MINTER_LOCKED();

    /// @dev Revert if not minter
    error NOT_MINTER();

    ///                                                          ///
    ///                         FUNCTIONS                        ///
    ///                                                          ///

    function minter() external view returns (address);

    function setMinter(address minter) external;

    function lockMinter() external;

    function mint(address account, uint256 amount) external;

    function decimals() external view returns (uint8);

    /// @notice Initializes a DAO's ERC-20 governance token contract
    /// @param initialOwner The address of the initial owner
    /// @param minter The address of the minter
    /// @param tokenParams The params of the token
    function initialize(
        address initialOwner,
        address minter,
        IRevolutionBuilder.PointsTokenParams calldata tokenParams
    ) external;
}
