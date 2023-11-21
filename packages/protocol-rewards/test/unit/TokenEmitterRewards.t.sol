// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "../ProtocolRewardsTest.sol";
import {RewardsSettings} from "../../src/abstract/RewardSplits.sol";

contract TokenEmitterRewardsTest is ProtocolRewardsTest {
    MockTokenEmitter internal mockTokenEmitter;

    function setUp() public override {
        super.setUp();

        mockTokenEmitter = new MockTokenEmitter(address(this), address(protocolRewards), revolution);

        vm.label(address(mockTokenEmitter), "MOCK_TOKENEMITTER");
    }

    function testDeposit(uint256 msgValue) public {
        vm.deal(collector, msgValue);

        vm.prank(collector);
        // // BPS too small to issue rewards
        if(msgValue < mockTokenEmitter.minPurchaseAmount() || msgValue > mockTokenEmitter.maxPurchaseAmount()) {
            //expect INVALID_ETH_AMOUNT()
            vm.expectRevert();
        }
        mockTokenEmitter.purchaseWithRewards{value: msgValue}(builderReferral, purchaseReferral, deployer);

        if(msgValue < mockTokenEmitter.minPurchaseAmount() || msgValue > mockTokenEmitter.maxPurchaseAmount()) {
            emit log_uint(msgValue);
            emit log_uint(mockTokenEmitter.maxPurchaseAmount());
            vm.expectRevert();
        }
        (RewardsSettings memory settings, uint256 totalReward) = mockTokenEmitter.computePurchaseRewards(msgValue);

        if(msgValue >= mockTokenEmitter.minPurchaseAmount() && msgValue <= mockTokenEmitter.maxPurchaseAmount()) {
            assertApproxEqAbs(protocolRewards.totalSupply(), totalReward, 5);
            assertApproxEqAbs(protocolRewards.balanceOf(builderReferral), settings.builderReferralReward, 5);
            assertApproxEqAbs(protocolRewards.balanceOf(purchaseReferral), settings.purchaseReferralReward, 5);
            assertApproxEqAbs(protocolRewards.balanceOf(deployer), settings.deployerReward, 5);
            assertApproxEqAbs(protocolRewards.balanceOf(revolution), settings.revolutionReward, 5);
        }
    }

    function testNullReferralRecipient(uint256 msgValue) public {
        mockTokenEmitter = new MockTokenEmitter(address(this), address(protocolRewards), revolution);

        vm.deal(collector, msgValue);

        vm.prank(collector);
        if(msgValue < mockTokenEmitter.minPurchaseAmount() || msgValue > mockTokenEmitter.maxPurchaseAmount()) {
            //expect INVALID_ETH_AMOUNT()
            vm.expectRevert();
        }
        mockTokenEmitter.purchaseWithRewards{value: msgValue}(builderReferral, address(0), deployer);

        if(msgValue < mockTokenEmitter.minPurchaseAmount() || msgValue > mockTokenEmitter.maxPurchaseAmount()) {
            //expect INVALID_ETH_AMOUNT()
            vm.expectRevert();
        }
        (RewardsSettings memory settings, uint256 totalReward) = mockTokenEmitter.computePurchaseRewards(msgValue);

        if(msgValue >= mockTokenEmitter.minPurchaseAmount() && msgValue <= mockTokenEmitter.maxPurchaseAmount()) {
            assertApproxEqAbs(protocolRewards.totalSupply(), totalReward, 5);
            assertApproxEqAbs(protocolRewards.balanceOf(builderReferral), settings.builderReferralReward, 5);
            assertApproxEqAbs(protocolRewards.balanceOf(deployer), settings.deployerReward, 5);
            assertApproxEqAbs(protocolRewards.balanceOf(revolution), settings.purchaseReferralReward + settings.revolutionReward, 5);
        }
    }

    // function testRevertInvalidEth(uint16 numTokens, uint256 pricePerToken) public {
    //     vm.assume(numTokens > 0);
    //     vm.assume(pricePerToken > 0 && pricePerToken < 100 ether);

    //     mockTokenEmitter.setSalePrice(pricePerToken);

    //     vm.expectRevert(abi.encodeWithSignature("INVALID_ETH_AMOUNT()"));
    //     mockTokenEmitter.purchaseWithRewards(collector, 0, numTokens, mintReferral);
    // }

    // function testRevertInvalidEthRemaining(uint16 numTokens, uint256 pricePerToken) public {
    //     vm.assume(numTokens > 0);
    //     vm.assume(pricePerToken > 0 && pricePerToken < 100 ether);

    //     mockTokenEmitter.setSalePrice(pricePerToken);

    //     uint256 totalReward = mockTokenEmitter.computeTotalReward(numTokens);
    //     uint256 totalSale = numTokens * pricePerToken;
    //     uint256 totalValue = totalReward + totalSale;

    //     vm.deal(collector, totalValue);

    //     vm.prank(collector);
    //     vm.expectRevert(abi.encodeWithSignature("MOCK_TOKENEMITTER_INVALID_REMAINING_VALUE()"));
    //     mockTokenEmitter.purchaseWithRewards{value: totalValue - 1}(collector, 0, numTokens, mintReferral);
    // }
}
