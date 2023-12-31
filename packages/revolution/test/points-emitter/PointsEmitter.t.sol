// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { unsafeWadDiv, toDaysWadUnsafe } from "../../src/libs/SignedWadMath.sol";
import { RevolutionPointsEmitter } from "../../src/RevolutionPointsEmitter.sol";
import { IRevolutionPointsEmitter } from "../../src/interfaces/IRevolutionPointsEmitter.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionProtocolRewards } from "@cobuild/protocol-rewards/src/RevolutionProtocolRewards.sol";
import { wadDiv } from "../../src/libs/SignedWadMath.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { IRevolutionPoints } from "../../src/interfaces/IRevolutionPoints.sol";
import { ERC1967Proxy } from "../../src/libs/proxy/ERC1967Proxy.sol";
import { console2 } from "forge-std/console2.sol";

contract PointsEmitterTest is RevolutionBuilderTest {
    event Log(string, uint);

    // 1,000 tokens per day is the target emission
    uint256 tokensPerTimeUnit = 1_000;

    uint256 expectedVolume = tokensPerTimeUnit * 1e18;

    string public tokenNamePrefix = "Vrb";

    function setUp() public override {
        super.setUp();
        super.setMockParams();

        super.setRevolutionTokenParams("Mock", "MOCK", "https://example.com/token/", tokenNamePrefix);

        int256 oneFullTokenTargetPrice = 1 ether;

        int256 priceDecayPercent = 1e18 / 10;

        super.setPointsEmitterParams(
            oneFullTokenTargetPrice,
            priceDecayPercent,
            int256(1e18 * tokensPerTimeUnit),
            creatorsAddress
        );

        super.deployMock();

        vm.deal(address(0), 100000 ether);
    }

    function getTokenQuoteForEtherHelper(uint256 etherAmount, int256 supply) public view returns (int gainedX) {
        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        return
            revolutionPointsEmitter.vrgdac().yToX({
                timeSinceStart: toDaysWadUnsafe(block.timestamp - revolutionPointsEmitter.startTime()),
                sold: supply,
                amount: int(etherAmount)
            });
    }

    function test_correctEmitted(uint256 creatorRateBps, uint256 entropyRateBps) public {
        // Assume valid rates
        vm.assume(creatorRateBps > 0 && creatorRateBps < 10000 && entropyRateBps < 10000);

        vm.startPrank(revolutionPointsEmitter.owner());
        //set creatorRate and entropyRate
        revolutionPointsEmitter.setCreatorRateBps(creatorRateBps);
        revolutionPointsEmitter.setEntropyRateBps(entropyRateBps);
        vm.stopPrank();

        vm.deal(address(this), 100000 ether);

        emit log_address(revolutionPointsEmitter.creatorsAddress());
        emit log_uint(revolutionPoints.balanceOf(revolutionPointsEmitter.creatorsAddress()));

        //expect balance to start out at 0
        assertEq(revolutionPoints.balanceOf(revolutionPointsEmitter.creatorsAddress()), 0, "Balance should start at 0");

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        //expect recipient0 balance to start out at 0
        assertEq(revolutionPoints.balanceOf(address(1)), 0, "Balance should start at 0");

        //get msg value remaining
        uint256 msgValueRemaining = 1 ether - revolutionPointsEmitter.computeTotalReward(1 ether);

        //Share of purchase amount to send to owner
        uint256 toPayOwner = (msgValueRemaining * (10_000 - creatorRateBps)) / 10_000;

        //Ether directly sent to creators
        uint256 creatorDirectPayment = ((msgValueRemaining - toPayOwner) * entropyRateBps) / 10_000;

        //get expected tokens for creators
        int256 expectedAmountForCreators = revolutionPointsEmitter.getTokenQuoteForEther(
            msgValueRemaining - toPayOwner - creatorDirectPayment
        );

        //get expected tokens for recipient0
        int256 expectedAmountForRecipient0 = getTokenQuoteForEtherHelper(toPayOwner, expectedAmountForCreators);

        revolutionPointsEmitter.buyToken{ value: 1 ether }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );

        //log creatorsAddress balance
        emit log_uint(revolutionPoints.balanceOf(revolutionPointsEmitter.creatorsAddress()));

        //assert that creatorsAddress balance is correct
        assertEq(
            uint(revolutionPoints.balanceOf(revolutionPointsEmitter.creatorsAddress())),
            uint(expectedAmountForCreators),
            "Creators should have correct balance"
        );

        //log recipient0 balance
        emit log_uint(revolutionPoints.balanceOf(address(1)));

        // assert that recipient0 balance is correct
        assertEq(
            uint(revolutionPoints.balanceOf(address(1))),
            uint(expectedAmountForRecipient0),
            "Recipient0 should have correct balance"
        );
    }

    //test that the pointsEmitter has no balance after someone buys tokens
    function test_PointsEmitterBalance(uint256 creatorRateBps, uint256 entropyRateBps) public {
        // Assume valid rates
        vm.assume(creatorRateBps > 0 && creatorRateBps <= 10000 && entropyRateBps > 0 && entropyRateBps <= 10000);

        vm.startPrank(revolutionPointsEmitter.owner());
        //set creatorRate and entropyRate
        revolutionPointsEmitter.setCreatorRateBps(creatorRateBps);
        revolutionPointsEmitter.setEntropyRateBps(entropyRateBps);
        vm.stopPrank();

        //expect pointsEmitter balance to start out at 0
        assertEq(address(revolutionPointsEmitter).balance, 0, "Balance should start at 0");

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        revolutionPointsEmitter.buyToken{ value: 1 ether }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );

        //assert that pointsEmitter balance is correct
        assertEq(uint(address(revolutionPointsEmitter).balance), 0, "PointsEmitter should have correct balance");
    }

    //test that owner receives correct amount of ether
    function test_OwnerBalance(uint256 creatorRateBps, uint256 entropyRateBps) public {
        // Assume valid rates
        vm.assume(creatorRateBps > 0 && creatorRateBps <= 10000 && entropyRateBps > 0 && entropyRateBps <= 10000);

        vm.startPrank(revolutionPointsEmitter.owner());
        //set creatorRate and entropyRate
        revolutionPointsEmitter.setCreatorRateBps(creatorRateBps);
        revolutionPointsEmitter.setEntropyRateBps(entropyRateBps);
        vm.stopPrank();

        //expect owner balance to start out at 0
        assertEq(address(revolutionPointsEmitter.owner()).balance, 0, "Balance should start at 0");

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        //get msg value remaining
        uint256 msgValueRemaining = 1 ether - revolutionPointsEmitter.computeTotalReward(1 ether);

        // Calculate share of purchase amount reserved for creators
        uint256 creatorsShare = (msgValueRemaining * creatorRateBps) / 10_000;

        // Calculate share of purchase amount reserved for buyers
        uint256 buyersShare = msgValueRemaining - creatorsShare;

        // Calculate ether directly sent to creators
        uint256 creatorDirectPayment = (creatorsShare * entropyRateBps) / 10_000;

        revolutionPointsEmitter.buyToken{ value: 1 ether }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(1),
                deployer: address(0)
            })
        );

        //assert that owner balance is correct
        assertEq(
            uint(address(revolutionPointsEmitter.owner()).balance),
            uint(buyersShare + creatorsShare - creatorDirectPayment),
            "Owner should have correct balance"
        );
    }

    function testCannotBuyAsOwner() public {
        vm.startPrank(revolutionPointsEmitter.owner());

        vm.deal(revolutionPointsEmitter.owner(), 100000 ether);

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        vm.expectRevert(abi.encodeWithSignature("FUNDS_RECIPIENT_CANNOT_BUY_TOKENS()"));
        revolutionPointsEmitter.buyToken{ value: 1e18 }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );
    }

    function testCannotBuyAsCreators() public {
        vm.startPrank(revolutionPointsEmitter.creatorsAddress());

        vm.deal(revolutionPointsEmitter.creatorsAddress(), 100000 ether);

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        vm.expectRevert(abi.encodeWithSignature("FUNDS_RECIPIENT_CANNOT_BUY_TOKENS()"));
        revolutionPointsEmitter.buyToken{ value: 1e18 }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );
    }

    function testTransferTokenContractOwnership() public {
        // makes a points emitter with one revolution points contract
        // makes a second with the same one
        // ensures that the second cannot mint and calling buyGovernance fails
        // transfers ownership to the second
        // ensures that the second can mint and calling buyGovernance succeeds

        address owner = address(0x123);

        RevolutionProtocolRewards protocolRewards = new RevolutionProtocolRewards();

        address governanceToken = address(new ERC1967Proxy(revolutionPointsImpl, ""));

        address emitter1 = address(new ERC1967Proxy(revolutionPointsEmitterImpl, ""));

        vm.startPrank(address(manager));
        IRevolutionPointsEmitter(emitter1).initialize({
            initialOwner: owner,
            weth: address(weth),
            revolutionPoints: address(governanceToken),
            vrgdac: address(revolutionPointsEmitter.vrgdac()),
            creatorsAddress: creatorsAddress,
            creatorParams: IRevolutionBuilder.PointsEmitterCreatorParams({
                creatorRateBps: 1_000,
                entropyRateBps: 5_000
            })
        });

        IRevolutionPoints(governanceToken).initialize({
            initialOwner: address(emitter1),
            revolutionPointsParams: IRevolutionBuilder.PointsParams({ name: "Revolution Governance", symbol: "GOV" })
        });

        vm.deal(address(21), 100000 ether);

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        vm.startPrank(address(21));
        IRevolutionPointsEmitter(emitter1).buyToken{ value: 1e18 }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );

        address emitter2 = address(new ERC1967Proxy(revolutionPointsEmitterImpl, ""));

        vm.startPrank(address(manager));
        IRevolutionPointsEmitter(emitter2).initialize({
            initialOwner: owner,
            weth: address(weth),
            revolutionPoints: address(governanceToken),
            vrgdac: address(revolutionPointsEmitter.vrgdac()),
            creatorsAddress: creatorsAddress,
            creatorParams: IRevolutionBuilder.PointsEmitterCreatorParams({
                creatorRateBps: 1_000,
                entropyRateBps: 5_000
            })
        });

        vm.startPrank(address(emitter1));
        RevolutionPoints(governanceToken).transferOwnership(address(emitter2));

        vm.startPrank(address(emitter2));
        //accept ownership transfer
        RevolutionPoints(governanceToken).acceptOwnership();

        vm.startPrank(address(48));
        vm.deal(address(48), 100000 ether);
        IRevolutionPointsEmitter(emitter2).buyToken{ value: 1e18 }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );
    }

    function testBuyTokenWithDifferentRates(uint256 creatorRate, uint256 entropyRate) public {
        // Assume valid rates
        vm.assume(creatorRate <= 10000 && entropyRate <= 10000);

        vm.startPrank(address(dao));
        // Set creator and entropy rates
        revolutionPointsEmitter.setCreatorRateBps(creatorRate);
        revolutionPointsEmitter.setEntropyRateBps(entropyRate);
        assertEq(revolutionPointsEmitter.creatorRateBps(), creatorRate, "Creator rate not set correctly");
        assertEq(revolutionPointsEmitter.entropyRateBps(), entropyRate, "Entropy rate not set correctly");

        // Setup for buying token
        address[] memory recipients = new address[](1);
        recipients[0] = address(1); // recipient address

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10000; // 100% of the tokens to the recipient

        uint256 valueToSend = 1 ether;
        revolutionPointsEmitter.setCreatorsAddress(address(80));
        address creatorsAddress = revolutionPointsEmitter.creatorsAddress();
        uint256 creatorsInitialEthBalance = address(revolutionPointsEmitter.creatorsAddress()).balance;

        uint256 feeAmount = revolutionPointsEmitter.computeTotalReward(valueToSend);

        // Calculate expected ETH sent to creator
        uint256 totalPaymentForCreator = ((valueToSend - feeAmount) * creatorRate) / 10000;
        uint256 expectedCreatorEth = (totalPaymentForCreator * entropyRate) / 10000;

        if (creatorRate == 0 || entropyRate == 10_000) vm.expectRevert(abi.encodeWithSignature("INVALID_PAYMENT()"));
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
        uint256 creatorTokenBalance = revolutionPointsEmitter.balanceOf(revolutionPointsEmitter.creatorsAddress());
        assertEq(creatorTokenBalance, expectedCreatorTokens, "Creator did not receive correct amount of tokens");

        // Verify ETH sent to creator
        uint256 creatorsNewEthBalance = address(revolutionPointsEmitter.creatorsAddress()).balance;
        assertEq(
            creatorsNewEthBalance - creatorsInitialEthBalance,
            expectedCreatorEth,
            "Incorrect ETH amount sent to creator"
        );

        // Verify tokens distributed to recipient
        uint256 recipientTokenBalance = revolutionPointsEmitter.balanceOf(address(1));
        assertEq(recipientTokenBalance, tokensSold, "Recipient did not receive correct amount of tokens");
    }

    function testBuyingLaterIsBetter() public {
        vm.startPrank(address(0));

        int256 initAmount = revolutionPointsEmitter.getTokenQuoteForEther(1e18);

        int256 firstPrice = revolutionPointsEmitter.buyTokenQuote(1e19);

        // solhint-disable-next-line not-rely-on-time
        vm.warp(block.timestamp + (10 days));

        int256 secondPrice = revolutionPointsEmitter.buyTokenQuote(1e19);

        emit log_int(firstPrice);
        emit log_int(secondPrice);

        int256 laterAmount = revolutionPointsEmitter.getTokenQuoteForEther(1e18);

        assertGt(laterAmount, initAmount, "Later amount should be greater than initial amount");

        assertLt(secondPrice, firstPrice, "Second price should be less than first price");
    }

    function testBuyToken() public {
        vm.startPrank(address(0));

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        vm.deal(address(0), 100000 ether);

        emit log_address(address(0));

        revolutionPointsEmitter.buyToken{ value: 1e18 }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );
        emit Log("Balance: ", revolutionPointsEmitter.balanceOf(address(1)));
    }

    function testBuyTokenPriceIncreases() public {
        vm.startPrank(address(0));

        address[] memory firstRecipients = new address[](1);
        firstRecipients[0] = address(1);

        address[] memory secondRecipients = new address[](1);
        secondRecipients[0] = address(2);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        revolutionPointsEmitter.buyToken{ value: 1e18 }(
            firstRecipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );

        revolutionPointsEmitter.buyToken{ value: 1e18 }(
            secondRecipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );

        // should get more expensive
        assertGt(revolutionPointsEmitter.balanceOf(address(1)), revolutionPointsEmitter.balanceOf(address(2)));
    }

    // test multiple payouts
    function testPercentagePayouts(uint firstBps) public {
        vm.assume(firstBps < 10000);
        vm.assume(firstBps > 0);
        vm.startPrank(address(0));

        uint creatorRateBps = revolutionPointsEmitter.creatorRateBps();
        uint entropyRateBps = revolutionPointsEmitter.entropyRateBps();

        address[] memory recipients = new address[](2);
        recipients[0] = address(1);
        recipients[1] = address(2);

        uint256[] memory bps = new uint256[](2);
        bps[0] = firstBps;
        bps[1] = 10_000 - firstBps;

        // estimate tokens to be emitted
        uint msgValueRemaining = 1e18 - revolutionPointsEmitter.computeTotalReward(1e18);
        uint creatorsShare = (msgValueRemaining * creatorRateBps) / 10_000;
        uint buyersShare = msgValueRemaining - creatorsShare;
        uint creatorsGovernancePayment = creatorsShare - (creatorsShare * entropyRateBps) / 10_000;
        int expectedCreatorsAmount = revolutionPointsEmitter.getTokenQuoteForEther(creatorsGovernancePayment);

        int expectedBuyerAmount = getTokenQuoteForEtherHelper(buyersShare, expectedCreatorsAmount);

        int expectedAmount = expectedCreatorsAmount + expectedBuyerAmount;

        revolutionPointsEmitter.buyToken{ value: 1e18 }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );
        //assert address balances are correct
        //multiply bps by expectedBuyerAmount and assert
        assertEq(
            revolutionPointsEmitter.balanceOf(address(1)),
            (firstBps * uint256(expectedBuyerAmount)) / 10_000,
            "First recipient should have correct balance"
        );
        assertEq(
            revolutionPointsEmitter.balanceOf(address(2)),
            ((10_000 - firstBps) * uint256(expectedBuyerAmount)) / 10_000,
            "Second recipient should have correct balance"
        );

        // //assert owner balance is correct
        assertEq(
            address(revolutionPointsEmitter.owner()).balance,
            1e18 - revolutionPointsEmitter.computeTotalReward(1e18) - (creatorsShare * entropyRateBps) / 10_000,
            "Owner should have payment - totalReward in balance"
        );
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

    //if buyToken is called with mismatched length arrays, then it should revert with PARALLEL_ARRAYS_REQUIRED()
    function test_revertMismatchedLengthArrays() public {
        vm.startPrank(address(0));

        address[] memory recipients = new address[](2);
        recipients[0] = address(1);
        recipients[1] = address(2);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        vm.expectRevert(abi.encodeWithSignature("PARALLEL_ARRAYS_REQUIRED()"));
        revolutionPointsEmitter.buyToken{ value: 1e18 }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(1),
                purchaseReferral: address(1),
                deployer: address(0)
            })
        );
    }

    // Test to ensure the total basis points add up to 100%
    function testTotalBasisPoints() public {
        vm.startPrank(address(0));

        uint256 creatorRateBps = revolutionPointsEmitter.creatorRateBps();
        uint256 entropyRateBps = revolutionPointsEmitter.entropyRateBps();

        address[] memory recipients = new address[](2);
        recipients[0] = address(1);
        recipients[1] = address(2);

        // Test case with correct total of 10,000 basis points (100%)
        uint256[] memory correctBps = new uint256[](2);
        correctBps[0] = 5000; // 50%
        correctBps[1] = 5000; // 50%

        uint256 msgValueRemaining = 1e18 - revolutionPointsEmitter.computeTotalReward(1e18);
        // Calculate share of purchase amount reserved for buyers
        uint256 buyersShare = msgValueRemaining - ((msgValueRemaining * creatorRateBps) / 10_000);

        // Calculate ether directly sent to creators
        uint256 creatorsDirectPayment = (msgValueRemaining * creatorRateBps * entropyRateBps) / 10_000 / 10_000;

        // Calculate ether spent on creators governance tokens
        uint256 creatorsGovernancePayment = ((msgValueRemaining * creatorRateBps) / 10_000) - creatorsDirectPayment;

        emit log_uint(buyersShare);
        emit log_uint(creatorsGovernancePayment);

        int expectedCreatorsAmount = revolutionPointsEmitter.getTokenQuoteForEther(creatorsGovernancePayment);

        int expectedBuyerAmount = getTokenQuoteForEtherHelper(buyersShare, expectedCreatorsAmount);

        int expectedAmount = expectedCreatorsAmount + expectedBuyerAmount;

        assertGt(expectedAmount, 0, "Token purchase should have a positive amount");

        // Attempting a valid token purchase
        uint emittedWad = revolutionPointsEmitter.buyToken{ value: 1e18 }(
            recipients,
            correctBps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );
        int totalSupplyAfterValidPurchase = int(revolutionPointsEmitter.totalSupply());
        assertEq(totalSupplyAfterValidPurchase, expectedAmount, "Supply should match the expected amount");
        // //emitted should match expected
        assertEq(int(emittedWad), expectedBuyerAmount, "Emitted amount should match expected amount");
        // //emitted should match supply
        assertEq(
            int(emittedWad) + int(revolutionPoints.balanceOf(revolutionPointsEmitter.creatorsAddress())),
            totalSupplyAfterValidPurchase,
            "Emitted amount should match total supply"
        );

        //expect owner to have payment - totalReward - creatorsDirectPayment in balance
        assertEq(
            address(revolutionPointsEmitter.owner()).balance,
            1e18 - revolutionPointsEmitter.computeTotalReward(1e18) - creatorsDirectPayment,
            "Owner should have payment - totalReward in balance"
        );

        // Test case with incorrect total of basis points
        uint256[] memory incorrectBps = new uint256[](2);
        incorrectBps[0] = 4000; // 40%
        incorrectBps[1] = 4000; // 40%

        // Expecting the transaction to revert due to incorrect total basis points
        vm.expectRevert(abi.encodeWithSignature("INVALID_BPS_SUM()"));
        revolutionPointsEmitter.buyToken{ value: 1e18 }(
            recipients,
            incorrectBps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );

        vm.stopPrank();
    }

    function testSetCreatorsAddress() public {
        // Setting Creators Address by Owner
        address newCreatorsAddress = address(0x123);
        vm.prank(address(dao));
        revolutionPointsEmitter.setCreatorsAddress(newCreatorsAddress);
        assertEq(
            revolutionPointsEmitter.creatorsAddress(),
            newCreatorsAddress,
            "Owner should be able to set creators address"
        );

        // Attempting to set Creators Address by Non-Owner
        address nonOwner = address(0x4156);
        vm.startPrank(nonOwner);
        try revolutionPointsEmitter.setCreatorsAddress(nonOwner) {
            fail("Non-owner should not be able to set creators address");
        } catch {}
        vm.stopPrank();
    }

    // // // TODO: test scamming creator fails with percentage low
    // function testFailLowPercentage() public {
    //     vm.startPrank(address(0));

    //     address[] memory recipients = new address[](2);
    //     recipients[0] = address(1);
    //     recipients[1] = address(2);

    //     uint256[] memory bps = new uint256[](2);
    //     bps[0] = 9_500;
    //     bps[1] = 500;

    //    revolutionPointsEmitter.buyToken{value: 1e18}(recipients, bps);
    // }

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

    function test_purchaseBounds(int256 amount) public {
        vm.assume(
            amount <= int(revolutionPointsEmitter.minPurchaseAmount()) ||
                amount >= int(revolutionPointsEmitter.maxPurchaseAmount())
        );

        vm.expectRevert();
        revolutionPointsEmitter.buyToken{ value: uint256(amount) }(
            new address[](1),
            new uint256[](1),
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(1),
                deployer: address(0)
            })
        );
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
        vm.prank(address(dao));
        revolutionPointsEmitter.setCreatorsAddress(address(100));

        // change creatorRateBps to 0
        vm.prank(address(dao));
        revolutionPointsEmitter.setCreatorRateBps(0);

        // set entropyRateBps to 0
        vm.prank(address(dao));
        revolutionPointsEmitter.setEntropyRateBps(0);

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

        console2.log("treasuryEthBalance: ", treasuryEthBalance);
        console2.log("buyerTokenBalance: ", buyerTokenBalance);

        // save protocol fees
        uint256 protocolFees = (1e18 * 250) / 10_000;

        console2.log("protocolFees: ", protocolFees);

        // convert token balances to ETH
        uint256 buyerTokenBalanceEth = uint256(revolutionPointsEmitter.buyTokenQuote(buyerTokenBalance));

        console2.log("buyerTokenBalanceEth: ", buyerTokenBalanceEth);

        console2.log("total: ", treasuryEthBalance + protocolFees + buyerTokenBalanceEth);

        // Sent in ETH should be almost equal (account for precision/rounding) to total ETH plus token value in ETH
        assertGt(1e18 * 2, treasuryEthBalance + protocolFees + buyerTokenBalanceEth, "");
    }

    function testBuyTokenReentrancy() public {
        // Deploy the malicious owner contract
        MaliciousOwner maliciousOwner = new MaliciousOwner(address(revolutionPointsEmitter));

        address governanceToken = address(new ERC1967Proxy(revolutionPointsImpl, ""));

        address emitter2 = address(new ERC1967Proxy(revolutionPointsEmitterImpl, ""));

        vm.startPrank(address(manager));
        IRevolutionPointsEmitter(emitter2).initialize({
            initialOwner: address(maliciousOwner),
            weth: address(weth),
            revolutionPoints: address(governanceToken),
            vrgdac: address(revolutionPointsEmitter.vrgdac()),
            creatorsAddress: creatorsAddress,
            creatorParams: IRevolutionBuilder.PointsEmitterCreatorParams({
                creatorRateBps: 1_000,
                entropyRateBps: 5_000
            })
        });

        IRevolutionPoints(governanceToken).initialize({
            initialOwner: address(emitter2),
            revolutionPointsParams: IRevolutionBuilder.PointsParams({ name: "Revolution Governance", symbol: "GOV" })
        });

        vm.deal(address(this), 100000 ether);

        //buy tokens and see if malicious owner can reenter
        address[] memory recipients = new address[](1);
        recipients[0] = address(1);
        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;
        vm.expectRevert();
        IRevolutionPointsEmitter(emitter2).buyToken{ value: 1e18 }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );
    }

    function testGetTokenAmountForMultiPurchaseGeneral(uint256 payment) public {
        vm.assume(payment > revolutionPointsEmitter.minPurchaseAmount());
        vm.assume(payment < revolutionPointsEmitter.maxPurchaseAmount());
        vm.startPrank(address(0));

        uint256 SOME_MAX_EXPECTED_VALUE = uint256(wadDiv(int256(payment), 1 ether)) * 1e18 * tokensPerTimeUnit;

        int256 slightlyMore = revolutionPointsEmitter.getTokenQuoteForEther((payment * 101) / 100);

        // Call the function with the typical payment amount
        int256 tokenAmount = revolutionPointsEmitter.getTokenQuoteForEther(payment);

        emit log_int(tokenAmount);

        // Assert that the token amount is reasonable (not zero or unexpectedly high)
        assertGt(tokenAmount, 0, "Token amount should be greater than zero");
        assertLt(
            tokenAmount,
            int256(SOME_MAX_EXPECTED_VALUE),
            "Token amount should be less than some max expected value"
        );
        assertLt(tokenAmount, slightlyMore, "Token amount should be less than slightly more");

        //buy 10 ether of tokens
        address[] memory recipients = new address[](1);
        recipients[0] = address(1);
        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        //ensure that enough volume was bought for the day, so purchase expectedVolume amount first
        revolutionPointsEmitter.buyToken{ value: expectedVolume }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );

        revolutionPointsEmitter.buyToken{ value: payment }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );

        int256 newTokenAmount = revolutionPointsEmitter.getTokenQuoteForEther(payment);

        // Assert that the new token amount is less than the previous tokenAmount
        assertLt(newTokenAmount, tokenAmount, "Token amount should be less than previous token amount");

        vm.stopPrank();
    }

    function testGetTokenAmountForMultiPurchaseEdgeCases() public {
        vm.startPrank(address(0));

        // Edge Case 1: Very Small Payment
        uint256 smallPayment = 0.00001 ether;
        int256 smallPaymentTokenAmount = revolutionPointsEmitter.getTokenQuoteForEther(smallPayment);
        assertGt(smallPaymentTokenAmount, 0, "Token amount for small payment should be greater than zero");
        emit log_int(smallPaymentTokenAmount);

        // A days worth of payment amount
        int256 dailyPaymentTokenAmount = revolutionPointsEmitter.getTokenQuoteForEther(expectedVolume);
        assertLt(
            uint256(dailyPaymentTokenAmount),
            tokensPerTimeUnit * 1e18,
            "Token amount for daily payment should be less than tokens per day"
        );
        emit log_string("Daily Payment Token Amount: ");
        emit log_int(dailyPaymentTokenAmount);

        // Edge Case 2: Very Large Payment
        // An unusually large payment amount
        int256 largePaymentTokenAmount = revolutionPointsEmitter.getTokenQuoteForEther(expectedVolume * 100);
        //spending 100x the expected amount per day should get you < 25x the tokens
        uint256 SOME_REALISTIC_UPPER_BOUND = 25 * tokensPerTimeUnit * 1e18;
        assertLt(
            uint256(largePaymentTokenAmount),
            SOME_REALISTIC_UPPER_BOUND,
            "Token amount for large payment should be less than some realistic upper bound"
        );
        emit log_string("Large Payment Token Amount: ");
        emit log_int(largePaymentTokenAmount);

        uint256 largestPayment = expectedVolume * 1_000; // An unusually large payment amount
        int256 largestPaymentTokenAmount = revolutionPointsEmitter.getTokenQuoteForEther(largestPayment);
        //spending 1000x the daily amount should get you less than 50x the tokens
        assertLt(
            uint256(largestPaymentTokenAmount),
            50 * tokensPerTimeUnit * 1e18,
            "Token amount for largest payment should be less than some realistic upper bound"
        );

        emit log_string("Largest Payment Token Amount: ");
        emit log_int(largestPaymentTokenAmount);

        vm.stopPrank();
    }

    function testGetTokenPrice() public {
        vm.startPrank(address(0));

        vm.deal(address(0), 100000 ether);
        vm.stopPrank();

        int256 priceAfterManyPurchases = revolutionPointsEmitter.buyTokenQuote(1e18);
        emit log_int(priceAfterManyPurchases);

        // Simulate the passage of time
        uint256 daysElapsed = 221;
        vm.warp(block.timestamp + daysElapsed * 1 days);

        int256 priceAfterManyDays = revolutionPointsEmitter.buyTokenQuote(1e18);

        emit log_int(priceAfterManyDays);

        // Assert that the price is greater than zero
        assertGt(priceAfterManyDays, 0, "Price should never hit zero");
    }

    //ensure when creating new points emitter, that INVALID_BPS is thrown if > 10_000
    function test_bpsInitialization() public {
        address owner = address(0x123);

        RevolutionProtocolRewards protocolRewards = new RevolutionProtocolRewards();

        address governanceToken = address(new ERC1967Proxy(revolutionPointsImpl, ""));

        address emitter1 = address(new ERC1967Proxy(revolutionPointsEmitterImpl, ""));

        address vrgdac = address(revolutionPointsEmitter.vrgdac());

        vm.startPrank(address(manager));
        vm.expectRevert(abi.encodeWithSignature("INVALID_BPS()"));
        IRevolutionPointsEmitter(emitter1).initialize({
            initialOwner: owner,
            weth: address(weth),
            revolutionPoints: address(governanceToken),
            vrgdac: vrgdac,
            creatorsAddress: creatorsAddress,
            creatorParams: IRevolutionBuilder.PointsEmitterCreatorParams({
                creatorRateBps: 100_000,
                entropyRateBps: 50_000
            })
        });
    }
}

contract MaliciousOwner {
    RevolutionPointsEmitter revolutionPointsEmitter;
    bool public reentryAttempted;

    constructor(address _emitter) {
        revolutionPointsEmitter = RevolutionPointsEmitter(_emitter);
        reentryAttempted = false;
    }

    // Fallback function to enable re-entrance to PointsEmitter
    function call() external payable {
        reentryAttempted = true;
        address[] memory recipients = new address[](1);
        recipients[0] = address(this);
        uint256[] memory bps = new uint256[](1);
        bps[0] = 10_000;

        // Attempt to re-enter PointsEmitter
        revolutionPointsEmitter.buyToken{ value: msg.value }(
            recipients,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                purchaseReferral: address(0),
                deployer: address(0)
            })
        );
    }
}
