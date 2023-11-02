// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title MaxHeap implementation in Solidity
/// @dev This contract implements a Max Heap data structure with basic operations
/// @author Written by rocketman and gpt4
contract MaxHeap {
    struct Item {
        uint256 itemId;
        uint256 voteCount;
    }
    mapping(uint256 => Item) public heap;
    uint256 public size = 0;
    uint256 public maxsize;

    /// @notice Constructor to initialize the MaxHeap
    /// @param _maxsize The maximum size of the heap
    constructor(uint256 _maxsize) {
        maxsize = _maxsize;
    }

    /// @notice Get the parent index of a given position
    /// @param pos The position for which to find the parent
    /// @return The index of the parent node
    function parent(uint256 pos) private pure returns (uint256) {
        require(pos != 0, "Position should not be zero");
        return (pos - 1) / 2;
    }

    /// @notice Swap two nodes in the heap
    /// @param fpos The position of the first node
    /// @param spos The position of the second node
    function swap(uint256 fpos, uint256 spos) private {
        Item memory temp = heap[fpos];
        heap[fpos] = heap[spos];
        heap[spos] = temp;
    }

    /// @notice Reheapify the heap starting at a given position
    /// @dev This ensures that the heap property is maintained
    /// @param pos The starting position for the heapify operation
    function maxHeapify(uint256 pos) public {
        uint256 left = 2 * pos + 1;
        uint256 right = 2 * pos + 2;

        if (pos >= (size / 2) && pos <= size) return;

        if (heap[pos].voteCount < heap[left].voteCount || heap[pos].voteCount < heap[right].voteCount) {
            if (heap[left].voteCount > heap[right].voteCount) {
                swap(pos, left);
                maxHeapify(left);
            } else {
                swap(pos, right);
                maxHeapify(right);
            }
        }
    }

    /// @notice Insert an element into the heap
    /// @dev The function will revert if the heap is full
    /// @param itemId The item ID to insert
    /// @param voteCount The vote count to insert
    function insert(uint256 itemId, uint256 voteCount) public {
        require(size < maxsize, "Heap is full");

        Item memory newItem = Item(itemId, voteCount);
        heap[size] = newItem;

        uint256 current = size;
        while (current != 0 && heap[current].voteCount > heap[parent(current)].voteCount) {
            swap(current, parent(current));
            current = parent(current);
        }
        size++;
    }

    /// @notice Extract the maximum element from the heap
    /// @dev The function will revert if the heap is empty
    /// @return The maximum element from the heap
    function extractMax() public returns (uint256, uint256) {
        require(size > 0, "Heap is empty");

        Item memory popped = heap[0];
        heap[0] = heap[--size];
        maxHeapify(0);

        return (popped.itemId, popped.voteCount);
    }

    /// @notice Get the maximum element from the heap
    /// @dev The function will revert if the heap is empty
    /// @return The maximum element from the heap
    function getMax() public view returns (uint256, uint256) {
        require(size > 0, "Heap is empty");
        return (heap[0].itemId, heap[0].voteCount);
    }
}

contract MaxHeapTest is MaxHeap {
    constructor(uint256 _maxsize) MaxHeap(_maxsize) {}

    /// @notice Function to set a value in the heap (ONLY FOR TESTING)
    /// @param pos The position to set
    /// @param value The value to set at the given position
    function _set(uint256 pos, uint256 itemId, uint256 value) public {
        heap[pos] = Item(itemId, value);
    }
}
