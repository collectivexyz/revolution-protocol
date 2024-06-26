// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { Test } from "forge-std/Test.sol";

import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { IRevolutionGrants } from "../../src/interfaces/IRevolutionGrants.sol";
import { RevolutionGrants } from "../../src/grants/RevolutionGrants.sol";
import { PoolConfig } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

contract RevolutionGrantsTest is RevolutionBuilderTest {
    address grants;

    function setUp() public virtual override {
        super.setUp();

        super.setMockParams();

        super.deployMock();

        // grants = address(new ERC1967Proxy(grantsImpl, ""));
        // address votingPowerAddress = address(revolutionVotingPower);
        // address initialOwner = address(this); // This contract is the initial owner

        // IRevolutionGrants.GrantsParams memory params = IRevolutionGrants.GrantsParams({
        //     tokenVoteWeight: 1e18, // Example token vote weight
        //     pointsVoteWeight: 1, // Example points vote weight
        //     quorumVotesBPS: 5000, // Example quorum votes in basis points (50%)
        //     minVotingPowerToVote: 1e18, // Minimum voting power required to vote
        //     minVotingPowerToCreate: 100 * 1e18 // Minimum voting power required to create a grant
        // });

        // vm.prank(address(manager));
        // IRevolutionGrants(grants).initialize({
        //     votingPower: votingPowerAddress,
        //     initialOwner: initialOwner,
        //     grantsParams: params
        // });
    }

    function test_initialize() public {
        // assertEq(address(RevolutionGrants(grants).votingPower()), address(revolutionVotingPower));
        // assertEq(RevolutionGrants(grants).minVotingPowerToVote(), 1e18);
        // assertEq(RevolutionGrants(grants).minVotingPowerToCreate(), 100 * 1e18);
        // assertEq(RevolutionGrants(grants).quorumVotesBPS(), 5000);
        // assertEq(RevolutionGrants(grants).tokenVoteWeight(), 1e18);
        // assertEq(RevolutionGrants(grants).pointsVoteWeight(), 1);
    }
}
