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

    /// forge-config: default.fuzz.runs = 100000
    function test_noNegatives(int256 amount) public {
        amount = bound(
            amount,
            int(revolutionPointsEmitter.minPurchaseAmount()),
            int(revolutionPointsEmitter.maxPurchaseAmount())
        );

        VRGDAC vrgdac = new VRGDAC(1 ether, 1e18 / 10, 1_000 * 1e18);
        int256 x = vrgdac.yToX({ timeSinceStart: 2000000000000000000, sold: 1000000000000000000, amount: amount });

        console2.log((x));
        console2.log(uint256(x));
        console2.log(uint256(x) / 1e18);

        assertGt(x, 0, "x should be greater than zero");
    }

    function test_yToXWithPurchasesAfterLongTime(uint256 randomTime, int256 sold) public {
        // randomTime = bound(randomTime, 1000 days, 1100 days); //it breaks above this, but this is a reasonable range
        randomTime = 500 days;

        // sold = bound(sold, 1e18 * 1e3, 1e18 * 1e8); // 1000 to 100m tokens sold over the course of 1000 days is reasonable
        sold = 99999 * 1e18;

        // setup vrgda
        VRGDAC vrgdac = new VRGDAC(1 ether, 1e18 / 10, 1_000 * 1e18);

        // call y to x ensure no revert
        int256 x = vrgdac.test_yToX({ timeSinceStart: toDaysWadUnsafe(randomTime), sold: sold, amount: 1e18 });
    }

    function test_t11s_yToXWithPurchasesAfterLongTime(uint256 randomTime, int256 sold) public {
        randomTime = bound(randomTime, 1000 days, 1100 days); //it breaks above this, but this is a reasonable range

        // sold = bound(sold, 1e18 * 1e3, 1e18 * 1e8); // 1000 to 100m tokens sold over the course of 1000 days is reasonable
        sold = 99999 * 1e18;

        // setup vrgda
        VRGDAC vrgdac = new VRGDAC(1 ether, 1e18 / 10, 1_000 * 1e18);

        // call y to x ensure no revert
        int256 x = vrgdac.yToX_t11s_Paradigm({ timeSinceStart: toDaysWadUnsafe(randomTime), sold: sold, amount: 1e18 });
    }
}
