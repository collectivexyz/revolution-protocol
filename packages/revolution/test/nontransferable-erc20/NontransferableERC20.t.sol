// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { NontransferableERC20Votes } from "../../src/NontransferableERC20Votes.sol";

contract NontransferableERC20TestSuite is Test {
    event Log(string, uint);

    NontransferableERC20Votes token;

    function setUp() public {
        token = new NontransferableERC20Votes(
            address(this),
            "Revolution Governance",
            "GOV"
        );
    }

    function testTransferRestrictions() public {
        // Setup: Mint some tokens to an account
        address account1 = address(0x1);
        uint256 mintAmount = 1000 * 1e18;
        token.mint(account1, mintAmount);
        assertEq(token.balanceOf(account1), mintAmount, "Minting failed");

        // Attempt to transfer tokens from account1 to account2
        address account2 = address(0x2);
        uint256 transferAmount = 500 * 1e18;
        vm.startPrank(account1);
        vm.expectRevert(abi.encodeWithSignature("TRANSFER_NOT_ALLOWED()"));
        token.transfer(account2, transferAmount);
        vm.stopPrank();

        // Verify that the balances remain unchanged
        assertEq(token.balanceOf(account1), mintAmount, "Balance of account1 should not change");
        assertEq(token.balanceOf(account2), 0, "Balance of account2 should remain zero");
    }

    function testApprovalRestrictions() public {
        // Setup: Use two accounts
        address owner = address(this);
        address spender = address(0x2);

        // Attempt to approve spender by the owner
        uint256 approvalAmount = 500 * 1e18;
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSignature("TRANSFER_NOT_ALLOWED()"));
        token.approve(spender, approvalAmount);
        vm.stopPrank();

        // Verify that the allowance remains zero
        assertEq(token.allowance(owner, spender), 0, "Allowance should remain zero");
    }

}