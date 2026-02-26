// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

contract RevolutionBuilderBasicTest is RevolutionBuilderTest {
    function setUp() public override {
        super.setUp();
        super.setMockParams();

        super.deployMock();
    }

    function test_getDAOVersions() public {
        //ensure we can pull latest versions
        IRevolutionBuilder.DAOVersionInfo memory versions = manager.getLatestVersions();
    }
}
