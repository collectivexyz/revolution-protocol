// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { unsafeWadDiv, toDaysWadUnsafe } from "../../src/libs/SignedWadMath.sol";
import { RevolutionPointsEmitter } from "../../src/RevolutionPointsEmitter.sol";
import { IRevolutionPointsEmitter } from "../../src/interfaces/IRevolutionPointsEmitter.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { ProtocolRewards } from "@cobuild/protocol-rewards/src/ProtocolRewards.sol";
import { wadDiv } from "../../src/libs/SignedWadMath.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { PointsEmitterTest } from "./PointsEmitter.t.sol";
import { IRevolutionPoints } from "../../src/interfaces/IRevolutionPoints.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";

contract EmissionRatesTest is PointsEmitterTest {
    function testBuyTokenWithDifferentRates(
        uint256 founderRateBps,
        uint256 founderEntropyRateBps,
        uint256 grantsRateBps
    ) public {
        // Assume valid rates
        founderRateBps = bound(founderRateBps, 0, 10000);
        founderEntropyRateBps = bound(founderEntropyRateBps, 0, 10000);
        grantsRateBps = bound(grantsRateBps, 0, 10000 - founderRateBps);

        setUpWithDifferentRates(founderRateBps, founderEntropyRateBps, grantsRateBps);

        vm.startPrank(address(executor));
        // Set creator and entropy rates
        assertEq(revolutionPointsEmitter.founderRateBps(), founderRateBps, "Creator rate not set correctly");
        assertEq(
            revolutionPointsEmitter.founderEntropyRateBps(),
            founderEntropyRateBps,
            "Entropy rate not set correctly"
        );

        // Setup for buying token
        address[] memory recipients = new address[](1);
        recipients[0] = address(1); // recipient address

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10000; // 100% of the tokens to the recipient

        uint256 valueToSend = 1 ether;
        revolutionPointsEmitter.setGrantsAddress(address(80));
        address creatorsAddress = revolutionPointsEmitter.founderAddress();
        uint256 creatorsInitialEthBalance = address(revolutionPointsEmitter.founderAddress()).balance;

        uint256 feeAmount = revolutionPointsEmitter.computeTotalReward(valueToSend);

        // Calculate expected ETH sent to creator
        uint256 totalPaymentForCreator = ((valueToSend - feeAmount) * founderRateBps) / 10000;
        uint256 expectedCreatorEth = (totalPaymentForCreator * founderEntropyRateBps) / 10000;

        if (founderRateBps == 0 || founderEntropyRateBps == 10_000)
            vm.expectRevert(abi.encodeWithSignature("INVALID_PAYMENT()"));
        uint256 expectedCreatorTokens = uint(
            revolutionPointsEmitter.getTokenQuoteForEther(totalPaymentForCreator - expectedCreatorEth)
        );

        // Perform token purchase
        vm.startPrank(address(this));
        uint256 tokensSold = revolutionPointsEmitter.buyToken{ value: valueToSend }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );

        // Verify tokens distributed to creator
        uint256 creatorTokenBalance = revolutionPointsEmitter.balanceOf(revolutionPointsEmitter.founderAddress());
        assertEq(creatorTokenBalance, expectedCreatorTokens, "Creator did not receive correct amount of tokens");

        // Verify ETH sent to creator
        uint256 creatorsNewEthBalance = address(revolutionPointsEmitter.founderAddress()).balance;
        assertEq(
            creatorsNewEthBalance - creatorsInitialEthBalance,
            expectedCreatorEth,
            "Incorrect ETH amount sent to creator"
        );

        // Verify tokens distributed to recipient
        uint256 recipientTokenBalance = revolutionPointsEmitter.balanceOf(address(1));
        assertEq(recipientTokenBalance, tokensSold, "Recipient did not receive correct amount of tokens");
    }

    function testGetTokenPrice() public {
        vm.startPrank(address(0));

        vm.deal(address(0), 100000 ether);
        vm.stopPrank();

        int256 priceAfterManyPurchases = revolutionPointsEmitter.buyTokenQuote(1e18);

        // Simulate the passage of time
        uint256 daysElapsed = 221;
        vm.warp(block.timestamp + daysElapsed * 1 days);

        int256 priceAfterManyDays = revolutionPointsEmitter.buyTokenQuote(1e18);

        // Assert that the price is greater than zero
        assertGt(priceAfterManyDays, 0, "Price should never hit zero");
    }

    function testBuyTokenTotalVal() public {
        vm.startPrank(address(0));

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        vm.deal(address(0), 100000 ether);

        vm.stopPrank();
        // set setCreatorsAddress
        vm.prank(address(executor));
        revolutionPointsEmitter.setGrantsAddress(address(100));

        setUpWithDifferentRates(0, 0, 0);

        vm.startPrank(address(0));

        revolutionPointsEmitter.buyToken{ value: 1e18 }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );

        // save treasury ETH balance
        uint256 treasuryEthBalance = address(revolutionPointsEmitter.owner()).balance;
        // save buyer token balance
        uint256 buyerTokenBalance = revolutionPointsEmitter.balanceOf(address(1));

        // save protocol fees
        uint256 protocolFees = (1e18 * 250) / 10_000;

        // convert token balances to ETH
        uint256 buyerTokenBalanceEth = uint256(revolutionPointsEmitter.buyTokenQuote(buyerTokenBalance));

        // Sent in ETH should be almost equal (account for precision/rounding) to total ETH plus token value in ETH
        assertGt(1e18 * 2, treasuryEthBalance + protocolFees + buyerTokenBalanceEth, "");
    }

    function testBuyingTwiceAmountIsNotMoreThanTwiceEmittedTokens() public {
        vm.startPrank(address(0));

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        revolutionPointsEmitter.buyToken{ value: 1e18 }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );
        uint256 firstAmount = revolutionPointsEmitter.balanceOf(address(1));

        revolutionPointsEmitter.buyToken{ value: 1e18 }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );
        uint256 secondAmountDifference = revolutionPointsEmitter.balanceOf(address(1)) - firstAmount;

        assert(secondAmountDifference <= 2 * revolutionPointsEmitter.totalSupply());
    }

    //if buyToken is called with payment 0, then it should revert with INVALID_PAYMENT()
    function test_revertNoPayment() public {
        vm.startPrank(address(0));

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        vm.expectRevert(abi.encodeWithSignature("INVALID_PAYMENT()"));
        revolutionPointsEmitter.buyToken{ value: 0 }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(1),
                deployer: address(0)
            })
        );
    }

    function test_correctEmitted(uint256 founderRateBps, uint256 founderEntropyRateBps, uint256 grantsRateBps) public {
        // Assume valid rates
        founderRateBps = bound(founderRateBps, 0, 10000);
        founderEntropyRateBps = bound(founderEntropyRateBps, 0, 10000);
        grantsRateBps = bound(grantsRateBps, 0, 10000 - founderRateBps);

        setUpWithDifferentRates(founderRateBps, founderEntropyRateBps, grantsRateBps);

        vm.startPrank(revolutionPointsEmitter.owner());

        vm.stopPrank();

        vm.deal(address(this), 100000 ether);

        //expect balance to start out at 0
        assertEq(revolutionPoints.balanceOf(revolutionPointsEmitter.founderAddress()), 0, "Balance should start at 0");

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        //expect recipient0 balance to start out at 0
        assertEq(revolutionPoints.balanceOf(address(1)), 0, "Balance should start at 0");

        //get msg value remaining
        uint256 msgValueRemaining = 1 ether - revolutionPointsEmitter.computeTotalReward(1 ether);

        //Share of purchase amount to send to owner
        uint256 toPayOwner = (msgValueRemaining * (10_000 - founderRateBps - grantsRateBps)) / 10_000;

        //Ether directly sent to creators
        uint256 founderDirectPayment = (msgValueRemaining * founderRateBps * founderEntropyRateBps) / 10_000 / 10_000;

        uint256 founderGovernancePayment = (msgValueRemaining * founderRateBps) / 10_000 - founderDirectPayment;

        //get expected tokens for creators
        int256 expectedAmountForFounder = founderGovernancePayment > 0
            ? revolutionPointsEmitter.getTokenQuoteForEther(founderGovernancePayment)
            : int256(0);

        //get expected tokens for recipient0
        int256 expectedAmountForRecipient0 = getTokenQuoteForEtherHelper(toPayOwner, expectedAmountForFounder);

        revolutionPointsEmitter.buyToken{ value: 1 ether }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );

        //assert that creatorsAddress balance is correct
        assertEq(
            uint(revolutionPoints.balanceOf(revolutionPointsEmitter.founderAddress())),
            uint(expectedAmountForFounder),
            "Creators should have correct balance"
        );

        // assert that recipient0 balance is correct
        assertEq(
            uint(revolutionPoints.balanceOf(address(1))),
            uint(expectedAmountForRecipient0),
            "Recipient0 should have correct balance"
        );
    }

    function test_BuyingFunctionBreaksAfterAPeriodOfTime(
        uint256 founderRateBps,
        uint256 founderEntropyRateBps,
        uint256 grantsRateBps,
        uint256 randomTime
    ) public {
        randomTime = bound(randomTime, 300 days, 700 days);
        // Assume valid rates
        founderRateBps = bound(founderRateBps, 0, 10000);
        founderEntropyRateBps = bound(founderEntropyRateBps, 0, 10000);
        grantsRateBps = bound(grantsRateBps, 0, 10000 - founderRateBps);

        uint256 currentTime = 1702801400;

        // warp to a more realistic time
        vm.warp(block.timestamp + currentTime);

        setUpWithDifferentRates(founderRateBps, founderEntropyRateBps, grantsRateBps);

        vm.startPrank(address(executor));
        // Set creator and entropy rates
        assertEq(revolutionPointsEmitter.founderRateBps(), founderRateBps, "Creator rate not set correctly");
        assertEq(
            revolutionPointsEmitter.founderEntropyRateBps(),
            founderEntropyRateBps,
            "Entropy rate not set correctly"
        );

        // Setup for buying token
        address[] memory recipients = new address[](1);
        recipients[0] = address(1); // recipient address

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10000; // 100% of the tokens to the recipient

        uint256 valueToSend = 1 ether;

        // Perform token purchase
        vm.startPrank(address(this));
        uint256 tokensSold = revolutionPointsEmitter.buyToken{ value: valueToSend }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );
    }

    function _calculateBuyTokenPaymentShares(
        uint256 msgValueRemaining
    ) internal view returns (IRevolutionPointsEmitter.BuyTokenPaymentShares memory buyTokenPaymentShares) {
        // If rewards are expired, founder gets 0
        uint256 founderPortion = revolutionPointsEmitter.founderRateBps();

        if (block.timestamp > revolutionPointsEmitter.founderRewardsExpirationDate()) {
            founderPortion = 0;
        }

        // Calculate share of purchase amount reserved for buyers
        buyTokenPaymentShares.buyersGovernancePayment =
            msgValueRemaining -
            ((msgValueRemaining * founderPortion) / 10_000) -
            ((msgValueRemaining * revolutionPointsEmitter.grantsRateBps()) / 10_000);

        // Calculate ether directly sent to founder
        buyTokenPaymentShares.founderDirectPayment =
            (msgValueRemaining * founderPortion * revolutionPointsEmitter.founderEntropyRateBps()) /
            10_000 /
            10_000;

        // Calculate ether spent on founder governance tokens
        buyTokenPaymentShares.founderGovernancePayment =
            ((msgValueRemaining * founderPortion) / 10_000) -
            buyTokenPaymentShares.founderDirectPayment;

        buyTokenPaymentShares.grantsDirectPayment =
            (msgValueRemaining * revolutionPointsEmitter.grantsRateBps()) /
            10_000;
    }

    struct PaymentDistribution {
        uint256 toPayOwner;
        uint256 toPayFounder;
    }

    function _calculatePaymentDistribution(
        uint256 founderGovernancePoints,
        IRevolutionPointsEmitter.BuyTokenPaymentShares memory buyTokenPaymentShares
    ) internal pure returns (PaymentDistribution memory distribution) {
        distribution.toPayOwner = buyTokenPaymentShares.buyersGovernancePayment;
        distribution.toPayFounder = buyTokenPaymentShares.founderDirectPayment;

        // If the founder is receiving points, add the founder's points payment to the owner's payment
        if (founderGovernancePoints > 0) {
            distribution.toPayOwner += buyTokenPaymentShares.founderGovernancePayment;
        } else if (founderGovernancePoints == 0 && buyTokenPaymentShares.founderGovernancePayment > 0) {
            // If the founder is not receiving any points, but ETH should be spent to buy them points, just send the ETH to the founder
            distribution.toPayFounder += buyTokenPaymentShares.founderGovernancePayment;
        }

        return distribution;
    }

    // Test that founder rewards expire after a set expiration time
    function test_FounderRewardsExpireCorrectly(
        uint256 founderRateBps,
        uint256 founderEntropyRateBps,
        uint256 grantsRateBps,
        uint256 valueToSend,
        uint256 expiryDuration
    ) public {
        valueToSend = bound(valueToSend, 0.0000001 ether, 1e12 ether);

        // Calculate value left after sharing protocol rewards
        uint256 msgValueRemaining = valueToSend - revolutionPointsEmitter.computeTotalReward(valueToSend);

        founderRateBps = bound(founderRateBps, 1, 10000);
        founderEntropyRateBps = bound(founderEntropyRateBps, 1, 10000);
        grantsRateBps = bound(grantsRateBps, 0, 10000 - founderRateBps);
        expiryDuration = bound(expiryDuration, 1 days, 3650 days);
        setUpWithDifferentRatesAndExpiry(
            founderRateBps,
            founderEntropyRateBps,
            grantsRateBps,
            block.timestamp + expiryDuration
        );

        // Warp to just before the expiry
        vm.warp(block.timestamp + expiryDuration - 1);

        IRevolutionPointsEmitter.BuyTokenPaymentShares memory buyTokenPaymentSharesOg = _calculateBuyTokenPaymentShares(
            msgValueRemaining
        );

        uint256 founderGovernancePoints = buyTokenPaymentSharesOg.founderGovernancePayment > 0
            ? uint256(revolutionPointsEmitter.getTokenQuoteForEther(buyTokenPaymentSharesOg.founderGovernancePayment))
            : 0;

        PaymentDistribution memory distribution = _calculatePaymentDistribution(
            founderGovernancePoints,
            buyTokenPaymentSharesOg
        );

        vm.expectEmit(true, true, true, true);
        emit IRevolutionPointsEmitter.PurchaseFinalized(
            address(this),
            valueToSend,
            distribution.toPayOwner,
            valueToSend - msgValueRemaining,
            buyTokenPaymentSharesOg.buyersGovernancePayment > 0
                ? uint256(
                    //since founder gov shares are purchased first
                    getTokenQuoteForEtherHelper(
                        buyTokenPaymentSharesOg.buyersGovernancePayment,
                        int256(founderGovernancePoints)
                    )
                )
                : 0,
            founderGovernancePoints,
            distribution.toPayFounder,
            buyTokenPaymentSharesOg.grantsDirectPayment
        );

        // Perform token purchase just before expiry
        performTokenPurchase(valueToSend);

        uint256 pointsBalanceBeforeExpiry = revolutionPoints.balanceOf(revolutionPointsEmitter.founderAddress());
        uint256 ethBalanceBeforeExpiry = address(revolutionPointsEmitter.founderAddress()).balance;

        // Check founder balance just before expiry
        if (founderEntropyRateBps < 9990) {
            assertGt(pointsBalanceBeforeExpiry, 0, "Founder should have points rewards before expiry");
        }
        assertGt(ethBalanceBeforeExpiry, 0, "Founder should have eth rewards before expiry");

        // Warp to just after the expiry
        vm.warp(block.timestamp + expiryDuration + 1);

        IRevolutionPointsEmitter.BuyTokenPaymentShares memory buyTokenPaymentShares = _calculateBuyTokenPaymentShares(
            msgValueRemaining
        );

        vm.expectEmit(true, true, true, true);
        emit IRevolutionPointsEmitter.PurchaseFinalized(
            address(this),
            valueToSend,
            buyTokenPaymentShares.buyersGovernancePayment + buyTokenPaymentShares.founderGovernancePayment,
            valueToSend - msgValueRemaining,
            uint256(revolutionPointsEmitter.getTokenQuoteForPayment(valueToSend)),
            0,
            0,
            buyTokenPaymentShares.grantsDirectPayment
        );

        // Perform token purchase just after expiry
        performTokenPurchase(valueToSend);

        assertEq(
            pointsBalanceBeforeExpiry,
            revolutionPoints.balanceOf(revolutionPointsEmitter.founderAddress()),
            "Founder should not receive points rewards after expiry"
        );

        assertEq(
            ethBalanceBeforeExpiry,
            address(revolutionPointsEmitter.founderAddress()).balance,
            "Founder should not receive eth rewards after expiry"
        );

        vm.expectEmit(true, true, true, true);
        emit IRevolutionPointsEmitter.PurchaseFinalized(
            address(this),
            valueToSend,
            buyTokenPaymentShares.buyersGovernancePayment + buyTokenPaymentShares.founderGovernancePayment,
            valueToSend - msgValueRemaining,
            uint256(
                revolutionPointsEmitter.getTokenQuoteForEther(
                    msgValueRemaining - buyTokenPaymentShares.grantsDirectPayment
                )
            ),
            0,
            0,
            buyTokenPaymentShares.grantsDirectPayment
        );

        // Perform token purchase just after expiry
        performTokenPurchase(valueToSend);
    }

    function performTokenPurchase(uint256 valueToSend) internal {
        address[] memory recipients = new address[](1);
        recipients[0] = address(1); // recipient address

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10000; // 100% of the tokens to the recipient

        //vm deal valueToSend
        vm.deal(address(this), valueToSend);

        // Perform token purchase
        vm.startPrank(address(this));
        revolutionPointsEmitter.buyToken{ value: valueToSend }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );
        vm.stopPrank();
    }

    // Test that founder rewards expire after a set expiration time
    function test_FounderRewardsExpireForQuoteUtils(
        uint256 founderRateBps,
        uint256 founderEntropyRateBps,
        uint256 grantsRateBps,
        uint256 valueToSend,
        uint256 expiryDuration
    ) public {
        valueToSend = bound(valueToSend, 1, 1e12 ether);

        // Calculate value left after sharing protocol rewards
        uint256 msgValueRemaining = valueToSend - revolutionPointsEmitter.computeTotalReward(valueToSend);

        founderRateBps = bound(founderRateBps, 1, 10000);
        founderEntropyRateBps = bound(founderEntropyRateBps, 1, 10000);
        grantsRateBps = bound(grantsRateBps, 0, 10000 - founderRateBps);

        expiryDuration = bound(expiryDuration, 1 days, 3650 days);

        setUpWithDifferentRatesAndExpiry(
            founderRateBps,
            founderEntropyRateBps,
            grantsRateBps,
            block.timestamp + expiryDuration
        );

        // Warp to just before the expiry
        vm.warp(block.timestamp + expiryDuration - 1);

        IRevolutionPointsEmitter.BuyTokenPaymentShares memory buyTokenPaymentSharesOg = _calculateBuyTokenPaymentShares(
            msgValueRemaining
        );

        int256 founderGovernance = buyTokenPaymentSharesOg.founderGovernancePayment > 0
            ? revolutionPointsEmitter.getTokenQuoteForEther(buyTokenPaymentSharesOg.founderGovernancePayment)
            : int(0);

        //expect getTokenQuoteForEther (buyergovernancepayment) == getTokenForPayment (valueToSend) since founder has rewards
        assertEq(
            buyTokenPaymentSharesOg.buyersGovernancePayment > 0
                ? uint256(
                    getTokenQuoteForEtherHelper(buyTokenPaymentSharesOg.buyersGovernancePayment, founderGovernance)
                )
                : 0,
            uint256(revolutionPointsEmitter.getTokenQuoteForPayment(valueToSend)),
            "Token quote for payment and ether should be equal for buyerGov payment"
        );

        // Warp to just after the expiry
        vm.warp(block.timestamp + expiryDuration + 1);

        IRevolutionPointsEmitter.BuyTokenPaymentShares memory buyTokenPaymentShares = _calculateBuyTokenPaymentShares(
            msgValueRemaining
        );

        //get token quote for ether doesn't account for founder rewards or protocol rewards
        //get token quote for payment accounts for founder rewards and protocol rewards
        uint256 msgValueMinusGrants = msgValueRemaining - buyTokenPaymentShares.grantsDirectPayment;

        assertEq(
            uint256(revolutionPointsEmitter.getTokenQuoteForEther(buyTokenPaymentShares.buyersGovernancePayment)),
            uint256(revolutionPointsEmitter.getTokenQuoteForEther(msgValueMinusGrants)),
            "Token quote for payment and ether should be equal for buyerGov payment"
        );

        //expect getTokenQuoteForEther (msgValueRemaining) ==  getTokenQuoteForPayment (valueToSend) since founder has no rewards
        assertEq(
            uint256(revolutionPointsEmitter.getTokenQuoteForPayment(valueToSend)),
            uint256(revolutionPointsEmitter.getTokenQuoteForEther(msgValueMinusGrants)),
            "Token quote for payment and ether should be equal"
        );
    }
}
