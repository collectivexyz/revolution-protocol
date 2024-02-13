// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { MockWETH } from "../mock/MockWETH.sol";
import { IRewardSplits } from "@cobuild/protocol-rewards/src/interfaces/IRewardSplits.sol";
import { RevolutionPointsEmitter } from "../../src/RevolutionPointsEmitter.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionProtocolRewards } from "@cobuild/protocol-rewards/src/RevolutionProtocolRewards.sol";
import { VRGDAC } from "../../src/libs/VRGDAC.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { IRevolutionPointsEmitter } from "../../src/interfaces/IRevolutionPointsEmitter.sol";

contract RevolutionRewardsTest is RevolutionBuilderTest {
    uint256 internal constant ETH_SUPPLY = 120_200_000 ether;

    address internal collector;
    address internal builderReferral;
    address internal purchaseReferral;
    address internal deployer;
    address internal revolution;

    //enable this contract to receive eth
    receive() external payable {}

    function setUp() public override {
        super.setUp();

        super.setMockParams();

        super.deployMock();

        vm.label(address(protocolRewards), "protocolRewards");

        collector = makeAddr("collector");
        builderReferral = makeAddr("builderReferral");
        purchaseReferral = makeAddr("purchaseReferral");
        deployer = makeAddr("firstMinter");
    }

    function testDeposit(uint256 msgValue) public {
        msgValue = bound(msgValue, 1, 1e12 ether);

        vm.deal(collector, msgValue);

        // array of len 1 addresses
        address[] memory addresses = new address[](1);
        addresses[0] = collector;
        uint[] memory bps = new uint[](1);
        bps[0] = 10_000;

        vm.prank(collector);

        IRevolutionPointsEmitter.ProtocolRewardAddresses memory rewardAddrs = IRevolutionPointsEmitter
            .ProtocolRewardAddresses({
                builder: builderReferral,
                purchaseReferral: purchaseReferral,
                deployer: deployer
            });

        revolutionPointsEmitter.buyToken{ value: msgValue }(addresses, bps, rewardAddrs);

        (IRewardSplits.RewardsSettings memory settings, uint256 totalReward) = revolutionPointsEmitter
            .computePurchaseRewards(msgValue);

        assertApproxEqAbs(RevolutionProtocolRewards(protocolRewards).totalRewardsSupply(), totalReward, 5);
        assertApproxEqAbs(
            RevolutionProtocolRewards(protocolRewards).balanceOf(builderReferral),
            settings.builderReferralReward,
            5
        );
        assertApproxEqAbs(
            RevolutionProtocolRewards(protocolRewards).balanceOf(purchaseReferral),
            settings.purchaseReferralReward,
            5
        );
        assertApproxEqAbs(RevolutionProtocolRewards(protocolRewards).balanceOf(deployer), settings.deployerReward, 5);
        assertApproxEqAbs(
            RevolutionProtocolRewards(protocolRewards).balanceOf(revolutionDAO),
            settings.revolutionReward,
            5
        );
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

        revolutionPointsEmitter.buyToken{ value: msgValue }(
            addresses,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: builderReferral,
                purchaseReferral: address(0),
                deployer: deployer
            })
        );

        (IRewardSplits.RewardsSettings memory settings, uint256 totalReward) = revolutionPointsEmitter
            .computePurchaseRewards(msgValue);

        assertApproxEqAbs(RevolutionProtocolRewards(protocolRewards).totalRewardsSupply(), totalReward, 5);
        assertApproxEqAbs(
            RevolutionProtocolRewards(protocolRewards).balanceOf(builderReferral),
            settings.builderReferralReward,
            5
        );
        assertApproxEqAbs(RevolutionProtocolRewards(protocolRewards).balanceOf(deployer), settings.deployerReward, 5);
        assertApproxEqAbs(
            RevolutionProtocolRewards(protocolRewards).balanceOf(revolutionDAO),
            settings.purchaseReferralReward + settings.revolutionReward,
            5
        );
    }
}
