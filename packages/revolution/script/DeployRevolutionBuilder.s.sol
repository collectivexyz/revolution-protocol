// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IRevolutionBuilder, RevolutionBuilder } from "../src/builder/RevolutionBuilder.sol";
import { IRevolutionToken, RevolutionToken } from "../src/RevolutionToken.sol";
import { Descriptor } from "../src/Descriptor.sol";
import { IAuctionHouse, AuctionHouse } from "../src/AuctionHouse.sol";
import { RevolutionDAOLogicV1 } from "../src/governance/RevolutionDAOLogicV1.sol";
import { DAOExecutor } from "../src/governance/DAOExecutor.sol";
import { CultureIndex } from "../src/culture-index/CultureIndex.sol";
import { RevolutionProtocolRewards } from "@cobuild/protocol-rewards/src/RevolutionProtocolRewards.sol";
import { MaxHeap } from "../src/culture-index/MaxHeap.sol";
import { RevolutionPoints } from "../src/RevolutionPoints.sol";
import { RevolutionVotingPower } from "../src/RevolutionVotingPower.sol";
import { RevolutionPointsEmitter } from "../src/RevolutionPointsEmitter.sol";
import { IDAOExecutor } from "../src/governance/RevolutionDAOInterfaces.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { SplitMain } from "@cobuild/splits/src/SplitMain.sol";

import { VRGDAC } from "../src/libs/VRGDAC.sol";

