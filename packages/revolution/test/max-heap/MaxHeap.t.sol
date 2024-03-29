// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { MaxHeap } from "../../src/culture-index/MaxHeap.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";

/// @title MaxHeapTestSuite
/// @dev The test suite for the MaxHeap contract
contract MaxHeapTestSuite is RevolutionBuilderTest {
    MaxHeapTester public maxHeapTester;

    /// @dev Sets up a new MaxHeap instance before each test
    function setUp() public override {
        super.setUp();

        super.setMockParams();

        super.deployMock();

        address maxHeapTesterImpl = address(new MaxHeapTester(address(this)));

        address maxHeapTesterAddr = address(new ERC1967Proxy(maxHeapTesterImpl, ""));

        MaxHeapTester(maxHeapTesterAddr).initialize(address(dao), address(cultureIndex));

        maxHeapTester = MaxHeapTester(maxHeapTesterAddr);

        vm.startPrank(address(cultureIndex));
    }

    function testOldHeapEntriesNotRemoved() public {
        //this was a test case to evoke an error from previously bad contract logic as found in the C4_audit_0

        uint256 popped;
        uint256 value;

        maxHeap.insert(0, 100);
        maxHeap.insert(1, 50);
        maxHeap.insert(2, 25);
        //size == 3
        /*
            0 (100)
            /     \
         1 (50)   2 (25)
        */
        // heap contains 3 items; we extract maximum one
        (popped, value) = maxHeap.extractMax();
        assertEq(popped, 0, "Popped should be 0 after extracting max");
        assertEq(value, 100, "Value should be 100 after extracting max");

        //size == 2
        /*
             1 (50)
            /      -
          2 (25)   2 (25)
        */
        // heap contains 2 items; we decrease value of 1 and in effect, 1 is removed from the heap
        maxHeap.updateValue(1, 1);
        /*
              2 (25)
             /     - 
          2 (25)   1 (1)
        */
        (popped, value) = maxHeap.extractMax();
        assertEq(popped, 2, "Popped should be 2 after extracting max");
        assertEq(value, 25, "Value should be 25 after extracting max");
        /*
            2
           - -
          2   1
        */

        // Ensure 2 will not be the maximum value for the second time
        (popped, value) = maxHeap.extractMax();
        // assert(popped == 1 && value == 1);
        assertEq(popped, 1, "Popped should be 1 after extracting max");
        assertEq(value, 1, "Value should be 1 after extracting max");
    }

    function testOldHeapEntriesNotRemove2() public {
        //this was a test case to evoke an error from previously bad contract logic as found in the C4_audit_0

        uint256 popped;
        uint256 value;

        maxHeap.insert(0, 50);
        maxHeap.insert(1, 100);
        maxHeap.insert(2, 25);
        //size == 3
        // heap contains 3 items; we extract maximum one
        (popped, value) = maxHeap.extractMax();
        assertEq(popped, 1, "Popped should be 1 after extracting max");
        assertEq(value, 100, "Value should be 100 after extracting max");

        //size == 2
        // heap contains 2 items; we decrease value of 1 and in effect, 1 is removed from the heap
        maxHeap.updateValue(0, 1);
        (popped, value) = maxHeap.extractMax();
        assertEq(popped, 2, "Popped should be 2 after extracting max");
        assertEq(value, 25, "Value should be 25 after extracting max");

        // Ensure 2 will not be the maximum value for the second time
        (popped, value) = maxHeap.extractMax();
        // assert(popped == 1 && value == 1);
        assertEq(popped, 0, "Popped should be 0 after extracting max");
        assertEq(value, 1, "Value should be 1 after extracting max");
    }

    /// @dev Tests that only the owner can call updateValue
    function testUpdateValueOnlyOwner() public {
        maxHeap.insert(1, 10); // Setup a state with an element

        address nonOwner = address(2);
        vm.startPrank(nonOwner);
        bool hasErrored = false;
        try maxHeap.updateValue(1, 20) {
            fail("updateValue should be callable only by the owner");
        } catch {
            hasErrored = true;
        }
        assertTrue(hasErrored, "updateValue should have errored");

        vm.startPrank(address(cultureIndex));
        maxHeap.updateValue(1, 20); // No error expected
    }

    /// @dev Tests that only the owner can call insert
    function testInsertOnlyOwner() public {
        vm.stopPrank();
        address nonOwner = address(3);
        vm.startPrank(nonOwner);
        bool hasErrored = false;
        try maxHeap.insert(2, 15) {
            fail("insert should be callable only by the owner");
        } catch {
            hasErrored = true;
        }
        assertTrue(hasErrored, "insert should have errored");

        vm.startPrank(address(cultureIndex));
        maxHeap.insert(2, 15); // No error expected
    }

    /// @dev Tests that only the owner can call extractMax
    function testExtractMaxOnlyOwner() public {
        // Insert an element to ensure the heap is not empty
        maxHeap.insert(1, 10);

        // Try to call extractMax as a non-owner and expect it to fail
        address nonOwner = address(2); // assume this address is not the owner
        vm.startPrank(nonOwner); // this sets the next call to be from the address `nonOwner`
        bool hasErrored = false;
        try maxHeap.extractMax() {
            fail("extractMax should only be callable by the owner");
        } catch {
            hasErrored = true;
        }

        assertTrue(hasErrored, "extractMax should have errored");

        // Call extractMax as the owner and expect it to succeed
        vm.startPrank(address(cultureIndex)); // set the owner to be the caller for the next transaction
        maxHeap.extractMax(); // this should succeed without reverting
    }

    /// @dev Tests the insert and getMax functions
    function testInsert() public {
        // Insert values into the max heap
        maxHeap.insert(1, 5);
        maxHeap.insert(2, 7);
        maxHeap.insert(3, 3);

        // Validate the max value
        (uint256 maxItemId, uint256 maxValue) = maxHeap.getMax();
        assertEq(maxValue, 7, "Max value should be 7");
        assertEq(maxItemId, 2, "Max piece ID should be 2");
    }

    /// @dev Tests the extractMax function and validates the new max value
    function testRemoveMax() public {
        // Insert and then remove max
        maxHeap.insert(1, 5);
        maxHeap.insert(2, 7);
        maxHeap.insert(3, 3);
        maxHeap.extractMax();

        // Validate the new max value
        (uint256 maxItemId, uint256 maxValue) = maxHeap.getMax();
        assertEq(maxValue, 5, "New max value should be 5");
        assertEq(maxItemId, 1, "New max piece ID should be 1");
    }

    /// @dev Tests the maxHeapify function to ensure it corrects the heap property
    function testHeapify() public {
        // Insert values and manually violate the heap property
        maxHeapTester.insert(1, 5);
        maxHeapTester.insert(2, 7);
        maxHeapTester.insert(3, 15);
        maxHeapTester.insert(4, 3);
        //set max to [10,2]
        maxHeapTester._set(0, 10, 2); // Assume a '_set' function for testing

        // Run heapify from the root
        maxHeapTester.maxHeapifyTest(0);

        // Validate the max value
        (uint256 maxItemId, uint256 correctedMaxValue) = maxHeapTester.getMax();
        assertEq(correctedMaxValue, 7, "Max value should be 7");
        assertEq(maxItemId, 2, "Max piece ID should be 2");
    }

    /// @dev Tests inserting duplicate values into the heap
    function testInsertDuplicateValues() public {
        maxHeap.insert(1, 5);
        maxHeap.insert(2, 5);
        maxHeap.insert(3, 5);
        (uint256 maxItemId, uint256 maxValue) = maxHeap.getMax();
        assertEq(maxValue, 5, "Max value should still be 5");
        assertEq(maxItemId, 1, "Max piece ID should be 1");
        assertEq(maxHeap.size(), 3, "Size should be 3");
    }

    /// @dev Tests that the heap is empty after all elements are removed
    function testHeapEmptyAfterAllRemoved() public {
        maxHeap.insert(1, 5);
        maxHeap.insert(2, 7);
        maxHeap.extractMax();
        maxHeap.extractMax();
        assertEq(maxHeap.size(), 0, "Heap should be empty");
    }

    /// @dev Tests that the heap maintains its properties after multiple insertions and removals
    function testHeapProperty() public {
        uint256[] memory values = new uint256[](6);
        values[0] = 4;
        values[1] = 7;
        values[2] = 15;
        values[3] = 9;
        values[4] = 10;
        values[5] = 20;
        for (uint256 i = 0; i < values.length; i++) {
            maxHeap.insert(i, values[i]);
        }

        uint256 lastVal = type(uint256).max; // Start with the maximum uint256 value
        while (maxHeap.size() > 0) {
            (, uint256 voteCount) = maxHeap.extractMax();
            assertTrue(voteCount <= lastVal, "Heap property violated");
            lastVal = voteCount;
        }
    }

    /// @dev Tests the maxHeapify function on a non-root node
    function testHeapifyOnNonRoot() public {
        maxHeapTester.insert(1, 10);
        maxHeapTester.insert(2, 15);
        maxHeapTester.insert(3, 5);
        maxHeapTester.insert(4, 12);
        maxHeapTester._set(1, 200, 4); // Assume a '_set' function for testing
        maxHeapTester.maxHeapifyTest(1);
        uint256 itemId = maxHeapTester.heap(1);
        (uint256 val, ) = maxHeapTester.items(itemId);
        assertEq(val, 10, "Value should be 10 after heapify");
        assertEq(itemId, 1, "Item ID should be 1 after heapify");
    }

    /// @dev Tests that the heap does not allow removal of max element when it's empty
    function testCannotRemoveMaxWhenEmpty() public {
        // Try to remove max and expect to fail
        vm.expectRevert(abi.encodeWithSignature("EMPTY_HEAP()"));
        maxHeap.extractMax();
    }
}

contract MaxHeapTester is MaxHeap {
    constructor(address _manager) MaxHeap(_manager) {}

    /// @notice Function to set a value in the heap (ONLY FOR TESTING)
    /// @param pos The position to set
    /// @param value The value to set at the given position
    function _set(uint256 pos, uint256 itemId, uint256 value) public {
        heap[pos] = itemId;
        items[itemId].value = value;
        items[itemId].heapIndex = pos;
    }

    /// @notice Function to call maxHeapify (ONLY FOR TESTING)
    /// @param pos The position to start heapify from
    function maxHeapifyTest(uint256 pos) public {
        super.maxHeapify(pos);
    }
}
