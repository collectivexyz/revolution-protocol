// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { SplitMain } from "../src/SplitMain.sol";
import { SplitWallet } from "../src/SplitWallet.sol";
import { ISplitMain } from "../src/interfaces/ISplitMain.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { SplitsTest } from "./Splits.t.sol";

contract ValidateSplitsTest is SplitsTest {
    function test__Revert_NoTreasurySplit() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(this);
        uint32[] memory percentAllocations = new uint32[](1);
        percentAllocations[0] = 1e6; // 100% allocation
        uint32 distributorFee = 0;
        address controller = address(this);

        SplitMain.PointsData memory pointsData = ISplitMain.PointsData({
            percentOfEther: 0,
            accounts: new address[](0),
            percentAllocations: new uint32[](0)
        });

        bytes4 selector = bytes4(keccak256("InvalidSplit__InvalidPointsPercent(uint32)"));

        vm.expectRevert(abi.encodeWithSelector(selector, 0));
        address split = ISplitMain(splits).createSplit(
            pointsData,
            accounts,
            percentAllocations,
            distributorFee,
            controller
        );
    }

    function test__Revert_TooFewSplitAccounts() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(this);

        uint32[] memory percentAllocations = new uint32[](1);
        percentAllocations[0] = 1e6 / 2; // 100% allocation
        uint32 distributorFee = 0;
        address controller = address(this);

        SplitMain.PointsData memory pointsData = ISplitMain.PointsData({
            percentOfEther: 1e6 / 2,
            accounts: accounts,
            percentAllocations: percentAllocations
        });

        bytes4 selector = bytes4(keccak256("InvalidSplit__TooFewAccounts(uint256)"));

        vm.expectRevert(abi.encodeWithSelector(selector, 0));
        address split = ISplitMain(splits).createSplit(
            pointsData,
            new address[](0),
            percentAllocations,
            distributorFee,
            controller
        );
    }

    function test__Revert_TooFewPointsAccounts() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(this);
        uint32[] memory percentAllocations = new uint32[](1);
        percentAllocations[0] = 1e6 / 2; // 100% allocation
        uint32 distributorFee = 0;
        address controller = address(this);

        SplitMain.PointsData memory pointsData = ISplitMain.PointsData({
            percentOfEther: 1e6 / 2,
            accounts: new address[](0),
            percentAllocations: new uint32[](0)
        });

        bytes4 selector = bytes4(keccak256("InvalidSplit__TooFewAccounts(uint256)"));

        vm.expectRevert(abi.encodeWithSelector(selector, 0));
        address split = ISplitMain(splits).createSplit(
            pointsData,
            accounts,
            percentAllocations,
            distributorFee,
            controller
        );
    }

    function test__Revert_LargeTreasurySplit() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(this);
        uint32[] memory percentAllocations = new uint32[](1);
        percentAllocations[0] = 1; // 100% allocation
        uint32 distributorFee = 0;
        address controller = address(this);

        SplitMain.PointsData memory pointsData = ISplitMain.PointsData({
            percentOfEther: 1e6 + 1,
            accounts: accounts,
            percentAllocations: percentAllocations
        });

        bytes4 selector = bytes4(keccak256("InvalidSplit__InvalidAllocationsSum(uint32)"));

        vm.expectRevert(abi.encodeWithSelector(selector, 1e6 + 2));
        address split = ISplitMain(splits).createSplit(
            pointsData,
            accounts,
            percentAllocations,
            distributorFee,
            controller
        );
    }
}
