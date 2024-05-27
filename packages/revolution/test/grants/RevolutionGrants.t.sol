// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";

import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { IRevolutionGrants } from "../../src/interfaces/IRevolutionGrants.sol";
import { RevolutionGrants } from "../../src/grants/RevolutionGrants.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import { PoolConfig } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import { ERC1820RegistryCompiled } from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import { SuperfluidFrameworkDeployer } from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";
import { TestToken } from "@superfluid-finance/ethereum-contracts/contracts/utils/TestToken.sol";
import { SuperToken } from "@superfluid-finance/ethereum-contracts/contracts/superfluid/SuperToken.sol";

contract RevolutionGrantsTest is RevolutionBuilderTest {
    SuperfluidFrameworkDeployer.Framework internal sf;
    SuperfluidFrameworkDeployer internal deployer;
    SuperToken internal superToken;

    address grants;

    function setUp() public virtual override {
        super.setUp();

        super.setMockParams();

        super.deployMock();

        grants = address(new ERC1967Proxy(grantsImpl, ""));
        address votingPowerAddress = address(revolutionVotingPower);
        address initialOwner = address(this); // This contract is the initial owner

        IRevolutionGrants.GrantsParams memory params = IRevolutionGrants.GrantsParams({
            tokenVoteWeight: 1e18, // Example token vote weight
            pointsVoteWeight: 1, // Example points vote weight
            quorumVotesBPS: 5000, // Example quorum votes in basis points (50%)
            minVotingPowerToVote: 1e18, // Minimum voting power required to vote
            minVotingPowerToCreate: 100 * 1e18 // Minimum voting power required to create a grant
        });

        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);

        deployer = new SuperfluidFrameworkDeployer();
        deployer.deployTestFramework();
        sf = deployer.getFramework();
        (TestToken underlyingToken, SuperToken token) = deployer.deployWrapperSuperToken(
            "MR Token",
            "MRx",
            18,
            10000000
        );

        superToken = token;

        vm.prank(address(manager));
        IRevolutionGrants(grants).initialize({
            votingPower: votingPowerAddress,
            superToken: address(superToken),
            initialOwner: initialOwner,
            grantsImpl: grantsImpl,
            grantsParams: params
        });
    }

    function test_initialize() public {
        assertEq(address(RevolutionGrants(grants).votingPower()), address(revolutionVotingPower));
        assertEq(RevolutionGrants(grants).minVotingPowerToVote(), 1e18);
        assertEq(RevolutionGrants(grants).minVotingPowerToCreate(), 100 * 1e18);
        assertEq(RevolutionGrants(grants).quorumVotesBPS(), 5000);
        assertEq(RevolutionGrants(grants).tokenVoteWeight(), 1e18);
        assertEq(RevolutionGrants(grants).pointsVoteWeight(), 1);

        superToken.createPool(
            address(this),
            PoolConfig({ transferabilityForUnitsOwner: false, distributionFromAnyAddress: false })
        );
    }
}
