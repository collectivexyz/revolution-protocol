// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { NontransferableERC20Votes } from "../../src/NontransferableERC20Votes.sol";

contract NontransferableERC20TestSuite is Test {
    event Log(string, uint);

    NontransferableERC20Votes token;

    function setUp() public {
        token = new NontransferableERC20Votes(address(this), "Revolution Governance", "GOV");
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

    function testMintingBehavior() public {
        address account = address(0x3);
        uint256 mintAmount = 500 * 1e18;

        // Attempt minting by a non-owner
        address nonOwner = address(0x4);
        vm.startPrank(nonOwner);
        vm.expectRevert();
        token.mint(account, mintAmount);
        vm.stopPrank();

        // Verify that the balance remains unchanged
        assertEq(token.balanceOf(account), 0, "Non-owner should not be able to mint");

        // Minting by the owner
        vm.startPrank(address(this));
        token.mint(account, mintAmount);
        vm.stopPrank();

        // Verify balance and total supply
        assertEq(token.balanceOf(account), mintAmount, "Minting failed to update balance");
        assertEq(token.totalSupply(), mintAmount, "Total supply not updated correctly");
    }

    function testVotingAndDelegation() public {
        address delegate = address(0x6);
        uint256 mintAmount = 1000 * 1e18;

        // Mint tokens to the owner
        vm.startPrank(address(this));
        token.mint(address(this), mintAmount);
        vm.stopPrank();

        // Delegate voting power
        token.delegate(delegate);

        // Check the voting power of the delegate
        assertEq(token.getVotes(delegate), mintAmount, "Delegation failed to assign voting power");

        // Ensure that no tokens were transferred in the process of delegation
        assertEq(token.balanceOf(delegate), 0, "Delegation should not transfer tokens");
    }

    function testTokenMetadata() public {
        assertEq(token.name(), "Revolution Governance", "Incorrect token name");
        assertEq(token.symbol(), "GOV", "Incorrect token symbol");
        assertEq(token.decimals(), 18, "Incorrect number of decimals");
    }

    function testSupplyInvariants(uint256 mintAmount1) public {
        vm.assume(mintAmount1 < type(uint208).max);

        uint256 total = mintAmount1 + mintAmount1 / 10;

        vm.assume(total < type(uint208).max);
        address account1 = address(0x7);
        address account2 = address(0x8);

        // Mint tokens to different accounts
        vm.startPrank(address(this));
        token.mint(account1, mintAmount1);
        token.mint(account2, mintAmount1 / 10);
        vm.stopPrank();

        // Check total supply
        uint256 totalSupply = token.totalSupply();

        emit Log("totalSupply", totalSupply);

        assertEq(totalSupply, mintAmount1 + mintAmount1 / 10, "Total supply should equal sum of balances");

        // Check individual balances
        assertEq(token.balanceOf(account1), mintAmount1, "Incorrect balance for account1");
        assertEq(token.balanceOf(account2), mintAmount1 / 10, "Incorrect balance for account2");
    }

    function testAccessControl() public {
        address nonOwner = address(0x9);
        uint256 mintAmount = 500 * 1e18;

        // Attempt to mint tokens by a non-owner
        vm.startPrank(nonOwner);
        vm.expectRevert();
        token.mint(address(1), mintAmount);
        vm.stopPrank();

        // Minting by the owner
        vm.startPrank(address(this));
        token.mint(address(1), mintAmount);
        vm.stopPrank();

        // Verify that the minting was successful
        assertEq(token.balanceOf(address(1)), mintAmount, "Owner should be able to mint");
    }

    function testEdgeCases() public {
        // Minting an excessive amount of tokens (overflow check)
        uint256 excessiveAmount = type(uint256).max;
        vm.startPrank(address(this));
        vm.expectRevert();
        token.mint(address(1), excessiveAmount);
        vm.stopPrank();
    }
}
