// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { SplitMain } from "@cobuild/splits/src/SplitMain.sol";
import { SplitWallet } from "@cobuild/splits/src/SplitWallet.sol";
import { ISplitMain } from "@cobuild/splits/src/interfaces/ISplitMain.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { RevolutionPointsEmitter } from "../../src/RevolutionPointsEmitter.sol";
import { RevolutionPoints } from "../../src/RevolutionPoints.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { IRevolutionPointsEmitter } from "../../src/interfaces/IRevolutionPointsEmitter.sol";
import { IRevolutionPoints } from "../../src/interfaces/IRevolutionPoints.sol";
import { VRGDAC } from "../../src/libs/VRGDAC.sol";
import { IVRGDAC } from "../../src/interfaces/IVRGDAC.sol";
import { ProtocolRewards } from "@cobuild/protocol-rewards/src/ProtocolRewards.sol";

contract SplitsTest is Test {
    SplitMain splitsMainImpl;

    address splits;

    address manager = makeAddr("manager");

    address initialOwner = makeAddr("initialOwner");

    address feeRecipient = makeAddr("feeRecipient");

    address grantsAddress = makeAddr("grantsAddress");

    address founder = makeAddr("founder");

    address weth = makeAddr("weth");

    address dao = makeAddr("dao");

    uint256 public PERCENTAGE_SCALE;

    address pointsEmitter;

    address revolutionPoints;

    address vrgda;

    function setUp() public {
        splitsMainImpl = new SplitMain(manager);

        bytes32 salt = bytes32(uint256(uint160(manager)) << 96);

        splits = address(new ERC1967Proxy{ salt: salt }(address(splitsMainImpl), ""));

        createPointsEmitter();

        vm.prank(manager);
        ISplitMain(address(splits)).initialize({ initialOwner: initialOwner, pointsEmitter: pointsEmitter });

        PERCENTAGE_SCALE = ISplitMain(splits).PERCENTAGE_SCALE();
    }

    function createPointsEmitter() public {
        address protocolRewards = address(new ProtocolRewards());

        address pointsEmitterImpl = address(new RevolutionPointsEmitter(manager, protocolRewards, feeRecipient));
        address pointsImpl = address(new RevolutionPoints(manager));

        address vrgdaImpl = address(new VRGDAC(manager));

        revolutionPoints = address(new ERC1967Proxy(pointsImpl, ""));

        pointsEmitter = address(new ERC1967Proxy(pointsEmitterImpl, ""));

        vrgda = address(new ERC1967Proxy(vrgdaImpl, ""));

        vm.prank(manager);
        IRevolutionPoints(revolutionPoints).initialize({
            initialOwner: dao,
            minter: pointsEmitter,
            tokenParams: IRevolutionBuilder.PointsTokenParams({ name: "Revolution Points", symbol: "RPT" })
        });

        vm.prank(manager);
        IRevolutionPointsEmitter(pointsEmitter).initialize({
            initialOwner: dao,
            revolutionPoints: address(revolutionPoints),
            vrgda: vrgda,
            founderParams: IRevolutionBuilder.FounderParams({
                totalRateBps: 1_000,
                founderAddress: founder,
                rewardsExpirationDate: 1_800_000_000,
                entropyRateBps: 5_000
            }),
            grantsParams: IRevolutionBuilder.GrantsParams({ totalRateBps: 1_000, grantsAddress: grantsAddress }),
            weth: weth
        });

        //initialize vrgda
        vm.prank(manager);
        IVRGDAC(vrgda).initialize({ initialOwner: dao, targetPrice: 1e18, priceDecayPercent: 5e17, perTimeUnit: 1e18 });
    }

    /** @notice Multiplies an amount by a scaled percentage
     *  @param amount Amount to get `scaledPercentage` of
     *  @param scaledPercent Percent scaled by PERCENTAGE_SCALE
     *  @return scaledAmount Percent of `amount`.
     */
    function _scaleAmountByPercentage(
        uint256 amount,
        uint256 scaledPercent
    ) internal view returns (uint256 scaledAmount) {
        // use assembly to bypass checking for overflow & division by 0
        // scaledPercent has been validated to be < PERCENTAGE_SCALE)
        // & PERCENTAGE_SCALE will never be 0
        // pernicious ERC20s may cause overflow, but results do not affect ETH & other ERC20 balances
        uint256 scale = PERCENTAGE_SCALE;
        assembly {
            /* eg (100 * 2*1e4) / (1e6) */
            scaledAmount := div(mul(amount, scaledPercent), scale)
        }
    }

    function distributeAndCheckETHBalances(
        uint256 totalETH,
        address split,
        SplitMain.PointsData memory pointsData,
        address[] memory accounts,
        uint32[] memory percentAllocations,
        uint32 distributorFee
    ) internal {
        uint256 splitMainBalance = address(splits).balance;

        uint256 splitBalance = address(split).balance;

        // Distribute ETH to the split
        ISplitMain(splits).distributeETH(
            split,
            pointsData,
            accounts,
            percentAllocations,
            distributorFee,
            address(this)
        );

        // assert split balance is 0 after distribution
        assertEq(address(split).balance, 0, "Split balance should be 0 after distribution");

        // assert splitMain balance gained the split balance
        assertEq(
            address(splits).balance,
            splitMainBalance + splitBalance,
            "SplitMain balance should gain the split balance"
        );

        // Check ETH balances for each account
        for (uint256 i = 0; i < accounts.length; i++) {
            uint256 expectedETHBalance = _scaleAmountByPercentage(
                _scaleAmountByPercentage(totalETH, PERCENTAGE_SCALE),
                percentAllocations[i]
            );
            uint256 actualETHBalance = ISplitMain(splits).getETHBalance(accounts[i]);
            assertEq(actualETHBalance, expectedETHBalance, "Incorrect ETH balance for account");
        }

        // Check ETH points balances for each points account
        for (uint256 i = 0; i < pointsData.accounts.length; i++) {
            uint256 expectedETHPointsBalance = _scaleAmountByPercentage(
                _scaleAmountByPercentage(totalETH, pointsData.percentOfEther),
                pointsData.percentAllocations[i]
            );
            uint256 actualETHPointsBalance = ISplitMain(splits).getETHPointsBalance(pointsData.accounts[i]);
            assertEq(actualETHPointsBalance, expectedETHPointsBalance, "Incorrect ETH points balance for account");
        }
    }

    function getBuyerPayment(uint256 etherAmount) public view returns (uint256) {
        uint256 msgValueRemaining = subtractRewards(etherAmount);

        return msgValueRemaining - getFounderPayment(etherAmount) - getGrantsPayment(etherAmount);
    }

    function getFounderGovernancePayment(uint256 etherAmount) public view returns (uint256) {
        return
            (IRevolutionPointsEmitter(pointsEmitter).founderRateBps() *
                subtractRewards(etherAmount) *
                (10_000 - IRevolutionPointsEmitter(pointsEmitter).founderEntropyRateBps())) / 1e8;
    }

    function getFounderPayment(uint256 etherAmount) public view returns (uint256) {
        return (IRevolutionPointsEmitter(pointsEmitter).founderRateBps() * subtractRewards(etherAmount)) / 1e4;
    }

    function getGrantsPayment(uint256 etherAmount) public view returns (uint256) {
        return (IRevolutionPointsEmitter(pointsEmitter).grantsRateBps() * subtractRewards(etherAmount)) / 1e4;
    }

    function subtractRewards(uint256 value) public view returns (uint256) {
        return value - IRevolutionPointsEmitter(pointsEmitter).computeTotalReward(value);
    }

    function getTokenQuoteForEtherHelper(uint256 etherAmount, int256 supply) public view returns (int gainedX) {
        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        return
            IRevolutionPointsEmitter(pointsEmitter).vrgda().yToX({
                timeSinceStart: toDaysWadUnsafe(block.timestamp - IRevolutionPointsEmitter(pointsEmitter).startTime()),
                sold: supply,
                amount: int(etherAmount)
            });
    }

    function setupBasicSplit()
        internal
        returns (
            address[] memory accounts,
            uint32[] memory percentAllocations,
            uint32 distributorFee,
            address controller,
            uint32[] memory pointsAllocations,
            SplitMain.PointsData memory pointsData
        )
    {
        accounts = new address[](1);
        address recipient = payable(address(0x3));
        accounts[0] = recipient;

        percentAllocations = new uint32[](1);
        percentAllocations[0] = uint32(PERCENTAGE_SCALE) - 10;

        distributorFee = 0;
        controller = address(this);

        pointsAllocations = new uint32[](1);
        pointsAllocations[0] = 1e6;

        pointsData = ISplitMain.PointsData({
            percentOfEther: 10,
            accounts: accounts,
            percentAllocations: pointsAllocations
        });

        return (accounts, percentAllocations, distributorFee, controller, pointsAllocations, pointsData);
    }

    /// @dev Takes an integer amount of seconds and converts it to a wad amount of days.
    /// @dev Will not revert on overflow, only use where overflow is not possible.
    /// @dev Not meant for negative second amounts, it assumes x is positive.
    function toDaysWadUnsafe(uint256 x) public pure returns (int256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // Multiply x by 1e18 and then divide it by 86400.
            r := div(mul(x, 1000000000000000000), 86400)
        }
    }
}
