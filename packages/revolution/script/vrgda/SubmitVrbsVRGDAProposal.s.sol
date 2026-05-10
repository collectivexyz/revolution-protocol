// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import {console2} from "forge-std/console2.sol";

import {IRevolutionTokenSale} from "../../src/interfaces/IRevolutionTokenSale.sol";

import {VrbsAddresses, VrbsMigrationHelpers, IVrbsDAO} from "./VrbsMigrationHelpers.sol";

/// @notice Broadcast helper to submit the already-built Vrbs DAO migration proposal.
/// @dev The signer must meet the DAO proposal threshold. Use BuildVrbsVRGDAProposal first for a dry-run/output file.
contract SubmitVrbsVRGDAProposal is VrbsMigrationHelpers {
    struct SubmissionContext {
        uint256 key;
        address proposer;
        address newTokenImpl;
        address newCultureIndexImpl;
        address expectedTokenSaleImpl;
        address tokenSale;
        address expectedProtocolFeeRecipient;
        uint256 maxLaunchPriceWei;
        string description;
        IRevolutionTokenSale.TokenSaleParams expectedParams;
        bool acceptCultureOwnership;
        uint256 launchPriceWei;
    }

    function run() external {
        SubmissionContext memory ctx = _loadSubmissionContext();
        _submitProposal(ctx);
    }

    function _loadSubmissionContext() internal returns (SubmissionContext memory ctx) {
        _requireBase();
        _requireVrbsContractsHaveCode();

        ctx.key = vm.envUint("PRIVATE_KEY");
        ctx.proposer = vm.addr(ctx.key);
        ctx.newTokenImpl = vm.envAddress("VRGDA_NEW_TOKEN_IMPL");
        ctx.newCultureIndexImpl = vm.envAddress("VRGDA_NEW_CULTURE_INDEX_IMPL");
        ctx.expectedTokenSaleImpl = vm.envAddress("TOKEN_SALE_IMPL");
        ctx.tokenSale = vm.envAddress("TOKEN_SALE_PROXY");
        ctx.expectedProtocolFeeRecipient = _readProtocolFeeRecipient();
        ctx.maxLaunchPriceWei = _readMaxLaunchPriceWei();
        ctx.description = _proposalDescription();
        ctx.expectedParams = _readSaleParams();
        _validateSaleParams(ctx.expectedParams);

        require(vm.envOr("VRBS_VRGDA_DRY_RUN_PASSED", uint256(0)) == 1, "fork dry-run gate not acknowledged");

        (ctx.acceptCultureOwnership, ctx.launchPriceWei) = _preflightVrbsVRGDAProposal(
            ctx.newTokenImpl,
            ctx.newCultureIndexImpl,
            ctx.tokenSale,
            ctx.expectedTokenSaleImpl,
            ctx.expectedParams,
            ctx.expectedProtocolFeeRecipient,
            ctx.maxLaunchPriceWei
        );
    }

    function _submitProposal(SubmissionContext memory ctx) internal {
        (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas) =
            _buildCommunityActions(ctx.newTokenImpl, ctx.newCultureIndexImpl, ctx.tokenSale, ctx.acceptCultureOwnership);

        console2.log("Submitting Vrbs DAO proposal from proposer");
        console2.logAddress(ctx.proposer);
        console2.log("DAO");
        console2.logAddress(VrbsAddresses.DAO);
        console2.log("TOKEN SALE LAUNCH PRICE WEI", ctx.launchPriceWei);
        console2.log("MAX LAUNCH PRICE WEI", ctx.maxLaunchPriceWei);

        vm.startBroadcast(ctx.key);
        uint256 proposalId =
            IVrbsDAO(VrbsAddresses.DAO).propose(targets, values, signatures, calldatas, ctx.description);
        vm.stopBroadcast();

        console2.log("Submitted proposal ID", proposalId);
    }
}
