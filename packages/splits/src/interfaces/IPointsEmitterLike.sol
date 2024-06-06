// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

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

    function getTokenQuoteForPayment(uint256 paymentAmount) external view returns (int256);
}
