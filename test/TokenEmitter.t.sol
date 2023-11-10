// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

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

        emitter = new TokenEmitter(governanceToken, treasury, 1e14, 1e17, 1e22);

        governanceToken.transferAdmin(address(emitter));

        vm.deal(address(0), 100000 ether);
        vm.stopPrank();
    }

    function testBuyToken() public {
        vm.startPrank(address(0));

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory percentages = new uint256[](1);
        percentages[0] = 100;

        emitter.buyToken{ value: 1e18 }(recipients, percentages, 1);
        emit Log("Balance: ", emitter.balanceOf(address(1)));
    }

    function testBuyTokenPriceIncreases() public {
        vm.startPrank(address(0));

        address[] memory firstRecipients = new address[](1);
        firstRecipients[0] = address(1);

        address[] memory secondRecipients = new address[](1);
        secondRecipients[0] = address(2);

        uint256[] memory percentages = new uint256[](1);
        percentages[0] = 100;

        emitter.buyToken{ value: 10e18 }(firstRecipients, percentages, 1);

        emitter.buyToken{ value: 10e18 }(secondRecipients, percentages, 1);

        // should get more expensive
        assert(emitter.balanceOf(address(1)) > emitter.balanceOf(address(2)));
    }

    // test multiple payouts
    function testPercentagePayouts() public {
        vm.startPrank(address(0));

        address[] memory recipients = new address[](2);
        recipients[0] = address(1);
        recipients[1] = address(2);

        uint256[] memory percentages = new uint256[](2);
        percentages[0] = 50;
        percentages[1] = 50;

        emitter.buyToken{ value: 1e18 }(recipients, percentages, 1);
        assert(emitter.balanceOf(address(1)) == emitter.balanceOf(address(2)));
    }

    // // TODO: test scamming creator fails with percentage low
    // function testFailLowPercentage() public {
    //     vm.startPrank(address(0));

    //     address[] memory recipients = new address[](2);
    //     recipients[0] = address(1);
    //     recipients[1] = address(2);

    //     uint256[] memory percentages = new uint256[](2);
    //     percentages[0] = 95;
    //     percentages[1] = 5;

    //     emitter.buyToken{value: 1e18}(recipients, percentages);
    // }

    function testBuyingTwiceAmountIsNotMoreThanTwiceEmittedTokens() public {
        vm.startPrank(address(0));

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory percentages = new uint256[](1);
        percentages[0] = 100;

        emitter.buyToken{ value: 1e18 }(recipients, percentages, 1);
        uint256 firstAmount = emitter.balanceOf(address(1));

        emitter.buyToken{ value: 1e18 }(recipients, percentages, 1);
        uint256 secondAmount = emitter.balanceOf(address(1)) - firstAmount;

        assert(secondAmount <= 2 * emitter.totalSupply());
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

        uint256[] memory percentages = new uint256[](1);
        percentages[0] = 100;

        emitter1.buyToken{ value: 1e18 }(recipients, percentages, 1);

        vm.stopPrank();
        vm.prank(address(emitter1));

        governanceToken.transferAdmin(address(emitter2));

        vm.prank(address(0));
        emitter2.buyToken{ value: 1e18 }(recipients, percentages, 1);
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
}
