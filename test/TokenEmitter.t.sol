// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { TokenEmitter } from "../packages/revolution-contracts/TokenEmitter.sol";
import { NontransferableERC20 } from "../packages/revolution-contracts/NontransferableERC20.sol";

contract TokenEmitterTest is Test {
    TokenEmitter public emitter;

    event Log(string, uint);

    function setUp() public {
        vm.startPrank(address(0));

        address treasury = address(0);

        // 0.1 per governance, 10% price decay per day, 100 governance sale target per day
        NontransferableERC20 governanceToken = new NontransferableERC20("Revolution Governance", "GOV");

        uint256 toScale = 1e18;

        uint256 tokensPerTimeUnit = 10_000;
        emitter = new TokenEmitter(governanceToken, treasury, 1e14, 1e17, int256(tokensPerTimeUnit * toScale));

        governanceToken.transferAdmin(address(emitter));

        vm.deal(address(0), 100000 ether);
        vm.stopPrank();
    }

    function testBuyToken() public {
        vm.startPrank(address(0));

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        emitter.buyToken{ value: 1e18 }(recipients, bps, 1);
        emit Log("Balance: ", emitter.balanceOf(address(1)));
    }

    function testBuyTokenPriceIncreases() public {
        vm.startPrank(address(0));

        address[] memory firstRecipients = new address[](1);
        firstRecipients[0] = address(1);

        address[] memory secondRecipients = new address[](1);
        secondRecipients[0] = address(2);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        emitter.buyToken{ value: 10e18 }(firstRecipients, bps, 1);

        emitter.buyToken{ value: 10e18 }(secondRecipients, bps, 1);

        // should get more expensive
        assert(emitter.balanceOf(address(1)) > emitter.balanceOf(address(2)));
    }

    // test multiple payouts
    function testPercentagePayouts() public {
        vm.startPrank(address(0));

        address[] memory recipients = new address[](2);
        recipients[0] = address(1);
        recipients[1] = address(2);

        uint256[] memory bps = new uint256[](2);
        bps[0] = 5_000;
        bps[1] = 5_000;

        emitter.buyToken{ value: 1e18 }(recipients, bps, 1);
        assert(emitter.balanceOf(address(1)) == emitter.balanceOf(address(2)));
    }

        // Test to ensure the total basis points add up to 100%
    function testTotalBasisPoints() public {
        vm.startPrank(address(0));

        address[] memory recipients = new address[](2);
        recipients[0] = address(1);
        recipients[1] = address(2);

        // Test case with correct total of 10,000 basis points (100%)
        uint256[] memory correctBps = new uint256[](2);
        correctBps[0] = 5000; // 50%
        correctBps[1] = 5000; // 50%

        // Attempting a valid token purchase
        emitter.buyToken{ value: 1e18 }(recipients, correctBps, 1);
        uint totalSupplyAfterValidPurchase = emitter.totalSupply();
        assertGt(totalSupplyAfterValidPurchase, 0, "Token purchase should have increased total supply");

        // Test case with incorrect total of basis points
        uint256[] memory incorrectBps = new uint256[](2);
        incorrectBps[0] = 4000; // 40%
        incorrectBps[1] = 4000; // 40%

        // Expecting the transaction to revert due to incorrect total basis points
        vm.expectRevert("bps must add up to 10_000");
        emitter.buyToken{ value: 1e18 }(recipients, incorrectBps, 1);

        vm.stopPrank();
    }

    // // TODO: test scamming creator fails with percentage low
    // function testFailLowPercentage() public {
    //     vm.startPrank(address(0));

    //     address[] memory recipients = new address[](2);
    //     recipients[0] = address(1);
    //     recipients[1] = address(2);

    //     uint256[] memory bps = new uint256[](2);
    //     bps[0] = 9_500;
    //     bps[1] = 500;

    //     emitter.buyToken{value: 1e18}(recipients, bps);
    // }

    function testBuyingTwiceAmountIsNotMoreThanTwiceEmittedTokens() public {
        vm.startPrank(address(0));

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        emitter.buyToken{ value: 1e18 }(recipients, bps, 1);
        uint256 firstAmount = emitter.balanceOf(address(1));

        emitter.buyToken{ value: 1e18 }(recipients, bps, 1);
        uint256 secondAmountDifference = emitter.balanceOf(address(1)) - firstAmount;

        assert(secondAmountDifference <= 2 * emitter.totalSupply());
    }

    function testBuyingLaterIsBetter() public {
        vm.startPrank(address(0));

        uint256 initAmount = emitter.getTokenAmountForMultiPurchase(1e18);
        // solhint-disable-next-line not-rely-on-time
        vm.warp(block.timestamp + (10 days));

        uint256 laterAmount = emitter.getTokenAmountForMultiPurchase(1e18);

        assert(laterAmount > initAmount);
    }

    function testTransferTokenContractOwnership() public {
        // makes a token emitter with one nontransferableerc20
        // makes a second with the same one
        // ensures that the second cannot mint and calling buyGovernance fails
        // transfers ownership to the second
        // ensures that the second can mint and calling buyGovernance succeeds

        vm.startPrank(address(0));

        address treasury = address(0);

        // 0.1 per governance, 10% price decay per day, 100 governance sale target per day
        NontransferableERC20 governanceToken = new NontransferableERC20("Revolution Governance", "GOV");

        TokenEmitter emitter1 = new TokenEmitter(governanceToken, treasury, 1e14, 1e17, 1e22);

        TokenEmitter emitter2 = new TokenEmitter(governanceToken, treasury, 1e14, 1e17, 1e22);

        governanceToken.transferAdmin(address(emitter1));

        vm.deal(address(0), 100000 ether);

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        emitter1.buyToken{ value: 1e18 }(recipients, bps, 1);

        vm.stopPrank();
        vm.prank(address(emitter1));

        governanceToken.transferAdmin(address(emitter2));

        vm.prank(address(0));
        emitter2.buyToken{ value: 1e18 }(recipients, bps, 1);
    }

    function testTransferTokenAdmin() public {
        vm.prank(address(0));
        emitter.transferTokenAdmin(address(1));
    }

    function testFailTransferTokenAdminIfNotAdmin() public {
        vm.prank(address(0));
        emitter.transferTokenAdmin(address(1));
        vm.prank(address(0));
        emitter.transferTokenAdmin(address(2));
    }
    
    function testBuyTokenReentrancy() public {
        vm.startPrank(address(0));

        // Deploy the malicious treasury contract
        MaliciousTreasury maliciousTreasury = new MaliciousTreasury(address(emitter));

        // Initialize TokenEmitter with the address of the malicious treasury
        NontransferableERC20 governanceToken = new NontransferableERC20("Revolution Governance", "GOV");
        uint256 toScale = 1e18;
        uint256 tokensPerTimeUnit = 10_000;
        TokenEmitter emitter2 = new TokenEmitter(governanceToken, address(maliciousTreasury), 1e14, 1e17, int256(tokensPerTimeUnit * toScale));
        governanceToken.transferAdmin(address(emitter2));

        vm.deal(address(0), 100000 ether);
        vm.stopPrank();

        // Send 1 ETH to the malicious treasury
        vm.prank(address(0));

        //buy tokens and see if malicious treasury can reenter
        address[] memory recipients = new address[](1);
        recipients[0] = address(1);
        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;
        vm.expectRevert();
        emitter2.buyToken{ value: 1e18 }(recipients, bps, 1);

        emit log_uint(emitter2.totalSupply());
        emit log_uint(emitter2.balanceOf(address(maliciousTreasury)));

        assertTrue(true);

    }

}


contract MaliciousTreasury {
    TokenEmitter emitter;
    bool public reentryAttempted;

    constructor(address _emitter) {
        emitter = TokenEmitter(_emitter);
        reentryAttempted = false;
    }

    // Fallback function to enable re-entrance to TokenEmitter
    function call() external payable {
        reentryAttempted = true;
        address[] memory recipients = new address[](1);
        recipients[0] = address(this);
        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        // Attempt to re-enter TokenEmitter
        emitter.buyToken{value: msg.value}(recipients, bps, 1);

    }
}

