// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { CultureIndexTestSuite } from "./CultureIndex.t.sol";

contract CultureIndexTopTenSelectionTest is CultureIndexTestSuite {
    function _seedRankedPieces(uint256 count) internal returns (uint256[] memory pieceIds) {
        pieceIds = new uint256[](count);

        vm.stopPrank();
        vm.startPrank(address(revolutionPointsEmitter));
        revolutionPoints.mint(address(this), 250);

        for (uint256 i; i < count; ++i) {
            revolutionPoints.mint(address(uint160(0x1000 + i)), 1_000 + i);
        }
        vm.stopPrank();

        vm.roll(vm.getBlockNumber() + 1);

        for (uint256 i; i < count; ++i) {
            pieceIds[i] = createDefaultArtPiece();
        }

        vm.roll(vm.getBlockNumber() + 1);

        for (uint256 i; i < count; ++i) {
            vm.prank(address(uint160(0x1000 + i)));
            cultureIndex.vote(pieceIds[i]);
        }
    }

    function testGetTopPieceIdsUsesHeapFrontierTraversal() public {
        _seedRankedPieces(12);

        uint256[] memory topPieceIds = cultureIndex.getTopPieceIds(10);

        assertEq(topPieceIds.length, 10);
        for (uint256 i; i < 10; ++i) {
            assertEq(topPieceIds[i], 11 - i, "top pieces should be returned by vote rank, not heap array index");
        }
    }

    function testIsPieceInTopNUsesRankPruning() public {
        _seedRankedPieces(12);

        assertTrue(cultureIndex.isPieceInTopN(2, 10), "rank 10 should be selectable");
        assertFalse(cultureIndex.isPieceInTopN(1, 10), "rank 11 should not be selectable");
    }

    function testDropPieceInTopNRemovesSelectedRankTenPiece() public {
        _seedRankedPieces(12);

        vm.prank(address(revolutionToken));
        ICultureIndex.ArtPieceCondensed memory droppedPiece = cultureIndex.dropPieceInTopN(2, 10);

        assertEq(droppedPiece.pieceId, 2);
        assertTrue(cultureIndex.getPieceById(2).isDropped, "selected piece should be marked dropped");
        assertFalse(cultureIndex.isPieceInTopN(2, 10), "dropped piece should not remain selectable");

        uint256[] memory topPieceIds = cultureIndex.getTopPieceIds(10);
        assertEq(topPieceIds[0], 11, "top piece should be preserved");
        assertEq(topPieceIds[9], 1, "rank 11 should enter the displayed pool after rank 10 is bought");
    }

    function testDropPieceInTopNRevertsForRankElevenPiece() public {
        _seedRankedPieces(12);

        vm.expectRevert(abi.encodeWithSignature("PIECE_NOT_IN_TOP_N()"));
        vm.prank(address(revolutionToken));
        cultureIndex.dropPieceInTopN(1, 10);
    }

    function testMintFromPieceMintsSelectedTopTenPieceToRecipient() public {
        _seedRankedPieces(12);

        address recipient = address(0xBEEF);

        vm.prank(address(executor));
        revolutionToken.setMinter(address(this));

        uint256 tokenId = revolutionToken.mintFromPiece(recipient, 2, 10);

        assertEq(revolutionToken.ownerOf(tokenId), recipient);
        assertEq(revolutionToken.getArtPieceById(tokenId).pieceId, 2);
        assertTrue(cultureIndex.getPieceById(2).isDropped);
    }

    function testSetLegacyQuorumExcludedTokenHolderRejectsInvalidCutoffConfig() public {
        vm.expectRevert(ICultureIndex.INVALID_QUORUM_CUTOFF.selector);
        cultureIndex.setLegacyQuorumExcludedTokenHolder(address(0xA11CE), block.number + 1);

        vm.expectRevert(ICultureIndex.INVALID_QUORUM_CUTOFF.selector);
        cultureIndex.setLegacyQuorumExcludedTokenHolder(address(0xA11CE), 0);

        vm.expectRevert(ICultureIndex.INVALID_QUORUM_CUTOFF.selector);
        cultureIndex.setLegacyQuorumExcludedTokenHolder(address(0), block.number);

        cultureIndex.setLegacyQuorumExcludedTokenHolder(address(0xA11CE), block.number);
        assertEq(cultureIndex.legacyQuorumExcludedTokenHolder(), address(0xA11CE));
        assertEq(cultureIndex.legacyQuorumCutoffBlock(), block.number);

        cultureIndex.setLegacyQuorumExcludedTokenHolder(address(0), 0);
        assertEq(cultureIndex.legacyQuorumExcludedTokenHolder(), address(0));
        assertEq(cultureIndex.legacyQuorumCutoffBlock(), 0);
    }

    function testSetLegacyQuorumExcludedTokenHolderCanBindCutoffToCurrentBlock() public {
        uint256 currentBlock = block.number;

        cultureIndex.setLegacyQuorumExcludedTokenHolder(address(0xA11CE), type(uint256).max);

        assertEq(cultureIndex.legacyQuorumExcludedTokenHolder(), address(0xA11CE));
        assertEq(cultureIndex.legacyQuorumCutoffBlock(), currentBlock);
    }

    function testGasIsPieceInTop10WithThousandPiecesDoesNotScanFullHeap() public {
        _seedRankedPieces(1_000);

        uint256 startGas = gasleft();
        bool selectable = cultureIndex.isPieceInTopN(990, 10);
        uint256 gasUsed = startGas - gasleft();

        assertTrue(selectable, "rank 10 should be selectable");
        assertLt(gasUsed, 500_000, "top-10 validation should remain bounded");
    }
}
