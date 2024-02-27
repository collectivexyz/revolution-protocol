// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { SplitMain } from "@cobuild/splits/src/SplitMain.sol";
import { SplitWallet } from "@cobuild/splits/src/SplitWallet.sol";
import { ISplitMain } from "@cobuild/splits/src/interfaces/ISplitMain.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { SplitsTest } from "./RevolutionSplits.t.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { IRevolutionPointsEmitter } from "../../src/interfaces/IRevolutionPointsEmitter.sol";
import { IRevolutionPoints } from "../../src/interfaces/IRevolutionPoints.sol";

contract CreateSplitsTest is SplitsTest {
    function test__CreateBasicSplit__EthPayouts() public {
        (
            address[] memory accounts,
            uint32[] memory percentAllocations,
            uint32 distributorFee,
            address controller,
            uint32[] memory pointsAllocations,
            SplitMain.PointsData memory pointsData
        ) = setupBasicSplit();

        address split = ISplitMain(splits).createSplit(
            pointsData,
            accounts,
            percentAllocations,
            distributorFee,
            controller
        );
        assertTrue(split != address(0));

        //ensure split is payable
        uint256 value = 1e18;
        (bool success, ) = address(split).call{ value: value }("");
        assertTrue(success);

        // get hash of split
        bytes32 splitHash = ISplitMain(splits).getHash(split);
        assertTrue(splitHash != bytes32(0));

        // distribute ETH from split wallet and check balances on splitmain
        distributeAndCheckETHBalances(value, split, pointsData, accounts, percentAllocations, distributorFee);

        // withdraw ETH and check actual ether balances
        withdrawEthBalances(accounts);
    }

    function test__CreateBasicSplit__PointsPayouts() public {
        (
            address[] memory accounts,
            uint32[] memory percentAllocations,
            uint32 distributorFee,
            address controller,
            uint32[] memory pointsAllocations,
            SplitMain.PointsData memory pointsData
        ) = setupBasicSplit();

        address split = ISplitMain(splits).createSplit(
            pointsData,
            accounts,
            percentAllocations,
            distributorFee,
            controller
        );
        assertTrue(split != address(0));

        //ensure split is payable
        uint256 value = 1e18;
        (bool success, ) = address(split).call{ value: value }("");
        assertTrue(success);

        // get hash of split
        bytes32 splitHash = ISplitMain(splits).getHash(split);
        assertTrue(splitHash != bytes32(0));

        // distribute ETH from split wallet and check balances on splitmain
        distributeAndCheckETHBalances(value, split, pointsData, accounts, percentAllocations, distributorFee);

        // withdraw eth points balances
        withdrawEthPointsBalances(accounts);
    }

    function withdrawEthBalances(address[] memory accounts) public {
        //build array of expected balances
        uint256[] memory expectedBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; i++) {
            expectedBalances[i] = ISplitMain(splits).getETHBalance(accounts[i]);
        }

        for (uint256 i = 0; i < accounts.length; i++) {
            // only Withdraw ETH from the split
            ISplitMain(splits).withdraw(accounts[i], 1, 0, new ERC20[](0));
        }

        // Check ETH balances for each account
        for (uint256 i = 0; i < accounts.length; i++) {
            assertEq(accounts[i].balance, expectedBalances[i] - 1, "Incorrect ETH balance for account");
            assertEq(ISplitMain(splits).getETHBalance(accounts[i]), 1, "ETH balance should be wiped");
        }
    }

    function withdrawEthPointsBalances(address[] memory accounts) public {
        //build array of expected balances
        int256[] memory expectedPointsBalances = new int256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; i++) {
            uint256 expectedEtherToSpend = ISplitMain(splits).getETHPointsBalance(accounts[i]) - 1;

            uint256 founderPayment = getFounderGovernancePayment(expectedEtherToSpend);

            int256 expectedFounderPoints = founderPayment > 0
                ? IRevolutionPointsEmitter(pointsEmitter).getTokenQuoteForEther(founderPayment)
                : int(0);

            int256 buyerGovShares = getTokenQuoteForEtherHelper(
                getBuyerPayment(expectedEtherToSpend),
                expectedFounderPoints
            );

            expectedPointsBalances[i] = buyerGovShares;

            int256 expected = ISplitMain(splits).getPointsBalance(accounts[i]);

            //assert eq
            assertEq(expected, expectedPointsBalances[i], "Incorrect points balance for account");
        }

        for (uint256 i = 0; i < accounts.length; i++) {
            // only withdraw points eth
            vm.prank(accounts[i]);
            ISplitMain(splits).withdraw(accounts[i], 0, 1, new ERC20[](0));
        }

        // Check points balances for each account
        for (uint256 i = 0; i < accounts.length; i++) {
            assertEq(
                IRevolutionPoints(revolutionPoints).balanceOf(accounts[i]),
                uint256(expectedPointsBalances[i]),
                "Incorrect points balance for account"
            );
            assertEq(ISplitMain(splits).getETHPointsBalance(accounts[i]), 1, "ETH points balance should be wiped");
        }
    }
}
