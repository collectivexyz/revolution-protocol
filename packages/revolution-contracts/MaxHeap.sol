// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title MaxHeap implementation in Solidity
/// @dev This contract implements a Max Heap data structure with basic operations
/// @author Written by rocketman and gpt4
contract MaxHeap {
    mapping(uint256 => uint) public heap;
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
        uint256 temp = heap[fpos];
        heap[fpos] = heap[spos];
        heap[spos] = temp;
    }

    /// @notice Reheapify the heap starting at a given position
    /// @dev This ensures that the heap property is maintained
    /// @param pos The starting position for the heapify operation
    function maxHeapify(uint256 pos) public {
        uint256 left = 2 * pos + 1;
        uint256 right = 2 * pos + 2;
        
        // Check if the position is a leaf node
        if (pos >= (size / 2) && pos <= size) return;

        // Check if the current node is smaller than either of its children
        if (heap[pos] < heap[left] || heap[pos] < heap[right]) {
            
            // Swap with the largest child and recurse
            if (heap[left] > heap[right]) {
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
    /// @param element The element to insert
    function insert(uint256 element) public {
        require(size < maxsize, "Heap is full");
        heap[size] = element;

        uint256 current = size;
        while (current != 0 && heap[current] > heap[parent(current)]) {
            swap(current, parent(current));
            current = parent(current);
        }
        size++;
    }

    /// @notice Extract the maximum element from the heap
    /// @dev The function will revert if the heap is empty
    /// @return The maximum element from the heap
    function extractMax() public returns (uint256) {
        require(size > 0, "Heap is empty");
        uint256 popped = heap[0];
        heap[0] = heap[--size];
        maxHeapify(0);
        return popped;
    }

    /// @notice Get the maximum element from the heap
    /// @dev The function will revert if the heap is empty
    /// @return The maximum element from the heap
    function getMax() public view returns (uint256) {
        require(size > 0, "Heap is empty");
        return heap[0];
    }
}

contract MaxHeapTest is MaxHeap {
    constructor(uint256 _maxsize) MaxHeap(_maxsize) {}

    /// @notice Function to set a value in the heap (ONLY FOR TESTING)
    /// @param pos The position to set
    /// @param value The value to set at the given position
    function _set(uint256 pos, uint256 value) public {
        heap[pos] = value;
    }
}