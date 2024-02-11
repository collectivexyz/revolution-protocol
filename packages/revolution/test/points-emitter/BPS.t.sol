// SPDX-License-Identifier: GPL-3.0-or-later
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
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { console2 } from "forge-std/console2.sol";

contract PointsEmitterBasicTest is PointsEmitterTest {
    // test multiple payouts
    function testPercentagePayouts(uint firstBps) public {
        firstBps = bound(firstBps, 1, 10_000 - 1);

        vm.startPrank(address(0));

        uint256 founderRateBps = revolutionPointsEmitter.founderRateBps();
        uint256 founderEntropyRateBps = revolutionPointsEmitter.founderEntropyRateBps();

        address[] memory recipients = new address[](2);
        recipients[0] = address(1);
        recipients[1] = address(2);

        uint256[] memory bps = new uint256[](2);
        bps[0] = firstBps;
        bps[1] = 10_000 - firstBps;

        // estimate tokens to be emitted
        uint256 msgValueRemaining = 1e18 - revolutionPointsEmitter.computeTotalReward(1e18);
        uint256 founderShare = (msgValueRemaining * founderRateBps) / 10_000;
        uint256 buyersShare = msgValueRemaining -
            founderShare -
            (msgValueRemaining * revolutionPointsEmitter.grantsRateBps()) /
            10_000;
        uint256 founderGovernancePayment = founderShare - (founderShare * founderEntropyRateBps) / 10_000;

        int256 expectedFounderPoints = revolutionPointsEmitter.getTokenQuoteForEther(founderGovernancePayment);

        int256 expectedBuyerAmount = getTokenQuoteForEtherHelper(buyersShare, expectedFounderPoints);

        int256 expectedAmount = expectedFounderPoints + expectedBuyerAmount;

        revolutionPointsEmitter.buyToken{ value: 1e18 }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );
        //assert address balances are correct
        //multiply bps by expectedBuyerAmount and assert
        assertEq(
            revolutionPointsEmitter.balanceOf(address(1)),
            (firstBps * uint256(expectedBuyerAmount)) / 10_000,
            "First recipient should have correct balance"
        );
        assertEq(
            revolutionPointsEmitter.balanceOf(address(2)),
            ((10_000 - firstBps) * uint256(expectedBuyerAmount)) / 10_000,
            "Second recipient should have correct balance"
        );

        // assert owner balance is correct
        assertEq(
            address(revolutionPointsEmitter.owner()).balance,
            1e18 -
                revolutionPointsEmitter.computeTotalReward(1e18) -
                (founderShare * founderEntropyRateBps) /
                10_000 -
                (msgValueRemaining * revolutionPointsEmitter.grantsRateBps()) /
                10_000,
            "Owner should have payment - totalReward in balance"
        );

        //assert grants address balance is correct
        assertEq(
            address(revolutionPointsEmitter.grantsAddress()).balance,
            (msgValueRemaining * revolutionPointsEmitter.grantsRateBps()) / 10_000,
            "Grants address should have correct balance"
        );
    }

    //if buyToken is called with mismatched length arrays, then it should revert with PARALLEL_ARRAYS_REQUIRED()
    function test_revertMismatchedLengthArrays() public {
        vm.startPrank(address(0));

        address[] memory recipients = new address[](2);
        recipients[0] = address(1);
        recipients[1] = address(2);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        vm.expectRevert(abi.encodeWithSignature("PARALLEL_ARRAYS_REQUIRED()"));
        revolutionPointsEmitter.buyToken{ value: 1e18 }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(1),
                purchaseReferral: address(1),
                deployer: address(0)
            })
        );
    }

    // Test to ensure the total basis points add up to 100%
    function testTotalBasisPoints() public {
        vm.startPrank(address(0));

        uint256 founderRateBps = revolutionPointsEmitter.founderRateBps();
        uint256 founderEntropyRateBps = revolutionPointsEmitter.founderEntropyRateBps();

        address[] memory recipients = new address[](2);
        recipients[0] = address(1);
        recipients[1] = address(2);

        // Test case with correct total of 10,000 basis points (100%)
        uint256[] memory correctBps = new uint256[](2);
        correctBps[0] = 5000; // 50%
        correctBps[1] = 5000; // 50%

        uint256 msgValueRemaining = 1e18 - revolutionPointsEmitter.computeTotalReward(1e18);
        // Calculate share of purchase amount reserved for buyers
        uint256 buyersShare = msgValueRemaining -
            ((msgValueRemaining * founderRateBps) / 10_000) -
            ((revolutionPointsEmitter.grantsRateBps() * msgValueRemaining) / 10_000);

        // Calculate ether directly sent to founder
        uint256 founderDirectPayment = (msgValueRemaining * founderRateBps * founderEntropyRateBps) / 10_000 / 10_000;

        // Calculate ether spent on founder governance tokens
        uint256 founderGovernancePayment = ((msgValueRemaining * founderRateBps) / 10_000) - founderDirectPayment;

        int256 expectedFounderPoints = revolutionPointsEmitter.getTokenQuoteForEther(founderGovernancePayment);

        int256 expectedBuyerPoints = getTokenQuoteForEtherHelper(buyersShare, expectedFounderPoints);

        int256 expectedAmount = expectedFounderPoints + expectedBuyerPoints;

        assertGt(expectedAmount, 0, "Token purchase should have a positive amount");

        // Attempting a valid token purchase
        uint256 emittedWad = revolutionPointsEmitter.buyToken{ value: 1e18 }(
            recipients,
            correctBps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );
        int256 totalSupplyAfterValidPurchase = int(revolutionPointsEmitter.totalSupply());
        assertEq(totalSupplyAfterValidPurchase, expectedAmount, "Supply should match the expected amount");

        // //emitted should match expected
        assertEq(int(emittedWad), expectedBuyerPoints, "Emitted amount should match expected amount");

        // //emitted should match supply
        assertEq(
            int(emittedWad) + int(revolutionPoints.balanceOf(revolutionPointsEmitter.founderAddress())),
            totalSupplyAfterValidPurchase,
            "Emitted amount should match total supply"
        );

        uint256 grantsPayment = (msgValueRemaining * revolutionPointsEmitter.grantsRateBps()) / 10_000;

        //expect owner to have payment - totalReward - founderDirectPayment in balance
        assertEq(
            address(revolutionPointsEmitter.owner()).balance,
            1e18 - revolutionPointsEmitter.computeTotalReward(1e18) - founderDirectPayment - grantsPayment,
            "Owner should have payment - totalReward in balance"
        );

        // Test case with incorrect total of basis points
        uint256[] memory incorrectBps = new uint256[](2);
        incorrectBps[0] = 4000; // 40%
        incorrectBps[1] = 4000; // 40%

        // Expecting the transaction to revert due to incorrect total basis points
        vm.expectRevert(abi.encodeWithSignature("INVALID_BPS_SUM()"));
        revolutionPointsEmitter.buyToken{ value: 1e18 }(
            recipients,
            incorrectBps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );

        vm.stopPrank();
    }

    //ensure when creating new points emitter, that INVALID_BPS is thrown if > 10_000
    function test_bpsInitialization() public {
        address owner = address(0x123);

        RevolutionProtocolRewards protocolRewards = new RevolutionProtocolRewards();

        address governanceToken = address(new ERC1967Proxy(revolutionPointsImpl, ""));

        address emitter1 = address(new ERC1967Proxy(revolutionPointsEmitterImpl, ""));

        address vrgdac = address(revolutionPointsEmitter.vrgda());

        vm.startPrank(address(manager));
        vm.expectRevert(abi.encodeWithSignature("INVALID_BPS()"));
        IRevolutionPointsEmitter(emitter1).initialize({
            initialOwner: owner,
            weth: address(weth),
            revolutionPoints: address(governanceToken),
            vrgda: vrgdac,
            founderParams: IRevolutionBuilder.FounderParams({
                totalRateBps: 100_000,
                founderAddress: founder,
                rewardsExpirationDate: 1_800_000_000,
                entropyRateBps: 50_000
            }),
            grantsParams: IRevolutionBuilder.GrantsParams({ totalRateBps: 1000, grantsAddress: grantsAddress })
        });
    }
}
