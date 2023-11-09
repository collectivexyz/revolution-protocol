// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {CultureIndex} from "../packages/revolution-contracts/CultureIndex.sol";
import {MockERC20} from "./MockERC20.sol";
import {CultureIndexVotingTest} from "./CultureIndex.Voting.t.sol";
import {ICultureIndex} from "../packages/revolution-contracts/interfaces/ICultureIndex.sol";

/**
 * @title CultureIndexArtPieceTest
 * @dev Test contract for CultureIndex art piece creation
 */
contract CultureIndexArtPieceTest is Test {
    CultureIndexVotingTest public voter1Test;
    CultureIndexVotingTest public voter2Test;
    CultureIndex public cultureIndex;
    MockERC20 public mockVotingToken;
    

    function setUp() public {
        mockVotingToken = new MockERC20();
        cultureIndex = new CultureIndex(address(mockVotingToken), address(this));

        // Create new test instances acting as different voters
        voter1Test = new CultureIndexVotingTest(address(cultureIndex), address(mockVotingToken));
        voter2Test = new CultureIndexVotingTest(address(cultureIndex), address(mockVotingToken));
    }

    // Function to create ArtPieceMetadata
    function createArtPieceMetadata(
        string memory name,
        string memory description,
        ICultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl
    ) public pure returns (CultureIndex.ArtPieceMetadata memory) { // <-- Change visibility and mutability as needed
        ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex
            .ArtPieceMetadata({
                name: name,
                description: description,
                mediaType: mediaType,
                image: image,
                text: text,
                animationUrl: animationUrl
            });

        return metadata;
    }

    // Function to create CreatorBps array
    function createArtPieceCreators(
        address creatorAddress,
        uint256 creatorBps
    ) public pure returns (CultureIndex.CreatorBps[] memory) { // <-- Change visibility and mutability as needed
        ICultureIndex.CreatorBps[]
            memory creators = new ICultureIndex.CreatorBps[](1);
        creators[0] = ICultureIndex.CreatorBps({
            creator: creatorAddress,
            bps: creatorBps
        });

        return creators;
    }

    //returns metadata and creators in a tuple
    function createArtPieceTuple(
        string memory name,
        string memory description,
        ICultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl,
        address creatorAddress,
        uint256 creatorBps
    ) public pure returns (CultureIndex.ArtPieceMetadata memory, ICultureIndex.CreatorBps[] memory) { // <-- Change here
        ICultureIndex.ArtPieceMetadata memory metadata = createArtPieceMetadata(
            name,
            description,
            mediaType,
            image,
            text,
            animationUrl
        );

        ICultureIndex.CreatorBps[] memory creators = createArtPieceCreators(
            creatorAddress,
            creatorBps
        );

        return (metadata, creators);
    }


    function createArtPiece(
        string memory name,
        string memory description,
        ICultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl,
        address creatorAddress,
        uint256 creatorBps
    ) public returns (uint256) { // <-- Change here
        //use createArtPieceTuple to create metadata and creators
        (CultureIndex.ArtPieceMetadata memory metadata, ICultureIndex.CreatorBps[] memory creators) = createArtPieceTuple(
            name,
            description,
            mediaType,
            image,
            text,
            animationUrl,
            creatorAddress,
            creatorBps
        );

        return cultureIndex.createPiece(metadata, creators);
    }

   function testVoteAndVerifyTopVotedPiece() public {
        setUp();

        uint256 firstPieceId = voter1Test.createDefaultArtPiece();
        uint256 secondPieceId = voter2Test.createDefaultArtPiece();
        uint256 thirdPieceId = voter2Test.createDefaultArtPiece();

        // Mint tokens to the test contracts (acting as voters)
        mockVotingToken._mint(address(voter1Test), 100);
        mockVotingToken._mint(address(voter2Test), 200);

        // Vote for the first piece with voter1
        voter1Test.voteForPiece(firstPieceId);
        assertEq(cultureIndex.topVotedPieceId(), firstPieceId, "First piece should be top-voted");

        // Vote for the second piece with voter2
        voter2Test.voteForPiece(secondPieceId);
        assertEq(cultureIndex.topVotedPieceId(), secondPieceId, "Second piece should now be top-voted");

        // Vote for the first piece with voter2
        voter2Test.voteForPiece(firstPieceId);
        assertEq(cultureIndex.topVotedPieceId(), firstPieceId, "First piece should now be top-voted again");

        mockVotingToken._mint(address(voter2Test), 21_000);
        voter2Test.voteForPiece(thirdPieceId);
        assertEq(cultureIndex.topVotedPieceId(), thirdPieceId, "Third piece should now be top-voted");

    }

    function testFetchTopVotedPiece() public {
        setUp();

        uint256 firstPieceId = voter1Test.createDefaultArtPiece();

        // Mint tokens to voter1
        mockVotingToken._mint(address(voter1Test), 100);

        // Vote for the first piece
        voter1Test.voteForPiece(firstPieceId);

        ICultureIndex.ArtPiece memory topVotedPiece = cultureIndex.getTopVotedPiece();
        assertEq(topVotedPiece.pieceId, firstPieceId, "Top voted piece should match the voted piece");
    }

    function testCorrectTopVotedPiece() public {
        setUp();

        uint256 firstPieceId = voter1Test.createDefaultArtPiece();
        uint256 secondPieceId = voter2Test.createDefaultArtPiece();

        // Mint tokens to the test contracts (acting as voters)
        mockVotingToken._mint(address(voter1Test), 100);
        mockVotingToken._mint(address(voter2Test), 200);

        // Vote for the first piece with voter1
        voter1Test.voteForPiece(firstPieceId);

        // Vote for the second piece with voter2
        voter2Test.voteForPiece(secondPieceId);

        ICultureIndex.ArtPiece memory poppedPiece = cultureIndex.getTopVotedPiece();
        assertEq(poppedPiece.pieceId, secondPieceId, "Top voted piece should be the second piece");
    }

    function testPopTopVotedPiece() public {
        setUp();

        uint256 firstPieceId = voter1Test.createDefaultArtPiece();
        mockVotingToken._mint(address(voter1Test), 100);
        voter1Test.voteForPiece(firstPieceId);

        ICultureIndex.ArtPiece memory poppedPiece = cultureIndex.dropTopVotedPiece();
        assertEq(poppedPiece.pieceId, firstPieceId, "Popped piece should be the first piece");
    }

    function testRemovedPieceShouldBeReplaced() public {
        setUp();

        uint256 firstPieceId = voter1Test.createDefaultArtPiece();
        uint256 secondPieceId = voter2Test.createDefaultArtPiece();

        mockVotingToken._mint(address(voter1Test), 100);
        mockVotingToken._mint(address(voter2Test), 200);

        voter1Test.voteForPiece(firstPieceId);
        voter2Test.voteForPiece(secondPieceId);

        ICultureIndex.ArtPiece memory poppedPiece = cultureIndex.dropTopVotedPiece();
        //assert its the second piece
        assertEq(poppedPiece.pieceId, secondPieceId, "Popped piece should be the second piece");

        uint256 topPieceId = cultureIndex.topVotedPieceId();
        assertEq(topPieceId, firstPieceId, "Top voted piece should be the first piece");
    }


    /// @dev Tests that log gas required to vote on a piece isn't out of control as heap grows
    function testGasForLargeVotes() public {
        setUp();

        // Insert a large number of items
        for (uint i = 0; i < 5_000; i++) {
            voter1Test.createDefaultArtPiece();
        }

        mockVotingToken._mint(address(voter1Test), 100);
        mockVotingToken._mint(address(voter2Test), 200);

        //vote on all pieces
        for (uint i = 2; i < 5_000; i++) {
            voter1Test.voteForPiece(i+1);
            voter2Test.voteForPiece(i+1);
        }

        //vote once and calculate gas used
        uint256 startGas = gasleft();
        voter1Test.voteForPiece(1);
        uint256 gasUsed = startGas - gasleft();
        emit log_uint(gasUsed);

        // Insert a large number of items
        for (uint i = 0; i < 20_000; i++) {
            voter1Test.createDefaultArtPiece();
        }

        mockVotingToken._mint(address(voter1Test), 100);
        mockVotingToken._mint(address(voter2Test), 200);

        //vote on all pieces
        for (uint i = 5_002; i < 25_000; i++) {
            voter1Test.voteForPiece(i+1);
            mockVotingToken._mint(address(voter1Test), i);
            mockVotingToken._mint(address(voter2Test), i*2);
            voter2Test.voteForPiece(i+1);
        }

        //vote once and calculate gas used
        startGas = gasleft();
        voter1Test.voteForPiece(5_001);
        uint256 gasUsed2 = startGas - gasleft();
        emit log_uint(gasUsed2);

        //make sure gas used isn't more than double
        assertLt(gasUsed2, 2 * gasUsed, "Gas used should not be more than 100% increase");
    }

    /// @dev Tests the gas used for creating art pieces as the number of items grows.
    function testGasForCreatingArtPieces() public {
        setUp();

        //log gas used for creating the first piece
        uint256 startGas = gasleft();
        voter1Test.createDefaultArtPiece();
        uint256 gasUsed = startGas - gasleft();
        emit log_uint(gasUsed);


        // Create a set number of pieces and log the gas used for the last creation.
        for (uint i = 0; i < 5_000; i++) {
            if (i == 4_999) {
                startGas = gasleft();
                voter1Test.createDefaultArtPiece();
                gasUsed = startGas - gasleft();
                emit log_uint(gasUsed);
            } else {
                voter1Test.createDefaultArtPiece();
            }
        }

        //vote on all pieces
        for (uint i = 0; i < 5_000; i++) {
            mockVotingToken._mint(address(voter1Test), i+1);
            voter1Test.voteForPiece(i+1);
        }

        // Create another set of pieces and log the gas used for the last creation.
        for (uint i = 0; i < 25_000; i++) {
            if (i == 24_999) {
                startGas = gasleft();
                voter1Test.createDefaultArtPiece();
                gasUsed = startGas - gasleft();
                emit log_uint(gasUsed);
            } else {
                voter1Test.createDefaultArtPiece();
            }
        }

        //assert dropping top piece is the correct pieceId
        assertEq(cultureIndex.topVotedPieceId(), 5_000, "Top voted piece should be the 5_000th piece");
    }

    /// @dev Tests the gas used for popping the top voted piece to ensure somewhat constant time
    function testGasForPopTopVotedPiece() public {
        setUp();

        // Create and vote on a set number of pieces.
        for (uint i = 0; i < 5_000; i++) {
            uint256 pieceId = voter1Test.createDefaultArtPiece();
            mockVotingToken._mint(address(voter1Test), i*2 + 1);
            voter1Test.voteForPiece(pieceId);
        }

        // Pop the top voted piece and log the gas used.
        uint256 startGas = gasleft();
        cultureIndex.dropTopVotedPiece();
        uint256 gasUsed = startGas - gasleft();
        emit log_uint(gasUsed);

        // Create and vote on another set of pieces.
        for (uint i = 0; i < 25_000; i++) {
            uint256 pieceId = voter1Test.createDefaultArtPiece();
            mockVotingToken._mint(address(voter1Test), i*3 + 1);
            voter1Test.voteForPiece(pieceId);
        }

        // Pop the top voted piece and log the gas used.
        startGas = gasleft();
        cultureIndex.dropTopVotedPiece();
        uint256 gasUsed2 = startGas - gasleft();
        emit log_uint(gasUsed2);

        assertLt(gasUsed2, gasUsed * 2, "Should not be more than double the gas");
    }

    function testDropTopVotedPieceSequentialOrder() public {
        setUp();

        // Create some pieces and vote on them
        uint256 pieceId1 = voter1Test.createDefaultArtPiece();
        mockVotingToken._mint(address(voter1Test), 10);
        voter1Test.voteForPiece(pieceId1);

        uint256 pieceId2 = voter1Test.createDefaultArtPiece();
        mockVotingToken._mint(address(voter1Test), 20);
        voter1Test.voteForPiece(pieceId2);

        // Drop the top voted piece
        ICultureIndex.ArtPiece memory artPiece2 = cultureIndex.dropTopVotedPiece();
        
        // Verify that the dropped piece is correctly indexed
        assertEq(artPiece2.pieceId, pieceId2, "First dropped piece should be pieceId2");

        // Drop another top voted piece
        ICultureIndex.ArtPiece memory artPiece1 = cultureIndex.dropTopVotedPiece();
        
        // Verify again
        assertEq(artPiece1.pieceId, pieceId1, "Second dropped piece should be pieceId1");
    }


    /// @dev Ensure that the dropTopVotedPiece function behaves correctly when there are no more pieces to drop
    function testDropTopVotedPieceWithNoMorePieces() public {
        setUp();

        // Create and vote on a single piece
        uint256 pieceId = voter1Test.createDefaultArtPiece();
        mockVotingToken._mint(address(voter1Test), 10);
        voter1Test.voteForPiece(pieceId);

        // Drop the top voted piece
        cultureIndex.dropTopVotedPiece();

        // Try to drop again and expect a failure
        bool hasErrorOccurred = false;
        try cultureIndex.dropTopVotedPiece() {
            // if this executes, there was no error
        } catch {
            // if we're here, an error occurred
            hasErrorOccurred = true;
        }
        assertEq(hasErrorOccurred,true, "Expected an error when trying to drop with no more pieces.");
    }


}
