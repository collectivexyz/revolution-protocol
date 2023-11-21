// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { IRevolutionProtocolRewards } from "../interfaces/IRevolutionProtocolRewards.sol";

struct RewardsSettings {
    uint256 builderReferralReward;
    uint256 purchaseReferralReward;
    uint256 deployerReward;
    uint256 revolutionReward;
}

/// @notice Common logic for Revolution TokenEmitter contracts for protocol reward splits & deposits
abstract contract RewardSplits {
    error CREATOR_FUNDS_RECIPIENT_NOT_SET();
    error INVALID_ADDRESS_ZERO();
    error INVALID_ETH_AMOUNT();
    error ONLY_CREATE_REFERRAL();

    // 2.1%
    uint256 internal constant TOTAL_REWARD_PER_PURCHASE_BPS = 210;

    uint256 internal constant DEPLOYER_REWARD_BPS = 21;
    uint256 internal constant REVOLUTION_REWARD_BPS = 77;
    uint256 internal constant BUILDER_REWARD_BPS = 77;
    uint256 internal constant PURCHASE_REFERRAL_BPS = 35;

    uint256 public minPurchaseAmount = 0.0000001 ether;
    uint256 public maxPurchaseAmount = 5_000 ether;

    address internal immutable revolutionRewardRecipient;
    IRevolutionProtocolRewards internal immutable protocolRewards;

    constructor(address _protocolRewards, address _revolutionRewardRecipient) payable {
        if (_protocolRewards == address(0) || _revolutionRewardRecipient == address(0)) {
            revert INVALID_ADDRESS_ZERO();
        }

        protocolRewards = IRevolutionProtocolRewards(_protocolRewards);
        revolutionRewardRecipient = _revolutionRewardRecipient;
    }

    function computeTotalReward(uint256 paymentAmountWei) public view returns (uint256) {
        if(paymentAmountWei <= minPurchaseAmount) {
            revert INVALID_ETH_AMOUNT();
        }

        if(paymentAmountWei >= maxPurchaseAmount) {
            revert INVALID_ETH_AMOUNT();
        }

        return (paymentAmountWei * TOTAL_REWARD_PER_PURCHASE_BPS) / 10_000;
    }

    function computePurchaseRewards(uint256 paymentAmountWei) public view returns (RewardsSettings memory, uint256) {
        if(paymentAmountWei <= minPurchaseAmount) {
            revert INVALID_ETH_AMOUNT();
        }

        if(paymentAmountWei >= maxPurchaseAmount) {
            revert INVALID_ETH_AMOUNT();
        }

        return
            (RewardsSettings({
                builderReferralReward: (paymentAmountWei * BUILDER_REWARD_BPS) / 10_000,
                purchaseReferralReward: (paymentAmountWei * PURCHASE_REFERRAL_BPS) / 10_000,
                deployerReward: (paymentAmountWei * DEPLOYER_REWARD_BPS) / 10_000,
                revolutionReward: (paymentAmountWei * REVOLUTION_REWARD_BPS) / 10_000
            }), (paymentAmountWei * BUILDER_REWARD_BPS) / 10_000 + (paymentAmountWei * PURCHASE_REFERRAL_BPS) / 10_000 + (paymentAmountWei * DEPLOYER_REWARD_BPS) / 10_000 + (paymentAmountWei * REVOLUTION_REWARD_BPS) / 10_000);
    }

    function _depositPurchaseRewards(uint256 paymentAmountWei, address builderReferral, address purchaseReferral, address deployer) internal returns (uint256) {
        (RewardsSettings memory settings, uint256 totalReward) = computePurchaseRewards(paymentAmountWei);

        if (builderReferral == address(0)) {
            builderReferral = revolutionRewardRecipient;
        }

        if (purchaseReferral == address(0)) {
            purchaseReferral = revolutionRewardRecipient;
        }

        if (deployer == address(0)) {
            deployer = revolutionRewardRecipient;
        }

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
