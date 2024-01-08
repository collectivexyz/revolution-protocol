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

    /// forge-config: default.fuzz.runs = 10000
    function test_yToXWithPurchasesAfterLongTime(uint256 randomTime, uint256 sold) public {
        randomTime = bound(randomTime, 100 days, 3650 days);

        uint256 perDayTarget = 1_000 * 1e18;
        uint256 nDays = randomTime / 1 days;

        emit log_named_uint("randomTime", randomTime);
        emit log_named_uint("nDays", nDays);
        emit log_named_uint("perDayTarget", perDayTarget / 1e18);

        //bound sold to perDayTarget * nDays < 50% both ways
        uint256 min = (perDayTarget * nDays * 5) / 10;
        uint256 max = (perDayTarget * nDays * 15) / 10;
        sold = bound(sold, min, max);

        emit log_named_uint("sold", sold / 1e18);

        // setup vrgda
        VRGDAC vrgdac = new VRGDAC(1 ether, 1e18 / 10, int(perDayTarget));

        // call y to x ensure no revert
        int256 x = vrgdac.yToX({ timeSinceStart: toDaysWadUnsafe(randomTime), sold: int(sold), amount: 1e18 });
    }
}
