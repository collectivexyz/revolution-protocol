// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { SplitMain } from "@cobuild/splits/src/SplitMain.sol";
import { SplitWallet } from "@cobuild/splits/src/SplitWallet.sol";
import { ISplitMain } from "@cobuild/splits/src/interfaces/ISplitMain.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { SplitsTest } from "./RevolutionSplits.t.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { IRevolutionPointsEmitter } from "../../src/interfaces/IRevolutionPointsEmitter.sol";
import { IRevolutionPoints } from "../../src/interfaces/IRevolutionPoints.sol";
import { IVRGDAC } from "../../src/interfaces/IVRGDAC.sol";

contract SplitsTestSetupTest is SplitsTest {
    // test setup of our points emitter
    function test__BuyToken() public {
        // assert minter of points is pointsEmitter
        assertEq(IRevolutionPoints(revolutionPoints).minter(), pointsEmitter, "Minter should be pointsEmitter");

        // make sure vrgda can be called
        IVRGDAC(vrgda).yToX(1, 1, 1);

        IRevolutionPointsEmitter(pointsEmitter).getTokenQuoteForPayment(1 ether);

        address buyer = makeAddr("buyer");

        vm.deal(buyer, 1 ether);

        address[] memory accounts = new address[](1);
        accounts[0] = address(buyer);

        uint256[] memory bps = new uint256[](1);
        bps[0] = 1e4;

        vm.prank(buyer);
        IRevolutionPointsEmitter(pointsEmitter).buyToken{ value: 1 ether }(
            accounts,
            bps,
            IRevolutionPointsEmitter.ProtocolRewardAddresses({
                builder: address(0),
                deployer: address(0),
                purchaseReferral: address(0)
            })
        );
    }
}
