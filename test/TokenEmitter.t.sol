// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { unsafeWadDiv } from "../packages/revolution-contracts/libs/SignedWadMath.sol";
import { TokenEmitter } from "../packages/revolution-contracts/TokenEmitter.sol";
import { NontransferableERC20 } from "../packages/revolution-contracts/NontransferableERC20.sol";

contract TokenEmitterTest is Test {
    TokenEmitter public emitter;

    event Log(string, uint);

    // 1,000 tokens per day is the target emission
    uint256 tokensPerTimeUnit = 1_000;

    function setUp() public {
        vm.startPrank(address(0));

        address treasury = address(0);
        vm.deal(address(0), 100000 ether);
        vm.stopPrank();

        //20% - how much the price decays per unit of time with no sales
        int256 priceDecayPercent = 1e18 / 10;

        NontransferableERC20 governanceToken = new NontransferableERC20(address(this), "Revolution Governance", "GOV", 4);        

        // 1e11 or 0.0000001 is 2 cents per token even at $200k eth price
        int256 tokenTargetPrice = 1e11;

        //this setup assumes an ideal of 1e18 or 1 ETH (1k (1e3) * 1e11 * 4 decimals) coming into the system per day, token prices will increaase if more ETH comes in
        emitter = new TokenEmitter(governanceToken, treasury, tokenTargetPrice, priceDecayPercent, int256(1e18 * 1e4 * tokensPerTimeUnit));

        address emitterAddress = address(emitter);
        address thisAddress = address(this);
        address currentOwner = governanceToken.owner();

        governanceToken.transferOwnership(emitterAddress);
    }

    function testBuyingLaterIsBetter() public {
        vm.startPrank(address(0));

        uint256 initAmount = emitter.getTokenAmountForMultiPurchase(1e18);

        uint256 firstPrice = emitter.getTokenPrice(emitter.totalSupply());
        int256 targetSaleTimeFirst = emitter.getTargetSaleTime(int256(emitter.totalSupply()));
        
        // solhint-disable-next-line not-rely-on-time
        vm.warp(block.timestamp + (10 days));

        uint256 secondPrice = emitter.getTokenPrice(emitter.totalSupply());
        int256 targetSaleTimeSecond = emitter.getTargetSaleTime(int256(emitter.totalSupply()));
       
        uint256 laterAmount = emitter.getTokenAmountForMultiPurchase(1e18);

        assertGt(laterAmount, initAmount, "Later amount should be greater than initial amount");
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

    function testTransferTokenContractOwnership() public {
        // makes a token emitter with one nontransferableerc20
        // makes a second with the same one
        // ensures that the second cannot mint and calling buyGovernance fails
        // transfers ownership to the second
        // ensures that the second can mint and calling buyGovernance succeeds

        address treasury = address(0);

        // 0.1 per governance, 10% price decay per day, 100 governance sale target per day
        NontransferableERC20 governanceToken = new NontransferableERC20(address(this), "Revolution Governance", "GOV", 4);

        TokenEmitter emitter1 = new TokenEmitter(governanceToken, treasury, 1e14, 1e17, 1e22);

        TokenEmitter emitter2 = new TokenEmitter(governanceToken, treasury, 1e14, 1e17, 1e22);

        governanceToken.transferOwnership(address(emitter1));

        vm.deal(address(this), 100000 ether);

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        emitter1.buyToken{ value: 1e18 }(recipients, bps, 1);

        vm.prank(address(emitter1));

        governanceToken.transferOwnership(address(emitter2));

        vm.prank(address(0));
        emitter2.buyToken{ value: 1e18 }(recipients, bps, 1);
    }
    
    function testBuyTokenReentrancy() public {
        // Deploy the malicious treasury contract
        MaliciousTreasury maliciousTreasury = new MaliciousTreasury(address(emitter));

        // Initialize TokenEmitter with the address of the malicious treasury
        NontransferableERC20 governanceToken = new NontransferableERC20(address(this), "Revolution Governance", "GOV", 4);
        uint256 toScale = 1e18 * 1e4;
        uint256 tokensPerTimeUnit_ = 10_000;
        
        TokenEmitter emitter2 = new TokenEmitter(governanceToken, address(maliciousTreasury), 1e14, 1e17, int256(tokensPerTimeUnit_ * toScale));
        governanceToken.transferOwnership(address(emitter2));

        vm.deal(address(this), 100000 ether);

        //buy tokens and see if malicious treasury can reenter
        address[] memory recipients = new address[](1);
        recipients[0] = address(1);
        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;
        vm.expectRevert();
        emitter2.buyToken{ value: 1e18 }(recipients, bps, 1);

        emit log_uint(emitter2.totalSupply());
        emit log_uint(emitter2.balanceOf(address(maliciousTreasury)));
    }

    function testGetTokenAmountForMultiPurchaseGeneral() public {
        vm.startPrank(address(0));

        // Set up a typical payment amount
        uint256 payment = 1 ether; // A typical payment amount

        uint256 SOME_MAX_EXPECTED_VALUE = tokensPerTimeUnit * 1e4;

        uint256 slightlyMore = emitter.getTokenAmountForMultiPurchase(1.01 ether);

        // Call the function with the typical payment amount
        uint256 tokenAmount = emitter.getTokenAmountForMultiPurchase(payment);

        emit log_uint(tokenAmount);

        // Assert that the token amount is reasonable (not zero or unexpectedly high)
        assertGt(tokenAmount, 0, "Token amount should be greater than zero");
        assertLt(tokenAmount, SOME_MAX_EXPECTED_VALUE, "Token amount should be less than some max expected value");
        assertLt(tokenAmount, slightlyMore, "Token amount should be less than slightly more");

        // Log the token amount for debugging
        emit Log("Token Amount for Typical Payment: ", tokenAmount);

        //buy 10 ether of tokens
        address[] memory recipients = new address[](1);
        recipients[0] = address(1);
        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        emitter.buyToken{ value: payment }(recipients, bps, 1);

        uint256 newTokenAmount = emitter.getTokenAmountForMultiPurchase(payment);

        // Assert that the new token amount is less than the previous tokenAmount
        assertLt(newTokenAmount, tokenAmount, "Token amount should be less than previous token amount");

        vm.stopPrank();
    }

    function testGetTokenAmountForMultiPurchaseEdgeCases() public {
        vm.startPrank(address(0));

        uint256 tokenSupply = emitter.totalSupply();

        // Edge Case 1: Very Small Payment
        uint256 smallPayment = 0.00001 ether;
        uint256 smallPaymentTokenAmount = emitter.getTokenAmountForMultiPurchase(smallPayment);
        uint256 smallPaymentAmount2 = emitter._getTokenAmountForSinglePurchase(smallPayment, tokenSupply);
        uint256 overEstimated = emitter.UNSAFE_getOverestimateTokenAmount(smallPayment, tokenSupply);
        uint256 priceForFirstToken = emitter.getTokenPrice(tokenSupply);
        assertGt(smallPaymentTokenAmount, 0, "Token amount for small payment should be greater than zero");
        emit log_uint(smallPaymentTokenAmount);

        // A days worth of payment amount
        uint256 dailyPaymentTokenAmount = emitter.getTokenAmountForMultiPurchase(1 ether);
        assertLt(dailyPaymentTokenAmount, tokensPerTimeUnit * 1e4, "Token amount for daily payment should be less than tokens per day");
        emit log_string("Daily Payment Token Amount: ");
        emit log_uint(dailyPaymentTokenAmount);

        // Edge Case 2: Very Large Payment
        // An unusually large payment amount
        uint256 largePaymentTokenAmount = emitter.getTokenAmountForMultiPurchase(100 ether);
        //spending 100x the expected amount per day should get you < 25x the tokens
        uint256 SOME_REALISTIC_UPPER_BOUND = 25 * tokensPerTimeUnit * 1e4;
        assertLt(largePaymentTokenAmount, SOME_REALISTIC_UPPER_BOUND, "Token amount for large payment should be less than some realistic upper bound");
        emit log_string("Large Payment Token Amount: ");
        emit log_uint(largePaymentTokenAmount);

        uint256 largestPayment = 1_000 ether; // An unusually large payment amount
        uint256 largestPaymentTokenAmount = emitter.getTokenAmountForMultiPurchase(largestPayment);
        //spending 1000x the daily amount should get you less than 50x the tokens
        assertLt(largestPaymentTokenAmount, 50 * tokensPerTimeUnit * 1e4, "Token amount for largest payment should be less than some realistic upper bound");
        
        emit log_string("Largest Payment Token Amount: ");
        emit log_uint(largestPaymentTokenAmount);

        vm.stopPrank();
    }


    function testUNSAFE_getOverestimateTokenAmount() public {
        vm.startPrank(address(0));
        
        vm.deal(address(0), 100000 ether);
        vm.stopPrank();

        // Define payment and supply for the test
        uint256 payment = 1_000 ether; 
        uint256 supply = 0;    

        uint256 overestimatedAmount = emitter.UNSAFE_getOverestimateTokenAmount(payment, supply);

        // Now get the correct token amount for comparison
        uint256 correctAmount = emitter.getTokenAmountForMultiPurchase(payment);

        // Assert that the overestimated amount is indeed greater than the correct amount
        assertGt(overestimatedAmount, correctAmount, "Overestimated amount should be greater than correct amount");

        // Log the amounts for debugging purposes
        emit Log("Overestimated Amount: ", overestimatedAmount);
        emit Log("Correct Amount: ", correctAmount);
    }


    function testGetTokenPrice() public {
        vm.startPrank(address(0));

        vm.deal(address(0), 100000 ether);
        vm.stopPrank();

        uint256 priceFirstPurchase = emitter.getTokenPrice(0);
        emit log_uint(priceFirstPurchase);

        uint256 priceAfterManyPurchases = emitter.getTokenPrice(1_000);
        emit log_uint(priceAfterManyPurchases);

        // Simulate the passage of time
        uint256 daysElapsed = 21_000_000; // Change this value to test different scenarios
        vm.warp(block.timestamp + daysElapsed * 1 days);

        uint256 priceAfterManyDays = emitter.getTokenPrice(1_001);

        emit log_uint(priceAfterManyDays);

        // Assert that the price is greater than zero
        assertGt(priceAfterManyDays, 0, "Price should never hit zero");
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

