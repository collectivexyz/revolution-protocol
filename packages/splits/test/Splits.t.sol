// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";

contract SplitsTest is Test {
    address splitMain;

    address revolutionPoints = address(0x1);

    function setUp() public override {
        splitMain = address(new SplitMain(revolutionPoints));
    }
}
