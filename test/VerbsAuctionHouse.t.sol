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
import { wadMul, wadDiv } from "../packages/revolution-contracts/libs/SignedWadMath.sol";
import { RevolutionProtocolRewards } from "../packages/protocol-rewards/RevolutionProtocolRewards.sol";
import {TokenEmitterRewards} from "../packages/protocol-rewards/abstract/TokenEmitter/TokenEmitterRewards.sol";

contract VerbsAuctionHouseTest is Test {
    VerbsAuctionHouse public auctionHouse;
    MockERC20 public mockWETH;
    VerbsToken public verbs;
    VerbsDescriptor public descriptor;
    CultureIndex public cultureIndex;
    TokenEmitter public tokenEmitter;
    NontransferableERC20 public governanceToken;

    // 1,000 tokens per day is the target emission
    uint256 tokensPerTimeUnit = 1_000;

    function setUp() public {
        mockWETH = new MockERC20();
        governanceToken = new NontransferableERC20(address(this), "Revolution Governance", "GOV", 4);        
        RevolutionProtocolRewards protocolRewards = new RevolutionProtocolRewards();
        
        // Additional setup for VerbsToken similar to VerbsTokenTest
        ProxyRegistry _proxyRegistry = new ProxyRegistry();

        CultureIndex _cultureIndex = new CultureIndex(address(governanceToken), address(this));
        cultureIndex = _cultureIndex;

        //20% - how much the price decays per unit of time with no sales
        int256 priceDecayPercent = 1e18 / 10;
        // 1e11 or 0.0000001 is 2 cents per token even at $200k eth price
        int256 tokenTargetPrice = 1e11;

        address protocolFeeRecipient = address(0x42069);

        tokenEmitter = new TokenEmitter(governanceToken, address(protocolRewards), protocolFeeRecipient, address(this), tokenTargetPrice, priceDecayPercent, int256(1e18 * 1e4 * tokensPerTimeUnit));
        governanceToken.transferOwnership(address(tokenEmitter));

        // Initialize VerbsToken with additional parameters
        verbs = new VerbsToken(
            address(this),             // Address of the minter (and initial owner)
            address(this),             // Address of the owner
            IVerbsDescriptorMinimal(address(0)),
            _proxyRegistry,
            ICultureIndex(address(_cultureIndex)),
            "Vrbs",
            "VRBS"
        );

        cultureIndex.transferOwnership(address(verbs));

        // Deploy a new VerbsDescriptor, which will be used by VerbsToken
        descriptor = new VerbsDescriptor(address(verbs), "Verb");
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
        address[] memory creatorAddresses = new address[](1);
        creatorAddresses[0] = creatorAddress;

        uint256[] memory creatorBpsArray = new uint256[](1);
        creatorBpsArray[0] = creatorBps;

        return createArtPieceMultiCreator(
            name,
            description,
            mediaType,
            image,
            text,
            animationUrl,
            creatorAddresses,
            creatorBpsArray
        );
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

        // Utility function to create a new art piece with multiple creators and return its ID
    function createArtPieceMultiCreator(
        string memory name,
        string memory description,
        ICultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl,
        address[] memory creatorAddresses,
        uint256[] memory creatorBps
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

        ICultureIndex.CreatorBps[] memory creators = new ICultureIndex.CreatorBps[](creatorAddresses.length);
        for (uint256 i = 0; i < creatorAddresses.length; i++) {
            creators[i] = ICultureIndex.CreatorBps({
                creator: creatorAddresses[i],
                bps: creatorBps[i]
            });
        }

        return cultureIndex.createPiece(metadata, creators);
    }


}

contract ProxyRegistry is IProxyRegistry {
    mapping(address => address) public proxies;
}