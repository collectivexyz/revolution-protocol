// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { unsafeWadDiv, toDaysWadUnsafe } from "../../src/libs/SignedWadMath.sol";
import { RevolutionPointsEmitter } from "../../src/RevolutionPointsEmitter.sol";
import { IRevolutionPointsEmitter } from "../../src/interfaces/IRevolutionPointsEmitter.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionProtocolRewards } from "@cobuild/protocol-rewards/src/RevolutionProtocolRewards.sol";
import { wadDiv } from "../../src/libs/SignedWadMath.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { PointsEmitterTest } from "./PointsEmitter.t.sol";
import { IRevolutionPoints } from "../../src/interfaces/IRevolutionPoints.sol";
import { ERC1967Proxy } from "../../src/libs/proxy/ERC1967Proxy.sol";
import { console2 } from "forge-std/console2.sol";

contract PointsEmitterBasicTest is PointsEmitterTest {
    //test that grants receives correct amount of ether
    function test_GrantsBalance(uint256 founderRateBps, uint256 founderEntropyRateBps, uint256 grantsRateBps) public {
        // Assume valid rates
        founderRateBps = bound(founderRateBps, 0, 10000);
        founderEntropyRateBps = bound(founderEntropyRateBps, 0, 10000);
        grantsRateBps = bound(grantsRateBps, 0, 10000 - founderRateBps);

        setUpWithDifferentRates(founderRateBps, founderEntropyRateBps, grantsRateBps);

        //expect grants balance to start out at 0
        assertEq(address(revolutionPointsEmitter.grantsAddress()).balance, 0, "Balance should start at 0");

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        //get msg value remaining
        uint256 msgValueRemaining = 1 ether - revolutionPointsEmitter.computeTotalReward(1 ether);

        // Ether directly sent to founder
        uint256 founderDirectPayment = (msgValueRemaining * founderRateBps * founderEntropyRateBps) / 10_000 / 10_000;

        // Ether spent on founder governance tokens
        uint256 founderGovernancePayment = ((msgValueRemaining * founderRateBps) / 10_000) - founderDirectPayment;

        uint256 grantsShare = (msgValueRemaining * grantsRateBps) / 10_000;

        // Calculate share of purchase amount reserved for buyers
        uint256 buyersShare = msgValueRemaining - founderGovernancePayment - founderDirectPayment - grantsShare;

        uint256 founderPoints = founderGovernancePayment > 0
            ? uint256(getTokenQuoteForEtherHelper(founderGovernancePayment, 0))
            : 0;

        vm.expectEmit(true, true, true, true);
        emit IRevolutionPointsEmitter.PurchaseFinalized(
            address(this),
            1 ether,
            buyersShare + founderGovernancePayment,
            1 ether - msgValueRemaining,
            buyersShare > 0
                ? uint256(
                    //since founder gov shares are purchased first
                    getTokenQuoteForEtherHelper(buyersShare, int256(founderPoints))
                )
                : 0,
            founderPoints,
            founderDirectPayment,
            grantsShare
        );

        revolutionPointsEmitter.buyToken{ value: 1 ether }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(1),
                deployer: address(0)
            })
        );

        //assert that grants balance is correct
        assertEq(
            uint(address(revolutionPointsEmitter.grantsAddress()).balance),
            grantsShare,
            "Grants should have correct balance"
        );
    }

    //ensure grants + founder rate can't be set to more than 10k when setGrantRateBps is called
    function test_SetGrantsRate(uint256 newGrantsRate) public {
        vm.startPrank(revolutionPointsEmitter.owner());
        newGrantsRate = bound(newGrantsRate, 0, 10000 - revolutionPointsEmitter.founderRateBps());

        revolutionPointsEmitter.setGrantsRateBps(newGrantsRate);
        vm.stopPrank();
        assertEq(
            revolutionPointsEmitter.grantsRateBps(),
            newGrantsRate,
            "Grants rate should be set to 10000 - founderRateBps"
        );

        vm.startPrank(revolutionPointsEmitter.owner());

        uint256 invalidGrantsRate = 10001 - revolutionPointsEmitter.founderRateBps();

        vm.expectRevert(abi.encodeWithSignature("INVALID_BPS()"));
        revolutionPointsEmitter.setGrantsRateBps(invalidGrantsRate);
        vm.stopPrank();
        //ensure grants rate didn't change
        assertEq(revolutionPointsEmitter.grantsRateBps(), newGrantsRate, "Grants rate should not have changed");
    }

    // test that grants + founder rate can't be set to more than 10k in initialization
    function test_InitializationGrantsFounderRateBounds(uint256 founderRate, uint256 grantsRate) public {
        super.setUp();
        super.setMockParams();

        founderRate = bound(founderRate, 0, 10000);
        grantsRate = bound(grantsRate, 0, 10001);

        super.setPointsEmitterParams(
            1 ether,
            1e18 / 10,
            int256(1e18 * tokensPerTimeUnit),
            IRevolutionBuilder.FounderParams({
                totalRateBps: founderRate,
                founderAddress: address(0x123),
                rewardsExpirationDate: 1_800_000_000,
                entropyRateBps: 0
            }),
            IRevolutionBuilder.GrantsParams({ totalRateBps: grantsRate, grantsAddress: grantsAddress })
        );

        if (grantsRate + founderRate > 10000) {
            vm.expectRevert(abi.encodeWithSignature("INVALID_BPS()"));
        }
        super.deployMock();
    }
}
