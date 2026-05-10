// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { console2 } from "forge-std/console2.sol";

import { VrbsAddresses, VrbsMigrationHelpers, IVrbsDAO } from "./VrbsMigrationHelpers.sol";

/// @notice Broadcast helper to submit the already-built Vrbs DAO migration proposal.
/// @dev The signer must meet the DAO proposal threshold. Use BuildVrbsVRGDAProposal first for a dry-run/output file.
contract SubmitVrbsVRGDAProposal is VrbsMigrationHelpers {
    function run() external {
        _requireBase();
        _requireVrbsContractsHaveCode();

        uint256 key = vm.envUint("PRIVATE_KEY");
        address proposer = vm.addr(key);
        address newTokenImpl = vm.envAddress("VRGDA_NEW_TOKEN_IMPL");
        address newCultureIndexImpl = vm.envAddress("VRGDA_NEW_CULTURE_INDEX_IMPL");
        address tokenSale = vm.envAddress("TOKEN_SALE_PROXY");
        string memory description = _proposalDescription();

        bool acceptCultureOwnership = _preflightVrbsVRGDAProposal(newTokenImpl, newCultureIndexImpl, tokenSale);

        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        ) = _buildCommunityActions(newTokenImpl, newCultureIndexImpl, tokenSale, acceptCultureOwnership);

        console2.log("Submitting Vrbs DAO proposal from proposer");
        console2.logAddress(proposer);
        console2.log("DAO");
        console2.logAddress(VrbsAddresses.DAO);

        vm.startBroadcast(key);
        uint256 proposalId = IVrbsDAO(VrbsAddresses.DAO).propose(targets, values, signatures, calldatas, description);
        vm.stopBroadcast();

        console2.log("Submitted proposal ID", proposalId);
    }
}
