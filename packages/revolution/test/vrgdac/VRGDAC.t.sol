// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { VRGDAC } from "../../src/libs/VRGDAC.sol";
import { toDaysWadUnsafe } from "../../src/libs/SignedWadMath.sol";
import { console2 } from "forge-std/console2.sol";

contract PointsTestSuite is RevolutionBuilderTest {
    event Log(string, uint);

    function setUp() public override {
        super.setUp();
        super.setMockParams();

        super.setPointsParams("Revolution Governance", "GOV");

        super.deployMock();
    }

    function test_noNegatives(int256 amount) public {
        vm.assume(
            amount > int(revolutionPointsEmitter.minPurchaseAmount()) &&
                amount < int(revolutionPointsEmitter.maxPurchaseAmount())
        );

        VRGDAC vrgdac = new VRGDAC(1 ether, 1e18 / 10, 1_000 * 1e18);
        int256 x = vrgdac.yToX({ timeSinceStart: 2000000000000000000, sold: 1000000000000000000, amount: amount });

        console2.log((x));
        console2.log(uint256(x));
        console2.log(uint256(x) / 1e18);

        assertGt(x, 0, "x should be greater than zero");
    }
}
