// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import {console2} from "forge-std/console2.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IRevolutionTokenSale} from "../../src/interfaces/IRevolutionTokenSale.sol";

import {VrbsAddresses, VrbsMigrationHelpers, IVrbsDAO} from "./VrbsMigrationHelpers.sol";

/// @notice Read-only helper that writes the exact Vrbs DAO proposal inputs and full propose calldata.
/// @dev Use the generated file in the BaseScan DAO write-contract UI or submit through SubmitVrbsVRGDAProposal.
contract BuildVrbsVRGDAProposal is VrbsMigrationHelpers {
    using Strings for uint256;

    struct ProposalContext {
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
        ProposalContext memory ctx = _loadProposalContext();

        _writeProposal(ctx);
        _logProposal(ctx);
    }

    function _loadProposalContext() internal returns (ProposalContext memory ctx) {
        _requireBase();
        _requireVrbsContractsHaveCode();

        ctx.newTokenImpl = vm.envAddress("VRGDA_NEW_TOKEN_IMPL");
        ctx.newCultureIndexImpl = vm.envAddress("VRGDA_NEW_CULTURE_INDEX_IMPL");
        ctx.expectedTokenSaleImpl = vm.envAddress("TOKEN_SALE_IMPL");
        ctx.tokenSale = vm.envAddress("TOKEN_SALE_PROXY");
        ctx.expectedProtocolFeeRecipient = _readProtocolFeeRecipient();
        ctx.maxLaunchPriceWei = _readMaxLaunchPriceWei();
        ctx.description = _proposalDescription();
        ctx.expectedParams = _readSaleParams();
        _validateSaleParams(ctx.expectedParams);

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

    function _writeProposal(ProposalContext memory ctx) internal {
        (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas) =
            _buildCommunityActions(ctx.newTokenImpl, ctx.newCultureIndexImpl, ctx.tokenSale, ctx.acceptCultureOwnership);

        bytes memory proposeCalldata =
            abi.encodeWithSelector(IVrbsDAO.propose.selector, targets, values, signatures, calldatas, ctx.description);

        string memory filePath = _outputFile("dao-proposal");
        _writeProposalHeader(filePath, ctx);
        _writeProposalActions(filePath, targets, values, signatures, calldatas);
        _writeProposalArrays(filePath, targets, values, signatures, calldatas, proposeCalldata);
    }

    function _writeProposalHeader(string memory filePath, ProposalContext memory ctx) internal {
        vm.writeFile(filePath, "");
        vm.writeLine(filePath, "# Vrbs DAO VRGDA migration proposal");
        vm.writeLine(
            filePath, "# DAO: https://basescan.org/address/0x613B7dDCA4B05355B3541F8c018B374987549E79#writeContract"
        );
        vm.writeLine(filePath, "# Use the propose(...) fields below, or submit the full proposeCalldata.");
        vm.writeLine(filePath, "# Action order must not be changed.");
        vm.writeLine(filePath, "");
        _writeAddressLine(filePath, "DAO", VrbsAddresses.DAO);
        _writeAddressLine(filePath, "Executor", VrbsAddresses.EXECUTOR);
        _writeAddressLine(filePath, "RevolutionToken", VrbsAddresses.TOKEN);
        _writeAddressLine(filePath, "CultureIndex", VrbsAddresses.CULTURE_INDEX);
        _writeAddressLine(filePath, "Auction", VrbsAddresses.AUCTION);
        _writeAddressLine(filePath, "TokenSale", ctx.tokenSale);
        _writeAddressLine(filePath, "TokenSaleImpl", ctx.expectedTokenSaleImpl);
        _writeAddressLine(filePath, "ProtocolRewards", VrbsAddresses.PROTOCOL_REWARDS);
        _writeAddressLine(filePath, "ProtocolFeeRecipient", ctx.expectedProtocolFeeRecipient);
        _writeAddressLine(filePath, "NewTokenImpl", ctx.newTokenImpl);
        _writeAddressLine(filePath, "NewCultureIndexImpl", ctx.newCultureIndexImpl);
        _writeUintLine(filePath, "LaunchPriceWei", ctx.launchPriceWei);
        _writeUintLine(filePath, "MaxLaunchPriceWei", ctx.maxLaunchPriceWei);
        _writeStringLine(filePath, "acceptCultureOwnership", ctx.acceptCultureOwnership ? "true" : "false");
        _writeStringLine(filePath, "description", ctx.description);
        vm.writeLine(filePath, "");
    }

    function _writeProposalActions(
        string memory filePath,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) internal {
        for (uint256 i; i < targets.length; ++i) {
            vm.writeLine(filePath, string.concat("action[", i.toString(), "]"));
            _writeAddressLine(filePath, "target", targets[i]);
            _writeUintLine(filePath, "value", values[i]);
            _writeStringLine(filePath, "signature", signatures[i]);
            _writeBytesLine(filePath, "calldata", calldatas[i]);
            vm.writeLine(filePath, "");
        }
    }

    function _writeProposalArrays(
        string memory filePath,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bytes memory proposeCalldata
    ) internal {
        vm.writeLine(filePath, "# Copy/paste arrays");
        vm.writeLine(filePath, string.concat("targets: [", _addressesCsv(targets), "]"));
        vm.writeLine(filePath, string.concat("values: [", _uintsCsv(values), "]"));
        vm.writeLine(filePath, string.concat("signatures: [", _stringsCsv(signatures), "]"));
        vm.writeLine(filePath, string.concat("calldatas: [", _bytesCsv(calldatas), "]"));
        vm.writeLine(filePath, "");
        _writeBytesLine(filePath, "proposeCalldata", proposeCalldata);
    }

    function _logProposal(ProposalContext memory ctx) internal pure {
        console2.log("DAO proposal output written to");
        console2.log(_outputFile("dao-proposal"));
        console2.log("DAO");
        console2.logAddress(VrbsAddresses.DAO);
        console2.log("TOKEN SALE LAUNCH PRICE WEI", ctx.launchPriceWei);
        console2.log("MAX LAUNCH PRICE WEI", ctx.maxLaunchPriceWei);
    }

    function _addressesCsv(address[] memory values) internal pure returns (string memory out) {
        for (uint256 i; i < values.length; ++i) {
            out = string.concat(out, i == 0 ? "" : ",", _addressToString(values[i]));
        }
    }

    function _uintsCsv(uint256[] memory values) internal pure returns (string memory out) {
        for (uint256 i; i < values.length; ++i) {
            out = string.concat(out, i == 0 ? "" : ",", values[i].toString());
        }
    }

    function _stringsCsv(string[] memory values) internal pure returns (string memory out) {
        for (uint256 i; i < values.length; ++i) {
            out = string.concat(out, i == 0 ? "" : ",", '"', values[i], '"');
        }
    }

    function _bytesCsv(bytes[] memory values) internal pure returns (string memory out) {
        for (uint256 i; i < values.length; ++i) {
            out = string.concat(out, i == 0 ? "" : ",", _bytesToHexString(values[i]));
        }
    }
}
