// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { CultureIndexTestSuite } from "./CultureIndex.t.sol";

/**
 * @title CultureIndexInitializationTest
 * @dev Test contract for CultureIndex initialization values
 */
contract CultureIndexInitializationTest is CultureIndexTestSuite {
    /**
     * @dev Setup function for each test case
     */
    function setUp() public virtual override {
        super.setUp();
        super.setMockParams();

        super.setCultureIndexParams(
            "Vrbs",
            "Our community Vrbs. Must be 32x32.",
            "- [ ] Must be 32x32.",
            "ipfs://template",
            10,
            1,
            200,
            0,
            0,
            ICultureIndex.PieceMaximums({ name: 100, description: 2100, image: 64_000, text: 256, animationUrl: 100 }),
            ICultureIndex.MediaType.NONE,
            ICultureIndex.RequiredMediaPrefix.MIXED
        );

        super.deployMock();

        //start prank to be cultureindex's owner
        vm.startPrank(address(executor));
    }

    //test that the culture index checklist is initialized correctly
    function testChecklistInitialization() public {
        string memory checklist = cultureIndex.checklist();

        string memory expectedChecklist = "- [ ] Must be 32x32.";

        assertEq(checklist, expectedChecklist, "Checklist should be initialized correctly");
    }

    //test the template
    function testTemplateInitialization() public {
        string memory template = cultureIndex.template();

        string memory expectedTemplate = "ipfs://template";

        assertEq(template, expectedTemplate, "Template should be initialized correctly");
    }
}