contract DeployContracts is Script {
    using Strings for uint256;

    struct DeployedContracts {
        address protocolRewards;
        address builderImpl0;
        address builderProxy;
        address revolutionTokenImpl;
        address descriptorImpl;
        address auctionImpl;
        address executorImpl;
        address daoImpl;
        address cultureIndexImpl;
        address maxHeapImpl;
        address revolutionPointsImpl;
        address revolutionPointsEmitterImpl;
        address revolutionVotingPowerImpl;
        address builderImpl;
        address vrgdaImpl;
        address splitMainImpl;
    }

    // Define the struct for deployed contracts
    DeployedContracts private deployedContracts;

    function run() public {
        uint256 chainID = vm.envUint("CHAIN_ID");
        uint256 key = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("MANAGER_OWNER");
        address rewardsRecipient = vm.envAddress("REWARDS_RECIPIENT");

        address deployerAddress = vm.addr(key);

        logDeploymentDetails(chainID, deployerAddress, owner);

        vm.startBroadcast(deployerAddress);

        deployedContracts.protocolRewards = deployProtocolRewards();
        deployRevolutionBuilderContracts(owner);
        deployOtherContracts(deployedContracts.protocolRewards, rewardsRecipient);

        vm.stopBroadcast();

        writeDeploymentDetailsToFile(chainID);
    }

    function deployProtocolRewards() private returns (address) {
        return address(new RevolutionProtocolRewards());
    }

    function deployRevolutionBuilderContracts(address owner) private {
        deployedContracts.builderImpl0 = address(
            new RevolutionBuilder(
                IRevolutionBuilder.PointsImplementations({
                    revolutionPointsEmitter: address(0),
                    revolutionPoints: address(0),
                    splitMain: address(0),
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

        deployedContracts.builderProxy = address(
            new ERC1967Proxy(deployedContracts.builderImpl0, abi.encodeWithSignature("initialize(address)", owner))
        );
    }

    function logDeploymentDetails(uint256 chainID, address deployerAddress, address owner) private pure {
        console2.log("~~~~~~~~~~ CHAIN ID ~~~~~~~~~~~");
        console2.log(chainID);
        console2.log("~~~~~~~~~~ DEPLOYER ~~~~~~~~~~~");
        console2.log(deployerAddress);
        console2.log("~~~~~~~~~~ OWNER ~~~~~~~~~~~");
        console2.log(owner);
        console2.log("");
    }

    function deployOtherContracts(address protocolRewards, address rewardsRecipient) private {
        deployedContracts.revolutionTokenImpl = address(new RevolutionToken(address(deployedContracts.builderProxy)));
        deployedContracts.descriptorImpl = address(new Descriptor(address(deployedContracts.builderProxy)));
        deployedContracts.auctionImpl = address(new AuctionHouse(address(deployedContracts.builderProxy)));
        deployedContracts.executorImpl = address(new DAOExecutor(address(deployedContracts.builderProxy)));
        deployedContracts.daoImpl = address(new RevolutionDAOLogicV1(address(deployedContracts.builderProxy)));
        deployedContracts.cultureIndexImpl = address(new CultureIndex(address(deployedContracts.builderProxy)));
        deployedContracts.maxHeapImpl = address(new MaxHeap(address(deployedContracts.builderProxy)));
        deployedContracts.revolutionPointsImpl = address(new RevolutionPoints(address(deployedContracts.builderProxy)));
        deployedContracts.revolutionPointsEmitterImpl = address(
            new RevolutionPointsEmitter(address(deployedContracts.builderProxy), protocolRewards, rewardsRecipient)
        );
        deployedContracts.revolutionVotingPowerImpl = address(
            new RevolutionVotingPower(address(deployedContracts.builderProxy))
        );
        deployedContracts.vrgdaImpl = address(new VRGDAC(address(deployedContracts.builderProxy)));
        deployedContracts.splitMainImpl = address(new VRGDAC(address(deployedContracts.builderProxy)));

        deployedContracts.builderImpl = address(
            new RevolutionBuilder(
                IRevolutionBuilder.PointsImplementations({
                    revolutionPoints: deployedContracts.revolutionPointsImpl,
                    revolutionPointsEmitter: deployedContracts.revolutionPointsEmitterImpl,
                    vrgda: deployedContracts.vrgdaImpl,
                    splitMain: deployedContracts.splitMainImpl
                }),
                IRevolutionBuilder.TokenImplementations({
                    revolutionToken: deployedContracts.revolutionTokenImpl,
                    descriptor: deployedContracts.descriptorImpl,
                    auction: deployedContracts.auctionImpl
                }),
                IRevolutionBuilder.DAOImplementations({
                    revolutionVotingPower: deployedContracts.revolutionVotingPowerImpl,
                    executor: deployedContracts.executorImpl,
                    dao: deployedContracts.daoImpl
                }),
                IRevolutionBuilder.CultureIndexImplementations({
                    cultureIndex: deployedContracts.cultureIndexImpl,
                    maxHeap: deployedContracts.maxHeapImpl
                })
            )
        );
    }

    function writeDeploymentDetailsToFile(uint256 chainID) private {
        string memory filePath = string(abi.encodePacked("deploys/", chainID.toString(), ".txt"));

        vm.writeFile(filePath, "");
        vm.writeLine(
            filePath,
            string(abi.encodePacked("Builder: ", addressToString(address(deployedContracts.builderProxy))))
        );
        vm.writeLine(
            filePath,
            string(
                abi.encodePacked(
                    "RevolutionToken implementation: ",
                    addressToString(deployedContracts.revolutionTokenImpl)
                )
            )
        );
        vm.writeLine(
            filePath,
            string(abi.encodePacked("Descriptor implementation: ", addressToString(deployedContracts.descriptorImpl)))
        );
        vm.writeLine(
            filePath,
            string(abi.encodePacked("Auction implementation: ", addressToString(deployedContracts.auctionImpl)))
        );
        vm.writeLine(
            filePath,
            string(abi.encodePacked("Executor implementation: ", addressToString(deployedContracts.executorImpl)))
        );
        vm.writeLine(
            filePath,
            string(abi.encodePacked("DAO implementation: ", addressToString(deployedContracts.daoImpl)))
        );
        vm.writeLine(
            filePath,
            string(abi.encodePacked("Builder implementation: ", addressToString(deployedContracts.builderImpl)))
        );
        vm.writeLine(
            filePath,
            string(
                abi.encodePacked("Culture Index implementation: ", addressToString(deployedContracts.cultureIndexImpl))
            )
        );
        vm.writeLine(
            filePath,
            string(abi.encodePacked("Max Heap implementation: ", addressToString(deployedContracts.maxHeapImpl)))
        );
        vm.writeLine(
            filePath,
            string(abi.encodePacked("Points implementation: ", addressToString(deployedContracts.revolutionPointsImpl)))
        );
        vm.writeLine(
            filePath,
            string(
                abi.encodePacked(
                    "PointsEmitter implementation: ",
                    addressToString(deployedContracts.revolutionPointsEmitterImpl)
                )
            )
        );
        vm.writeLine(
            filePath,
            string(
                abi.encodePacked(
                    "RevolutionVotingPower implementation: ",
                    addressToString(deployedContracts.revolutionVotingPowerImpl)
                )
            )
        );
        vm.writeLine(
            filePath,
            string(abi.encodePacked("VRGDAC implementation: ", addressToString(deployedContracts.vrgdaImpl)))
        );
        vm.writeLine(
            filePath,
            string(abi.encodePacked("SplitMain implementation: ", addressToString(deployedContracts.splitMainImpl)))
        );

        console2.log("~~~~~~~~~~ MANAGER IMPL 0 ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.builderImpl0);

        console2.log("~~~~~~~~~~ MANAGER IMPL 1 ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.builderImpl);

        console2.log("~~~~~~~~~~ MANAGER PROXY ~~~~~~~~~~~");
        console2.logAddress(address(deployedContracts.builderProxy));
        console2.log("");

        console2.log("~~~~~~~~~~ TOKEN IMPL ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.revolutionTokenImpl);

        console2.log("~~~~~~~~~~ DESCRIPTOR IMPL ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.descriptorImpl);

        console2.log("~~~~~~~~~~ AUCTION IMPL ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.auctionImpl);

        console2.log("~~~~~~~~~~ executor IMPL ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.executorImpl);

        console2.log("~~~~~~~~~~ DAO IMPL ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.daoImpl);

        console2.log("~~~~~~~~~~ CULTURE INDEX IMPL ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.cultureIndexImpl);

        console2.log("~~~~~~~~~~ MAX HEAP IMPL ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.maxHeapImpl);

        console2.log("~~~~~~~~~~ POINTS IMPL ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.revolutionPointsImpl);

        console2.log("~~~~~~~~~~ POINTS EMITTER IMPL ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.revolutionPointsEmitterImpl);

        console2.log("~~~~~~~~~~ VOTING POWER IMPL ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.revolutionVotingPowerImpl);

        console2.log("~~~~~~~~~~ VRGDAC IMPL ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.vrgdaImpl);

        console2.log("~~~~~~~~~~ SPLIT MAIN IMPL ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.splitMainImpl);

        console2.log("~~~~~~~~~~ PROTOCOL REWARDS ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.protocolRewards);

        console2.log("~~~~~~~~~~ DEPLOYMENT DETAILS WRITTEN TO FILE ~~~~~~~~~~~");
        console2.log(filePath);

        console2.log("~~~~~~~~~~ DEPLOYMENT COMPLETE ~~~~~~~~~~~");
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
