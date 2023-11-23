// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { VerbsAuctionHouse } from "../../src/VerbsAuctionHouse.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { VerbsToken } from "../../src/VerbsToken.sol";
import { IVerbsToken } from "../../src/interfaces/IVerbsToken.sol";
import { IProxyRegistry } from "../../src/external/opensea/IProxyRegistry.sol";
import { VerbsDescriptor } from "../../src/VerbsDescriptor.sol";
import { CultureIndex } from "../../src/CultureIndex.sol";
import { IVerbsDescriptorMinimal } from "../../src/interfaces/IVerbsDescriptorMinimal.sol";
import { ICultureIndex, ICultureIndexEvents } from "../../src/interfaces/ICultureIndex.sol";
import { IVerbsAuctionHouse } from "../../src/interfaces/IVerbsAuctionHouse.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { NontransferableERC20 } from "../../src/NontransferableERC20.sol";
import { TokenEmitter } from "../../src/TokenEmitter.sol";
import { ITokenEmitter } from "../../src/interfaces/ITokenEmitter.sol";
import { wadMul, wadDiv } from "../../src/libs/SignedWadMath.sol";
import { RevolutionProtocolRewards } from "@collectivexyz/protocol-rewards/src/RevolutionProtocolRewards.sol";
import { TokenEmitterRewards } from "@collectivexyz/protocol-rewards/src/abstract/TokenEmitter/TokenEmitterRewards.sol";
import { VerbsAuctionHouseTest } from "./AuctionHouse.t.sol";

