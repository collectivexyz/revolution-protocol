// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { AuctionHouseTest } from "./AuctionHouse.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { IRevolutionToken } from "../../src/interfaces/IRevolutionToken.sol";
import { MockWETH } from "../mock/MockWETH.sol";
import { toDaysWadUnsafe } from "../../src/libs/SignedWadMath.sol";
import { IRevolutionPointsEmitter } from "../../src/interfaces/IRevolutionPointsEmitter.sol";

contract AuctionHouseSettleTest is AuctionHouseTest {
    // Fallback function to allow contract to receive Ether
    receive() external payable {}

    function test__VotesCount(uint8 nDays) public {
        createDefaultArtPiece();
        createDefaultArtPiece();

        vm.roll(vm.getBlockNumber() + 1);

        auction.unpause();

        uint256 bidAmount = auction.reservePrice();
        vm.deal(address(11), bidAmount);
        vm.startPrank(address(11));
        auction.createBid{ value: bidAmount }(0, address(11), address(0)); // Assuming first auction's tokenId is 0
        vm.stopPrank();

        vm.warp(block.timestamp + auction.duration() + nDays); // Fast forward time to end the auction

        createDefaultArtPiece();
        auction.settleCurrentAndCreateNewAuction();
        vm.roll(vm.getBlockNumber() + 1);

        assertEq(revolutionToken.ownerOf(0), address(11), "Token should be transferred to the highest bidder");
        // cultureIndex currentVotes of highest bidder should be 10
        assertEq(
            cultureIndex.votingPower().getVotesWithWeights(address(11), 1, cultureIndex.tokenVoteWeight()),
            cultureIndex.tokenVoteWeight(),
            "Highest bidder should have 10 votes"
        );
    }

    function test__OwnerPayment(uint8 nDays) public {
        createDefaultArtPiece();
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

        auction.unpause();

        uint256 bidAmount = auction.reservePrice();
        vm.deal(address(11), bidAmount);
        vm.startPrank(address(11));
        auction.createBid{ value: bidAmount }(0, address(11), address(0)); // Assuming first auction's tokenId is 0
        vm.stopPrank();

        vm.warp(block.timestamp + auction.duration() + nDays); // Fast forward time to end the auction

        createDefaultArtPiece();
        auction.settleCurrentAndCreateNewAuction();
        vm.roll(vm.getBlockNumber() + 1);

        //calculate fee
        uint256 auctioneerPayment = (bidAmount * (10_000 - auction.creatorRateBps())) / 10_000;

        //amount spent on governance
        uint256 etherToSpendOnGovernanceTotal = (bidAmount * auction.creatorRateBps()) /
            10_000 -
            (bidAmount * (auction.entropyRateBps() * auction.creatorRateBps())) /
            10_000 /
            10_000;

        uint256 feeAmount = revolutionPointsEmitter.computeTotalReward(etherToSpendOnGovernanceTotal);

        uint256 msgValueRemaining = etherToSpendOnGovernanceTotal - feeAmount;

        uint256 pointsValueFounder = (msgValueRemaining * revolutionPointsEmitter.founderRateBps()) / 10_000;
        uint256 pointsValueFounderDirect = (pointsValueFounder * revolutionPointsEmitter.founderEntropyRateBps()) /
            10_000;
        uint256 pointsValueFounderGov = pointsValueFounder - pointsValueFounderDirect;

        uint256 grantsDirectPayment = (msgValueRemaining * revolutionPointsEmitter.grantsRateBps()) / 10_000;

        uint256 pointsEmitterValueOwner = msgValueRemaining - pointsValueFounder - grantsDirectPayment;

        assertEq(
            address(executor).balance,
            auctioneerPayment + pointsEmitterValueOwner + pointsValueFounderGov,
            "Bid amount minus entropy should be transferred to the auction house owner"
        );
    }

    function test__SettlingAuctionWithNoBids(uint8 nDays) public {
        uint256 tokenId = createDefaultArtPiece();
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

        auction.unpause();

        vm.warp(block.timestamp + auction.duration() + nDays); // Fast forward time to end the auction

        // Assuming revolutionToken.burn is called for auctions with no bids
        vm.expectEmit(true, true, true, true);
        emit IRevolutionToken.RevolutionTokenBurned(tokenId);

        auction.settleCurrentAndCreateNewAuction();
    }

    function test__SettlingAuctionPrematurely() public {
        createDefaultArtPiece();
        createDefaultArtPiece();

        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

        auction.unpause();

        vm.expectRevert();
        auction.settleAuction(); // Attempt to settle before the auction ends
    }

    function test__TransferFailureAndFallbackToWETH(uint256 amount) public {
        amount = bound(amount, auction.reservePrice(), 1e12 ether);

        createDefaultArtPiece();
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

        auction.unpause();

        address recipient = address(new ContractThatRejectsEther());

        auction.transferOwnership(recipient);

        vm.startPrank(address(auction));

        vm.deal(address(auction), amount);
        auction.createBid{ value: amount }(0, address(this), address(0)); // Assuming first auction's tokenId is 0

        // Initially, recipient should have 0 ether and 0 WETH
        assertEq(recipient.balance, 0);
        assertEq(IERC20(address(weth)).balanceOf(recipient), 0);

        //go in future
        vm.warp(block.timestamp + auction.duration() + 1); // Fast forward time to end the auction

        auction.settleCurrentAndCreateNewAuction();

        // Check if the recipient received WETH instead of Ether
        uint256 creatorRate = auction.creatorRateBps();
        uint256 grantsRate = auction.grantsRateBps();
        uint256 expectedOwner = amount - ((amount * creatorRate) / 10_000) - ((amount * grantsRate) / 10_000);
        assertEq(IERC20(address(weth)).balanceOf(recipient), expectedOwner, "Owner should receive WETH");

        assertEq(recipient.balance, 0, "Ether balance should still be 0"); // Ether balance should still be 0

        //make sure voting weight on culture index is 721 vote weight for winning bidder
        assertEq(
            cultureIndex.votingPower().getVotesWithWeights(address(this), 1, cultureIndex.tokenVoteWeight()),
            cultureIndex.tokenVoteWeight(),
            "Highest bidder should have 10 votes"
        );
    }

    function test__TransferToEOA() public {
        createDefaultArtPiece();
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

        auction.unpause();

        address recipient = address(0x123); // Some EOA address
        uint256 amount = 1 ether;

        auction.transferOwnership(recipient);

        vm.startPrank(address(auction));
        vm.deal(address(auction), amount);
        auction.createBid{ value: amount }(0, address(this), address(0)); // Assuming first auction's tokenId is 0

        // Initially, recipient should have 0 ether
        assertEq(recipient.balance, 0);

        //go in future
        vm.warp(block.timestamp + auction.duration() + 1); // Fast forward time to end the auction

        auction.settleCurrentAndCreateNewAuction();

        // Check if the recipient received Ether
        uint256 creatorRate = auction.creatorRateBps();
        assertEq(recipient.balance, (amount * (10_000 - creatorRate)) / 10_000);
        //make sure voting weight on culture index is 721 vote weight for winning bidder
        assertEq(
            cultureIndex.votingPower().getVotesWithWeights(address(this), 1, cultureIndex.tokenVoteWeight()),
            cultureIndex.tokenVoteWeight(),
            "Highest bidder should have 10 votes"
        );
    }

    function test__TransferToContractWithoutReceiveOrFallback(uint256 amount) public {
        amount = bound(amount, auction.reservePrice(), 1e12 ether);

        createDefaultArtPiece();
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

        auction.unpause();

        address recipient = address(new ContractWithoutReceiveOrFallback());

        auction.transferOwnership(recipient);

        vm.startPrank(address(auction));

        vm.deal(address(auction), amount);
        auction.createBid{ value: amount }(0, address(this), address(0)); // Assuming first auction's tokenId is 0

        // Initially, recipient should have 0 ether and 0 WETH
        assertEq(recipient.balance, 0);
        assertEq(IERC20(address(weth)).balanceOf(recipient), 0);

        //go in future
        vm.warp(block.timestamp + auction.duration() + 1); // Fast forward time to end the auction

        auction.settleCurrentAndCreateNewAuction();

        // Check if the recipient received WETH instead of Ether
        uint256 creatorRate = auction.creatorRateBps();

        assertEq(
            IERC20(address(weth)).balanceOf(recipient),
            amount - ((amount * creatorRate) / 10_000) - ((amount * auction.grantsRateBps()) / 10_000),
            "Owner should receive WETH"
        );
        assertEq(recipient.balance, 0, "Ether balance should still be 0");
        //make sure voting weight on culture index is 721 vote weight for winning bidder
        assertEq(
            cultureIndex.votingPower().getVotesWithWeights(address(this), 1, cultureIndex.tokenVoteWeight()),
            cultureIndex.tokenVoteWeight(),
            "Highest bidder should have 10 votes"
        );
    }

    function getTokenQuoteForEtherHelper(uint256 etherAmount, int256 supply) public view returns (int gainedX) {
        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        return
            revolutionPointsEmitter.vrgda().yToX({
                timeSinceStart: toDaysWadUnsafe(block.timestamp - revolutionPointsEmitter.startTime()),
                sold: supply,
                amount: int(etherAmount)
            });
    }

    function getCreatorGovernancePayoutHelper(uint bidAmount) public returns (uint) {
        // Ether going to owner of the auction
        uint256 auctioneerPayment = (bidAmount * (10_000 - auction.creatorRateBps())) / 10_000;

        //Total amount of ether going to creator
        uint256 creatorsAuctionShare = bidAmount - auctioneerPayment;
        uint256 ethPaidToCreators = (creatorsAuctionShare * auction.entropyRateBps()) / (10_000);

        //amount to buy creators governance with
        uint256 creatorPointsEther = (creatorsAuctionShare - ethPaidToCreators);

        uint256 msgValueRemaining = creatorPointsEther - revolutionPointsEmitter.computeTotalReward(creatorPointsEther);

        uint256 founderShare = (msgValueRemaining * revolutionPointsEmitter.founderRateBps()) / 10_000;
        uint256 grantsShare = (msgValueRemaining * revolutionPointsEmitter.grantsRateBps()) / 10_000;
        uint256 buyersShare = msgValueRemaining - founderShare - grantsShare;
        uint256 founderDirectPayment = (founderShare * revolutionPointsEmitter.founderEntropyRateBps()) / 10_000;
        uint256 founderGovernancePayment = founderShare - founderDirectPayment;

        int256 expectedGrantsGovernanceTokenPayout = revolutionPointsEmitter.getTokenQuoteForEther(
            founderGovernancePayment
        );

        return uint256(getTokenQuoteForEtherHelper(buyersShare, expectedGrantsGovernanceTokenPayout));
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

    function _getTotalPointsEmitterPayment(
        uint256 creatorsShare,
        uint256 directPayment
    ) internal view returns (uint256) {
        uint256 ethPaidToCreators = 0;

        // If the amount to be spent on governance for creators is less than the minimum purchase amount for points
        if ((creatorsShare - (directPayment / 10_000)) <= revolutionPointsEmitter.minPurchaseAmount()) {
            // Set the amount to the full creators share, so creators are paid fully in ETH
            // 10_000 assumes 100% in BPS of the creators share is paid to the creators
            directPayment = creatorsShare * 10_000;
        }

        for (uint256 i = 0; i < 1; i++) {
            ethPaidToCreators += (directPayment * 10_000) / (10_000 * 10_000);
        }

        return creatorsShare - ethPaidToCreators;
    }

    //assuming dao owns both auction and revolutionPointsEmitter
    function getDAOPayout(uint bidAmount) public returns (uint) {
        uint256 grantsShare = (bidAmount * auction.grantsRateBps()) / 10_000;
        uint256 creatorsShare = (bidAmount * auction.creatorRateBps()) / 10_000;

        // Ether going to owner of the auction
        uint256 auctioneerPayment = bidAmount - creatorsShare - grantsShare;

        uint256 creatorPointsPayment = _getTotalPointsEmitterPayment(
            creatorsShare,
            (creatorsShare * auction.entropyRateBps())
        );

        uint256 msgValueRemaining = creatorPointsPayment -
            revolutionPointsEmitter.computeTotalReward(creatorPointsPayment);

        IRevolutionPointsEmitter.BuyTokenPaymentShares memory buyTokenPaymentShares = _calculateBuyTokenPaymentShares(
            msgValueRemaining
        );

        return (buyTokenPaymentShares.buyersGovernancePayment +
            buyTokenPaymentShares.founderGovernancePayment +
            auctioneerPayment);
    }

    function getFounderDirectPayment(uint bidAmount) public returns (uint) {
        uint256 grantsShare = (bidAmount * auction.grantsRateBps()) / 10_000;
        uint256 creatorsShare = (bidAmount * auction.creatorRateBps()) / 10_000;

        // Ether going to owner of the auction
        uint256 auctioneerPayment = bidAmount - creatorsShare - grantsShare;

        uint256 creatorPointsPayment = _getTotalPointsEmitterPayment(
            creatorsShare,
            (creatorsShare * auction.entropyRateBps())
        );

        uint256 msgValueRemaining = creatorPointsPayment -
            revolutionPointsEmitter.computeTotalReward(creatorPointsPayment);

        IRevolutionPointsEmitter.BuyTokenPaymentShares memory buyTokenPaymentShares = _calculateBuyTokenPaymentShares(
            msgValueRemaining
        );

        return buyTokenPaymentShares.founderDirectPayment;
    }

    function test__SettlingAuctionWithMultipleCreators(uint256 nCreators) public {
        vm.stopPrank();
        nCreators = bound(nCreators, 1, cultureIndex.MAX_NUM_CREATORS() - 1);

        address[] memory creatorAddresses = new address[](nCreators);
        uint256[] memory creatorBps = new uint256[](nCreators);
        uint256 totalBps = 0;

        // Assume n creators with equal share
        for (uint256 i = 0; i < nCreators; i++) {
            creatorAddresses[i] = address(uint160(i + 1)); // Example creator addresses
            if (i == nCreators - 1) {
                creatorBps[i] = 10_000 - totalBps;
            } else {
                creatorBps[i] = (10_000) / (nCreators - 1);
            }

            totalBps += creatorBps[i];
        }

        //mint points
        vm.prank(address(revolutionPointsEmitter));
        revolutionPoints.mint(address(this), 1000);
        vm.roll(vm.getBlockNumber() + 1);

        uint256 oldPieceId = createDefaultArtPiece();

        //mint 1 more token
        vm.prank(address(revolutionPointsEmitter));
        revolutionPoints.mint(address(this), 1000);
        vm.roll(vm.getBlockNumber() + 1);

        uint256 pieceId = createArtPieceMultiCreator(
            "Multi Creator Art",
            "An art piece with multiple creators",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://multi-creator-art",
            "",
            "",
            creatorAddresses,
            creatorBps
        );

        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

        //mint tokens and vote for piece
        vm.prank(address(this));
        cultureIndex.vote(pieceId);
        cultureIndex.vote(oldPieceId);

        vm.prank(address(executor));
        auction.unpause();

        vm.deal(address(21_000), auction.reservePrice() + 1 ether);
        vm.startPrank(address(21_000));
        auction.createBid{ value: auction.reservePrice() }(0, address(21_000), address(0));
        vm.stopPrank();

        vm.warp(block.timestamp + auction.duration() + 1); // Fast forward time to end the auction

        // Track balances before auction settlement
        uint256[] memory balancesBefore = new uint256[](creatorAddresses.length);
        uint256[] memory mockWETHBalancesBefore = new uint256[](creatorAddresses.length);
        uint256[] memory governanceTokenBalancesBefore = new uint256[](creatorAddresses.length);
        for (uint256 i = 0; i < creatorAddresses.length; i++) {
            balancesBefore[i] = address(creatorAddresses[i]).balance;
            governanceTokenBalancesBefore[i] = revolutionPoints.balanceOf(creatorAddresses[i]);
            mockWETHBalancesBefore[i] = MockWETH(payable(weth)).balanceOf(creatorAddresses[i]);
        }

        uint256 expectedGovernanceTokenPayout = getCreatorGovernancePayoutHelper(auction.reservePrice());

        auction.settleCurrentAndCreateNewAuction();

        //assert auctionHouse balance is 0
        assertEq(address(auction).balance, 0, "Auction house balance should be 0");

        // Verify each creator's payout
        for (uint256 i = 0; i < creatorAddresses.length; i++) {
            uint256 expectedEtherShare = uint256(
                ((auction.reservePrice()) * creatorBps[i] * auction.creatorRateBps()) / 10_000 / 10_000
            );

            //either the creator gets ETH or WETH
            assertEq(
                address(creatorAddresses[i]).balance - balancesBefore[i] > 0
                    ? address(creatorAddresses[i]).balance - balancesBefore[i]
                    : MockWETH(payable(weth)).balanceOf(creatorAddresses[i]) - mockWETHBalancesBefore[i],
                (expectedEtherShare * auction.entropyRateBps()) / 10_000,
                "Incorrect ETH payout for creator"
            );

            assertEq(
                revolutionPoints.balanceOf(creatorAddresses[i]) - governanceTokenBalancesBefore[i],
                uint256((expectedGovernanceTokenPayout * creatorBps[i]) / 10_000),
                "Incorrect governance token payout for creator"
            );
        }

        // Verify ownership of the token
        assertEq(revolutionToken.ownerOf(0), address(21_000), "Token should be transferred to the highest bidder");
        // Verify voting weight on culture index is 721 vote weight for winning bidder
        assertEq(
            cultureIndex.votingPower().getVotesWithWeights(address(21_000), 1, cultureIndex.tokenVoteWeight()),
            cultureIndex.tokenVoteWeight(),
            "Highest bidder should have 10 votes"
        );
    }

    function test__SettlingAuctionWithWinningBidAndCreatorPayout(uint256 bidAmount) public {
        bidAmount = bound(bidAmount, auction.reservePrice(), 1e12 ether);

        uint256 tokenId = createArtPiece(
            "Art Piece",
            "A new art piece",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://image",
            "",
            "",
            address(0x1),
            10_000
        );
        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

        auction.unpause();

        vm.deal(address(21_000), bidAmount);
        vm.startPrank(address(21_000));
        auction.createBid{ value: bidAmount }(tokenId, address(21_000), address(0));
        vm.stopPrank();

        vm.warp(block.timestamp + auction.duration() + 1); // Fast forward time to end the auction

        // Track ETH balances
        uint256 balanceBeforeCreator = address(0x1).balance;
        uint256 balanceBeforeOwner = address(dao).balance;

        uint256 expectedGovernanceTokens = getCreatorGovernancePayoutHelper(bidAmount);

        //create default art piece and roll
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1);

        auction.settleCurrentAndCreateNewAuction();

        //Total amount of ether going to creator
        uint256 creatorsShare = (bidAmount * auction.creatorRateBps()) / 10_000;

        //Amount going to grants program
        uint256 grantsShare = (bidAmount * auction.grantsRateBps()) / 10_000;

        // Ether going to owner of the auction
        uint256 auctioneerPayment = bidAmount - creatorsShare - grantsShare;

        uint256 creatorsDirectPayment = (creatorsShare * (auction.entropyRateBps())) / 10_000;

        uint256 creatorsGovernancePayment = creatorsShare - creatorsDirectPayment;

        // Checking if the creator received their share
        assertEq(
            address(0x1).balance - balanceBeforeCreator,
            creatorsDirectPayment,
            "Creator did not receive the correct amount of ETH"
        );

        assertEq(
            address(revolutionPointsEmitter.founderAddress()).balance,
            getFounderDirectPayment(bidAmount),
            "Founder address did not receive the correct amount of ETH"
        );

        assertEq(
            address(executor).balance - balanceBeforeOwner,
            getDAOPayout(bidAmount),
            "Owner did not receive the correct amount of ETH"
        );

        // ensure grant address balance is correct
        assertEq(
            address(revolutionPointsEmitter.grantsAddress()).balance,
            ((creatorsGovernancePayment - revolutionPointsEmitter.computeTotalReward(creatorsGovernancePayment)) *
                revolutionPointsEmitter.grantsRateBps()) / 10_000,
            "Grants address should have correct balance"
        );

        assertEq(
            revolutionToken.ownerOf(tokenId),
            address(21_000),
            "Token should be transferred to the highest bidder"
        );
        // Checking voting weight on culture index is 721 vote weight for winning bidder
        assertEq(
            cultureIndex.votingPower().getVotesWithWeights(address(21_000), 1, cultureIndex.tokenVoteWeight()),
            cultureIndex.tokenVoteWeight(),
            "Highest bidder should have 10 votes"
        );

        assertEq(
            revolutionPoints.balanceOf(address(0x1)),
            expectedGovernanceTokens,
            "Creator did not receive the correct amount of governance tokens"
        );
    }

    function test__EntropyPecentCannotLeadToDos(uint256 bidAmount) public {
        //set entropy to 9999
        auction.setEntropyRateBps(9999);

        // Ensure bidAmount is within bounds to make creatorGovernancePayment <= minPurchaseAmount
        uint256 minPurchaseAmount = revolutionPointsEmitter.minPurchaseAmount();
        uint256 minCreatorsShare = (minPurchaseAmount * 10_000) / (10_000 - auction.entropyRateBps());

        uint256 maxBidAmount = minCreatorsShare / (1 - (10_000 - auction.creatorRateBps()) / 10_000);

        bidAmount = bound(bidAmount, 1, maxBidAmount);

        // Ether going to owner of the auction
        // uint256 auctioneerPayment = (bidAmount * (10_000 - auction.creatorRateBps())) / 10_000;
        uint256 auctioneerPayment = bidAmount -
            (bidAmount * auction.creatorRateBps()) /
            10_000 -
            (bidAmount * auction.grantsRateBps()) /
            10_000;

        //set reserve price to the bid amount
        auction.setReservePrice(bidAmount);

        // create 2 art pieces
        uint256 pieceId = createDefaultArtPiece();
        createDefaultArtPiece();

        // roll block number to enable voting snapshot
        vm.roll(vm.getBlockNumber() + 1);

        //deal alice some eth
        address alice = vm.addr(uint256(1001));
        vm.deal(alice, bidAmount);

        // start the first auction
        auction.unpause();
        vm.stopPrank();

        // have alice create a  bid
        vm.prank(alice);
        auction.createBid{ value: bidAmount }(0, alice, address(0));

        // warp to the end of the auction
        (, , , uint256 endTime, , , ) = auction.auction();
        vm.warp(endTime + 1);

        // create a new auction
        auction.settleCurrentAndCreateNewAuction();

        //ensure creator got no governance, but got ETH
        address creator = cultureIndex.getPieceById(pieceId).creators[0].creator;

        assertEq(revolutionPoints.balanceOf(creator), 0, "Creator should not receive governance tokens");

        //Total amount of ether going to creator
        uint256 creatorsShare = bidAmount - auctioneerPayment;

        assertEq(creator.balance, creatorsShare, "Creator should receive ETH");
    }

    function test__SettleAuctionZeroEntropyRate() public {
        // set entropy rate to 0
        auction.setEntropyRateBps(0);

        createDefaultArtPiece();
        createDefaultArtPiece();
        vm.roll(vm.getBlockNumber() + 1); // roll block number to enable voting snapshot

        auction.unpause();

        address recipient = address(0x123); // Some EOA address
        uint256 amount = 1 ether;

        vm.startPrank(address(auction));
        vm.deal(address(auction), amount);
        auction.createBid{ value: amount }(0, address(this), address(0)); // Assuming first auction's tokenId is 0
        //go in future
        vm.warp(block.timestamp + auction.duration() + 1); // Fast forward time to end the auction

        auction.settleCurrentAndCreateNewAuction();
    }

    function test__RevertTopVotedPieceMeetsQuorum() public {
        vm.stopPrank();
        uint256 pointsSupply = 1000;

        vm.startPrank(address(revolutionPointsEmitter));
        revolutionPoints.mint(address(this), pointsSupply);
        vm.roll(vm.getBlockNumber() + 1);

        uint256 pieceId = createDefaultArtPiece();

        // Cast votes
        vm.startPrank(address(this));
        cultureIndex.vote(pieceId);

        // Mint token and govTokens, create a new piece and check fields
        vm.startPrank(address(executor));
        vm.roll(vm.getBlockNumber() + 1);

        auction.unpause();

        ICultureIndex.ArtPiece memory newPiece = cultureIndex.getPieceById(pieceId);
        vm.roll(vm.getBlockNumber() + 1);

        uint256 expectedTotalVotesSupply = pointsSupply;

        uint256 expectedQuorumVotes = (cultureIndex.quorumVotesBPS() * (expectedTotalVotesSupply)) / 10_000;
        assertEq(
            cultureIndex.quorumVotesForPiece(newPiece.pieceId),
            expectedQuorumVotes,
            "Quorum votes should be set correctly on creation"
        );

        // create art piece and vote for it again
        uint256 pieceId2 = createDefaultArtPiece();

        // roll
        vm.roll(vm.getBlockNumber() + 1);

        bool meetsQuorum = cultureIndex.topVotedPieceMeetsQuorum();
        assertTrue(!meetsQuorum, "Top voted piece should not meet quorum");

        // Cast votes
        vm.startPrank(address(this));
        cultureIndex.vote(pieceId2);

        // roll
        vm.roll(vm.getBlockNumber() + 1);

        meetsQuorum = cultureIndex.topVotedPieceMeetsQuorum();
        assertTrue(meetsQuorum, "Top voted piece should meet quorum");
    }

    function test_CreateAuctionWithoutSettle() public {
        vm.stopPrank();
        // mint points
        vm.prank(address(revolutionPointsEmitter));
        revolutionPoints.mint(address(this), 1000);

        vm.roll(vm.getBlockNumber() + 1);

        uint256 tokenId = createDefaultArtPiece();
        createDefaultArtPiece();

        //vote for tokenId
        vm.prank(address(this));
        cultureIndex.vote(tokenId);

        // roll
        vm.roll(vm.getBlockNumber() + 1);

        // Unpause the auction
        vm.prank(address(executor));
        auction.unpause();

        // warp to the end
        vm.warp(block.timestamp + auction.duration() + 1);

        //create and settle and expect revert
        vm.expectRevert(abi.encodeWithSignature("QUORUM_NOT_MET()"));
        auction.settleCurrentAndCreateNewAuction();

        // ensure auction is not paused and auction is not settled
        assertEq(auction.paused(), false, "Auction house should not be paused");

        (, , , , , , bool settled) = auction.auction();

        // Check that auction is not created
        assertEq(settled, false, "Auction should not be settled");
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
