// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ERC1967Proxy } from "../../src/libs/proxy/ERC1967Proxy.sol";

contract VotingPowerTest is RevolutionBuilderTest {
    event Log(string, uint);

    function setUp() public override {
        super.setUp();
        super.setMockParams();

        super.deployMock();
    }

    function test_initializeVotingPower() public {
        //ensure we can pull latest versions
        address revolutionToken = address(new ERC1967Proxy(revolutionTokenImpl, ""));

        bytes32 salt = bytes32(uint256(uint160(revolutionToken)) << 96);

        address revolutionVotingPower = address(new ERC1967Proxy{ salt: salt }(revolutionVotingPowerImpl, ""));
    }
}
