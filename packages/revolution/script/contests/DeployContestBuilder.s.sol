// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { ContestBuilder } from "../../src/culture-index/contests/ContestBuilder.sol";
import { IContestBuilder } from "../../src/culture-index/contests/IContestBuilder.sol";
import { BaseContest } from "../../src/culture-index/contests/BaseContest.sol";
import { CultureIndex } from "../../src/culture-index/CultureIndex.sol";
import { MaxHeap } from "../../src/culture-index/MaxHeap.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { SplitMain } from "@cobuild/splits/src/SplitMain.sol";

contract DeployContestBuilder is Script {
    using Strings for uint256;

    struct DeployedContracts {
        address contestBuilderImpl0;
        address contestBuilderProxy;
        address cultureIndexImpl;
        address maxHeapImpl;
        address baseContestImpl;
        address contestBuilderImpl;
    }

    // Define the struct for deployed contracts
    DeployedContracts private deployedContracts;

    function run() public {
        uint256 chainID = vm.envUint("CHAIN_ID");
        address deployerAddress = vm.envAddress("DEPLOYER_ADDRESS");
        address owner = vm.envAddress("MANAGER_OWNER");
        address rewardsRecipient = vm.envAddress("REWARDS_RECIPIENT");
        address protocolRewards = vm.envAddress("PROTOCOL_REWARDS");

        logDeploymentDetails(chainID, deployerAddress, owner);

        vm.startBroadcast(deployerAddress);

        deployContestBuilderContracts(owner);

        deployOtherContracts(protocolRewards, rewardsRecipient);
        vm.stopBroadcast();

        writeDeploymentDetailsToFile(chainID);
    }

    function deployContestBuilderContracts(address owner) private {
        deployedContracts.contestBuilderImpl0 = address(
            new ContestBuilder(
                address(0),
                IContestBuilder.CultureIndexImplementations({ cultureIndex: address(0), maxHeap: address(0) })
            )
        );

        deployedContracts.contestBuilderProxy = address(
            new ERC1967Proxy(
                deployedContracts.contestBuilderImpl0,
                abi.encodeWithSignature("initialize(address)", owner)
            )
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
        deployedContracts.cultureIndexImpl = address(new CultureIndex(address(deployedContracts.contestBuilderProxy)));
        deployedContracts.maxHeapImpl = address(new MaxHeap(address(deployedContracts.contestBuilderProxy)));
        deployedContracts.baseContestImpl = address(
            new BaseContest(address(deployedContracts.contestBuilderProxy), protocolRewards, rewardsRecipient)
        );

        deployedContracts.contestBuilderImpl = address(
            new ContestBuilder(
                deployedContracts.baseContestImpl,
                IContestBuilder.CultureIndexImplementations({
                    cultureIndex: deployedContracts.cultureIndexImpl,
                    maxHeap: deployedContracts.maxHeapImpl
                })
            )
        );
    }

    function writeDeploymentDetailsToFile(uint256 chainID) private {
        string memory filePath = string(abi.encodePacked("deploys/contests/", chainID.toString(), ".txt"));

        vm.writeFile(filePath, "");
        vm.writeLine(
            filePath,
            string(
                abi.encodePacked("Contest Builder: ", addressToString(address(deployedContracts.contestBuilderProxy)))
            )
        );

        vm.writeLine(
            filePath,
            string(
                abi.encodePacked(
                    "Contest Builder implementation: ",
                    addressToString(deployedContracts.contestBuilderImpl)
                )
            )
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
            string(
                abi.encodePacked("Base Contest implementation: ", addressToString(deployedContracts.baseContestImpl))
            )
        );

        console2.log("~~~~~~~~~~ MANAGER IMPL 0 ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.contestBuilderImpl0);

        console2.log("~~~~~~~~~~ MANAGER IMPL 1 ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.contestBuilderImpl);

        console2.log("~~~~~~~~~~ MANAGER PROXY ~~~~~~~~~~~");
        console2.logAddress(address(deployedContracts.contestBuilderProxy));
        console2.log("");

        console2.log("~~~~~~~~~~ CULTURE INDEX IMPL ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.cultureIndexImpl);

        console2.log("~~~~~~~~~~ MAX HEAP IMPL ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.maxHeapImpl);

        console2.log("~~~~~~~~~~ BASE CONTEST IMPL ~~~~~~~~~~~");
        console2.logAddress(deployedContracts.baseContestImpl);

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
