// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

interface IRevolutionExtension {
    function contractExtensionType() external view returns (string memory);
}
