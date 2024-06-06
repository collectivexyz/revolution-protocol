// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

interface IVersionedContract {
    function contractVersion() external view returns (string memory);
}