contract VerbsAuctionHouseSettleTest is VerbsAuctionHouseTest {
    //calculate bps amount given split
    function bps(uint256 x, uint256 y) pure public returns (uint256) {
        return uint256(wadDiv(wadMul(int256(x), int256(y)), 10000));
    }

    // Fallback function to allow contract to receive Ether
    receive() external payable {}

    function testSettlingAuctionWithWinningBid() public {
        setUp();
        createDefaultArtPiece();
        auctionHouse.unpause();

        uint256 balanceBefore = address(this).balance;

        uint256 bidAmount = auctionHouse.reservePrice();
        vm.deal(address(1), bidAmount);
        vm.startPrank(address(1));
        auctionHouse.createBid{ value: bidAmount }(0); // Assuming first auction's verbId is 0
        vm.stopPrank();

        vm.warp(block.timestamp + auctionHouse.duration() + 1); // Fast forward time to end the auction

        createDefaultArtPiece();
        auctionHouse.settleCurrentAndCreateNewAuction();

        uint256 balanceAfter = address(this).balance;

        assertEq(verbs.ownerOf(0), address(1), "Verb should be transferred to the highest bidder");

        uint256 creatorRate = auctionHouse.creatorRateBps();
        uint256 entropyRate = auctionHouse.entropyRateBps();

        //calculate fee
        uint256 amountToOwner = (bidAmount * (10_000 - (creatorRate * entropyRate) / 10_000)) / 10_000;

        //amount spent on governance
        uint256 etherToSpendOnGovernanceTotal = (bidAmount * creatorRate) / 10_000 - (bidAmount * (entropyRate * creatorRate)) / 10_000 / 10_000;
        uint256 feeAmount = tokenEmitter.computeTotalReward(etherToSpendOnGovernanceTotal);

        assertEq(balanceAfter - balanceBefore, amountToOwner - feeAmount, "Bid amount minus entropy should be transferred to the auction house owner");
    }

    function testSettlingAuctionWithNoBids() public {
        setUp();
        uint256 verbId = createDefaultArtPiece();
        auctionHouse.unpause();

        vm.warp(block.timestamp + auctionHouse.duration() + 1); // Fast forward time to end the auction

        // Assuming verbs.burn is called for auctions with no bids
        vm.expectEmit(true, true, true, true);
        emit IVerbsToken.VerbBurned(verbId);

        auctionHouse.settleCurrentAndCreateNewAuction();
    }

    function testSettlingAuctionPrematurely() public {
        setUp();
        createDefaultArtPiece();
        auctionHouse.unpause();

        vm.expectRevert();
        auctionHouse.settleAuction(); // Attempt to settle before the auction ends
    }

    function testTransferFailureAndFallbackToWETH() public {
        setUp();
        createDefaultArtPiece();
        auctionHouse.unpause();

        address recipient = address(new ContractThatRejectsEther());

        auctionHouse.transferOwnership(recipient);

        uint256 amount = 1 ether;

        vm.deal(address(auctionHouse), amount);
        auctionHouse.createBid{ value: amount }(0); // Assuming first auction's verbId is 0

        // Initially, recipient should have 0 ether and 0 WETH
        assertEq(recipient.balance, 0);
        assertEq(IERC20(address(mockWETH)).balanceOf(recipient), 0);

        //go in future
        vm.warp(block.timestamp + auctionHouse.duration() + 1); // Fast forward time to end the auction

        auctionHouse.settleCurrentAndCreateNewAuction();

        // Check if the recipient received WETH instead of Ether
        uint256 creatorRate = auctionHouse.creatorRateBps();
        assertEq(IERC20(address(mockWETH)).balanceOf(recipient), bps(amount, 10_000 - creatorRate));
        assertEq(recipient.balance, 0); // Ether balance should still be 0
    }

    function testTransferToEOA() public {
        setUp();
        createDefaultArtPiece();
        auctionHouse.unpause();

        address recipient = address(0x123); // Some EOA address
        uint256 amount = 1 ether;

        auctionHouse.transferOwnership(recipient);

        vm.deal(address(auctionHouse), amount);
        auctionHouse.createBid{ value: amount }(0); // Assuming first auction's verbId is 0

        // Initially, recipient should have 0 ether
        assertEq(recipient.balance, 0);

        //go in future
        vm.warp(block.timestamp + auctionHouse.duration() + 1); // Fast forward time to end the auction

        auctionHouse.settleCurrentAndCreateNewAuction();

        // Check if the recipient received Ether
        uint256 creatorRate = auctionHouse.creatorRateBps();
        assertEq(recipient.balance, bps(amount, 10_000 - creatorRate));
    }

    function testTransferToContractWithoutReceiveOrFallback() public {
        setUp();
        createDefaultArtPiece();
        auctionHouse.unpause();

        address recipient = address(new ContractWithoutReceiveOrFallback());
        uint256 amount = 1 ether;

        auctionHouse.transferOwnership(recipient);

        vm.deal(address(auctionHouse), amount);
        auctionHouse.createBid{ value: amount }(0); // Assuming first auction's verbId is 0

        // Initially, recipient should have 0 ether and 0 WETH
        assertEq(recipient.balance, 0);
        assertEq(IERC20(address(mockWETH)).balanceOf(recipient), 0);

        //go in future
        vm.warp(block.timestamp + auctionHouse.duration() + 1); // Fast forward time to end the auction

        auctionHouse.settleCurrentAndCreateNewAuction();

        // Check if the recipient received WETH instead of Ether
        uint256 creatorRate = auctionHouse.creatorRateBps();

        assertEq(IERC20(address(mockWETH)).balanceOf(recipient), bps(amount, 10_000 - creatorRate));
        assertEq(recipient.balance, 0); // Ether balance should still be 0
    }

    function testSettlingAuctionWithMultipleCreators() public {
        setUp();
        uint256 creatorRate = (auctionHouse.creatorRateBps());
        uint256 entropyRate = (auctionHouse.entropyRateBps());

        address[] memory creatorAddresses = new address[](5);
        uint256[] memory creatorBps = new uint256[](5);
        uint256 totalBps = 0;

        // Assume 5 creators with equal shares
        for (uint256 i = 0; i < 3; i++) {
            creatorAddresses[i] = address(uint160(i + 1)); // Example creator addresses
            creatorBps[i] = 2000; // 20% for each creator
            totalBps += creatorBps[i];
        }

        //add a creator with  21% and then 19%
        creatorAddresses[3] = address(uint160(4));
        creatorBps[3] = 2100;
        totalBps += creatorBps[3];

        creatorAddresses[4] = address(uint160(5));
        creatorBps[4] = 1900;
        totalBps += creatorBps[4];

        uint256 verbId = createArtPieceMultiCreator(
            "Multi Creator Art",
            "An art piece with multiple creators",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://multi-creator-art",
            "",
            "",
            creatorAddresses,
            creatorBps
        );

        auctionHouse.unpause();

        uint256 bidAmount = auctionHouse.reservePrice();
        vm.deal(address(1), bidAmount);
        vm.startPrank(address(1));
        auctionHouse.createBid{ value: bidAmount }(verbId);
        vm.stopPrank();

        vm.warp(block.timestamp + auctionHouse.duration() + 1); // Fast forward time to end the auction

        // Track balances before auction settlement
        uint256[] memory balancesBefore = new uint256[](creatorAddresses.length);
        uint256[] memory governanceTokenBalancesBefore = new uint256[](creatorAddresses.length);
        for (uint256 i = 0; i < creatorAddresses.length; i++) {
            balancesBefore[i] = address(creatorAddresses[i]).balance;
            governanceTokenBalancesBefore[i] = governanceToken.balanceOf(creatorAddresses[i]);
        }

        // Track expected governance token payout
        uint256 etherToSpendOnGovernanceTotal = uint256((bidAmount * creatorRate) / 10_000 - (bidAmount * (entropyRate * creatorRate)) / 10_000 / 10_000);

        uint256 expectedGovernanceTokenPayout = uint256(tokenEmitter.getTokenQuoteForPayment(
            etherToSpendOnGovernanceTotal - tokenEmitter.computeTotalReward(etherToSpendOnGovernanceTotal)
        ));

        auctionHouse.settleCurrentAndCreateNewAuction();

        // Verify each creator's payout
        for (uint256 i = 0; i < creatorAddresses.length; i++) {
            uint256 expectedEtherShare = uint256((bidAmount * creatorBps[i] * creatorRate) / totalBps / 10_000);
            assertEq(address(creatorAddresses[i]).balance - balancesBefore[i], (expectedEtherShare * entropyRate) / 10_000, "Incorrect ETH payout for creator");

            uint256 expectedGovernanceTokenShare = uint256((expectedGovernanceTokenPayout * creatorBps[i]) / totalBps);

            assertEq(
                governanceToken.balanceOf(creatorAddresses[i]) - governanceTokenBalancesBefore[i],
                expectedGovernanceTokenShare,
                "Incorrect governance token payout for creator"
            );
        }

        // Verify ownership of the verb
        assertEq(verbs.ownerOf(verbId), address(1), "Verb should be transferred to the highest bidder");
    }

    function testSettlingAuctionWithWinningBidAndCreatorPayout() public {
        setUp();
        uint256 verbId = createArtPiece("Art Piece", "A new art piece", ICultureIndex.MediaType.IMAGE, "ipfs://image", "", "", address(0x1), 10_000);

        uint256 creatorRate = auctionHouse.creatorRateBps();
        uint256 entropyRate = auctionHouse.entropyRateBps();

        auctionHouse.unpause();

        uint256 bidAmount = auctionHouse.reservePrice();
        vm.deal(address(1), bidAmount);
        vm.startPrank(address(1));
        auctionHouse.createBid{ value: bidAmount }(verbId);
        vm.stopPrank();

        //the amount of creator's eth to be spent on governance
        uint256 expectedCreatorShare = (bidAmount * (entropyRate * creatorRate)) / 10_000 / 10_000;
        uint256 etherToSpendOnGovernanceTotal = (bidAmount * creatorRate) / 10_000 - expectedCreatorShare;
        //Get expected protocol fee amount
        uint256 feeAmount = tokenEmitter.computeTotalReward(etherToSpendOnGovernanceTotal);

        // Get expected amount of ETH to be spent on governance
        uint256 etherToSpendOnGovernance = etherToSpendOnGovernanceTotal - feeAmount;

        vm.warp(block.timestamp + auctionHouse.duration() + 1); // Fast forward time to end the auction

        uint256 expectedGovernanceTokens = uint256(tokenEmitter.getTokenQuoteForPayment(etherToSpendOnGovernance));

        // Track ETH balances
        uint256 balanceBeforeCreator = address(0x1).balance;
        uint256 balanceBeforeTreasury = address(this).balance;

        // Track governance token balances
        uint256 governanceTokenBalanceBeforeCreator = governanceToken.balanceOf(address(0x1));

        auctionHouse.settleCurrentAndCreateNewAuction();

        // Checking if the creator received their share
        assertEq(address(0x1).balance - balanceBeforeCreator, expectedCreatorShare, "Creator did not receive the correct amount of ETH");

        // Checking if the contract received the correct amount
        uint256 expectedContractShare = bidAmount - expectedCreatorShare - feeAmount;
        assertEq(address(this).balance - balanceBeforeTreasury, expectedContractShare, "Contract did not receive the correct amount of ETH");

        // Checking ownership of the verb
        assertEq(verbs.ownerOf(verbId), address(1), "Verb should be transferred to the highest bidder");

        assertEq(
            governanceToken.balanceOf(address(0x1)) - governanceTokenBalanceBeforeCreator,
            expectedGovernanceTokens,
            "Creator did not receive the correct amount of governance tokens"
        );
    }
}

contract ContractWithoutReceiveOrFallback {
    // This contract intentionally does not have receive() or fallback()
    // functions to test the behavior of sending Ether to such a contract.
}

contract ContractThatRejectsEther {
    // This contract has a receive() function that reverts any Ether transfers.
    receive() external payable {
        revert("Rejecting Ether transfer");
    }

    // Alternatively, you could use a fallback function that reverts.
    // fallback() external payable {
    //     revert("Rejecting Ether transfer");
    // }
}
