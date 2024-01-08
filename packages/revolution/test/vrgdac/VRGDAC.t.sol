// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { VRGDAC } from "../../src/libs/VRGDAC.sol";
import { toDaysWadUnsafe, unsafeWadDiv, wadLn, wadExp, wadMul } from "../../src/libs/SignedWadMath.sol";
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
    function test_noNegatives(int256 amount, int256 perTimeUnit) public {
        perTimeUnit = bound(perTimeUnit, 1 * 1e18, 1_000_000 * 1e18);

        int256 priceDecayPercent = 1e18 / 10;
        int256 targetPrice = 1 ether;

        amount = bound(
            amount,
            int(revolutionPointsEmitter.minPurchaseAmount()),
            int(revolutionPointsEmitter.maxPurchaseAmount())
        );

        VRGDAC vrgdac = new VRGDAC(targetPrice, priceDecayPercent, perTimeUnit);
        int256 x = vrgdac.yToX({ timeSinceStart: 2000000000000000000, sold: 1000000000000000000, amount: amount });

        console2.log((x));
        console2.log(uint256(x));
        console2.log(uint256(x) / 1e18);

        assertGt(x, 0, "x should be greater than zero");
    }

    /// forge-config: default.fuzz.runs = 21000
    function test_yToX_NoPurchasesAfterLongTime(int256 randomTime, int256 sold, int256 perTimeUnit) public {
        perTimeUnit = bound(perTimeUnit, 1 * 1e18, 1_000_000 * 1e18);
        randomTime = bound(randomTime, 10 days, 7665 days);

        int256 nDays = randomTime / 1 days;
        int256 timeSinceStart = toDaysWadUnsafe(uint(randomTime));
        int256 priceDecayPercent = 1e18 / 10;
        int256 targetPrice = 1 ether;

        //bound sold to perTimeUnit * nDays < 50% undersold
        int256 min = (perTimeUnit * nDays * 5) / 10;
        sold = bound(sold, min, perTimeUnit * nDays);

        // setup vrgda
        VRGDAC vrgdac = new VRGDAC(targetPrice, priceDecayPercent, perTimeUnit);

        // call y to x ensure no revert
        int256 x = vrgdac.yToX({ timeSinceStart: timeSinceStart, sold: sold, amount: targetPrice });

        // ensure x is not negative even though there haven't been any sales in forever
        assertGt(x, 0, "x should be greater than zero");
    }

    /// forge-config: default.fuzz.runs = 21000
    function test_yToX_ManyPurchasesAfterLongTime(int256 randomTime, int256 sold, int256 perTimeUnit) public {
        perTimeUnit = bound(perTimeUnit, 1 * 1e18, 1_000_000 * 1e18);
        randomTime = bound(randomTime, 10 days, 7665 days);

        int256 nDays = randomTime / 1 days;
        int256 timeSinceStart = toDaysWadUnsafe(uint(randomTime));
        int256 priceDecayPercent = 1e18 / 10;
        int256 targetPrice = 1 ether;

        //bound sold to perTimeUnit * nDays < 50% oversold
        int256 max = (perTimeUnit * nDays * 15) / 10;
        sold = bound(sold, perTimeUnit * nDays, max);

        emit log_named_int("sold", sold / 1e18);
        emit log_named_int("targetPrice", targetPrice / 1e18);

        // setup vrgda
        VRGDAC vrgdac = new VRGDAC(1 ether, priceDecayPercent, perTimeUnit);

        int256 wadExpParameter = (wadLn(1e18 - priceDecayPercent) *
            (timeSinceStart - unsafeWadDiv(sold, perTimeUnit))) / 1e18; // when this overflows, we just want to floor / max it

        emit log_named_int("wadExpParameter", wadExpParameter);

        // call y to x ensure no revert
        int256 x = vrgdac.yToX({ timeSinceStart: timeSinceStart, sold: sold, amount: targetPrice });
    }
}
