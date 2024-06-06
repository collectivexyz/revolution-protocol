// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { SplitMain } from "../src/SplitMain.sol";
import { SplitWallet } from "../src/SplitWallet.sol";
import { ISplitMain } from "../src/interfaces/ISplitMain.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { SplitsTest } from "./Splits.t.sol";

contract SplitsEventsTest is SplitsTest {
    // function test__Event() public {
    //     address[] memory accounts = new address[](0);
    //     uint32[] memory percentAllocations = new uint32[](0);
    //     address[] memory pointsAccounts = new address[](1);
    //     pointsAccounts[0] = address(this);
    //     uint32[] memory pointsAllocations = new uint32[](1);
    //     pointsAllocations[0] = 1e6; // 100% allocation
    //     uint32 distributorFee = 0;
    //     address controller = address(this);
    //     SplitMain.PointsData memory pointsData = ISplitMain.PointsData({
    //         pointsPercent: 1e6,
    //         accounts: pointsAccounts,
    //         percentAllocations: pointsAllocations
    //     });
    //     vm.expectEmit(true, true, true, true);
    //     address split = ISplitMain(splits).predictImmutableSplitAddress(
    //         pointsData,
    //         accounts,
    //         percentAllocations,
    //         distributorFee
    //     );
    //     emit ISplitMain.CreateSplit(split, pointsData, accounts, percentAllocations, distributorFee, controller);
    //     ISplitMain(splits).createSplit(pointsData, accounts, percentAllocations, distributorFee, controller);
    // }
}
