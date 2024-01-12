// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { RevolutionToken } from "../../src/RevolutionToken.sol";
import { IRevolutionToken } from "../../src/interfaces/IRevolutionToken.sol";
import { IDescriptorMinimal } from "../../src/interfaces/IDescriptorMinimal.sol";

import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { Descriptor } from "../../src/Descriptor.sol";
import "../utils/Base64Decode.sol";
import "../utils/JsmnSolLib.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";

/// @title RevolutionTokenTestSuite
/// @dev The base test suite for the RevolutionToken contract
contract RevolutionTokenTestSuite is RevolutionBuilderTest {
    string public tokenNamePrefix = "Vrb";
    string public tokenName = "Vrbs";
    string public tokenSymbol = "VRBS";

    /// @dev Sets up a new RevolutionToken instance before each test
    function setUp() public override {
        super.setUp();
        super.setMockParams();

        super.setRevolutionTokenParams(tokenName, tokenSymbol, "https://example.com/token/", tokenNamePrefix);

        super.setCultureIndexParams("Vrbs", "Our community Vrbs. Must be 32x32.", 10, 200, 0);

        super.deployMock();

        vm.startPrank(address(executor));
    }
}
