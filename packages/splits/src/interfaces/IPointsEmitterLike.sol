// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IRevolutionPointsEmitter {
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
