// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { ProtocolRewardsTest } from "../ProtocolRewardsTest.sol";
import { MockWETH } from "../mock/MockWETH.sol";
import { IRewardSplits } from "../../src/interfaces/IRewardSplits.sol";
import { ProtocolRewards } from "../../src/ProtocolRewards.sol";

contract RevolutionRewardsTest is ProtocolRewardsTest {
    //enable this contract to receive eth
    receive() external payable {}

    function setUp() public override {
        super.setUp();
    }

    function testDeposit(uint256 msgValue) public {
        msgValue = bound(msgValue, 1, 1e12 ether);

        vm.deal(collector, msgValue);

        // array of len 1 addresses
        address[] memory addresses = new address[](1);
        addresses[0] = collector;
        uint[] memory bps = new uint[](1);
        bps[0] = 10_000;

        (IRewardSplits.RewardsSettings memory settings, uint256 totalReward) = rewardsTest.computePurchaseRewards(
            msgValue
        );

        vm.prank(collector);
        rewardsTest.buyAndIssueRewards{ value: msgValue }(builderReferral, purchaseReferral, deployer);

        assertApproxEqAbs(ProtocolRewards(protocolRewards).totalRewardsSupply(), totalReward, 5);
        assertApproxEqAbs(
            ProtocolRewards(protocolRewards).balanceOf(builderReferral),
            settings.builderReferralReward,
            5
        );
        assertApproxEqAbs(
            ProtocolRewards(protocolRewards).balanceOf(purchaseReferral),
            settings.purchaseReferralReward,
            5
        );
        assertApproxEqAbs(ProtocolRewards(protocolRewards).balanceOf(deployer), settings.deployerReward, 5);
        assertApproxEqAbs(ProtocolRewards(protocolRewards).balanceOf(revolutionDAO), settings.revolutionReward, 5);
    }

    function testNullReferralRecipient(uint256 msgValue) public {
        msgValue = bound(msgValue, 1, 1e12 ether);

        // array of len 1 addresses
        address[] memory addresses = new address[](1);
        addresses[0] = collector;
        uint[] memory bps = new uint[](1);
        bps[0] = 10_000;

        vm.deal(collector, msgValue);

        vm.prank(collector);

        (IRewardSplits.RewardsSettings memory settings, uint256 totalReward) = rewardsTest.computePurchaseRewards(
            msgValue
        );

        vm.prank(collector);
        rewardsTest.buyAndIssueRewards{ value: msgValue }(builderReferral, address(0), deployer);

        assertApproxEqAbs(ProtocolRewards(protocolRewards).totalRewardsSupply(), totalReward, 5);
        assertApproxEqAbs(
            ProtocolRewards(protocolRewards).balanceOf(builderReferral),
            settings.builderReferralReward,
            5
        );
        assertApproxEqAbs(ProtocolRewards(protocolRewards).balanceOf(deployer), settings.deployerReward, 5);
        assertApproxEqAbs(
            ProtocolRewards(protocolRewards).balanceOf(revolutionDAO),
            settings.purchaseReferralReward + settings.revolutionReward,
            5
        );
    }
}
