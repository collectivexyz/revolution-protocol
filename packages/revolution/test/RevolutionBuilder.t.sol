// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";

import { SplitMain } from "@cobuild/splits/src/SplitMain.sol";

import { IRevolutionBuilder } from "../src/interfaces/IRevolutionBuilder.sol";
import { RevolutionBuilder } from "../src/builder/RevolutionBuilder.sol";
import { RevolutionToken, IRevolutionToken } from "../src/RevolutionToken.sol";
import { Descriptor } from "../src/Descriptor.sol";
import { IAuctionHouse, AuctionHouse } from "../src/AuctionHouse.sol";
import { RevolutionDAOLogicV1 } from "../src/governance/RevolutionDAOLogicV1.sol";
import { DAOExecutor } from "../src/governance/DAOExecutor.sol";
import { CultureIndex } from "../src/culture-index/CultureIndex.sol";
import { ICultureIndex } from "../src/interfaces/ICultureIndex.sol";
import { RevolutionPoints } from "../src/RevolutionPoints.sol";
import { RevolutionVotingPower } from "../src/RevolutionVotingPower.sol";
import { RevolutionPointsEmitter } from "../src/RevolutionPointsEmitter.sol";
import { MaxHeap } from "../src/culture-index/MaxHeap.sol";
import { RevolutionDAOStorageV1 } from "../src/governance/RevolutionDAOInterfaces.sol";
import { ProtocolRewards } from "@cobuild/protocol-rewards/src/ProtocolRewards.sol";
import { RevolutionBuilderTypesV1 } from "../src/builder/types/RevolutionBuilderTypesV1.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";

import { MockERC721 } from "./mock/MockERC721.sol";
import { MockERC1155 } from "./mock/MockERC1155.sol";
import { MockWETH } from "./mock/MockWETH.sol";
import { VRGDAC } from "../src/libs/VRGDAC.sol";

