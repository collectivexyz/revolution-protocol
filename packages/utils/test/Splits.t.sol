// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { SplitMain } from "../src/SplitMain.sol";

contract SplitsTest is Test {
    address splitMain;

    address revolutionPoints = address(0x1);

    function setUp() public {
        splitMain = address(new SplitMain(revolutionPoints));
    }

    function test__Blank() public {
        assertTrue(true);
    }
}
