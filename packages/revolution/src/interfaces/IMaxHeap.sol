// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

interface IMaxHeap {
    /**
     * @notice Initializes the maxheap contract
     * @param initialOwner The initial owner of the contract
     * @param admin The contract that is allowed to update the data store
     */
    function initialize(address initialOwner, address admin) external;

    /**
     * @notice Returns the size of the max heap, the number of non-removed items
     * @return size The size of the max heap
     */
    function size() external view returns (uint256);
}
