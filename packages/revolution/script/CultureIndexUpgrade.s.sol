// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IRevolutionBuilder, RevolutionBuilder } from "../src/builder/RevolutionBuilder.sol";
import { CultureIndex } from "../src/culture-index/CultureIndex.sol";

contract CultureIndexUpgrade is Script {
    using Strings for uint256;

    string configFile;

    function _getKey(string memory key) internal returns (address result) {
        (result) = abi.decode(vm.parseJson(configFile, string.concat(".", key)), (address));
    }

    function run() public {
        uint256 chainID = vm.envUint("CHAIN_ID");
        console.log("CHAIN_ID", chainID);
        uint256 key = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(key);

        configFile = vm.readFile(string.concat("./addresses/", Strings.toString(chainID), ".json"));

        console.log("CONFIG FILE", configFile);

        console2.log("~~~~~~~~~~ DEPLOYER ADDRESS ~~~~~~~~~~~");
        console2.logAddress(deployerAddress);

        console2.log("~~~~~~~~~~ BUILDER PROXY ~~~~~~~~~~~");
        console2.logAddress(_getKey("BuilderProxy"));

        console2.log("~~~~~~~~~~ REVOLUTION TOKEN ~~~~~~~~~~~");
        console2.logAddress(_getKey("RevolutionToken"));

        console2.log("~~~~~~~~~~ DESCRIPTOR ~~~~~~~~~~~");
        console2.logAddress(_getKey("Descriptor"));

        console2.log("~~~~~~~~~~ AUCTION ~~~~~~~~~~~");
        console2.logAddress(_getKey("Auction"));

        console2.log("~~~~~~~~~~ EXECUTOR ~~~~~~~~~~~");
        console2.logAddress(_getKey("Executor"));

        console2.log("~~~~~~~~~~ DAO ~~~~~~~~~~~");
        console2.logAddress(_getKey("DAO"));

        console2.log("~~~~~~~~~~ MAX HEAP ~~~~~~~~~~~");
        console2.logAddress(_getKey("MaxHeap"));

        console2.log("~~~~~~~~~~ REVOLUTION POINTS ~~~~~~~~~~~");
        console2.logAddress(_getKey("Points"));

        console2.log("~~~~~~~~~~ REVOLUTION POINTS EMITTER ~~~~~~~~~~~");
        console2.logAddress(_getKey("PointsEmitter"));

        console2.log("~~~~~~~~~~ REVOLUTION VOTING POWER ~~~~~~~~~~~");
        console2.logAddress(_getKey("RevolutionVotingPower"));

        console2.log("~~~~~~~~~~ VRGDAC ~~~~~~~~~~~");
        console2.logAddress(_getKey("VRGDAC"));

        console2.log("~~~~~~~~~~ SPLIT MAIN ~~~~~~~~~~~");
        console2.logAddress(_getKey("SplitMain"));

        console2.log("~~~~~~~~~~ DEPLOYING CULTURE INDEX UPGRADE ~~~~~~~~~~~");

        vm.startBroadcast(deployerAddress);

        // Deploy culture index upgrade implementation
        address cultureIndexUpgradeImpl = address(new CultureIndex(_getKey("BuilderProxy")));

        address builderImpl = address(
            new RevolutionBuilder(
                IRevolutionBuilder.PointsImplementations({
                    revolutionPointsEmitter: _getKey("PointsEmitter"),
                    revolutionPoints: _getKey("Points"),
                    splitsCreator: _getKey("SplitMain"),
                    vrgda: _getKey("VRGDAC")
                }),
                IRevolutionBuilder.TokenImplementations({
                    revolutionToken: _getKey("RevolutionToken"),
                    descriptor: _getKey("Descriptor"),
                    auction: _getKey("Auction")
                }),
                IRevolutionBuilder.DAOImplementations({
                    revolutionVotingPower: _getKey("RevolutionVotingPower"),
                    executor: _getKey("Executor"),
                    dao: _getKey("DAO")
                }),
                IRevolutionBuilder.CultureIndexImplementations({
                    cultureIndex: cultureIndexUpgradeImpl,
                    maxHeap: _getKey("MaxHeap")
                })
            )
        );

        console2.log("CU");
        console2.log(cultureIndexUpgradeImpl);

        console2.log("B");
        console2.log(builderImpl);

        // console2.log("OWNER", manager.owner());

        // builder.upgradeTo(builderImpl);

        vm.stopBroadcast();

        string memory filePath = string(abi.encodePacked("deploys/", chainID.toString(), ".upgradeCultureIndex.txt"));
        vm.writeFile(filePath, "");
        vm.writeLine(
            filePath,
            string(abi.encodePacked("Culture Index Upgrade implementation: ", addressToString(cultureIndexUpgradeImpl)))
        );
        vm.writeLine(filePath, string(abi.encodePacked("Builder implementation: ", addressToString(builderImpl))));
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
