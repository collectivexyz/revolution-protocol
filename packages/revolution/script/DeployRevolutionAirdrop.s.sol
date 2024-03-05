pragma solidity 0.8.22;

import { RevolutionAirdrop } from "../src/RevolutionAirdrop.sol";
import "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

contract RevolutionAirdropScript is Script {
    function run() external {
        console2.log("Deploying RevolutionAirdrop...");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address tokenAddress = address(0xDFb1cd29c4aB6985F1614e0d65782cd136115b6A);
        address owner = address(0xAC11CAA24071d28C8853054D1658A84E64954A1e);
        vm.startBroadcast(deployerPrivateKey);
        address airdropAddress = address(new RevolutionAirdrop(tokenAddress, owner));
        vm.stopBroadcast();
        console2.log("Deployed contract at address: ", airdropAddress);
    }
}
