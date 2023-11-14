// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {VerbsAuctionHouse} from "../packages/revolution-contracts/VerbsAuctionHouse.sol";
import {MockERC20} from "./MockERC20.sol";
import {VerbsToken} from "../packages/revolution-contracts/VerbsToken.sol";
import {IVerbsToken} from "../packages/revolution-contracts/interfaces/IVerbsToken.sol";
import { IProxyRegistry } from "../packages/revolution-contracts/external/opensea/IProxyRegistry.sol";
import {VerbsDescriptor} from "../packages/revolution-contracts/VerbsDescriptor.sol";
import {CultureIndex} from "../packages/revolution-contracts/CultureIndex.sol";
import { IVerbsDescriptorMinimal } from "../packages/revolution-contracts/interfaces/IVerbsDescriptorMinimal.sol";
import { ICultureIndex, ICultureIndexEvents } from "../packages/revolution-contracts/interfaces/ICultureIndex.sol";
import { IVerbsAuctionHouse } from "../packages/revolution-contracts/interfaces/IVerbsAuctionHouse.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { NontransferableERC20 } from "../packages/revolution-contracts/NontransferableERC20.sol";
import { TokenEmitter } from "../packages/revolution-contracts/TokenEmitter.sol";
import { ITokenEmitter } from "../packages/revolution-contracts/interfaces/ITokenEmitter.sol";
import { wadMul, wadDiv } from "solmate/utils/SignedWadMath.sol";

