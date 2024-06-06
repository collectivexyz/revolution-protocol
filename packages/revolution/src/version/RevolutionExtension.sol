// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { IRevolutionExtension } from "@cobuild/utility-contracts/src/interfaces/IRevolutionExtension.sol";

/// @title RevolutionExtension
/// @notice Base contract for defining extension contract types
contract RevolutionExtension is IRevolutionExtension {
    error INVALID_EXTENSION_TYPE();

    string public extensionType;

    /**
     * @dev Initializes the extension type.
     *
     * - `_extensionType`: the user readable name of the extension.
     *
     */
    constructor(string memory _extensionType) payable {
        if (bytes(_extensionType).length == 0) revert INVALID_EXTENSION_TYPE();

        extensionType = _extensionType;
    }

    /// @notice The version of the contract
    function contractExtensionType() external view override returns (string memory) {
        return extensionType;
    }
}
