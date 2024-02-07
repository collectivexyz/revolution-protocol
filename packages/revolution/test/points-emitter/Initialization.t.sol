// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IRevolutionPointsEmitter } from "../../src/interfaces/IRevolutionPointsEmitter.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";

/**
 * @title PointsEmitterInitializationTest
 * @dev Test contract for PointsEmitter initialization values
 */
contract PointsEmitterInitializationTest is RevolutionBuilderTest {
    uint256 tokensPerTimeUnit = 1_000;

    /**
     * @dev Setup function for each test case
     */
    function setUp() public virtual override {
        super.setUp();
        super.setMockParams();

        super.setPointsEmitterParams(
            1 ether,
            1e18 / 10,
            int256(1e18 * tokensPerTimeUnit),
            IRevolutionBuilder.FounderParams({
                totalRateBps: 2000,
                founderAddress: founder,
                rewardsExpirationDate: 1_800_000_000,
                entropyRateBps: 2000
            }),
            IRevolutionBuilder.GrantsParams({ totalRateBps: 1000, grantsAddress: grantsAddress })
        );

        super.deployMock();

        //start prank to be cultureindex's owner
        vm.startPrank(address(executor));
    }

    // test that the founder params
    function test__FounderFieldsInitialization() public {
        assertEq(
            revolutionPointsEmitter.founderRateBps(),
            2000,
            "Founder totalRateBps should be initialized correctly"
        );
        assertEq(
            revolutionPointsEmitter.founderAddress(),
            founder,
            "Founder founderAddress should be initialized correctly"
        );
        assertEq(
            revolutionPointsEmitter.founderRewardsExpirationDate(),
            1_800_000_000,
            "Founder rewardsExpirationDate should be initialized correctly"
        );
        assertEq(
            revolutionPointsEmitter.founderEntropyRateBps(),
            2000,
            "Founder entropyRateBps should be initialized correctly"
        );
    }

    //test that the culture index checklist is initialized correctly
    function test__GrantsFieldsInitialization() public {
        assertEq(revolutionPointsEmitter.grantsRateBps(), 1000, "Grants totalRateBps should be initialized correctly");
        assertEq(
            revolutionPointsEmitter.grantsAddress(),
            grantsAddress,
            "Grants grantsAddress should be initialized correctly"
        );
    }
}
