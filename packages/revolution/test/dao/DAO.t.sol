// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { VRGDAC } from "../../src/libs/VRGDAC.sol";
import { toDaysWadUnsafe, unsafeWadDiv, wadLn, wadExp, wadMul } from "../../src/libs/SignedWadMath.sol";
import { console2 } from "forge-std/console2.sol";
import { ERC1967Proxy } from "../../src/libs/proxy/ERC1967Proxy.sol";
import { IVRGDAC } from "../../src/interfaces/IVRGDAC.sol";

contract DAOTestSuite is RevolutionBuilderTest {
    function setUp() public override {
        super.setUp();
        super.setMockParams();

        super.setGovParams(
            2 days,
            1 seconds,
            1 weeks,
            50,
            founder,
            1000,
            1000,
            1000,
            "Vrbs DAO",
            "To do good for the public and posterity",
            unicode"⌐◨-◨"
        );

        super.deployMock();
    }

    //test that the culture index checklist is initialized correctly
    function testDAOSymbol() public {
        string memory flag = dao.flag();

        string memory expectedFlag = unicode"⌐◨-◨";

        assertEq(flag, expectedFlag, "Flag should be initialized correctly");
    }

    //test dao purpose
    function testDAOPurpose() public {
        string memory purpose = dao.purpose();

        string memory expectedPurpose = "To do good for the public and posterity";

        assertEq(purpose, expectedPurpose, "Purpose should be initialized correctly");
    }
}
