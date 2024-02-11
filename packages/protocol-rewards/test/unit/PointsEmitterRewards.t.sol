// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import "../ProtocolRewardsTest.sol";
import { MockWETH } from "../mock/MockWETH.sol";
import { IRewardSplits } from "../../src/interfaces/IRewardSplits.sol";
import { RevolutionPoints, IRevolutionPointsEmitter, IRevolutionBuilder, VRGDAC, ERC1967Proxy, RevolutionPointsEmitter } from "../utils/PointsEmitterLibrary.sol";

contract PointsEmitterRewardsTest is ProtocolRewardsTest {
    RevolutionPointsEmitter mockPointsEmitter;
    RevolutionPoints internal revolutionPoints;

    address creatorsAddress;
    address vrgda;

    //enable this contract to receive eth
    receive() external payable {}

    function setUp() public override {
        super.setUp();

        creatorsAddress = address(0x1);

        // Deploy the VRGDAC contract
        vrgda = address(new VRGDAC(1e11, 1e17, 1e22));

        address revolutionPointsEmitterImpl = address(
            new RevolutionPointsEmitter(address(this), address(protocolRewards), revolution)
        );

        revolutionPoints = new RevolutionPoints(address(this), "Revolution Governance", "GOV");

        address mockPointsEmitterAddress = address(new ERC1967Proxy(revolutionPointsEmitterImpl, ""));

        IRevolutionPointsEmitter(mockPointsEmitterAddress).initialize({
            initialOwner: address(this),
            revolutionPoints: address(revolutionPoints),
            vrgda: vrgda,
            founderParams: IRevolutionBuilder.FounderParams({
                totalRateBps: 1_000,
                founderAddress: creatorsAddress,
                rewardsExpirationDate: 1_800_000_000,
                entropyRateBps: 5_000
            }),
            weth: address(new MockWETH())
        });

        revolutionPoints.transferOwnership(mockPointsEmitterAddress);

        vm.label(mockPointsEmitterAddress, "MOCK_POINTSEMITTER");

        mockPointsEmitter = RevolutionPointsEmitter(mockPointsEmitterAddress);
    }

    function testDeposit(uint256 msgValue) public {
        msgValue = bound(msgValue, 1, 1e12 ether);

        vm.deal(collector, msgValue);

        // array of len 1 addresses
        address[] memory addresses = new address[](1);
        addresses[0] = collector;
        uint[] memory bps = new uint[](1);
        bps[0] = 10_000;

        vm.prank(collector);

        IRevolutionPointsEmitter.ProtocolRewardAddresses memory rewardAddrs = IRevolutionPointsEmitter
            .ProtocolRewardAddresses({
                builder: builderReferral,
                purchaseReferral: purchaseReferral,
                deployer: deployer
            });

        mockPointsEmitter.buyToken{ value: msgValue }(addresses, bps, rewardAddrs);

        (IRewardSplits.RewardsSettings memory settings, uint256 totalReward) = mockPointsEmitter.computePurchaseRewards(
            msgValue
        );

        assertApproxEqAbs(protocolRewards.totalRewardsSupply(), totalReward, 5);
        assertApproxEqAbs(protocolRewards.balanceOf(builderReferral), settings.builderReferralReward, 5);
        assertApproxEqAbs(protocolRewards.balanceOf(purchaseReferral), settings.purchaseReferralReward, 5);
        assertApproxEqAbs(protocolRewards.balanceOf(deployer), settings.deployerReward, 5);
        assertApproxEqAbs(protocolRewards.balanceOf(revolution), settings.revolutionReward, 5);
    }

    function testNullReferralRecipient(uint256 msgValue) public {
        msgValue = bound(msgValue, 1, 1e12 ether);
        RevolutionPoints govToken2 = new RevolutionPoints(address(this), "Revolution Governance", "GOV");

        address mockPointsEmitterImpl = address(
            new RevolutionPointsEmitter(address(this), address(protocolRewards), revolution)
        );

        address mockPointsEmitterAddress = address(new ERC1967Proxy(mockPointsEmitterImpl, ""));

        IRevolutionPointsEmitter(mockPointsEmitterAddress).initialize({
            initialOwner: address(this),
            revolutionPoints: address(govToken2),
            vrgda: vrgda,
            founderParams: IRevolutionBuilder.FounderParams({
                totalRateBps: 1_000,
                founderAddress: creatorsAddress,
                rewardsExpirationDate: 1_800_000_000,
                entropyRateBps: 5_000
            }),
            weth: address(new MockWETH())
        });

        mockPointsEmitter = RevolutionPointsEmitter(mockPointsEmitterAddress);

        govToken2.transferOwnership(address(mockPointsEmitter));

        // array of len 1 addresses
        address[] memory addresses = new address[](1);
        addresses[0] = collector;
        uint[] memory bps = new uint[](1);
        bps[0] = 10_000;

        vm.deal(collector, msgValue);

        vm.prank(collector);

        mockPointsEmitter.buyToken{ value: msgValue }(
            addresses,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: builderReferral,
                purchaseReferral: address(0),
                deployer: deployer
            })
        );

        (IRewardSplits.RewardsSettings memory settings, uint256 totalReward) = mockPointsEmitter.computePurchaseRewards(
            msgValue
        );

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
