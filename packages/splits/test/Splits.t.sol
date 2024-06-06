// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { SplitMain } from "../src/SplitMain.sol";
import { SplitWallet } from "../src/SplitWallet.sol";
import { ISplitMain } from "../src/interfaces/ISplitMain.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { ProtocolRewards } from "@cobuild/protocol-rewards/src/ProtocolRewards.sol";

contract SplitsTest is Test {
    SplitMain splitsMainImpl;

    address splits;

    address manager = makeAddr("manager");

    address initialOwner = makeAddr("initialOwner");

    address pointsEmitter;

    uint256 public PERCENTAGE_SCALE;

    function setUp() public {
        splitsMainImpl = new SplitMain(manager);

        bytes32 salt = bytes32(uint256(uint160(manager)) << 96);

        splits = address(new ERC1967Proxy{ salt: salt }(address(splitsMainImpl), ""));

        vm.prank(manager);
        ISplitMain(address(splits)).initialize({ initialOwner: initialOwner, pointsEmitter: pointsEmitter });

        PERCENTAGE_SCALE = ISplitMain(splits).PERCENTAGE_SCALE();
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
            pointsPercent: 10,
            accounts: accounts,
            percentAllocations: pointsAllocations
        });

        return (accounts, percentAllocations, distributorFee, controller, pointsAllocations, pointsData);
    }
}
