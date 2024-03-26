pragma solidity 0.8.22;

import { RevolutionAirdrop } from "../../../src/airdrop/RevolutionAirdrop.sol";
import "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

contract RevolutionAirdropScript is Script {
    function run() external {
        console2.log("Deploying RevolutionAirdrop...");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address tokenAddress = vm.envAddress("TOKEN");
        address owner = vm.envAddress("OWNER");
        vm.startBroadcast(deployerPrivateKey);
        address airdropAddress = address(new RevolutionAirdrop(tokenAddress, owner));
        vm.stopBroadcast();
        console2.log("Deployed contract at address: ", airdropAddress);
    }
}
