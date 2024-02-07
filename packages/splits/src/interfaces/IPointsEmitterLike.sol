// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IRewardSplits } from "@cobuild/protocol-rewards/src/abstract/RewardSplits.sol";

interface IRevolutionPointsEmitter is IRewardSplits {
    struct ProtocolRewardAddresses {
        address builder;
        address purchaseReferral;
        address deployer;
    }

    function buyToken(
        address[] calldata addresses,
        uint[] calldata bps,
        ProtocolRewardAddresses calldata protocolRewardsRecipients
    ) external payable returns (uint);
}
