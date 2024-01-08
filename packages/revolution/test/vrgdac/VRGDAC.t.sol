// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { VRGDAC } from "../../src/libs/VRGDAC.sol";
import { toDaysWadUnsafe, unsafeWadDiv, wadLn, wadExp } from "../../src/libs/SignedWadMath.sol";
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
    function test_yToX_NoPurchasesAfterLongTime(int256 randomTime, int256 sold) public {
        randomTime = bound(randomTime, 10 days, 7665 days);

        int256 perTimeUnit = 1_000 * 1e18;
        int256 nDays = randomTime / 1 days;
        int256 timeSinceStart = toDaysWadUnsafe(uint(randomTime));
        int256 priceDecayPercent = 1e18 / 10;
        int256 targetPrice = 1 ether;

        //bound sold to perTimeUnit * nDays < 40% both ways
        int256 min = (perTimeUnit * nDays * 6) / 10;
        sold = bound(sold, min, perTimeUnit * nDays);

        emit log_named_int("sold", sold / 1e18);

        // setup vrgda
        VRGDAC vrgdac = new VRGDAC(targetPrice, priceDecayPercent, perTimeUnit);

        // call y to x ensure no revert
        int256 x = vrgdac.yToX({ timeSinceStart: timeSinceStart, sold: sold, amount: 1e18 });
    }

    // /// forge-config: default.fuzz.runs = 10000
    // function test_yToXWithManyPurchasesAfterLongTime(int256 randomTime, int256 sold) public {
    //     randomTime = bound(randomTime, 100 days, 3650 days);

    //     int256 perTimeUnit = 1_000 * 1e18;
    //     int256 nDays = randomTime / 1 days;
    //     int256 timeSinceStart = toDaysWadUnsafe(uint(randomTime));
    //     int256 priceDecayPercent = 1e18 / 10;

    //     emit log_named_int("nDays", nDays);
    //     emit log_named_int("perTimeUnit", perTimeUnit / 1e18);

    //     //bound sold to perTimeUnit * nDays < 40% both ways
    //     int256 min = (perTimeUnit * nDays * 6) / 10;
    //     int256 max = (perTimeUnit * nDays * 14) / 10;
    //     sold = bound(sold, min, max);

    //     emit log_named_int("sold", sold / 1e18);

    //     // setup vrgda
    //     VRGDAC vrgdac = new VRGDAC(1 ether, priceDecayPercent, perTimeUnit);

    //     int256 wadExpParameter = (wadLn(1e18 - priceDecayPercent) *
    //         (timeSinceStart - unsafeWadDiv(sold, perTimeUnit))) / 1e18; // when this overflows, we just want to floor / max it

    //     emit log_named_int("wadExpParameter", wadExpParameter / 1e18);

    //     // call y to x ensure no revert
    //     int256 x = vrgdac.yToX({ timeSinceStart: timeSinceStart, sold: sold, amount: 1e18 });
    // }
}
