// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {CultureIndex} from "../packages/revolution-contracts/CultureIndex.sol";
import {MockERC20} from "./MockERC20.sol";
import {CultureIndexVotingTest} from "./CultureIndex.Voting.t.sol";

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
        cultureIndex = new CultureIndex(address(mockVotingToken));

        // Create new test instances acting as different voters
        voter1Test = new CultureIndexVotingTest(address(cultureIndex), address(mockVotingToken));
        voter2Test = new CultureIndexVotingTest(address(cultureIndex), address(mockVotingToken));
    }

    // Function to create ArtPieceMetadata
    function createArtPieceMetadata(
        string memory name,
        string memory description,
        CultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl
    ) public pure returns (CultureIndex.ArtPieceMetadata memory) { // <-- Change visibility and mutability as needed
        CultureIndex.ArtPieceMetadata memory metadata = CultureIndex
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
        CultureIndex.CreatorBps[]
            memory creators = new CultureIndex.CreatorBps[](1);
        creators[0] = CultureIndex.CreatorBps({
            creator: creatorAddress,
            bps: creatorBps
        });

        return creators;
    }

    //returns metadata and creators in a tuple
    function createArtPieceTuple(
        string memory name,
        string memory description,
        CultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl,
        address creatorAddress,
        uint256 creatorBps
    ) public pure returns (CultureIndex.ArtPieceMetadata memory, CultureIndex.CreatorBps[] memory) { // <-- Change here
        CultureIndex.ArtPieceMetadata memory metadata = createArtPieceMetadata(
            name,
            description,
            mediaType,
            image,
            text,
            animationUrl
        );

        CultureIndex.CreatorBps[] memory creators = createArtPieceCreators(
            creatorAddress,
            creatorBps
        );

        return (metadata, creators);
    }


    function createArtPiece(
        string memory name,
        string memory description,
        CultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl,
        address creatorAddress,
        uint256 creatorBps
    ) public returns (uint256) { // <-- Change here
        //use createArtPieceTuple to create metadata and creators
        (CultureIndex.ArtPieceMetadata memory metadata, CultureIndex.CreatorBps[] memory creators) = createArtPieceTuple(
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

        CultureIndex.ArtPiece memory topVotedPiece = cultureIndex.getTopVotedPiece();
        assertEq(topVotedPiece.id, firstPieceId, "Top voted piece should match the voted piece");
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

        CultureIndex.ArtPiece memory poppedPiece = cultureIndex.getTopVotedPiece();
        assertEq(poppedPiece.id, secondPieceId, "Top voted piece should be the second piece");
    }

    function testPopTopVotedPiece() public {
        setUp();

        uint256 firstPieceId = voter1Test.createDefaultArtPiece();
        mockVotingToken._mint(address(voter1Test), 100);
        voter1Test.voteForPiece(firstPieceId);

        CultureIndex.ArtPiece memory poppedPiece = cultureIndex.popTopVotedPiece();
        assertEq(poppedPiece.id, firstPieceId, "Popped piece should be the first piece");
    }

    function testRemovedPieceShouldBeReplaced() public {
        setUp();

        uint256 firstPieceId = voter1Test.createDefaultArtPiece();
        uint256 secondPieceId = voter2Test.createDefaultArtPiece();

        mockVotingToken._mint(address(voter1Test), 100);
        mockVotingToken._mint(address(voter2Test), 200);

        voter1Test.voteForPiece(firstPieceId);
        voter2Test.voteForPiece(secondPieceId);

        CultureIndex.ArtPiece memory poppedPiece = cultureIndex.popTopVotedPiece();
        //assert its the second piece
        assertEq(poppedPiece.id, secondPieceId, "Popped piece should be the second piece");
       
        // Trying to vote for a removed piece
        try
            voter1Test.voteForPiece(secondPieceId)
        {
            fail("Should not be able to vote for a removed piece");
        } catch Error(string memory reason) {
            assertEq(reason, "Dropped piece can not be voted on");
        }

        uint256 topPieceId = cultureIndex.topVotedPieceId();
        assertEq(topPieceId, firstPieceId, "Top voted piece should be the first piece");
    }


    /// @dev Tests that log gas
    function testGasForLargeVotes() public {
        setUp();

        // Insert a large number of items
        for (uint i = 0; i < 50000; i++) {
            voter1Test.createDefaultArtPiece();
        }

        mockVotingToken._mint(address(voter1Test), 100);
        mockVotingToken._mint(address(voter2Test), 200);

        //vote on all pieces
        for (uint i = 2; i < 50000; i++) {
            voter1Test.voteForPiece(i+1);
            voter2Test.voteForPiece(i+1);
        }

        //vote once and calculate gas used
        uint256 startGas = gasleft();
        voter1Test.voteForPiece(1);
        uint256 gasUsed = startGas - gasleft();
        emit log_uint(gasUsed);

        // Insert a large number of items
        for (uint i = 0; i < 50000; i++) {
            voter1Test.createDefaultArtPiece();
        }

        mockVotingToken._mint(address(voter1Test), 100);
        mockVotingToken._mint(address(voter2Test), 200);

        //vote on all pieces
        for (uint i = 50_002; i < 100_000; i++) {
            voter1Test.voteForPiece(i+1);
            mockVotingToken._mint(address(voter1Test), i);
            voter2Test.voteForPiece(i+1);
        }

        //vote once and calculate gas used
        startGas = gasleft();
        voter1Test.voteForPiece(50_001);
        gasUsed = startGas - gasleft();
        emit log_uint(gasUsed);
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
        for (uint i = 0; i < 50_000; i++) {
            if (i == 49_999) {
                startGas = gasleft();
                voter1Test.createDefaultArtPiece();
                gasUsed = startGas - gasleft();
                emit log_uint(gasUsed);
            } else {
                voter1Test.createDefaultArtPiece();
            }
        }

        // Create another set of pieces and log the gas used for the last creation.
        for (uint i = 0; i < 250_000; i++) {
            if (i == 249_999) {
                startGas = gasleft();
                voter1Test.createDefaultArtPiece();
                gasUsed = startGas - gasleft();
                emit log_uint(gasUsed);
            } else {
                voter1Test.createDefaultArtPiece();
            }
        }
    }

    /// @dev Tests the gas used for popping the top voted piece to ensure constant time operation.
    function testGasForPopTopVotedPiece() public {
        setUp();

        // Create and vote on a set number of pieces.
        for (uint i = 0; i < 50_000; i++) {
            uint256 pieceId = voter1Test.createDefaultArtPiece();
            mockVotingToken._mint(address(voter1Test), i*2);
            voter1Test.voteForPiece(pieceId);
        }

        // Pop the top voted piece and log the gas used.
        uint256 startGas = gasleft();
        cultureIndex.popTopVotedPiece();
        uint256 gasUsed = startGas - gasleft();
        emit log_uint(gasUsed);

        // Create and vote on another set of pieces.
        for (uint i = 0; i < 250_000; i++) {
            uint256 pieceId = voter1Test.createDefaultArtPiece();
            mockVotingToken._mint(address(voter1Test), i*3);
            voter1Test.voteForPiece(pieceId);
        }

        // Pop the top voted piece and log the gas used.
        startGas = gasleft();
        cultureIndex.popTopVotedPiece();
        gasUsed = startGas - gasleft();
        emit log_uint(gasUsed);
    }


}
