// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import "forge-std/Test.sol";

import "../src/ProtocolRewards.sol";

contract ProtocolRewardsTest is Test {
    uint256 internal constant ETH_SUPPLY = 120_200_000 ether;

    ProtocolRewards internal protocolRewards;

    address internal collector;
    address internal builderReferral;
    address internal purchaseReferral;
    address internal deployer;
    address internal revolution;

    function setUp() public virtual {
        protocolRewards = new ProtocolRewards();

        vm.label(address(protocolRewards), "protocolRewards");

        collector = makeAddr("collector");
        builderReferral = makeAddr("builderReferral");
        purchaseReferral = makeAddr("purchaseReferral");
        deployer = makeAddr("firstMinter");
        revolution = makeAddr("revolution");
    }
}
