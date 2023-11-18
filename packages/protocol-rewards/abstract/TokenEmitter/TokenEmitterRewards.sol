// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {RewardSplits} from "../RewardSplits.sol";

abstract contract ERC721Rewards is RewardSplits {
    constructor(address _protocolRewards, address _revolutionRewardRecipient) payable RewardSplits(_protocolRewards, _revolutionRewardRecipient) {}

    function _handleRewards(
        uint256 msgValue,
        address builderReferral,
        address purchaseReferral,
        address deployer
    ) internal {
        uint256 totalReward = computeTotalReward(msgValue);

        _depositPurchaseRewards(totalReward, msgValue, builderReferral, purchaseReferral, deployer);
    }
}