contract RevolutionBuilderTest is Test {
    ///                                                          ///
    ///                          BASE SETUP                      ///
    ///                                                          ///

    IRevolutionBuilder internal manager;

    address internal managerImpl0;
    address internal managerImpl;
    address internal revolutionTokenImpl;
    address internal descriptorImpl;
    address internal auctionImpl;
    address internal executorImpl;
    address internal daoImpl;
    address internal revolutionPointsImpl;
    address internal revolutionPointsEmitterImpl;
    address internal cultureIndexImpl;
    address internal maxHeapImpl;
    address internal revolutionVotingPowerImpl;
    address internal vrgdaImpl;
    address internal splitsCreatorImpl;

    address internal nounsDAO;
    address internal revolutionDAO;
    address internal creatorsAddress;
    address internal founder;
    address internal founder2;
    address internal grantsAddress;
    address internal weth;
    address internal protocolRewards;

    MockERC721 internal mock721;
    MockERC1155 internal mock1155;

    function setUp() public virtual {
        weth = address(new MockWETH());

        mock721 = new MockERC721();
        mock1155 = new MockERC1155();

        nounsDAO = vm.addr(0xA11CE);
        revolutionDAO = vm.addr(0xB0B);

        protocolRewards = address(new ProtocolRewards());

        founder = vm.addr(0xCAB);
        founder2 = vm.addr(0xDAD);
        grantsAddress = vm.addr(0xBAE);

        creatorsAddress = vm.addr(0xCAFEBABE);

        vm.label(revolutionDAO, "REVOLUTION_DAO");
        vm.label(nounsDAO, "NOUNS_DAO");

        vm.label(founder, "FOUNDER");
        vm.label(founder2, "FOUNDER_2");

        managerImpl0 = address(
            new RevolutionBuilder(
                IRevolutionBuilder.PointsImplementations({
                    revolutionPointsEmitter: address(0),
                    revolutionPoints: address(0),
                    splitsCreator: address(0),
                    vrgda: address(0)
                }),
                IRevolutionBuilder.TokenImplementations({
                    revolutionToken: address(0),
                    descriptor: address(0),
                    auction: address(0)
                }),
                IRevolutionBuilder.DAOImplementations({
                    revolutionVotingPower: address(0),
                    executor: address(0),
                    dao: address(0)
                }),
                IRevolutionBuilder.CultureIndexImplementations({ cultureIndex: address(0), maxHeap: address(0) })
            )
        );
        manager = RevolutionBuilder(
            address(new ERC1967Proxy(managerImpl0, abi.encodeWithSignature("initialize(address)", revolutionDAO)))
        );

        revolutionTokenImpl = address(new RevolutionToken(address(manager)));
        descriptorImpl = address(new Descriptor(address(manager)));
        auctionImpl = address(new AuctionHouse(address(manager), address(protocolRewards), revolutionDAO));
        executorImpl = address(new DAOExecutor(address(manager)));
        daoImpl = address(new RevolutionDAOLogicV1(address(manager)));
        revolutionPointsImpl = address(new RevolutionPoints(address(manager)));
        revolutionPointsEmitterImpl = address(
            new RevolutionPointsEmitter(address(manager), address(protocolRewards), revolutionDAO)
        );
        cultureIndexImpl = address(new CultureIndex(address(manager)));
        maxHeapImpl = address(new MaxHeap(address(manager)));
        revolutionVotingPowerImpl = address(new RevolutionVotingPower(address(manager)));
        vrgdaImpl = address(new VRGDAC(address(manager)));
        splitsCreatorImpl = address(new SplitMain(address(manager)));

        managerImpl = address(
            new RevolutionBuilder(
                IRevolutionBuilder.PointsImplementations({
                    revolutionPoints: revolutionPointsImpl,
                    revolutionPointsEmitter: revolutionPointsEmitterImpl,
                    vrgda: vrgdaImpl,
                    splitsCreator: splitsCreatorImpl
                }),
                IRevolutionBuilder.TokenImplementations({
                    revolutionToken: revolutionTokenImpl,
                    descriptor: descriptorImpl,
                    auction: auctionImpl
                }),
                IRevolutionBuilder.DAOImplementations({
                    revolutionVotingPower: revolutionVotingPowerImpl,
                    executor: executorImpl,
                    dao: daoImpl
                }),
                IRevolutionBuilder.CultureIndexImplementations({ cultureIndex: cultureIndexImpl, maxHeap: maxHeapImpl })
            )
        );

        vm.prank(revolutionDAO);
        manager.upgradeTo(managerImpl);
    }

    ///                                                          ///
    ///                     DAO CUSTOMIZATION UTILS              ///
    ///                                                          ///

    IRevolutionBuilder.RevolutionTokenParams internal revolutionTokenParams;
    IRevolutionBuilder.AuctionParams internal auctionParams;
    IRevolutionBuilder.GovParams internal govParams;
    IRevolutionBuilder.CultureIndexParams internal cultureIndexParams;
    IRevolutionBuilder.RevolutionPointsParams internal revolutionPointsParams;
    IRevolutionBuilder.RevolutionVotingPowerParams internal revolutionVotingPowerParams;

    function setMockRevolutionTokenParams() internal virtual {
        setRevolutionTokenParams("Mock Token", "MOCK", "Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j", "Mock");
    }

    function setRevolutionTokenParams(
        string memory _name,
        string memory _symbol,
        string memory _contractURI,
        string memory _tokenNamePrefix
    ) internal virtual {
        revolutionTokenParams = IRevolutionBuilder.RevolutionTokenParams({
            name: _name,
            symbol: _symbol,
            contractURIHash: _contractURI,
            tokenNamePrefix: _tokenNamePrefix
        });
    }

    function setMockRevolutionVotingPowerParams() internal virtual {
        setRevolutionVotingPowerParams(1000, 1);
    }

    function setRevolutionVotingPowerParams(uint256 _tokenVoteWeight, uint256 _pointsVoteWeight) internal virtual {
        revolutionVotingPowerParams = IRevolutionBuilder.RevolutionVotingPowerParams({
            tokenVoteWeight: _tokenVoteWeight,
            pointsVoteWeight: _pointsVoteWeight
        });
    }

    function setMockAuctionParams() internal virtual {
        setAuctionParams(
            15 minutes,
            1 ether,
            24 hours,
            5,
            1000,
            1000,
            1000,
            IRevolutionBuilder.GrantsParams({ totalRateBps: 1000, grantsAddress: grantsAddress })
        );
    }

    function setAuctionParams(
        uint256 _timeBuffer,
        uint256 _reservePrice,
        uint256 _duration,
        uint8 _minBidIncrementPercentage,
        uint256 _creatorRateBps,
        uint256 _entropyRateBps,
        uint256 _minCreatorRateBps,
        IRevolutionBuilder.GrantsParams memory _grantsParams
    ) internal virtual {
        auctionParams = IRevolutionBuilder.AuctionParams({
            timeBuffer: _timeBuffer,
            reservePrice: _reservePrice,
            duration: _duration,
            minBidIncrementPercentage: _minBidIncrementPercentage,
            creatorRateBps: _creatorRateBps,
            entropyRateBps: _entropyRateBps,
            minCreatorRateBps: _minCreatorRateBps,
            grantsParams: _grantsParams
        });
    }

    function setMockGovParams() internal virtual {
        setGovParams(
            2 days,
            1 seconds,
            1 weeks,
            50,
            founder,
            1000,
            1000,
            1000,
            "Vrbs DAO",
            "To do good for the public and posterity",
            unicode"⌐◨-◨"
        );
    }

    function setGovParams(
        uint256 _timelockDelay,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThresholdBPS,
        address _vetoer,
        uint16 _minQuorumVotesBPS,
        uint16 _maxQuorumVotesBPS,
        uint16 _quorumCoefficient,
        string memory _daoName,
        string memory _daoPurpose,
        string memory _daoFlag
    ) internal virtual {
        govParams = IRevolutionBuilder.GovParams({
            timelockDelay: _timelockDelay,
            votingDelay: _votingDelay,
            votingPeriod: _votingPeriod,
            proposalThresholdBPS: _proposalThresholdBPS,
            vetoer: _vetoer,
            dynamicQuorumParams: RevolutionDAOStorageV1.DynamicQuorumParams({
                minQuorumVotesBPS: _minQuorumVotesBPS,
                maxQuorumVotesBPS: _maxQuorumVotesBPS,
                quorumCoefficient: _quorumCoefficient
            }),
            name: _daoName,
            purpose: _daoPurpose,
            flag: _daoFlag
        });
    }

    function setMockCultureIndexParams() internal virtual {
        setCultureIndexParams(
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

    function setCultureIndexParams(
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
        cultureIndexParams = IRevolutionBuilder.CultureIndexParams({
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

    function setMockPointsParams() internal virtual {
        setPointsParams("Mock Token", "MOCK");
    }

    function setPointsParams(string memory _name, string memory _symbol) internal virtual {
        revolutionPointsParams = revolutionPointsParams = IRevolutionBuilder.RevolutionPointsParams({
            emitterParams: revolutionPointsParams.emitterParams,
            tokenParams: IRevolutionBuilder.PointsTokenParams({ name: _name, symbol: _symbol })
        });
    }

    function setMockPointsEmitterParams() internal virtual {
        setPointsEmitterParams(
            1 ether,
            1e18 / 10,
            1_000 * 1e18,
            IRevolutionBuilder.FounderParams({
                totalRateBps: 1000,
                founderAddress: founder,
                rewardsExpirationDate: 1_800_000_000,
                entropyRateBps: 4_000
            }),
            //todo set back to 1000
            IRevolutionBuilder.GrantsParams({ totalRateBps: 0, grantsAddress: grantsAddress })
        );
    }

    function setPointsEmitterParams(
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _tokensPerTimeUnit,
        IRevolutionBuilder.FounderParams memory _founderParams,
        IRevolutionBuilder.GrantsParams memory _grantsParams
    ) internal virtual {
        revolutionPointsParams = IRevolutionBuilder.RevolutionPointsParams({
            tokenParams: revolutionPointsParams.tokenParams,
            emitterParams: IRevolutionBuilder.PointsEmitterParams({
                vrgdaParams: IRevolutionBuilder.VRGDAParams({
                    targetPrice: _targetPrice,
                    priceDecayPercent: _priceDecayPercent,
                    tokensPerTimeUnit: _tokensPerTimeUnit
                }),
                founderParams: _founderParams,
                grantsParams: _grantsParams
            })
        });
    }

    ///                                                          ///
    ///                       DAO DEPLOY UTILS                   ///
    ///                                                          ///

    RevolutionToken internal revolutionToken;
    Descriptor internal descriptor;
    AuctionHouse internal auction;
    DAOExecutor internal executor;
    RevolutionDAOLogicV1 internal dao;
    CultureIndex internal cultureIndex;
    RevolutionPoints internal revolutionPoints;
    RevolutionPointsEmitter internal revolutionPointsEmitter;
    MaxHeap internal maxHeap;
    RevolutionVotingPower internal revolutionVotingPower;
    SplitMain internal splitMain;

    function setMockParams() internal virtual {
        setMockRevolutionTokenParams();
        setMockAuctionParams();
        setMockGovParams();
        setMockCultureIndexParams();
        setMockPointsParams();
        setMockPointsEmitterParams();
        setMockRevolutionVotingPowerParams();
        setMockGrantsParams();
    }

    function deployMock() internal virtual {
        deploy(
            founder,
            weth,
            revolutionTokenParams,
            auctionParams,
            govParams,
            cultureIndexParams,
            revolutionPointsParams,
            revolutionVotingPowerParams
        );
    }

    function deploy(
        address _initialOwner,
        address _weth,
        IRevolutionBuilder.RevolutionTokenParams memory _RevolutionTokenParams,
        IRevolutionBuilder.AuctionParams memory _auctionParams,
        IRevolutionBuilder.GovParams memory _govParams,
        IRevolutionBuilder.CultureIndexParams memory _cultureIndexParams,
        IRevolutionBuilder.RevolutionPointsParams memory _pointsParams,
        IRevolutionBuilder.RevolutionVotingPowerParams memory _revolutionVotingPowerParams
    ) internal virtual {
        RevolutionBuilderTypesV1.DAOAddresses memory _addresses = manager.deploy(
            _initialOwner,
            _weth,
            _RevolutionTokenParams,
            _auctionParams,
            _govParams,
            _cultureIndexParams,
            _pointsParams,
            _revolutionVotingPowerParams
        );

        revolutionToken = RevolutionToken(_addresses.revolutionToken);
        descriptor = Descriptor(_addresses.descriptor);
        auction = AuctionHouse(_addresses.auction);
        executor = DAOExecutor(payable(_addresses.executor));
        dao = RevolutionDAOLogicV1(payable(_addresses.dao));
        cultureIndex = CultureIndex(_addresses.cultureIndex);
        revolutionPoints = RevolutionPoints(_addresses.revolutionPoints);
        revolutionPointsEmitter = RevolutionPointsEmitter(_addresses.revolutionPointsEmitter);
        maxHeap = MaxHeap(_addresses.maxHeap);
        revolutionVotingPower = RevolutionVotingPower(_addresses.revolutionVotingPower);
        splitMain = SplitMain(payable(_addresses.splitsCreator));

        // ensure the points is initialized before ops - might fail if another contract fails to initialize
        if (address(revolutionPoints) != address(0)) {
            emit log_address(revolutionPoints.owner());

            vm.startPrank(_initialOwner);
            // make minter of points the pointsEmitter
            revolutionPoints.setMinter(address(revolutionPointsEmitter));
            // transfer ownership of the points to the executor
            revolutionPoints.transferOwnership(address(executor));
            vm.stopPrank();
        }

        vm.label(address(revolutionToken), "ERC721TOKEN");
        vm.label(address(descriptor), "DESCRIPTOR");
        vm.label(address(auction), "AUCTION");
        vm.label(address(executor), "EXECUTOR");
        vm.label(address(dao), "DAO");
        vm.label(address(cultureIndex), "CULTURE_INDEX");
        vm.label(address(revolutionPoints), "Points");
        vm.label(address(revolutionPointsEmitter), "POINTS_EMITTER");
        vm.label(address(maxHeap), "MAX_HEAP");
        vm.label(address(revolutionVotingPower), "VOTING_POWER");
        vm.label(address(splitMain), "SPLIT_MAIN");
    }

    ///                                                          ///
    ///                           USER UTILS                     ///
    ///                                                          ///

    function createUser(uint256 _privateKey) internal virtual returns (address) {
        return vm.addr(_privateKey);
    }

    address[] internal otherUsers;

    function createUsers(uint256 _numUsers, uint256 _balance) internal virtual {
        otherUsers = new address[](_numUsers);

        unchecked {
            for (uint256 i; i < _numUsers; ++i) {
                address user = vm.addr(i + 1);

                vm.deal(user, _balance);

                otherUsers[i] = user;
            }
        }
    }

    function createTokens(uint256 _numTokens) internal {
        uint256 reservePrice = auction.reservePrice();
        uint256 duration = auction.duration();

        unchecked {
            for (uint256 i; i < _numTokens; ++i) {
                (uint256 tokenId, , , , , , ) = auction.auction();

                vm.prank(otherUsers[i]);
                auction.createBid{ value: reservePrice }(tokenId, otherUsers[i], address(0));

                vm.warp(block.timestamp + duration);

                auction.settleCurrentAndCreateNewAuction();
            }
        }
    }

    function createVoters(uint256 _numVoters, uint256 _balance) internal {
        createUsers(_numVoters, _balance);

        createTokens(_numVoters);
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

        return
            createArtPieceMultiCreator(
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
        return
            createArtPiece(
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

        return cultureIndex.createPiece(metadata, creators);
    }

    //function to create basic metadata
    function createDefaultMetadata() internal pure returns (ICultureIndex.ArtPieceMetadata memory) {
        return
            ICultureIndex.ArtPieceMetadata({
                name: "Mona Lisa",
                description: "A masterpiece",
                mediaType: ICultureIndex.MediaType.IMAGE,
                image: "ipfs://legends",
                text: "",
                animationUrl: ""
            });
    }

    // Function to create ArtPieceMetadata
    function createArtPieceMetadata(
        string memory name,
        string memory description,
        ICultureIndex.MediaType mediaType,
        string memory image,
        string memory text,
        string memory animationUrl
    ) public pure returns (CultureIndex.ArtPieceMetadata memory) {
        // <-- Change visibility and mutability as needed
        ICultureIndex.ArtPieceMetadata memory metadata = ICultureIndex.ArtPieceMetadata({
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
    ) public pure returns (CultureIndex.CreatorBps[] memory) {
        // <-- Change visibility and mutability as needed
        ICultureIndex.CreatorBps[] memory creators = new ICultureIndex.CreatorBps[](1);
        creators[0] = ICultureIndex.CreatorBps({ creator: creatorAddress, bps: creatorBps });
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
    ) public pure returns (CultureIndex.ArtPieceMetadata memory, ICultureIndex.CreatorBps[] memory) {
        // <-- Change here
        ICultureIndex.ArtPieceMetadata memory metadata = createArtPieceMetadata(
            name,
            description,
            mediaType,
            image,
            text,
            animationUrl
        );
        ICultureIndex.CreatorBps[] memory creators = createArtPieceCreators(creatorAddress, creatorBps);
        return (metadata, creators);
    }
}
