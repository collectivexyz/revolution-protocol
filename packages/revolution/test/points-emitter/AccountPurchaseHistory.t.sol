// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

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
import { console2 } from "forge-std/console2.sol";
import { IRevolutionToken } from "../../src/interfaces/IRevolutionToken.sol";
import { IAuctionHouse } from "../../src/interfaces/IAuctionHouse.sol";

contract AccountPurchaseHistoryTest is PointsEmitterTest {
    function calculateAmountForBuyers(uint256 amount) public view returns (uint256) {
        // Accessing creatorRateBps and grantsRateBps from the revolutionPointsEmitter contract
        uint256 founderRateBps = revolutionPointsEmitter.founderRateBps();
        uint256 grantsRateBps = revolutionPointsEmitter.grantsRateBps();

        uint256 founderShare = (amount * founderRateBps) / 10_000;
        uint256 grantsShare = (amount * grantsRateBps) / 10_000;
        uint256 amountPaidToOwner = amount - founderShare - grantsShare;
        return amountPaidToOwner;
    }

    function calculateFounderGovernancePayment(uint256 amount) public view returns (uint256) {
        // Accessing creatorRateBps and grantsRateBps from the revolutionPointsEmitter contract
        uint256 founderRate = revolutionPointsEmitter.founderRateBps();
        uint256 founderEntropyRateBps = revolutionPointsEmitter.founderEntropyRateBps();

        // Ether directly sent to founder
        uint256 founderDirectPayment = (amount * founderRate * founderEntropyRateBps) / 10_000 / 10_000;

        // Ether spent on founder governance tokens
        return ((amount * founderRate) / 10_000) - founderDirectPayment;
    }

    function test__PurchaseHistorySaved() public {
        uint256 value = 1 ether;
        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        vm.deal(address(0), 100000 ether);

        //ensure getAccountPurchaseHistory returns the correct amount
        IRevolutionPointsEmitter.AccountPurchaseHistory memory accountPurchaseHistory0 = revolutionPointsEmitter
            .getAccountPurchaseHistory(address(1));

        // assert averagePurchaseBlockWad is 0
        assertEq(accountPurchaseHistory0.averagePurchaseBlockWad, 0, "averagePurchaseBlockWad should be 0");
        assertEq(accountPurchaseHistory0.amountPaidToOwner, 0, "amountPaidToOwner should be 0");
        assertEq(accountPurchaseHistory0.tokensBought, 0, "tokensBought should be 0");

        uint256 msgValueRemaining = value - revolutionPointsEmitter.computeTotalReward(value);

        uint256 amountPaidToOwner = calculateAmountForBuyers(msgValueRemaining);
        uint256 founderGovernancePayment = calculateFounderGovernancePayment(msgValueRemaining);

        int256 expectedFounderPoints = revolutionPointsEmitter.getTokenQuoteForEther(founderGovernancePayment);

        int256 expectedBuyerAmount = getTokenQuoteForEtherHelper(amountPaidToOwner, expectedFounderPoints);

        revolutionPointsEmitter.buyToken{ value: value }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );

        //ensure getAccountPurchaseHistory returns the correct amount
        IRevolutionPointsEmitter.AccountPurchaseHistory memory accountPurchaseHistory = revolutionPointsEmitter
            .getAccountPurchaseHistory(address(1));

        // assert amount paid to owner is > 0 and correct
        assertGt(accountPurchaseHistory.amountPaidToOwner, 0, "amountPaidToOwner should be greater than 0");
        assertEq(accountPurchaseHistory.amountPaidToOwner, amountPaidToOwner, "amountPaidToOwner should be correct");

        // assert tokensBought
        assertGt(accountPurchaseHistory.tokensBought, 0, "tokensBought should be greater than 0");
        assertEq(accountPurchaseHistory.tokensBought, uint256(expectedBuyerAmount), "tokensBought should be correct");

        // assert averagePurchaseBlockWad is > 0
        assertGt(accountPurchaseHistory.averagePurchaseBlockWad, 0, "averagePurchaseBlockWad should be greater than 0");
        // no purchases have been made previously so averagePurchaseBlockWad should be the current block
        assertEq(
            accountPurchaseHistory.averagePurchaseBlockWad,
            vm.getBlockNumber(),
            "averagePurchaseBlockWad should be the current block"
        );
    }

    // test that only 0 values are saved to the account purchase history if founder rate is super high
    function test__PurchaseHistoryZeroesGrantsRateHigh() public {
        uint256 value = 1 ether;
        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        vm.deal(address(0), 100000 ether);

        //ensure getAccountPurchaseHistory returns the correct amount
        IRevolutionPointsEmitter.AccountPurchaseHistory memory accountPurchaseHistory0 = revolutionPointsEmitter
            .getAccountPurchaseHistory(address(1));

        // assert averagePurchaseBlockWad is 0
        assertEq(accountPurchaseHistory0.averagePurchaseBlockWad, 0, "averagePurchaseBlockWad should be 0");
        assertEq(accountPurchaseHistory0.amountPaidToOwner, 0, "amountPaidToOwner should be 0");
        assertEq(accountPurchaseHistory0.tokensBought, 0, "tokensBought should be 0");

        uint256 msgValueRemaining = value - revolutionPointsEmitter.computeTotalReward(value);

        uint256 amountPaidToOwner = calculateAmountForBuyers(msgValueRemaining);
        uint256 founderGovernancePayment = calculateFounderGovernancePayment(msgValueRemaining);

        int256 expectedFounderPoints = revolutionPointsEmitter.getTokenQuoteForEther(founderGovernancePayment);

        int256 expectedBuyerAmount = getTokenQuoteForEtherHelper(amountPaidToOwner, expectedFounderPoints);

        // set founderRateBps to 10000
        vm.startPrank(address(executor));
        revolutionPointsEmitter.setGrantsRateBps(10_000 - revolutionPointsEmitter.founderRateBps());
        vm.stopPrank();

        revolutionPointsEmitter.buyToken{ value: value }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );

        //ensure getAccountPurchaseHistory returns the correct amount
        IRevolutionPointsEmitter.AccountPurchaseHistory memory accountPurchaseHistory = revolutionPointsEmitter
            .getAccountPurchaseHistory(address(1));

        // assert amount paid to owner is 0
        assertEq(accountPurchaseHistory.amountPaidToOwner, 0, "amountPaidToOwner should be 0");

        // assert tokensBought is 0
        assertEq(accountPurchaseHistory.tokensBought, 0, "tokensBought should be 0");

        // assert averagePurchaseBlock
        assertEq(accountPurchaseHistory.averagePurchaseBlockWad, 0, "averagePurchaseBlockWad should be 0");
    }

    // test that purchase account history is saved after multiple purchases for the same account
    function test__PurchaseHistorySavedMultiplePurchases() public {
        // purchase for the first account
        uint256 value = 1 ether;

        address[] memory recipients = new address[](1);
        recipients[0] = address(1); // Assuming address(1) is the recipient for simplicity

        uint[] memory bps = new uint[](1);
        bps[0] = 10_000; // Assigning all tokens to the single recipient

        IRevolutionPointsEmitter.ProtocolRewardAddresses memory protocolRewardAddresses = IRevolutionPointsEmitter
            .ProtocolRewardAddresses({ builder: address(0), purchaseReferral: address(0), deployer: address(0) });

        uint256 msgValueRemaining = value - revolutionPointsEmitter.computeTotalReward(value);

        uint256 amountPaidToOwner = calculateAmountForBuyers(msgValueRemaining);

        int256 expectedFounderPoints = revolutionPointsEmitter.getTokenQuoteForEther(
            calculateFounderGovernancePayment(msgValueRemaining)
        );

        int256 expectedBuyerAmount = getTokenQuoteForEtherHelper(amountPaidToOwner, expectedFounderPoints);

        // First purchase
        revolutionPointsEmitter.buyToken{ value: value }(recipients, bps, protocolRewardAddresses);

        uint256 firstBlockNumber = vm.getBlockNumber();

        vm.roll(firstBlockNumber + 1e2);

        // Second purchase, different value
        uint256 secondValue = 2 ether;

        uint256 msgValueRemaining2 = secondValue - revolutionPointsEmitter.computeTotalReward(secondValue);

        uint256 amountPaidToOwner2 = calculateAmountForBuyers(msgValueRemaining2);

        int256 expectedFounderPoints2 = revolutionPointsEmitter.getTokenQuoteForEther(
            calculateFounderGovernancePayment(msgValueRemaining2)
        );

        int256 expectedBuyerAmount2 = getTokenQuoteForEtherHelper(
            amountPaidToOwner2,
            expectedFounderPoints2 + int256(revolutionPoints.totalSupply())
        );

        revolutionPointsEmitter.buyToken{ value: secondValue }(recipients, bps, protocolRewardAddresses);

        // Check the account purchase history after multiple purchases
        IRevolutionPointsEmitter.AccountPurchaseHistory memory accountPurchaseHistory = revolutionPointsEmitter
            .getAccountPurchaseHistory(address(1));

        // assert amount paid to owner is > 0 and correct
        assertGt(accountPurchaseHistory.amountPaidToOwner, 0, "amountPaidToOwner should be greater than 0");
        assertEq(
            accountPurchaseHistory.amountPaidToOwner,
            amountPaidToOwner + amountPaidToOwner2,
            "amountPaidToOwner should be correct"
        );

        // assert tokensBought
        assertGt(accountPurchaseHistory.tokensBought, 0, "tokensBought should be greater than 0");
        assertEq(
            accountPurchaseHistory.tokensBought,
            uint256(expectedBuyerAmount + expectedBuyerAmount2),
            "tokensBought should be correct"
        );

        // assert averagePurchaseBlockWad is > 0
        assertGt(accountPurchaseHistory.averagePurchaseBlockWad, 0, "averagePurchaseBlockWad should be greater than 0");

        // calculate the average block number
        uint256 averageBlock = (firstBlockNumber * amountPaidToOwner + vm.getBlockNumber() * amountPaidToOwner2) /
            (amountPaidToOwner + amountPaidToOwner2);
        assertEq(
            accountPurchaseHistory.averagePurchaseBlockWad,
            averageBlock,
            "averagePurchaseBlockWad should be correct"
        );
    }
}
