// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { unsafeWadDiv } from "../../src/libs/SignedWadMath.sol";
import { TokenEmitter } from "../../src/TokenEmitter.sol";
import { NontransferableERC20 } from "../../src/NontransferableERC20.sol";
import { RevolutionProtocolRewards } from "@collectivexyz/protocol-rewards/src/RevolutionProtocolRewards.sol";

contract TokenEmitterTest is Test {
    TokenEmitter public emitter;

    event Log(string, uint);

    // 1,000 tokens per day is the target emission
    uint256 tokensPerTimeUnit = 1_000;

    function setUp() public {
        vm.startPrank(address(0));
        RevolutionProtocolRewards protocolRewards = new RevolutionProtocolRewards();

        address treasury = address(0);
        vm.deal(address(0), 100000 ether);
        vm.stopPrank();

        //20% - how much the price decays per unit of time with no sales
        int256 priceDecayPercent = 1e18 / 10;

        NontransferableERC20 governanceToken = new NontransferableERC20(address(this), "Revolution Governance", "GOV", 4);

        // 1e11 or 0.0000001 is 2 cents per token even at $200k eth price
        int256 tokenTargetPrice = 1e11;

        //this setup assumes an ideal of 1e18 or 1 ETH (1k (1e3) * 1e11 * 4 decimals) coming into the system per day, token prices will increaase if more ETH comes in
        emitter = new TokenEmitter(
            governanceToken,
            address(protocolRewards),
            address(this),
            treasury,
            tokenTargetPrice,
            priceDecayPercent,
            int256(1e18 * 1e4 * tokensPerTimeUnit)
        );

        address emitterAddress = address(emitter);

        governanceToken.transferOwnership(emitterAddress);
    }

    function testBuyingLaterIsBetter() public {
        vm.startPrank(address(0));

        int256 initAmount = emitter.getTokenQuoteForPayment(1e18);

        int256 firstPrice = emitter.buyTokenQuote(emitter.totalSupply());

        // solhint-disable-next-line not-rely-on-time
        vm.warp(block.timestamp + (10 days));

        int256 secondPrice = emitter.buyTokenQuote(emitter.totalSupply());

        int256 laterAmount = emitter.getTokenQuoteForPayment(1e18);

        assertGt(laterAmount, initAmount, "Later amount should be greater than initial amount");

        assertLt(secondPrice, firstPrice, "Second price should be less than first price");
    }

    function testBuyToken() public {
        vm.startPrank(address(0));

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        emitter.buyToken{ value: 1e18 }(recipients, bps, address(0), address(0), address(0));
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

        emitter.buyToken{ value: 10e18 }(firstRecipients, bps, address(0), address(0), address(0));

        emitter.buyToken{ value: 10e18 }(secondRecipients, bps, address(0), address(0), address(0));

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

        emitter.buyToken{ value: 1e18 }(recipients, bps, address(0), address(0), address(0));
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
        emitter.buyToken{ value: 1e18 }(recipients, correctBps, address(0), address(0), address(0));
        uint totalSupplyAfterValidPurchase = emitter.totalSupply();
        assertGt(totalSupplyAfterValidPurchase, 0, "Token purchase should have increased total supply");

        // Test case with incorrect total of basis points
        uint256[] memory incorrectBps = new uint256[](2);
        incorrectBps[0] = 4000; // 40%
        incorrectBps[1] = 4000; // 40%

        // Expecting the transaction to revert due to incorrect total basis points
        vm.expectRevert("bps must add up to 10_000");
        emitter.buyToken{ value: 1e18 }(recipients, incorrectBps, address(0), address(0), address(0));

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

        emitter.buyToken{ value: 1e18 }(recipients, bps, address(0), address(0), address(0));
        uint256 firstAmount = emitter.balanceOf(address(1));

        emitter.buyToken{ value: 1e18 }(recipients, bps, address(0), address(0), address(0));
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
        RevolutionProtocolRewards protocolRewards = new RevolutionProtocolRewards();

        TokenEmitter emitter1 = new TokenEmitter(governanceToken, address(protocolRewards), address(this), treasury, 1e14, 1e17, 1e22);

        TokenEmitter emitter2 = new TokenEmitter(governanceToken, address(protocolRewards), address(this), treasury, 1e14, 1e17, 1e22);

        governanceToken.transferOwnership(address(emitter1));

        vm.deal(address(this), 100000 ether);

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        emitter1.buyToken{ value: 1e18 }(recipients, bps, address(0), address(0), address(0));

        vm.prank(address(emitter1));

        governanceToken.transferOwnership(address(emitter2));

        vm.prank(address(0));
        emitter2.buyToken{ value: 1e18 }(recipients, bps, address(0), address(0), address(0));
    }

    function testBuyTokenReentrancy() public {
        // Deploy the malicious treasury contract
        MaliciousTreasury maliciousTreasury = new MaliciousTreasury(address(emitter));

        // Initialize TokenEmitter with the address of the malicious treasury
        NontransferableERC20 governanceToken = new NontransferableERC20(address(this), "Revolution Governance", "GOV", 4);
        uint256 toScale = 1e18 * 1e4;
        uint256 tokensPerTimeUnit_ = 10_000;
        RevolutionProtocolRewards protocolRewards = new RevolutionProtocolRewards();

        TokenEmitter emitter2 = new TokenEmitter(
            governanceToken,
            address(protocolRewards),
            address(this),
            address(maliciousTreasury),
            1e14,
            1e17,
            int256(tokensPerTimeUnit_ * toScale)
        );
        governanceToken.transferOwnership(address(emitter2));

        vm.deal(address(this), 100000 ether);

        //buy tokens and see if malicious treasury can reenter
        address[] memory recipients = new address[](1);
        recipients[0] = address(1);
        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;
        vm.expectRevert();
        emitter2.buyToken{ value: 1e18 }(recipients, bps, address(0), address(0), address(0));

        emit log_uint(emitter2.totalSupply());
        emit log_uint(emitter2.balanceOf(address(maliciousTreasury)));
    }

    function testGetTokenAmountForMultiPurchaseGeneral() public {
        vm.startPrank(address(0));

        // Set up a typical payment amount
        uint256 payment = 1 ether; // A typical payment amount

        uint256 SOME_MAX_EXPECTED_VALUE = tokensPerTimeUnit * 1e4;

        int256 slightlyMore = emitter.getTokenQuoteForPayment(1.01 ether);

        // Call the function with the typical payment amount
        int256 tokenAmount = emitter.getTokenQuoteForPayment(payment);

        emit log_int(tokenAmount);

        // Assert that the token amount is reasonable (not zero or unexpectedly high)
        assertGt(tokenAmount, 0, "Token amount should be greater than zero");
        assertLt(tokenAmount, int256(SOME_MAX_EXPECTED_VALUE), "Token amount should be less than some max expected value");
        assertLt(tokenAmount, slightlyMore, "Token amount should be less than slightly more");

        //buy 10 ether of tokens
        address[] memory recipients = new address[](1);
        recipients[0] = address(1);
        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        emitter.buyToken{ value: payment }(recipients, bps, address(0), address(0), address(0));

        int256 newTokenAmount = emitter.getTokenQuoteForPayment(payment);

        // Assert that the new token amount is less than the previous tokenAmount
        assertLt(newTokenAmount, tokenAmount, "Token amount should be less than previous token amount");

        vm.stopPrank();
    }

    function testGetTokenAmountForMultiPurchaseEdgeCases() public {
        vm.startPrank(address(0));

        // Edge Case 1: Very Small Payment
        uint256 smallPayment = 0.00001 ether;
        int256 smallPaymentTokenAmount = emitter.getTokenQuoteForPayment(smallPayment);
        assertGt(smallPaymentTokenAmount, 0, "Token amount for small payment should be greater than zero");
        emit log_int(smallPaymentTokenAmount);

        // A days worth of payment amount
        int256 dailyPaymentTokenAmount = emitter.getTokenQuoteForPayment(1 ether);
        assertLt(uint256(dailyPaymentTokenAmount), tokensPerTimeUnit * 1e4, "Token amount for daily payment should be less than tokens per day");
        emit log_string("Daily Payment Token Amount: ");
        emit log_int(dailyPaymentTokenAmount);

        // Edge Case 2: Very Large Payment
        // An unusually large payment amount
        int256 largePaymentTokenAmount = emitter.getTokenQuoteForPayment(100 ether);
        //spending 100x the expected amount per day should get you < 25x the tokens
        uint256 SOME_REALISTIC_UPPER_BOUND = 25 * tokensPerTimeUnit * 1e4;
        assertLt(uint256(largePaymentTokenAmount), SOME_REALISTIC_UPPER_BOUND, "Token amount for large payment should be less than some realistic upper bound");
        emit log_string("Large Payment Token Amount: ");
        emit log_int(largePaymentTokenAmount);

        uint256 largestPayment = 1_000 ether; // An unusually large payment amount
        int256 largestPaymentTokenAmount = emitter.getTokenQuoteForPayment(largestPayment);
        //spending 1000x the daily amount should get you less than 50x the tokens
        assertLt(uint256(largestPaymentTokenAmount), 50 * tokensPerTimeUnit * 1e4, "Token amount for largest payment should be less than some realistic upper bound");

        emit log_string("Largest Payment Token Amount: ");
        emit log_int(largestPaymentTokenAmount);
        

        vm.stopPrank();
    }

    function testGetTokenPrice() public {
        vm.startPrank(address(0));

        vm.deal(address(0), 100000 ether);
        vm.stopPrank();

        int256 priceFirstPurchase = emitter.buyTokenQuote(0);
        emit log_int(priceFirstPurchase);

        int256 priceAfterManyPurchases = emitter.buyTokenQuote(1_000);
        emit log_int(priceAfterManyPurchases);

        // Simulate the passage of time
        uint256 daysElapsed = 21_000_000; // Change this value to test different scenarios
        vm.warp(block.timestamp + daysElapsed * 1 days);

        int256 priceAfterManyDays = emitter.buyTokenQuote(1_001);

        emit log_int(priceAfterManyDays);

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
        emitter.buyToken{ value: msg.value }(recipients, bps, address(0), address(0), address(0));
    }
}
