// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { Test } from "forge-std/Test.sol";

import { IRevolutionBuilder } from "../src/interfaces/IRevolutionBuilder.sol";
import { RevolutionBuilder } from "../src/builder/RevolutionBuilder.sol";
import { VerbsToken, IVerbsToken } from "../src/VerbsToken.sol";
import { VerbsDescriptor } from "../src/VerbsDescriptor.sol";
import { IVerbsAuctionHouse, VerbsAuctionHouse } from "../src/VerbsAuctionHouse.sol";
import { VerbsDAOLogicV1 } from "../src/governance/VerbsDAOLogicV1.sol";
import { VerbsDAOExecutor } from "../src/governance/VerbsDAOExecutor.sol";
import { CultureIndex } from "../src/CultureIndex.sol";
import { NontransferableERC20Votes } from "../src/NontransferableERC20Votes.sol";
import { TokenEmitter } from "../src/TokenEmitter.sol";

import { ERC1967Proxy } from "../src/libs/proxy/ERC1967Proxy.sol";
import { MockERC721 } from "./mock/MockERC721.sol";
import { MockERC1155 } from "./mock/MockERC1155.sol";
import { MockWETH } from "./mock/MockWETH.sol";

contract RevolutionBuilderTest is Test {
    ///                                                          ///
    ///                          BASE SETUP                      ///
    ///                                                          ///

    IRevolutionBuilder internal manager;

    address internal managerImpl0;
    address internal managerImpl;
    address internal tokenImpl;
    address internal descriptorImpl;
    address internal auctionImpl;
    address internal executorImpl;
    address internal daoImpl;

    address internal nounsDAO;
    address internal zoraDAO;
    address internal founder;
    address internal founder2;
    address internal weth;

    MockERC721 internal mock721;
    MockERC1155 internal mock1155;

    function setUp() public virtual {
        weth = address(new MockWETH());

        mock721 = new MockERC721();
        mock1155 = new MockERC1155();

        nounsDAO = vm.addr(0xA11CE);
        zoraDAO = vm.addr(0xB0B);

        founder = vm.addr(0xCAB);
        founder2 = vm.addr(0xDAD);

        vm.label(zoraDAO, "ZORA_DAO");
        vm.label(nounsDAO, "NOUNS_DAO");

        vm.label(founder, "FOUNDER");
        vm.label(founder2, "FOUNDER_2");

        managerImpl0 = address(
            new RevolutionBuilder(
                address(0),
                address(0),
                address(0),
                address(0),
                address(0),
                address(0),
                address(0),
                address(0)
            )
        );
        manager = RevolutionBuilder(
            address(new ERC1967Proxy(managerImpl0, abi.encodeWithSignature("initialize(address)", zoraDAO)))
        );

        tokenImpl = address(new VerbsToken(address(manager)));
        descriptorImpl = address(new VerbsDescriptor(address(manager)));
        // auctionImpl = address(new VerbsAuctionHouse(address(manager), weth));
        // executorImpl = address(new VerbsDAOExecutor(address(manager)));
        // daoImpl = address(new VerbsDAOLogicV1(address(manager)));

        // managerImpl = address(new RevolutionBuilder(tokenImpl, descriptorImpl, auctionImpl, executorImpl, daoImpl));

        vm.prank(zoraDAO);
        // manager.upgradeTo(managerImpl);
    }

    ///                                                          ///
    ///                     DAO CUSTOMIZATION UTILS              ///
    ///                                                          ///

    IRevolutionBuilder.ERC721TokenParams internal erc721TokenParams;
    IRevolutionBuilder.AuctionParams internal auctionParams;
    IRevolutionBuilder.GovParams internal govParams;
    IRevolutionBuilder.CultureIndexParams internal cultureIndexParams;
    IRevolutionBuilder.ERC20TokenParams internal erc20TokenParams;
    IRevolutionBuilder.ERC20TokenEmitterParams internal erc20TokenEmitterParams;

    function setMockERC721TokenParams() internal virtual {
        setERC721TokenParams("Mock Token", "MOCK", "Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j");
    }

    function setERC721TokenParams(
        string memory _name,
        string memory _symbol,
        string memory _contractURI
    ) internal virtual {
        erc721TokenParams = IRevolutionBuilder.ERC721TokenParams({
            name: _name,
            symbol: _symbol,
            contractURIHash: _contractURI
        });
    }

    function setMockAuctionParams() internal virtual {
        setAuctionParams(0.01 ether, 10 minutes, 2, 1000, 1000, 1000);
    }

    function setAuctionParams(
        uint256 _reservePrice,
        uint256 _duration,
        uint256 _minBidIncrementPercentage,
        uint256 _creatorRateBps,
        uint256 _entropyRateBps,
        uint256 _minCreatorRateBps
    ) internal virtual {
        auctionParams = IRevolutionBuilder.AuctionParams({
            reservePrice: _reservePrice,
            duration: _duration,
            minBidIncrementPercentage: _minBidIncrementPercentage,
            creatorRateBps: _creatorRateBps,
            entropyRateBps: _entropyRateBps,
            minCreatorRateBps: _minCreatorRateBps
        });
    }

    function setMockGovParams() internal virtual {
        setGovParams(2 days, 1 seconds, 1 weeks, 50, 1000, founder);
    }

    function setGovParams(
        uint256 _timelockDelay,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThresholdBps,
        uint256 _quorumThresholdBps,
        address _vetoer
    ) internal virtual {
        govParams = IRevolutionBuilder.GovParams({
            timelockDelay: _timelockDelay,
            votingDelay: _votingDelay,
            votingPeriod: _votingPeriod,
            proposalThresholdBps: _proposalThresholdBps,
            quorumThresholdBps: _quorumThresholdBps,
            vetoer: _vetoer
        });
    }

    function setMockCultureIndexParams() internal virtual {
        setCultureIndexParams("Vrbs", "Our community Vrbs. Must be 32x32.", 100, 1000, 0);
    }

    function setCultureIndexParams(
        string memory _name,
        string memory _description,
        uint256 _erc721VotingTokenWeight,
        uint256 _quorumVotesBPS,
        uint256 _minVoteWeight
    ) internal virtual {
        cultureIndexParams = IRevolutionBuilder.CultureIndexParams({
            name: _name,
            description: _description,
            erc721VotingTokenWeight: _erc721VotingTokenWeight,
            quorumVotesBPS: _quorumVotesBPS,
            minVoteWeight: _minVoteWeight
        });
    }

    function setMockERC20TokenParams() internal virtual {
        setERC20TokenParams("Mock Token", "MOCK");
    }

    function setERC20TokenParams(string memory _tokenName, string memory _tokenSymbol) internal virtual {
        erc20TokenParams = IRevolutionBuilder.ERC20TokenParams({
            tokenName: _tokenName,
            tokenSymbol: _tokenSymbol
        });
    }

    function setMockERC20TokenEmitterParams() internal virtual {
        setERC20TokenEmitterParams(1 ether, 1e18 / 10, 1_000);
    }

    function setERC20TokenEmitterParams(
        uint256 _targetPrice,
        uint256 _priceDecayPercent,
        uint256 _tokensPerTimeUnit
    ) internal virtual {
        erc20TokenEmitterParams = IRevolutionBuilder.ERC20TokenEmitterParams({
            targetPrice: _targetPrice,
            priceDecayPercent: _priceDecayPercent,
            tokensPerTimeUnit: _tokensPerTimeUnit
        });
    }

    ///                                                          ///
    ///                       DAO DEPLOY UTILS                   ///
    ///                                                          ///

    VerbsToken internal token;
    VerbsDescriptor internal descriptor;
    VerbsAuctionHouse internal auction;
    VerbsDAOExecutor internal executor;
    VerbsDAOLogicV1 internal dao;
    CultureIndex internal cultureIndex;
    NontransferableERC20Votes internal erc20Token;
    TokenEmitter internal erc20TokenEmitter;

    function deployMock() internal virtual {
        setMockERC721TokenParams();

        setMockAuctionParams();

        setMockGovParams();

        deploy(
            founder,
            erc721TokenParams,
            auctionParams,
            govParams,
            cultureIndexParams,
            erc20TokenParams,
            erc20TokenEmitterParams
        );
    }

    function deploy(
        address _initialOwner,
        IRevolutionBuilder.ERC721TokenParams memory _ERC721TokenParams,
        IRevolutionBuilder.AuctionParams memory _auctionParams,
        IRevolutionBuilder.GovParams memory _govParams,
        IRevolutionBuilder.CultureIndexParams memory _cultureIndexParams,
        IRevolutionBuilder.ERC20TokenParams memory _ERC20TokenParams,
        IRevolutionBuilder.ERC20TokenEmitterParams memory _ERC20TokenEmitterParams
    ) internal virtual {
        (
            address _token,
            address _descriptor,
            address _auction,
            address _executor,
            address _dao,
            address _cultureIndex,
            address _erc20Token,
            address _erc20TokenEmitter
        ) = manager.deploy(
                _initialOwner,
                _ERC721TokenParams,
                _auctionParams,
                _govParams,
                _cultureIndexParams,
                _ERC20TokenParams,
                _ERC20TokenEmitterParams
            );

        token = VerbsToken(_token);
        descriptor = VerbsDescriptor(_descriptor);
        auction = VerbsAuctionHouse(_auction);
        executor = VerbsDAOExecutor(payable(_executor));
        dao = VerbsDAOLogicV1(_dao);
        cultureIndex = CultureIndex(_cultureIndex);
        erc20Token = NontransferableERC20Votes(_erc20Token);
        erc20TokenEmitter = TokenEmitter(_erc20TokenEmitter);

        vm.label(address(token), "ERC721TOKEN");
        vm.label(address(descriptor), "DESCRIPTOR");
        vm.label(address(auction), "AUCTION");
        vm.label(address(executor), "EXECUTOR");
        vm.label(address(dao), "DAO");
        vm.label(address(cultureIndex), "CULTURE_INDEX");
        vm.label(address(erc20Token), "ERC20TOKEN");
        vm.label(address(erc20TokenEmitter), "ERC20TOKEN_EMITTER");
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
                (uint256 tokenId, , , , , ) = auction.auction();

                vm.prank(otherUsers[i]);
                auction.createBid{ value: reservePrice }(tokenId, otherUsers[i]);

                vm.warp(block.timestamp + duration);

                auction.settleCurrentAndCreateNewAuction();
            }
        }
    }

    function createVoters(uint256 _numVoters, uint256 _balance) internal {
        createUsers(_numVoters, _balance);

        createTokens(_numVoters);
    }
}
