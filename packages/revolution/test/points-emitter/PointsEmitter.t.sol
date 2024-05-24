// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { unsafeWadDiv, toDaysWadUnsafe } from "../../src/libs/SignedWadMath.sol";
import { RevolutionPointsEmitter } from "../../src/RevolutionPointsEmitter.sol";
import { IRevolutionPointsEmitter } from "../../src/interfaces/IRevolutionPointsEmitter.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { ProtocolRewards } from "@cobuild/protocol-rewards/src/ProtocolRewards.sol";
import { wadDiv } from "../../src/libs/SignedWadMath.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { IRevolutionPoints } from "../../src/interfaces/IRevolutionPoints.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { console2 } from "forge-std/console2.sol";

contract PointsEmitterTest is RevolutionBuilderTest {
    // 1,000 tokens per day is the target emission
    uint256 tokensPerTimeUnit = 1_000;

    uint256 expectedVolume = tokensPerTimeUnit * 1e18;

    string public tokenNamePrefix = "Vrb";

    function setUp() public override {
        super.setUp();
        super.setMockParams();

        super.setRevolutionTokenParams("Mock", "MOCK", "https://example.com/token/", tokenNamePrefix);

        int256 oneFullTokenTargetPrice = 1 ether;

        int256 priceDecayPercent = 1e18 / 10;

        super.setPointsEmitterParams(
            oneFullTokenTargetPrice,
            priceDecayPercent,
            int256(1e18 * tokensPerTimeUnit),
            IRevolutionBuilder.FounderParams({
                totalRateBps: 1000,
                founderAddress: founder,
                rewardsExpirationDate: 1_800_000_000,
                entropyRateBps: 4_000
            }),
            IRevolutionBuilder.GrantsParams({ totalRateBps: 1000, grantsAddress: grantsAddress })
        );

        super.deployMock();

        vm.deal(address(0), 100000 ether);
    }

    function getTokenQuoteForEtherHelper(uint256 etherAmount, int256 supply) public returns (int gainedX) {
        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        return
            revolutionPointsEmitter.vrgda().yToX({
                timeSinceStart: toDaysWadUnsafe(block.timestamp - revolutionPointsEmitter.startTime()),
                sold: supply,
                amount: int(etherAmount)
            });
    }

    function setUpWithDifferentRates(uint256 founderRate, uint256 founderEntropyRate, uint256 grantsRate) public {
        super.setUp();
        super.setMockParams();

        super.setPointsEmitterParams(
            1 ether,
            1e18 / 10,
            int256(1e18 * tokensPerTimeUnit),
            IRevolutionBuilder.FounderParams({
                totalRateBps: founderRate,
                founderAddress: address(0x123),
                rewardsExpirationDate: 1_800_000_000,
                entropyRateBps: founderEntropyRate
            }),
            IRevolutionBuilder.GrantsParams({ totalRateBps: grantsRate, grantsAddress: grantsAddress })
        );

        super.deployMock();
    }

    function setUpWithDifferentRatesAndExpiry(
        uint256 founderRate,
        uint256 founderEntropyRate,
        uint256 grantsRate,
        uint256 expiry
    ) public {
        super.setUp();
        super.setMockParams();

        super.setPointsEmitterParams(
            1 ether,
            1e18 / 10,
            int256(1e18 * tokensPerTimeUnit),
            IRevolutionBuilder.FounderParams({
                totalRateBps: founderRate,
                founderAddress: address(0x123),
                rewardsExpirationDate: expiry,
                entropyRateBps: founderEntropyRate
            }),
            IRevolutionBuilder.GrantsParams({ totalRateBps: grantsRate, grantsAddress: grantsAddress })
        );

        super.deployMock();
    }
}
