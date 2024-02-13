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

    function test__NO_Revert_TooFewSplitAccounts() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(this);

        uint32[] memory pointsAllocations = new uint32[](1);
        pointsAllocations[0] = 1e6; // 100% allocation
        uint32 distributorFee = 0;
        address controller = address(this);

        SplitMain.PointsData memory pointsData = ISplitMain.PointsData({
            percentOfEther: 1e6,
            accounts: accounts,
            percentAllocations: pointsAllocations
        });

        ISplitMain(splits).createSplit(pointsData, new address[](0), new uint32[](0), distributorFee, controller);
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

        bytes4 selector = bytes4(keccak256("InvalidSplit__TooFewPointsAccounts(uint256)"));

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

    // test that percentAllocations in pointsData must sum to 1e6
    function test__Revert_SmallPointsSplit() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(this);
        uint32[] memory percentAllocations = new uint32[](1);
        percentAllocations[0] = 1e6 - 1; // 100% allocation
        uint32 distributorFee = 0;
        address controller = address(this);

        uint32[] memory pointsAllocations = new uint32[](1);
        pointsAllocations[0] = 1e6 - 1;

        SplitMain.PointsData memory pointsData = ISplitMain.PointsData({
            percentOfEther: 1,
            accounts: accounts,
            percentAllocations: pointsAllocations
        });

        bytes4 selector = bytes4(keccak256("InvalidSplit__InvalidPointsAllocationsSum(uint32)"));

        vm.expectRevert(abi.encodeWithSelector(selector, 1e6 - 1));
        address split = ISplitMain(splits).createSplit(
            pointsData,
            accounts,
            percentAllocations,
            distributorFee,
            controller
        );
    }

    // test that percentAllocations in pointsData must sum to 1e6
    function test__Revert_LargePointsSplit() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(this);
        uint32[] memory percentAllocations = new uint32[](1);
        percentAllocations[0] = 1e6 - 1; // 100% allocation
        uint32 distributorFee = 0;
        address controller = address(this);

        uint32[] memory pointsAllocations = new uint32[](1);
        pointsAllocations[0] = 1e6 + 1;

        SplitMain.PointsData memory pointsData = ISplitMain.PointsData({
            percentOfEther: 1,
            accounts: accounts,
            percentAllocations: pointsAllocations
        });

        bytes4 selector = bytes4(keccak256("InvalidSplit__InvalidPointsAllocationsSum(uint32)"));

        vm.expectRevert(abi.encodeWithSelector(selector, 1e6 + 1));
        address split = ISplitMain(splits).createSplit(
            pointsData,
            accounts,
            percentAllocations,
            distributorFee,
            controller
        );
    }

    //test that PointsAccountsAndAllocationsMismatch is thrown when points accounts and percents have differing lengths
    function test__Revert_AccountsAndAllocationsMismatch() public {
        address[] memory accounts = new address[](2);
        accounts[0] = address(this);
        accounts[1] = address(this);

        uint32[] memory percentAllocations = new uint32[](1);
        percentAllocations[0] = 1e6; // 100% allocation
        uint32 distributorFee = 0;
        address controller = address(this);

        uint32[] memory pointsAllocations = new uint32[](1);
        pointsAllocations[0] = 1e6;

        SplitMain.PointsData memory pointsData = ISplitMain.PointsData({
            percentOfEther: 1,
            accounts: accounts,
            percentAllocations: pointsAllocations
        });

        bytes4 selector = bytes4(keccak256("InvalidSplit__AccountsAndAllocationsMismatch(uint256,uint256)"));

        vm.expectRevert(abi.encodeWithSelector(selector, 2, 1));
        address split = ISplitMain(splits).createSplit(
            pointsData,
            accounts,
            percentAllocations,
            distributorFee,
            controller
        );
    }

    //same as above function except with points data
    function test__Revert_PointsAccountsAndAllocationsMismatch() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(this);

        uint32[] memory percentAllocations = new uint32[](1);
        percentAllocations[0] = 1e6; // 100% allocation
        uint32 distributorFee = 0;
        address controller = address(this);

        uint32[] memory pointsAllocations = new uint32[](2);
        pointsAllocations[0] = 1e6;
        pointsAllocations[1] = 1e6;

        SplitMain.PointsData memory pointsData = ISplitMain.PointsData({
            percentOfEther: 1,
            accounts: accounts,
            percentAllocations: pointsAllocations
        });

        bytes4 selector = bytes4(keccak256("InvalidSplit__PointsAccountsAndAllocationsMismatch(uint256,uint256)"));

        vm.expectRevert(abi.encodeWithSelector(selector, 1, 2));
        address split = ISplitMain(splits).createSplit(
            pointsData,
            accounts,
            percentAllocations,
            distributorFee,
            controller
        );
    }

    // ensure all points percent allocations are > 0 - expect revert InvalidSplit__AllocationMustBePositive if not
    function test__Revert_AllocationMustBePositive() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(this);
        uint32[] memory percentAllocations = new uint32[](1);
        percentAllocations[0] = 1e6 - 1;
        uint32 distributorFee = 0;
        address controller = address(this);

        address[] memory pointsAccounts = new address[](2);
        pointsAccounts[0] = address(1);
        pointsAccounts[1] = address(2);

        uint32[] memory pointsAllocations = new uint32[](2);
        pointsAllocations[0] = 0;
        pointsAllocations[1] = 1e6;

        SplitMain.PointsData memory pointsData = ISplitMain.PointsData({
            percentOfEther: 1,
            accounts: pointsAccounts,
            percentAllocations: pointsAllocations
        });

        bytes4 selector = bytes4(keccak256("InvalidSplit__PointsAllocationMustBePositive(uint256)"));

        vm.expectRevert(abi.encodeWithSelector(selector, 0));
        address split = ISplitMain(splits).createSplit(
            pointsData,
            accounts,
            percentAllocations,
            distributorFee,
            controller
        );
    }

    // ensure all points percent allocations are > 0 - expect revert InvalidSplit__AllocationMustBePositive if not
    function test__Revert_PointsAccountsMustBeOrdered() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(this);
        uint32[] memory percentAllocations = new uint32[](1);
        percentAllocations[0] = 1e6 - 1;
        uint32 distributorFee = 0;
        address controller = address(this);

        address[] memory pointsAccounts = new address[](2);
        pointsAccounts[0] = address(this);
        pointsAccounts[1] = address(this);

        uint32[] memory pointsAllocations = new uint32[](2);
        pointsAllocations[0] = 1e6 / 2;
        pointsAllocations[1] = 1e6 / 2;

        SplitMain.PointsData memory pointsData = ISplitMain.PointsData({
            percentOfEther: 1,
            accounts: pointsAccounts,
            percentAllocations: pointsAllocations
        });

        bytes4 selector = bytes4(keccak256("InvalidSplit__PointsAccountsOutOfOrder(uint256)"));

        vm.expectRevert(abi.encodeWithSelector(selector, 0));
        address split = ISplitMain(splits).createSplit(
            pointsData,
            accounts,
            percentAllocations,
            distributorFee,
            controller
        );
    }
}
