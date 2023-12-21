// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IRevolutionBuilder, RevolutionBuilder } from "../src/builder/RevolutionBuilder.sol";
import { IVerbsToken, VerbsToken } from "../src/VerbsToken.sol";
import { Descriptor } from "../src/Descriptor.sol";
import { IAuctionHouse, AuctionHouse } from "../src/AuctionHouse.sol";
import { VerbsDAOLogicV1 } from "../src/governance/VerbsDAOLogicV1.sol";
import { DAOExecutor } from "../src/governance/DAOExecutor.sol";
import { CultureIndex } from "../src/CultureIndex.sol";
import { RevolutionProtocolRewards } from "@cobuild/protocol-rewards/src/RevolutionProtocolRewards.sol";
import { MaxHeap } from "../src/MaxHeap.sol";
import { NontransferableERC20Votes } from "../src/NontransferableERC20Votes.sol";
import { ERC20TokenEmitter } from "../src/ERC20TokenEmitter.sol";
import { IDAOExecutor } from "../src/governance/VerbsDAOInterfaces.sol";
import { ERC1967Proxy } from "../src/libs/proxy/ERC1967Proxy.sol";

contract DeployContracts is Script {
    using Strings for uint256;

    function run() public {
        uint256 chainID = vm.envUint("CHAIN_ID");
        uint256 key = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("MANAGER_OWNER");
        address rewardsRecipient = vm.envAddress("REWARDS_RECIPIENT");

        address deployerAddress = vm.addr(key);

        console2.log("~~~~~~~~~~ CHAIN ID ~~~~~~~~~~~");
        console2.log(chainID);

        console2.log("~~~~~~~~~~ DEPLOYER ~~~~~~~~~~~");
        console2.log(deployerAddress);

        console2.log("~~~~~~~~~~ OWNER ~~~~~~~~~~~");
        console2.log(owner);
        console2.log("");

        vm.startBroadcast(deployerAddress);

        // Deploy protocol rewards
        address protocolRewards = address(new RevolutionProtocolRewards());

        // Deploy root manager implementation + proxy
        address builderImpl0 = address(
            new RevolutionBuilder(
                address(0),
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

        RevolutionBuilder builder = RevolutionBuilder(
            address(new ERC1967Proxy(builderImpl0, abi.encodeWithSignature("initialize(address)", owner)))
        );

        // Deploy token implementation
        address erc721TokenImpl = address(new VerbsToken(address(builder)));

        // Deploy metadata renderer implementation
        address descriptorImpl = address(new Descriptor(address(builder)));

        // Deploy auction house implementation
        address auctionImpl = address(new AuctionHouse(address(builder)));

        // Deploy executor implementation
        address executorImpl = address(new DAOExecutor(address(builder)));

        // Deploy dao implementation
        address daoImpl = address(new VerbsDAOLogicV1(address(builder)));

        // Deploy culture index implementation
        address cultureIndexImpl = address(new CultureIndex(address(builder)));

        // Deploy max heap implementation
        address maxHeapImpl = address(new MaxHeap(address(builder)));

        // Deploy nontransferable erc20 implementation
        address nontransferableERC20Impl = address(new NontransferableERC20Votes(address(builder)));

        // Deploy erc20 token emitter implementation
        address erc20TokenEmitterImpl = address(
            new ERC20TokenEmitter(address(builder), address(rewardsRecipient), rewardsRecipient)
        );

        address builderImpl = address(
            new RevolutionBuilder(
                erc721TokenImpl,
                descriptorImpl,
                auctionImpl,
                executorImpl,
                daoImpl,
                cultureIndexImpl,
                nontransferableERC20Impl,
                erc20TokenEmitterImpl,
                maxHeapImpl
            )
        );

        // vm.prank(owner);
        // manager.upgradeTo(managerImpl);

        vm.stopBroadcast();

        string memory filePath = string(abi.encodePacked("deploys/", chainID.toString(), ".txt"));

        vm.writeFile(filePath, "");
        vm.writeLine(filePath, string(abi.encodePacked("Builder: ", addressToString(address(builder)))));
        vm.writeLine(
            filePath,
            string(abi.encodePacked("ERC721Token implementation: ", addressToString(erc721TokenImpl)))
        );
        vm.writeLine(
            filePath,
            string(abi.encodePacked("Descriptor implementation: ", addressToString(descriptorImpl)))
        );
        vm.writeLine(filePath, string(abi.encodePacked("Auction implementation: ", addressToString(auctionImpl))));
        vm.writeLine(filePath, string(abi.encodePacked("Executor implementation: ", addressToString(executorImpl))));
        vm.writeLine(filePath, string(abi.encodePacked("DAO implementation: ", addressToString(daoImpl))));
        vm.writeLine(filePath, string(abi.encodePacked("Builder implementation: ", addressToString(builderImpl))));
        vm.writeLine(
            filePath,
            string(abi.encodePacked("Culture Index implementation: ", addressToString(cultureIndexImpl)))
        );
        vm.writeLine(filePath, string(abi.encodePacked("Max Heap implementation: ", addressToString(maxHeapImpl))));
        vm.writeLine(
            filePath,
            string(
                abi.encodePacked("Nontransferable ERC20 implementation: ", addressToString(nontransferableERC20Impl))
            )
        );
        vm.writeLine(
            filePath,
            string(abi.encodePacked("ERC20 Token Emitter implementation: ", addressToString(erc20TokenEmitterImpl)))
        );

        console2.log("~~~~~~~~~~ MANAGER IMPL 0 ~~~~~~~~~~~");
        console2.logAddress(builderImpl0);

        console2.log("~~~~~~~~~~ MANAGER IMPL 1 ~~~~~~~~~~~");
        console2.logAddress(builderImpl);

        console2.log("~~~~~~~~~~ MANAGER PROXY ~~~~~~~~~~~");
        console2.logAddress(address(builder));
        console2.log("");

        console2.log("~~~~~~~~~~ TOKEN IMPL ~~~~~~~~~~~");
        console2.logAddress(erc721TokenImpl);

        console2.log("~~~~~~~~~~ DESCRIPTOR IMPL ~~~~~~~~~~~");
        console2.logAddress(descriptorImpl);

        console2.log("~~~~~~~~~~ AUCTION IMPL ~~~~~~~~~~~");
        console2.logAddress(auctionImpl);

        console2.log("~~~~~~~~~~ executor IMPL ~~~~~~~~~~~");
        console2.logAddress(executorImpl);

        console2.log("~~~~~~~~~~ DAO IMPL ~~~~~~~~~~~");
        console2.logAddress(daoImpl);
    }

    function addressToString(address _addr) private pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(_addr)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(abi.encodePacked("0x", string(s)));
    }

    function char(bytes1 b) private pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}
