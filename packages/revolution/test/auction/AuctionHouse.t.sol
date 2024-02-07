// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { AuctionHouse } from "../../src/AuctionHouse.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { RevolutionToken } from "../../src/RevolutionToken.sol";
import { IRevolutionToken } from "../../src/interfaces/IRevolutionToken.sol";
import { Descriptor } from "../../src/Descriptor.sol";
import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { IDescriptorMinimal } from "../../src/interfaces/IDescriptorMinimal.sol";
import { ICultureIndex, ICultureIndexEvents } from "../../src/interfaces/ICultureIndex.sol";
import { IAuctionHouse } from "../../src/interfaces/IAuctionHouse.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { RevolutionPointsEmitter } from "../../src/RevolutionPointsEmitter.sol";
import { IRevolutionPointsEmitter } from "../../src/interfaces/IRevolutionPointsEmitter.sol";
import { wadMul, wadDiv } from "../../src/libs/SignedWadMath.sol";
import { RevolutionProtocolRewards } from "@cobuild/protocol-rewards/src/RevolutionProtocolRewards.sol";
import { PointsEmitterRewards } from "@cobuild/protocol-rewards/src/abstract/PointsEmitter/PointsEmitterRewards.sol";
import { ERC721CheckpointableUpgradeable } from "../../src/base/ERC721CheckpointableUpgradeable.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";

contract AuctionHouseTest is RevolutionBuilderTest {
    function setUp() public virtual override {
        super.setUp();
        super.setMockParams();

        super.setPointsParams("Revolution Governance", "GOV");

        super.setCultureIndexParams(
            "Vrbs",
            "Our community Vrbs.",
            "Must be 32x32.",
            "ipfs://",
            10,
            1,
            200,
            0,
            0,
            ICultureIndex.PieceMaximums({ name: 100, description: 2100, image: 64_000, text: 256, animationUrl: 100 }),
            ICultureIndex.MediaType.NONE,
            ICultureIndex.RequiredMediaPrefix.MIXED
        );

        super.setRevolutionTokenParams("Vrbs", "VRBS", "QmQzDwaZ7yQxHHs7sQQenJVB89riTSacSGcJRv9jtHPuz5", "Vrb");

        super.setAuctionParams(
            15 minutes, // timeBuffer
            1 ether, // reservePrice
            24 hours, // duration
            5, // minBidIncrementPercentage
            2_000, // creatorRateBps
            5_000, //entropyRateBps
            1_000, //minCreatorRateBps
            IRevolutionBuilder.GrantsParams({ totalRateBps: 0, grantsAddress: grantsAddress })
        );

        super.deployMock();

        //transfer ownership and accept
        vm.prank(address(founder));
        auction.transferOwnership(address(executor));

        vm.startPrank(address(executor));
    }
}
