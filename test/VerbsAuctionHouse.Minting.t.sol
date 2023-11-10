// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {VerbsAuctionHouse} from "../packages/revolution-contracts/VerbsAuctionHouse.sol";
import {MockERC20} from "./MockERC20.sol";
import {VerbsToken} from "../packages/revolution-contracts/VerbsToken.sol";
import {IVerbsToken} from "../packages/revolution-contracts/interfaces/IVerbsToken.sol";
import { IProxyRegistry } from "../packages/revolution-contracts/external/opensea/IProxyRegistry.sol";
import {VerbsDescriptor} from "../packages/revolution-contracts/VerbsDescriptor.sol";
import {CultureIndex} from "../packages/revolution-contracts/CultureIndex.sol";
import { IVerbsDescriptorMinimal } from "../packages/revolution-contracts/interfaces/IVerbsDescriptorMinimal.sol";
import { ICultureIndex, ICultureIndexEvents } from "../packages/revolution-contracts/interfaces/ICultureIndex.sol";
import { IVerbsAuctionHouse } from "../packages/revolution-contracts/interfaces/IVerbsAuctionHouse.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { VerbsAuctionHouseTest } from "./VerbsAuctionHouse.t.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract VerbsAuctionHouseMintTest is VerbsAuctionHouseTest {

   function testMintFailureDueToEmptyNFTList() public {
        setUp();
        emit log_address(address(auctionHouse));

        // Pre-conditions setup to ensure the CultureIndex is empty
        vm.expectEmit(true, true, true, true);
        emit PausableUpgradeable.Paused(address(this));
        auctionHouse.unpause();

        // Expect that the auction is paused due to error
        assertEq(auctionHouse.paused(), true, "Auction house should be paused");
    }


    function testBehaviorOnMintFailureDuringAuctionCreation() public {
        // Pre-conditions setup to trigger mint failure

        auctionHouse.unpause();

        (uint256 verbId, uint256 amount, uint256 auctionStartTime, uint256 auctionEndTime, address payable bidder, bool settled) = auctionHouse.auction();

        // Check that auction is not created
        assertEq(verbId, 0);
        assertEq(amount, 0);
        assertEq(auctionStartTime, 0);
        assertEq(auctionEndTime, 0);
        assertEq(bidder, address(0));
        assertEq(settled, false);
        
    }

}

