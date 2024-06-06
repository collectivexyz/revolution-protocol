// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { IProtocolRewards } from "../interfaces/IProtocolRewards.sol";
import { IRewardSplits } from "../interfaces/IRewardSplits.sol";

/// @notice Common logic for Revolution RevolutionPointsEmitter contracts for protocol reward splits & deposits
abstract contract RewardSplits is IRewardSplits {
    // 2.5% total
    uint256 internal constant DEPLOYER_REWARD_BPS = 25;
    uint256 internal constant REVOLUTION_REWARD_BPS = 75;
    uint256 internal constant BUILDER_REWARD_BPS = 100;
    uint256 internal constant PURCHASE_REFERRAL_BPS = 50;

    address internal immutable revolutionRewardRecipient;
    IProtocolRewards internal immutable protocolRewards;

    constructor(address _protocolRewards, address _revolutionRewardRecipient) payable {
        if (_protocolRewards == address(0) || _revolutionRewardRecipient == address(0)) revert("Invalid Address Zero");

        protocolRewards = IProtocolRewards(_protocolRewards);
        revolutionRewardRecipient = _revolutionRewardRecipient;
    }

    /*
     * @param _paymentAmountWei The amount of ETH being paid for the purchase
     */
    function computeTotalReward(uint256 paymentAmountWei) public pure override returns (uint256) {
        return
            ((paymentAmountWei * BUILDER_REWARD_BPS) / 10_000) +
            ((paymentAmountWei * PURCHASE_REFERRAL_BPS) / 10_000) +
            ((paymentAmountWei * DEPLOYER_REWARD_BPS) / 10_000) +
            ((paymentAmountWei * REVOLUTION_REWARD_BPS) / 10_000);
    }

    function computePurchaseRewards(
        uint256 paymentAmountWei
    ) public pure override returns (RewardsSettings memory, uint256) {
        return (
            RewardsSettings({
                builderReferralReward: (paymentAmountWei * BUILDER_REWARD_BPS) / 10_000,
                purchaseReferralReward: (paymentAmountWei * PURCHASE_REFERRAL_BPS) / 10_000,
                deployerReward: (paymentAmountWei * DEPLOYER_REWARD_BPS) / 10_000,
                revolutionReward: (paymentAmountWei * REVOLUTION_REWARD_BPS) / 10_000
            }),
            computeTotalReward(paymentAmountWei)
        );
    }

    function _depositPurchaseRewards(
        uint256 paymentAmountWei,
        address builderReferral,
        address purchaseReferral,
        address deployer
    ) internal returns (uint256) {
        (RewardsSettings memory settings, uint256 totalReward) = computePurchaseRewards(paymentAmountWei);

        if (builderReferral == address(0)) builderReferral = revolutionRewardRecipient;

        if (deployer == address(0)) deployer = revolutionRewardRecipient;

        if (purchaseReferral == address(0)) purchaseReferral = revolutionRewardRecipient;

        protocolRewards.depositRewards{ value: totalReward }(
            builderReferral,
            settings.builderReferralReward,
            purchaseReferral,
            settings.purchaseReferralReward,
            deployer,
            settings.deployerReward,
            revolutionRewardRecipient,
            settings.revolutionReward
        );

        return totalReward;
    }
}
