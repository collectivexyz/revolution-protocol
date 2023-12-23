// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "../ProtocolRewardsTest.sol";
import { RewardsSettings } from "../../src/abstract/RewardSplits.sol";
import { NontransferableERC20Votes, IERC20TokenEmitter, IRevolutionBuilder, VRGDAC, ERC1967Proxy, ERC20TokenEmitter } from "../utils/TokenEmitterLibrary.sol";

contract TokenEmitterRewardsTest is ProtocolRewardsTest {
    ERC20TokenEmitter mockTokenEmitter;
    NontransferableERC20Votes internal erc20Token;

    address creatorsAddress;
    address vrgdac;

    //enable this contract to receive eth
    receive() external payable {}

    function setUp() public override {
        super.setUp();

        creatorsAddress = address(0x1);

        // Deploy the VRGDAC contract
        vrgdac = address(new VRGDAC(1e11, 1e17, 1e22));

        address erc20TokenEmitterImpl = address(
            new ERC20TokenEmitter(address(this), address(protocolRewards), revolution)
        );

        erc20Token = new NontransferableERC20Votes(address(this), "Revolution Governance", "GOV");

        address mockTokenEmitterAddress = address(new ERC1967Proxy(erc20TokenEmitterImpl, ""));

        IERC20TokenEmitter(mockTokenEmitterAddress).initialize({
            initialOwner: address(this),
            erc20Token: address(erc20Token),
            vrgdac: vrgdac,
            creatorsAddress: creatorsAddress,
            creatorParams: IRevolutionBuilder.TokenEmitterCreatorParams({
                creatorRateBps: 1_000,
                entropyRateBps: 5_000
            })
        });

        erc20Token.transferOwnership(mockTokenEmitterAddress);

        vm.label(mockTokenEmitterAddress, "MOCK_TOKENEMITTER");

        mockTokenEmitter = ERC20TokenEmitter(mockTokenEmitterAddress);
    }

    function testDeposit(uint256 msgValue) public {
        bool shouldExpectRevert = msgValue <= mockTokenEmitter.minPurchaseAmount() ||
            msgValue >= mockTokenEmitter.maxPurchaseAmount();

        vm.deal(collector, msgValue);

        // array of len 1 addresses
        address[] memory addresses = new address[](1);
        addresses[0] = collector;
        uint[] memory bps = new uint[](1);
        bps[0] = 10_000;

        vm.prank(collector);
        // // BPS too small to issue rewards
        if (shouldExpectRevert) {
            //expect INVALID_ETH_AMOUNT()
            vm.expectRevert();
        }

        IERC20TokenEmitter.ProtocolRewardAddresses memory rewardAddrs = IERC20TokenEmitter.ProtocolRewardAddresses({
            builder: builderReferral,
            purchaseReferral: purchaseReferral,
            deployer: deployer
        });

        mockTokenEmitter.buyToken{ value: msgValue }(addresses, bps, rewardAddrs);

        if (shouldExpectRevert) {
            vm.expectRevert();
        }
        (RewardsSettings memory settings, uint256 totalReward) = mockTokenEmitter.computePurchaseRewards(msgValue);

        if (!shouldExpectRevert) {
            assertApproxEqAbs(protocolRewards.totalRewardsSupply(), totalReward, 5);
            assertApproxEqAbs(protocolRewards.balanceOf(builderReferral), settings.builderReferralReward, 5);
            assertApproxEqAbs(protocolRewards.balanceOf(purchaseReferral), settings.purchaseReferralReward, 5);
            assertApproxEqAbs(protocolRewards.balanceOf(deployer), settings.deployerReward, 5);
            assertApproxEqAbs(protocolRewards.balanceOf(revolution), settings.revolutionReward, 5);
        }
    }

    function testNullReferralRecipient(uint256 msgValue) public {
        bool shouldExpectRevert = msgValue <= mockTokenEmitter.minPurchaseAmount() ||
            msgValue >= mockTokenEmitter.maxPurchaseAmount();

        NontransferableERC20Votes govToken2 = new NontransferableERC20Votes(
            address(this),
            "Revolution Governance",
            "GOV"
        );

        address mockTokenEmitterImpl = address(
            new ERC20TokenEmitter(address(this), address(protocolRewards), revolution)
        );

        address mockTokenEmitterAddress = address(new ERC1967Proxy(mockTokenEmitterImpl, ""));

        IERC20TokenEmitter(mockTokenEmitterAddress).initialize({
            initialOwner: address(this),
            erc20Token: address(govToken2),
            vrgdac: vrgdac,
            creatorsAddress: creatorsAddress,
            creatorParams: IRevolutionBuilder.TokenEmitterCreatorParams({
                creatorRateBps: 1_000,
                entropyRateBps: 5_000
            })
        });

        mockTokenEmitter = ERC20TokenEmitter(mockTokenEmitterAddress);

        govToken2.transferOwnership(address(mockTokenEmitter));

        // array of len 1 addresses
        address[] memory addresses = new address[](1);
        addresses[0] = collector;
        uint[] memory bps = new uint[](1);
        bps[0] = 10_000;

        vm.deal(collector, msgValue);

        vm.prank(collector);
        if (shouldExpectRevert) {
            //expect INVALID_ETH_AMOUNT()
            vm.expectRevert();
        }
        mockTokenEmitter.buyToken{ value: msgValue }(
            addresses,
            bps,
            IERC20TokenEmitter.ProtocolRewardAddresses({
                builder: builderReferral,
                purchaseReferral: address(0),
                deployer: deployer
            })
        );

        if (shouldExpectRevert) {
            //expect INVALID_ETH_AMOUNT()
            vm.expectRevert();
        }
        (RewardsSettings memory settings, uint256 totalReward) = mockTokenEmitter.computePurchaseRewards(msgValue);

        if (!shouldExpectRevert) {
            assertApproxEqAbs(protocolRewards.totalRewardsSupply(), totalReward, 5);
            assertApproxEqAbs(protocolRewards.balanceOf(builderReferral), settings.builderReferralReward, 5);
            assertApproxEqAbs(protocolRewards.balanceOf(deployer), settings.deployerReward, 5);
            assertApproxEqAbs(
                protocolRewards.balanceOf(revolution),
                settings.purchaseReferralReward + settings.revolutionReward,
                5
            );
        }
    }

    function testRevertInvalidEth(uint16 msgValue) public {
        vm.assume(msgValue < mockTokenEmitter.minPurchaseAmount() || msgValue > mockTokenEmitter.maxPurchaseAmount());

        vm.expectRevert(abi.encodeWithSignature("INVALID_ETH_AMOUNT()"));
        mockTokenEmitter.computePurchaseRewards(msgValue);
    }
}
