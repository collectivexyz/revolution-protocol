// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { Test } from "forge-std/Test.sol";

import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { IContestBuilder } from "../../src/culture-index/contests/IContestBuilder.sol";
import { IBaseContest } from "../../src/culture-index/contests/IBaseContest.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { BaseContest } from "../../src/culture-index/contests/BaseContest.sol";
import { ContestBuilder } from "../../src/culture-index/contests/ContestBuilder.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { MaxHeap } from "../../src/culture-index/MaxHeap.sol";
import { ISplitMain } from "@cobuild/splits/src/interfaces/ISplitMain.sol";

import { MockERC721 } from "../mock/MockERC721.sol";
import { MockERC1155 } from "../mock/MockERC1155.sol";
import { MockWETH } from "../mock/MockWETH.sol";

contract ContestBuilderTest is RevolutionBuilderTest {
    ///                                                          ///
    ///                          BASE SETUP                      ///
    ///                                                          ///

    IContestBuilder internal contestBuilder;

    address internal builderImpl0;
    address internal builderImpl;
    address internal baseContestImpl;
    address internal contest_CultureIndexImpl;
    address internal contest_MaxHeapImpl;

    function setUp() public virtual override {
        super.setUp();

        super.setMockParams();

        super.setCultureIndexParams(
            "Vrbs",
            "Our community Vrbs. Must be 32x32.",
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
        super.deployMock();

        builderImpl0 = address(
            new ContestBuilder(
                address(0),
                IContestBuilder.CultureIndexImplementations({ cultureIndex: address(0), maxHeap: address(0) })
            )
        );
        contestBuilder = ContestBuilder(
            address(new ERC1967Proxy(builderImpl0, abi.encodeWithSignature("initialize(address)", revolutionDAO)))
        );

        baseContestImpl = address(new BaseContest(address(contestBuilder), protocolRewards, revolutionDAO));
        contest_CultureIndexImpl = address(new CultureIndex(address(contestBuilder)));
        contest_MaxHeapImpl = address(new MaxHeap(address(contestBuilder)));

        builderImpl = address(
            new ContestBuilder(
                baseContestImpl,
                IContestBuilder.CultureIndexImplementations({
                    cultureIndex: contest_CultureIndexImpl,
                    maxHeap: contest_MaxHeapImpl
                })
            )
        );

        vm.prank(revolutionDAO);
        contestBuilder.upgradeTo(builderImpl);
    }

    IBaseContest.BaseContestParams internal baseContestParams;
    IRevolutionBuilder.CultureIndexParams internal contest_CultureIndexParams;

    function setMockContestCultureIndexParams() internal virtual {
        setContestCultureIndexParams(
            "Vrbs",
            "Our community Vrbs.",
            "- [ ] Must be 32x32. - [ ] Must include the noggles.",
            "ipfs://",
            100 * 1e18,
            1,
            1000,
            0,
            0,
            ICultureIndex.PieceMaximums({ name: 100, description: 2100, image: 64_000, text: 256, animationUrl: 100 }),
            ICultureIndex.MediaType.NONE,
            ICultureIndex.RequiredMediaPrefix.MIXED
        );
    }

    function setContestCultureIndexParams(
        string memory _name,
        string memory _description,
        string memory _checklist,
        string memory _template,
        uint256 _tokenVoteWeight,
        uint256 _pointsVoteWeight,
        uint256 _quorumVotesBPS,
        uint256 _minVotingPowerToVote,
        uint256 _minVotingPowerToCreate,
        ICultureIndex.PieceMaximums memory _pieceMaximums,
        ICultureIndex.MediaType _requiredMediaType,
        ICultureIndex.RequiredMediaPrefix _requiredMediaPrefix
    ) internal virtual {
        contest_CultureIndexParams = IRevolutionBuilder.CultureIndexParams({
            name: _name,
            description: _description,
            checklist: _checklist,
            template: _template,
            tokenVoteWeight: _tokenVoteWeight,
            pointsVoteWeight: _pointsVoteWeight,
            quorumVotesBPS: _quorumVotesBPS,
            minVotingPowerToVote: _minVotingPowerToVote,
            minVotingPowerToCreate: _minVotingPowerToCreate,
            pieceMaximums: _pieceMaximums,
            requiredMediaType: _requiredMediaType,
            requiredMediaPrefix: _requiredMediaPrefix
        });
    }

    function setMockBaseContestParams() internal virtual {
        uint256[] memory payoutSplits = new uint256[](1);
        payoutSplits[0] = 1e6;
        baseContestParams = IBaseContest.BaseContestParams({
            entropyRate: 100,
            // 1 week
            endTime: block.timestamp + 60 * 60 * 24 * 7,
            payoutSplits: payoutSplits
        });
    }

    function setBaseContestParams(
        uint256 _entropyRate,
        uint256 _endTime,
        uint256[] memory _payoutSplits
    ) internal virtual {
        baseContestParams = IBaseContest.BaseContestParams({
            entropyRate: _entropyRate,
            endTime: _endTime,
            payoutSplits: _payoutSplits
        });
    }

    BaseContest internal baseContest;
    CultureIndex internal contest_CultureIndex;

    function setMockContestParams() internal virtual {
        setMockContestCultureIndexParams();
        setMockBaseContestParams();
    }

    function deployContestMock() internal virtual {
        deployContest(
            founder,
            weth,
            address(revolutionVotingPower),
            address(splitMain),
            cultureIndexParams,
            baseContestParams
        );
    }

    function deployContest(
        address _initialOwner,
        address _weth,
        address _votingPower,
        address _splitMain,
        IRevolutionBuilder.CultureIndexParams memory _cultureIndexParams,
        IBaseContest.BaseContestParams memory _baseContestParams
    ) internal virtual {
        (address baseContestAddr, , ) = contestBuilder.deployBaseContest(
            _initialOwner,
            _weth,
            _votingPower,
            _splitMain,
            founder,
            _cultureIndexParams,
            _baseContestParams
        );

        baseContest = BaseContest(baseContestAddr);
        contest_CultureIndex = CultureIndex(address(baseContest.cultureIndex()));

        vm.label(address(baseContest), "BASE_CONTEST");
    }

    // Utility function to create a new art piece and return its ID
    function createContestSubmission(
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

        return
            createContestSubmissionMultiCreator(
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

    // Utility function to create a new art piece with multiple creators and return its ID
    function createContestSubmissionMultiCreator(
        string memory name,
        string memory description,
        ICultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl,
        address[] memory creatorAddresses,
        uint256[] memory creatorBps
    ) internal returns (uint256) {
        ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex.ArtPieceMetadata({
            name: name,
            description: description,
            mediaType: mediaType,
            image: image,
            text: text,
            animationUrl: animationUrl
        });

        ICultureIndex.CreatorBps[] memory creators = new ICultureIndex.CreatorBps[](creatorAddresses.length);
        for (uint256 i = 0; i < creatorAddresses.length; i++) {
            creators[i] = ICultureIndex.CreatorBps({ creator: creatorAddresses[i], bps: creatorBps[i] });
        }

        return contest_CultureIndex.createPiece(metadata, creators);
    }

    //Utility function to create default art piece
    function createDefaultSubmission() public returns (uint256) {
        return
            createContestSubmission(
                "Vrbs Legend",
                "A vrbish masterpiece",
                ICultureIndex.MediaType.IMAGE,
                "ipfs://vrbs",
                "",
                "",
                address(0x1),
                10000
            );
    }

    function createThreeSubmissions() public {
        createDefaultSubmission();
        createContestSubmission(
            "Second Submission",
            "Second masterpiece",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://second",
            "",
            "",
            address(0x2),
            10000
        );
        createContestSubmission(
            "Third Submission",
            "Third masterpiece",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://third",
            "",
            "",
            address(0x3),
            10000
        );
    }

    function setupBasicSplit()
        internal
        returns (
            address[] memory accounts,
            uint32[] memory percentAllocations,
            uint32 distributorFee,
            address controller,
            uint32[] memory pointsAllocations,
            ISplitMain.PointsData memory pointsData
        )
    {
        accounts = new address[](1);
        address recipient = payable(address(0x3));
        accounts[0] = recipient;

        percentAllocations = new uint32[](1);
        percentAllocations[0] = uint32(1e6);

        distributorFee = 0;
        controller = address(0);

        pointsAllocations = new uint32[](1);
        pointsAllocations[0] = 1e6;

        pointsData = ISplitMain.PointsData({
            pointsPercent: 1e6 / 2,
            accounts: accounts,
            percentAllocations: pointsAllocations
        });

        return (accounts, percentAllocations, distributorFee, controller, pointsAllocations, pointsData);
    }
}
