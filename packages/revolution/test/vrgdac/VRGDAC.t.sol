// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { VRGDAC } from "../../src/libs/VRGDAC.sol";
import { toDaysWadUnsafe, unsafeWadDiv, wadLn, wadExp, wadMul } from "../../src/libs/SignedWadMath.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { IVRGDAC } from "../../src/interfaces/IVRGDAC.sol";

contract PointsTestSuite is RevolutionBuilderTest {
    function setUp() public override {
        super.setUp();
        super.setMockParams();

        super.setPointsParams("Revolution Governance", "GOV");

        super.deployMock();
    }

    function test_noNegatives(int256 amount, int256 perTimeUnit, int256 targetPrice, int256 priceDecayPercent) public {
        perTimeUnit = bound(perTimeUnit, 1 * 1e18, 1_000_000 * 1e18);
        targetPrice = bound(targetPrice, 1 * 1e10, 1_000 * 1e18);
        priceDecayPercent = bound(priceDecayPercent, 1e18 / 1000, 1e18 / 2);

        amount = bound(amount, 1, 1e12 ether);

        address vrgdac = address(new ERC1967Proxy(vrgdaImpl, ""));

        //prank manager
        vm.prank(address(manager));
        IVRGDAC(vrgdac).initialize({
            initialOwner: address(executor),
            targetPrice: targetPrice,
            priceDecayPercent: priceDecayPercent,
            perTimeUnit: perTimeUnit
        });

        int256 x = IVRGDAC(vrgdac).yToX({
            timeSinceStart: 2000000000000000000,
            sold: 1000000000000000000,
            amount: amount
        });

        assertGe(x, 0, "x should be greater than or equal to zero");
    }

    function test_yToX_NoPurchasesAfterLongTime(
        int256 amount,
        int256 randomTime,
        int256 sold,
        int256 perTimeUnit,
        int256 targetPrice,
        int256 priceDecayPercent
    ) public {
        targetPrice = bound(targetPrice, 1 * 1e10, 1_000 * 1e18);
        perTimeUnit = bound(perTimeUnit, 1 * 1e18, 1_000_000 * 1e18);
        randomTime = bound(randomTime, 10 days, 7665 days);
        priceDecayPercent = bound(priceDecayPercent, 1e18 / 1000, 1e18 / 2);

        amount = bound(amount, 1, 1e12 ether);

        address vrgdac = address(new ERC1967Proxy(vrgdaImpl, ""));

        //prank manager
        vm.prank(address(manager));
        IVRGDAC(vrgdac).initialize({
            initialOwner: address(executor),
            targetPrice: targetPrice,
            priceDecayPercent: priceDecayPercent,
            perTimeUnit: perTimeUnit
        });

        int256 nDays = randomTime / 1 days;
        int256 timeSinceStart = toDaysWadUnsafe(uint(randomTime));

        //bound sold to perTimeUnit * nDays < 50% undersold
        sold = bound(sold, (perTimeUnit * nDays * 5) / 10, perTimeUnit * nDays);

        // call y to x ensure no revert
        int256 x = IVRGDAC(vrgdac).yToX({ timeSinceStart: timeSinceStart, sold: sold, amount: amount });

        // ensure x is not negative even though there haven't been any sales in forever
        assertGe(x, 0, "x should be greater than or equal to zero");
    }

    function test_yToX_ManyPurchasesAfterLongTime(
        int256 amount,
        int256 randomTime,
        int256 sold,
        int256 perTimeUnit,
        int256 targetPrice,
        int256 priceDecayPercent
    ) public {
        targetPrice = bound(targetPrice, 1 * 1e10, 1_000 * 1e18);
        perTimeUnit = bound(perTimeUnit, 1 * 1e18, 1_000_000 * 1e18);
        randomTime = bound(randomTime, 10 days, 7665 days);
        priceDecayPercent = bound(priceDecayPercent, 1e18 / 1000, 1e18 / 2);
        amount = bound(amount, 1, 1e12 ether);

        address vrgdac = address(new ERC1967Proxy(vrgdaImpl, ""));

        //prank manager
        vm.prank(address(manager));
        IVRGDAC(vrgdac).initialize({
            initialOwner: address(executor),
            targetPrice: targetPrice,
            priceDecayPercent: priceDecayPercent,
            perTimeUnit: perTimeUnit
        });

        int256 nDays = randomTime / 1 days;
        int256 timeSinceStart = toDaysWadUnsafe(uint(randomTime));

        //bound sold to perTimeUnit * nDays < 50% oversold
        sold = bound(sold, perTimeUnit * nDays, (perTimeUnit * nDays * 15) / 10);

        // call y to x ensure no revert
        IVRGDAC(vrgdac).yToX({ timeSinceStart: timeSinceStart, sold: sold, amount: amount });
    }
}
