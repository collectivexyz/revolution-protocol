// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";

import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { IRevolutionTokenSale } from "../../src/interfaces/IRevolutionTokenSale.sol";
import { RevolutionTokenSale } from "../../src/RevolutionTokenSale.sol";

contract RevolutionTokenSaleTest is RevolutionBuilderTest {
    RevolutionTokenSale internal tokenSale;

    function setUp() public override {
        super.setUp();
        super.setMockParams();

        // Keep quorum out of these tests so rank/top-N behavior is isolated.
        super.setCultureIndexParams(
            "Vrbs",
            "Our community Vrbs.",
            "- [ ] Must be 32x32. - [ ] Must include the noggles.",
            "ipfs://",
            100 * 1e18,
            1,
            0,
            0,
            0,
            ICultureIndex.PieceMaximums({ name: 100, description: 2100, image: 64_000, text: 256, animationUrl: 100 }),
            ICultureIndex.MediaType.NONE,
            ICultureIndex.RequiredMediaPrefix.MIXED
        );

        super.deployMock();

        vm.warp(30 days);
        _deployTokenSale(_defaultSaleParams());
    }

    function testGetTopPieceIdsUsesHeapFrontierNotBackingArraySlice() public {
        uint256[] memory pieceIds = _createRankedPieces(12);

        uint256[] memory topPieces = cultureIndex.getTopPieceIds(10);

        assertEq(topPieces.length, 10);
        assertEq(topPieces[0], pieceIds[11]);
        assertEq(topPieces[1], pieceIds[10]);
        assertEq(topPieces[9], pieceIds[2]);

        assertTrue(cultureIndex.isPieceInTopN(pieceIds[2], 10));
        assertFalse(cultureIndex.isPieceInTopN(pieceIds[1], 10));
    }

    function testBuyNowMintsSelectedRankTenPieceToRecipient() public {
        uint256[] memory pieceIds = _createRankedPieces(12);
        uint256 selectedPieceId = pieceIds[2]; // rank 10 by vote weight
        address buyer = address(0xB0B0);
        address recipient = address(0xCAFE);

        _switchMinterAndUnpauseSale();

        uint256 price = tokenSale.getCurrentPrice();
        vm.deal(buyer, price);

        vm.prank(buyer);
        (uint256 tokenId, uint256 paidPrice) = tokenSale.buyNow{ value: price }(
            selectedPieceId,
            recipient,
            price,
            address(0)
        );

        assertEq(paidPrice, price);
        assertEq(tokenId, 0);
        assertEq(revolutionToken.ownerOf(tokenId), recipient);
        ICultureIndex.ArtPiece memory mintedPiece = revolutionToken.getArtPieceById(tokenId);
        assertEq(mintedPiece.pieceId, selectedPieceId);
        assertEq(tokenSale.soldByVRGDA(), 1);
        assertFalse(cultureIndex.isPieceInTopN(selectedPieceId, 10));

        IRevolutionTokenSale.SaleHistory memory sale = tokenSale.getPastSale(tokenId);
        assertEq(sale.amount, price);
        assertEq(sale.buyer, buyer);
        assertEq(sale.recipient, recipient);
        assertEq(sale.pieceId, selectedPieceId);
    }

    function testBuyNowRejectsPieceOutsideTopTen() public {
        uint256[] memory pieceIds = _createRankedPieces(12);
        uint256 rankElevenPieceId = pieceIds[1];
        address buyer = address(0xB0B0);
        address recipient = address(0xCAFE);

        _switchMinterAndUnpauseSale();

        uint256 price = tokenSale.getCurrentPrice();
        vm.deal(buyer, price);

        vm.prank(buyer);
        vm.expectRevert(ICultureIndex.PIECE_NOT_IN_TOP_N.selector);
        tokenSale.buyNow{ value: price }(rankElevenPieceId, recipient, price, address(0));
    }

    function testBuyNowHonorsMaxPriceAndRefundsOverpayment() public {
        uint256[] memory pieceIds = _createRankedPieces(12);
        uint256 selectedPieceId = pieceIds[11];
        address buyer = address(0xB0B0);
        address recipient = address(0xCAFE);

        _switchMinterAndUnpauseSale();

        uint256 price = tokenSale.getCurrentPrice();
        vm.deal(buyer, price + 1 ether);

        vm.prank(buyer);
        vm.expectRevert(IRevolutionTokenSale.MAX_PRICE_EXCEEDED.selector);
        tokenSale.buyNow{ value: price }(selectedPieceId, recipient, price - 1, address(0));

        uint256 balanceBefore = buyer.balance;

        vm.prank(buyer);
        tokenSale.buyNow{ value: price + 1 ether }(selectedPieceId, recipient, price, address(0));

        assertEq(balanceBefore - buyer.balance, price);
    }

    function testBuyNowRollsBackMintIfCreatorGovernancePurchaseReverts() public {
        uint256[] memory pieceIds = _createRankedPieces(12);
        uint256 selectedPieceId = pieceIds[11];
        address buyer = address(0xB0B0);
        address recipient = address(0xCAFE);

        _switchMinterAndUnpauseSale();

        vm.prank(address(executor));
        revolutionPointsEmitter.pause();

        uint256 price = tokenSale.getCurrentPrice();
        vm.deal(buyer, price);

        vm.prank(buyer);
        vm.expectRevert();
        tokenSale.buyNow{ value: price }(selectedPieceId, recipient, price, address(0));

        assertEq(tokenSale.soldByVRGDA(), 0);
        assertEq(revolutionToken.balanceOf(recipient), 0);
        assertFalse(cultureIndex.getPieceById(selectedPieceId).isDropped);
        assertTrue(cultureIndex.isPieceInTopN(selectedPieceId, 10));
    }

    function testGetAvailablePiecesIsCappedBySalePoolSize() public {
        _createRankedPieces(12);

        vm.prank(founder);
        tokenSale.setPoolSize(5);

        (uint256[] memory pieceIds, uint256 price) = tokenSale.getAvailablePieces(10);

        assertEq(pieceIds.length, 5);
        assertEq(price, tokenSale.getCurrentPrice());
    }

    function testGrantsConfigCannotRoutePositiveRateToZeroAddress() public {
        IRevolutionTokenSale.TokenSaleParams memory params = _defaultSaleParams();
        params.grantsParams.grantsAddress = address(0);
        params.grantsParams.totalRateBps = 1;

        _expectTokenSaleDeployRevert(IRevolutionTokenSale.INVALID_GRANTS_CONFIG.selector, params);

        vm.prank(founder);
        vm.expectRevert(IRevolutionTokenSale.INVALID_GRANTS_CONFIG.selector);
        tokenSale.setGrantsAddress(address(0));

        vm.prank(founder);
        tokenSale.setGrantsRateBps(0);

        vm.prank(founder);
        tokenSale.setGrantsAddress(address(0));

        vm.prank(founder);
        vm.expectRevert(IRevolutionTokenSale.INVALID_GRANTS_CONFIG.selector);
        tokenSale.setGrantsRateBps(1);
    }

    function testBuyNowRejectsWhenSoldCountCannotPriceAnotherSale() public {
        uint256[] memory pieceIds = _createRankedPieces(12);
        uint256 selectedPieceId = pieceIds[11];
        address buyer = address(0xB0B0);
        address recipient = address(0xCAFE);
        uint256 maxSoldByVRGDA = tokenSale.MAX_SOLD_BY_VRGDA();

        vm.prank(founder);
        tokenSale.setSoldByVRGDA(maxSoldByVRGDA);

        _switchMinterAndUnpauseSale();

        vm.prank(buyer);
        vm.expectRevert(IRevolutionTokenSale.INVALID_SOLD_COUNT.selector);
        tokenSale.buyNow{ value: 0 }(selectedPieceId, recipient, type(uint256).max, address(0));
    }

    function testVRGDAPricingRejectsUnsafeTargetPrice() public {
        IRevolutionTokenSale.TokenSaleParams memory params = _defaultSaleParams();
        params.vrgdaParams.targetPrice = tokenSale.MAX_TARGET_PRICE() + 1;

        _expectTokenSaleDeployRevert(IRevolutionTokenSale.INVALID_VRGDA_PARAMS.selector, params);

        vm.prank(founder);
        vm.expectRevert(IRevolutionTokenSale.INVALID_VRGDA_PARAMS.selector);
        tokenSale.setVRGDAParams(params.vrgdaParams);
    }

    function testVRGDAPricingRejectsUnsafeWadOverflowSoldCount() public {
        uint256 safeMaxSoldCount = tokenSale.MAX_SOLD_BY_VRGDA();
        uint256 unsafeSoldCount = safeMaxSoldCount + 1;

        assertEq(tokenSale.getPrice(safeMaxSoldCount), type(uint256).max);

        vm.expectRevert(IRevolutionTokenSale.INVALID_SOLD_COUNT.selector);
        tokenSale.getPrice(unsafeSoldCount);

        vm.prank(founder);
        vm.expectRevert(IRevolutionTokenSale.INVALID_SOLD_COUNT.selector);
        tokenSale.setSoldByVRGDA(unsafeSoldCount);
    }

    function testVRGDAPriceFallsWhenBehindAndRisesWhenAhead() public {
        uint256 initialPrice = tokenSale.getCurrentPrice();
        assertEq(initialPrice, 1 ether);

        vm.warp(block.timestamp + 1 days);
        uint256 behindPrice = tokenSale.getCurrentPrice();
        assertLt(behindPrice, initialPrice);
        assertGe(behindPrice, tokenSale.minPriceWei());

        // At launch, pricing the second token before the first target interval has elapsed is ahead of schedule.
        vm.warp(block.timestamp - 1 days);
        uint256 aheadPrice = tokenSale.getPrice(1);
        assertGt(aheadPrice, initialPrice);
    }

    function testGas_IsPieceInTopTenWithThousandPieceHeap() public {
        uint256[] memory pieceIds = _createLargeHeapWithRankedTail(1_000);
        uint256 rankTenPieceId = pieceIds[990];

        uint256 gasStart = gasleft();
        bool inTopTen = cultureIndex.isPieceInTopN(rankTenPieceId, 10);
        uint256 gasUsed = gasStart - gasleft();

        emit log_named_uint("isPieceInTopN(rank10, 10) gas, 1000-piece heap", gasUsed);
        assertTrue(inTopTen);
        assertLt(gasUsed, 250_000);
    }

    function testGas_BuyNowRankTenWithThousandPieceHeap() public {
        uint256[] memory pieceIds = _createLargeHeapWithRankedTail(1_000);
        uint256 rankTenPieceId = pieceIds[990];
        address buyer = address(0xB0B0);
        address recipient = address(0xCAFE);

        _switchMinterAndUnpauseSale();

        uint256 price = tokenSale.getCurrentPrice();
        vm.deal(buyer, price);

        vm.prank(buyer);
        uint256 gasStart = gasleft();
        tokenSale.buyNow{ value: price }(rankTenPieceId, recipient, price, address(0));
        uint256 gasUsed = gasStart - gasleft();

        emit log_named_uint("buyNow(rank10) gas, 1000-piece heap", gasUsed);
        assertLt(gasUsed, 2_500_000);
    }

    function _defaultSaleParams() internal view returns (IRevolutionTokenSale.TokenSaleParams memory) {
        return
            IRevolutionTokenSale.TokenSaleParams({
                minPriceWei: 0.01 ether,
                creatorRateBps: auctionParams.creatorRateBps,
                entropyRateBps: auctionParams.entropyRateBps,
                minCreatorRateBps: auctionParams.minCreatorRateBps,
                grantsParams: auctionParams.grantsParams,
                vrgdaParams: IRevolutionTokenSale.VRGDAParams({
                    targetPrice: int256(1 ether),
                    priceDecayPercent: int256(31e16),
                    tokensPerTimeUnit: int256(1e18)
                }),
                saleStartTime: block.timestamp - 1 days,
                soldByVRGDA: 0,
                priceUpdateInterval: 15 minutes,
                poolSize: 10
            });
    }

    function _deployTokenSale(IRevolutionTokenSale.TokenSaleParams memory params) internal {
        address saleImpl = address(new RevolutionTokenSale(address(manager), address(protocolRewards), revolutionDAO));
        bytes memory init = abi.encodeWithSelector(
            RevolutionTokenSale.initialize.selector,
            address(revolutionToken),
            address(revolutionPointsEmitter),
            founder,
            weth,
            params
        );

        tokenSale = RevolutionTokenSale(address(new ERC1967Proxy(saleImpl, init)));
        vm.label(address(tokenSale), "TOKEN_SALE");
    }

    function _expectTokenSaleDeployRevert(
        bytes4 expectedRevert,
        IRevolutionTokenSale.TokenSaleParams memory params
    ) internal {
        address saleImpl = address(new RevolutionTokenSale(address(manager), address(protocolRewards), revolutionDAO));
        bytes memory init = abi.encodeWithSelector(
            RevolutionTokenSale.initialize.selector,
            address(revolutionToken),
            address(revolutionPointsEmitter),
            founder,
            weth,
            params
        );

        vm.expectRevert(expectedRevert);
        new ERC1967Proxy(saleImpl, init);
    }

    function _switchMinterAndUnpauseSale() internal {
        vm.prank(address(executor));
        revolutionToken.setMinter(address(tokenSale));

        vm.prank(founder);
        tokenSale.unpause();
    }

    function _createRankedPieces(uint256 count) internal returns (uint256[] memory pieceIds) {
        pieceIds = new uint256[](count);
        address[] memory voters = new address[](count);

        vm.startPrank(address(revolutionPointsEmitter));
        for (uint256 i; i < count; ++i) {
            voters[i] = vm.addr(10_000 + i);
            revolutionPoints.mint(voters[i], (i + 1) * 1e18);
        }
        vm.stopPrank();

        vm.roll(block.number + 1);

        for (uint256 i; i < count; ++i) {
            vm.prank(voters[i]);
            pieceIds[i] = cultureIndex.createPiece(
                createDefaultMetadata(),
                _singleCreator(address(uint160(0xA11CE + i)))
            );
        }

        vm.roll(block.number + 1);

        for (uint256 i; i < count; ++i) {
            vm.prank(voters[i]);
            cultureIndex.vote(pieceIds[i]);
        }
    }

    function _createLargeHeapWithRankedTail(uint256 heapSize) internal returns (uint256[] memory pieceIds) {
        pieceIds = new uint256[](heapSize);
        address[] memory voters = new address[](12);

        vm.startPrank(address(revolutionPointsEmitter));
        for (uint256 i; i < 12; ++i) {
            voters[i] = vm.addr(20_000 + i);
            revolutionPoints.mint(voters[i], (i + 1) * 1e18);
        }
        vm.stopPrank();

        vm.roll(block.number + 1);

        for (uint256 i; i < heapSize; ++i) {
            pieceIds[i] = cultureIndex.createPiece(createDefaultMetadata(), _singleCreator(address(uint160(0xBEEF))));
        }

        vm.roll(block.number + 1);

        uint256 tailStart = heapSize - 12;
        for (uint256 i; i < 12; ++i) {
            vm.prank(voters[i]);
            cultureIndex.vote(pieceIds[tailStart + i]);
        }
    }

    function _singleCreator(address creator) internal pure returns (ICultureIndex.CreatorBps[] memory creators) {
        creators = new ICultureIndex.CreatorBps[](1);
        creators[0] = ICultureIndex.CreatorBps({ creator: creator, bps: 10_000 });
    }
}
