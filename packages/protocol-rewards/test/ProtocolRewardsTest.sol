// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import "../src/ProtocolRewards.sol";
import { RevolutionRewards } from "../src/abstract/RevolutionRewards.sol";

contract ProtocolRewardsTest is Test {
    uint256 internal constant ETH_SUPPLY = 120_200_000 ether;

    ProtocolRewards internal protocolRewards;

    RewardsTest internal rewardsTest;

    address internal collector;
    address internal builderReferral;
    address internal purchaseReferral;
    address internal deployer;
    address internal revolutionDAO;

    function setUp() public virtual {
        collector = makeAddr("collector");
        builderReferral = makeAddr("builderReferral");
        purchaseReferral = makeAddr("purchaseReferral");
        deployer = makeAddr("firstMinter");
        revolutionDAO = makeAddr("revolutionDAO");

        protocolRewards = new ProtocolRewards();

        rewardsTest = new RewardsTest(address(protocolRewards), address(revolutionDAO));

        vm.label(address(protocolRewards), "protocolRewards");
    }
}

contract RewardsTest is RevolutionRewards {
    /// @param _protocolRewards The protocol rewards contract address
    /// @param _protocolFeeRecipient The protocol fee recipient address
    constructor(
        address _protocolRewards,
        address _protocolFeeRecipient
    ) payable RevolutionRewards(_protocolRewards, _protocolFeeRecipient) {
        if (_protocolRewards == address(0)) revert();
        if (_protocolFeeRecipient == address(0)) revert();
    }

    function buyAndIssueRewards(
        address builder,
        address purchaseReferral,
        address deployer
    ) public payable returns (uint256 tokensSoldWad) {
        // Calculate value left after sharing protocol rewards
        uint256 msgValueRemaining = _handleRewardsAndGetValueToSend(msg.value, builder, purchaseReferral, deployer);
    }
}
