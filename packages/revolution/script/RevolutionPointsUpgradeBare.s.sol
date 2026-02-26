// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { RevolutionPoints } from "../src/RevolutionPoints.sol";

contract RevolutionPointsUpgradeBare is Script {
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

        console2.log("~~~~~~~~~~ DEPLOYING REVOLUTION POINTS UPGRADE ~~~~~~~~~~~");

        vm.startBroadcast(deployerAddress);

        // Deploy revolution points upgrade implementation
        address revolutionPointsUpgradeImpl = address(new RevolutionPoints(_getKey("BuilderProxy")));

        console2.log("REVOLUTION POINTS UPGRADE IMPLEMENTATION");
        console2.log(revolutionPointsUpgradeImpl);

        vm.stopBroadcast();

        string memory filePath = string(abi.encodePacked("deploys/", chainID.toString(), ".upgradeRevolutionPoints.txt"));
        vm.writeFile(filePath, "");
        vm.writeLine(
            filePath,
            string(abi.encodePacked("Revolution Points Upgrade implementation: ", addressToString(revolutionPointsUpgradeImpl)))
        );
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
