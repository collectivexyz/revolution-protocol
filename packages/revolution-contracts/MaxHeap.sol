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
        //isLeaf
        if (pos < size && pos > (size / 2)) return;

        uint256 left = 2 * pos + 1;
        uint256 right = 2 * pos + 2;


        uint256 currentValue = heap[pos];
        uint256 leftValue = heap[left];
        uint256 rightValue = heap[right];

        if (currentValue < leftValue || currentValue < rightValue) {
            uint256 largest = (leftValue > rightValue) ? left : right;
            swap(pos, largest);
            maxHeapify(largest);
        }

    }

    /// @notice Insert an element into the heap
    /// @dev The function will revert if the heap is full
    /// @param element The element to insert
    function insert(uint256 element) public {
        require(size < maxsize, "Heap is full");
        heap[size] = element;

        uint256 current = size;
        while (heap[current] > heap[parent(current)]) {
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
}