contract VerbsAuctionHouseTest is Test {
    VerbsAuctionHouse public auctionHouse;
    MockERC20 public mockWETH;
    VerbsToken public verbs;
    VerbsDescriptor public descriptor;
    CultureIndex public cultureIndex;
    TokenEmitter public tokenEmitter;

    // 1,000 tokens per day is the target emission
    uint256 tokensPerTimeUnit = 1_000;

    function setUp() public {
        mockWETH = new MockERC20();
        NontransferableERC20 governanceToken = new NontransferableERC20(address(this), "Revolution Governance", "GOV", 4);        

        // Additional setup for VerbsToken similar to VerbsTokenTest
        ProxyRegistry _proxyRegistry = new ProxyRegistry();

        CultureIndex _cultureIndex = new CultureIndex(address(mockWETH), address(this));
        cultureIndex = _cultureIndex;

        //20% - how much the price decays per unit of time with no sales
        int256 priceDecayPercent = 1e18 / 10;
        // 1e11 or 0.0000001 is 2 cents per token even at $200k eth price
        int256 tokenTargetPrice = 1e11;

        tokenEmitter = new TokenEmitter(governanceToken, address(this), tokenTargetPrice, priceDecayPercent, int256(1e18 * 1e4 * tokensPerTimeUnit));
        governanceToken.transferOwnership(address(tokenEmitter));

        // Initialize VerbsToken with additional parameters
        verbs = new VerbsToken(
            address(this),             // Address of the minter (and initial owner)
            address(this),             // Address of the owner
            IVerbsDescriptorMinimal(address(0)),
            _proxyRegistry,
            ICultureIndex(address(_cultureIndex))
        );

        cultureIndex.transferOwnership(address(verbs));

        // Deploy a new VerbsDescriptor, which will be used by VerbsToken
        descriptor = new VerbsDescriptor(address(verbs));
        IVerbsDescriptorMinimal _descriptor = descriptor;

        // Set the culture index and descriptor in VerbsToken
        verbs.setCultureIndex(ICultureIndex(address(_cultureIndex)));

        auctionHouse = new VerbsAuctionHouse();

        // Initialize the auction house with mock contracts and parameters
        auctionHouse.initialize(
            IVerbsToken(address(verbs)),
            ITokenEmitter(address(tokenEmitter)),
            address(mockWETH),
            address(this), // Owner of the auction house
            15 minutes,    // timeBuffer
            1 ether,       // reservePrice
            5,             // minBidIncrementPercentage
            24 hours,       // duration
            2_000,          // creatorRateBps
            5_000         //entropyRateBps
        );

        //set minter of verbstoken to be auction house
        verbs.setMinter(address(auctionHouse));
        verbs.lockMinter();
    }


    //calculate bps amount given split
    function bps(uint256 x, uint256 y) public returns (uint256) {
        return uint256(wadDiv(wadMul(int256(x), int256(y)), 10000));
    }

    // Fallback function to allow contract to receive Ether
    receive() external payable {}

    function testInitializationParameters() public {

        assertEq(auctionHouse.weth(), address(mockWETH), "WETH address should be set correctly");
        assertEq(auctionHouse.timeBuffer(), 15 minutes, "Time buffer should be set correctly");
        assertEq(auctionHouse.reservePrice(), 1 ether, "Reserve price should be set correctly");
        assertEq(auctionHouse.minBidIncrementPercentage(), 5, "Min bid increment percentage should be set correctly");
        assertEq(auctionHouse.duration(), 24 hours, "Auction duration should be set correctly");
    }
    

    function testAuctionCreation() public {
        setUp();
        createDefaultArtPiece();

        auctionHouse.unpause();
        uint256 startTime = block.timestamp;

        (uint256 verbId, uint256 amount, uint256 auctionStartTime, uint256 auctionEndTime, address payable bidder, bool settled) = auctionHouse.auction();
        assertEq(auctionStartTime, startTime, "Auction start time should be set correctly");
        assertEq(auctionEndTime, startTime + auctionHouse.duration(), "Auction end time should be set correctly");
        assertEq(verbId, 0, "Auction should be for the zeroth verb");
        assertEq(amount, 0, "Auction amount should be 0");
        assertEq(bidder, address(0), "Auction bidder should be 0");
        assertEq(settled, false, "Auction should not be settled");
        
    }


    function testBiddingProcess() public {
        setUp();
        createDefaultArtPiece();

        auctionHouse.unpause();
        uint256 bidAmount = auctionHouse.reservePrice() + 0.1 ether;
        vm.deal(address(1), bidAmount + 2 ether);

        vm.startPrank(address(1));
        auctionHouse.createBid{value: bidAmount}(0); // Assuming the first auction's verbId is 0
        (uint256 verbId, uint256 amount, , uint256 endTime, address payable bidder, ) = auctionHouse.auction();

        assertEq(amount, bidAmount, "Bid amount should be set correctly");
        assertEq(bidder, address(1), "Bidder address should be set correctly");
        vm.stopPrank();

        vm.warp(endTime + 1);
        createDefaultArtPiece();

        auctionHouse.settleCurrentAndCreateNewAuction(); // This will settle the current auction and create a new one

        assertEq(verbs.ownerOf(verbId), address(1), "Verb should be transferred to the auction house");
    }
    
    function testSettlingAuctions() public {
        setUp();
        createDefaultArtPiece();
        auctionHouse.unpause();

        (uint256 verbId, , , uint256 endTime, , ) = auctionHouse.auction();
        assertEq(verbs.ownerOf(verbId), address(auctionHouse), "Verb should be transferred to the auction house");

        vm.warp(endTime + 1);
        createDefaultArtPiece();

        auctionHouse.settleCurrentAndCreateNewAuction(); // This will settle the current auction and create a new one

        (, , , , , bool settled) = auctionHouse.auction();

        assertEq(settled, false, "Auction should not be settled because new one created");
    }

    

    function testAdministrativeFunctions() public {
        uint256 newTimeBuffer = 10 minutes;
        auctionHouse.setTimeBuffer(newTimeBuffer);
        assertEq(auctionHouse.timeBuffer(), newTimeBuffer, "Time buffer should be updated correctly");

        uint256 newReservePrice = 2 ether;
        auctionHouse.setReservePrice(newReservePrice);
        assertEq(auctionHouse.reservePrice(), newReservePrice, "Reserve price should be updated correctly");

        uint8 newMinBidIncrementPercentage = 10;
        auctionHouse.setMinBidIncrementPercentage(newMinBidIncrementPercentage);
        assertEq(auctionHouse.minBidIncrementPercentage(), newMinBidIncrementPercentage, "Min bid increment percentage should be updated correctly");
    }
    

    function testAccessControl() public {
        vm.startPrank(address(1));
        vm.expectRevert();
        auctionHouse.pause();
        vm.stopPrank();

        vm.startPrank(address(1));
        vm.expectRevert();
        auctionHouse.unpause();
        vm.stopPrank();
    }

    function testSettlingAuctionWithWinningBid() public {
        setUp();
        createDefaultArtPiece();
        auctionHouse.unpause();

        uint256 balanceBefore = address(this).balance;

        uint256 bidAmount = auctionHouse.reservePrice();
        vm.deal(address(1), bidAmount);
        vm.startPrank(address(1));
        auctionHouse.createBid{value: bidAmount}(0); // Assuming first auction's verbId is 0
        vm.stopPrank();

        vm.warp(block.timestamp + auctionHouse.duration() + 1); // Fast forward time to end the auction

        createDefaultArtPiece();
        auctionHouse.settleCurrentAndCreateNewAuction();

        uint256 balanceAfter = address(this).balance;

        assertEq(verbs.ownerOf(0), address(1), "Verb should be transferred to the highest bidder");
        
        uint256 creatorRate = auctionHouse.creatorRateBps();

        assertEq(balanceAfter - balanceBefore, bps(bidAmount, 10_000 - creatorRate), "Bid amount should be transferred to the auction house owner");
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
        auctionHouse.createBid{value: amount}(0); // Assuming first auction's verbId is 0

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
        auctionHouse.createBid{value: amount}(0); // Assuming first auction's verbId is 0

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
        auctionHouse.createBid{value: amount}(0); // Assuming first auction's verbId is 0

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

    // Utility function to create a new art piece and return its ID
    function createArtPiece(
        string memory name,
        string memory description,
        ICultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl,
        address creatorAddress,
        uint256 creatorBps
    ) internal returns (uint256) {
        ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex
            .ArtPieceMetadata({
                name: name,
                description: description,
                mediaType: mediaType,
                image: image,
                text: text,
                animationUrl: animationUrl
            });

        ICultureIndex.CreatorBps[]
            memory creators = new ICultureIndex.CreatorBps[](1);
        creators[0] = ICultureIndex.CreatorBps({
            creator: creatorAddress,
            bps: creatorBps
        });

        return cultureIndex.createPiece(metadata, creators);
    }

    //Utility function to create default art piece
    function createDefaultArtPiece() public returns (uint256) {
        return createArtPiece(
            "Mona Lisa",
            "A masterpiece",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://legends",
            "",
            "",
            address(0x1),
            10000
        );
    }
}

contract ProxyRegistry is IProxyRegistry {
    mapping(address => address) public proxies;
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
