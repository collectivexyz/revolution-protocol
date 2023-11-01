// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {MaxHeapTest} from "../packages/revolution-contracts/MaxHeap.sol";  // Update this path

contract MaxHeapTestSuite is Test {
    MaxHeapTest public maxHeap;

    function setUp() public {
        maxHeap = new MaxHeapTest(50);
    }

    function testInsert() public {
        setUp();

        // Insert values into the max heap
        maxHeap.insert(5);
        maxHeap.insert(7);
        maxHeap.insert(3);

        // Validate the max value
        uint256 maxValue = maxHeap.getMax();
        assertEq(maxValue, 7, "Max value should be 7");
    }

    function testRemoveMax() public {
        setUp();

        // Insert and then remove max
        maxHeap.insert(5);
        maxHeap.insert(7);
        maxHeap.insert(3);
        maxHeap.extractMax();

        // Validate the new max value
        uint256 newMaxValue = maxHeap.getMax();
        assertEq(newMaxValue, 5, "New max value should be 5");
    }

    function testHeapify() public {
        setUp();

        // Insert values and manually violate the heap property
        maxHeap.insert(5);
        maxHeap.insert(7);
        maxHeap.insert(15);
        maxHeap.insert(3);
        //set max to 2
        maxHeap._set(0, 2);  // Assume a '_set' function for testing

        // Run heapify from the root
        maxHeap.maxHeapify(0);

        // Validate the max value
        uint256 correctedMaxValue = maxHeap.getMax();
        assertEq(correctedMaxValue, 7, "Max value should be 7");
    }

    function testInsertDuplicateValues() public {
        setUp();
        maxHeap.insert(5);
        maxHeap.insert(5);
        maxHeap.insert(5);
        assertEq(maxHeap.getMax(), 5, "Max value should still be 5");
        assertEq(maxHeap.size(), 3, "Size should be 3");
    }

    function testHeapEmptyAfterAllRemoved() public {
        setUp();
        maxHeap.insert(5);
        maxHeap.insert(7);
        maxHeap.extractMax();
        maxHeap.extractMax();
        assertEq(maxHeap.size(), 0, "Heap should be empty");
    }

    function testHeapProperty() public {
        setUp();
        uint256[] memory values = new uint256[](6);
        values[0] = 4;
        values[1] = 7;
        values[2] = 15;
        values[3] = 9;
        values[4] = 10;
        values[5] = 20;
        for (uint256 i = 0; i < values.length; i++) {
            maxHeap.insert(values[i]);
        }
        
        uint256 lastVal = type(uint256).max;  // Start with the maximum uint256 value
        while(maxHeap.size() > 0) {
            uint256 val = maxHeap.extractMax();
            assertTrue(val <= lastVal, "Heap property violated");
            lastVal = val;
        }
    }

    function testHeapifyOnNonRoot() public {
        setUp();
        maxHeap.insert(10);
        maxHeap.insert(15);
        maxHeap.insert(5);
        maxHeap.insert(12);
        maxHeap._set(1, 4);  // Assume a '_set' function for testing
        maxHeap.maxHeapify(1);
        assertEq(maxHeap.heap(1), 10, "Value should be 10 after heapify");
    }

    function testCannotInsertWhenFull() public {
        setUp();

        // Fill the heap to its max size
        for(uint i = 0; i < maxHeap.maxsize(); i++) {
            maxHeap.insert(i);
        }

        // Try to insert again and expect to fail
        try maxHeap.insert(100) {
            fail("Should not be able to insert when heap is full");
        } catch Error(string memory reason) {
            assertEq(reason, "Heap is full");
        }
    }

    function testCannotRemoveMaxWhenEmpty() public {
        setUp();

        // Try to remove max and expect to fail
        try maxHeap.extractMax() {
            fail("Should not be able to remove max when heap is empty");
        } catch Error(string memory reason) {
            assertEq(reason, "Heap is empty");
        }
    }
}
