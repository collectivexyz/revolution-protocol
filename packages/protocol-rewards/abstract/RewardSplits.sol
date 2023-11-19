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

    uint256 internal constant DEPLOYER_REWARD_BPS = 23;
    uint256 internal constant REVOLUTION_REWARD_BPS = 77;
    uint256 internal constant BUILDER_REWARD_BPS = 77;
    uint256 internal constant PURCHASE_REFERRAL_BPS = 33;

    address internal immutable revolutionRewardRecipient;
    IRevolutionProtocolRewards internal immutable protocolRewards;

    constructor(address _protocolRewards, address _revolutionRewardRecipient) payable {
        if (_protocolRewards == address(0) || _revolutionRewardRecipient == address(0)) {
            revert INVALID_ADDRESS_ZERO();
        }

        protocolRewards = IRevolutionProtocolRewards(_protocolRewards);
        revolutionRewardRecipient = _revolutionRewardRecipient;
    }

    function computeTotalReward(uint256 paymentAmountWei) public pure returns (uint256) {
        return (paymentAmountWei * TOTAL_REWARD_PER_PURCHASE_BPS) / 10_000;
    }

    function computePurchaseRewards(uint256 paymentAmountWei) public pure returns (RewardsSettings memory) {
        return
            RewardsSettings({
                builderReferralReward: (paymentAmountWei * BUILDER_REWARD_BPS) / 10_000,
                purchaseReferralReward: (paymentAmountWei * PURCHASE_REFERRAL_BPS) / 10_000,
                deployerReward: (paymentAmountWei * DEPLOYER_REWARD_BPS) / 10_000,
                revolutionReward: (paymentAmountWei * REVOLUTION_REWARD_BPS) / 10_000
            });
    }

    function _depositPurchaseRewards(uint256 totalReward, uint256 paymentAmountWei, address builderReferral, address purchaseReferral, address deployer) internal {
        RewardsSettings memory settings = computePurchaseRewards(paymentAmountWei);

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
    }
}
