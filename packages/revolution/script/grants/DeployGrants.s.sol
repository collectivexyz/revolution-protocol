// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { RevolutionGrants } from "../../src/grants/RevolutionGrants.sol";
import { ERC1967Proxy } from "@cobuild/utility-contracts/src/proxy/ERC1967Proxy.sol";
import { IRevolutionGrants } from "../../src/interfaces/IRevolutionGrants.sol";

contract DeployGrants is Script {
    using Strings for uint256;

    address grants;
    address grantsImpl;

    function run() public {
        uint256 chainID = vm.envUint("CHAIN_ID");
        uint256 key = vm.envUint("PRIVATE_KEY");
        address manager = vm.envAddress("MANAGER_OWNER");
        address votingPower = vm.envAddress("VOTING_POWER");
        address superToken = vm.envAddress("SUPER_TOKEN");

        address deployerAddress = vm.addr(key);

        vm.startBroadcast(deployerAddress);

        IRevolutionGrants.GrantsParams memory params = IRevolutionGrants.GrantsParams({
            tokenVoteWeight: 1e18, // Example token vote weight
            pointsVoteWeight: 1, // Example points vote weight
            quorumVotesBPS: 0, // Example quorum votes in basis points (50%)
            minVotingPowerToVote: 1, // Minimum voting power required to vote
            minVotingPowerToCreate: 100 * 1e18 // Minimum voting power required to create a grant
        });

        grantsImpl = address(new RevolutionGrants(manager));
        grants = address(new ERC1967Proxy(grantsImpl, ""));

        IRevolutionGrants(grants).initialize({
            votingPower: votingPower,
            superToken: superToken,
            initialOwner: manager,
            grantsParams: params
        });

        vm.stopBroadcast();

        writeDeploymentDetailsToFile(chainID);
    }

    function writeDeploymentDetailsToFile(uint256 chainID) private {
        string memory filePath = string(abi.encodePacked("deploys/grants/", chainID.toString(), ".txt"));

        vm.writeFile(filePath, "");
        vm.writeLine(filePath, string(abi.encodePacked("Grants: ", addressToString(grants))));
        vm.writeLine(filePath, string(abi.encodePacked("GrantsImpl: ", addressToString(grantsImpl))));
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
