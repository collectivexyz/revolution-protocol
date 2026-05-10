// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { console2 } from "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";

import {
    VrbsAddresses,
    VrbsMigrationHelpers,
    IAuctionHouseRead,
    IRevolutionTokenRead,
    IRevolutionTokenSaleRead,
    IVrbsDAO
} from "./VrbsMigrationHelpers.sol";

/// @notice Read-only helper that writes the exact Vrbs DAO proposal inputs and full propose calldata.
/// @dev Use the generated file in the BaseScan DAO write-contract UI or submit through SubmitVrbsVRGDAProposal.
contract BuildVrbsVRGDAProposal is VrbsMigrationHelpers {
    using Strings for uint256;

    function run() external {
        _requireBase();
        _requireVrbsContractsHaveCode();

        address newTokenImpl = vm.envAddress("VRGDA_NEW_TOKEN_IMPL");
        address newCultureIndexImpl = vm.envAddress("VRGDA_NEW_CULTURE_INDEX_IMPL");
        address tokenSale = vm.envAddress("TOKEN_SALE_PROXY");
        string memory description = _proposalDescription();

        bool acceptCultureOwnership = _preflight(newTokenImpl, newCultureIndexImpl, tokenSale);

        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        ) = _buildCommunityActions(newTokenImpl, newCultureIndexImpl, tokenSale, acceptCultureOwnership);

        bytes memory proposeCalldata = abi.encodeWithSelector(
            IVrbsDAO.propose.selector,
            targets,
            values,
            signatures,
            calldatas,
            description
        );

        string memory filePath = _outputFile("dao-proposal");
        vm.writeFile(filePath, "");
        vm.writeLine(filePath, "# Vrbs DAO VRGDA migration proposal");
        vm.writeLine(filePath, "# DAO: https://basescan.org/address/0x613B7dDCA4B05355B3541F8c018B374987549E79#writeContract");
        vm.writeLine(filePath, "# Use the propose(...) fields below, or submit the full proposeCalldata.");
        vm.writeLine(filePath, "# Action order must not be changed.");
        vm.writeLine(filePath, "");
        _writeAddressLine(filePath, "DAO", VrbsAddresses.DAO);
        _writeAddressLine(filePath, "Executor", VrbsAddresses.EXECUTOR);
        _writeAddressLine(filePath, "RevolutionToken", VrbsAddresses.TOKEN);
        _writeAddressLine(filePath, "CultureIndex", VrbsAddresses.CULTURE_INDEX);
        _writeAddressLine(filePath, "Auction", VrbsAddresses.AUCTION);
        _writeAddressLine(filePath, "TokenSale", tokenSale);
        _writeAddressLine(filePath, "NewTokenImpl", newTokenImpl);
        _writeAddressLine(filePath, "NewCultureIndexImpl", newCultureIndexImpl);
        _writeStringLine(filePath, "acceptCultureOwnership", acceptCultureOwnership ? "true" : "false");
        _writeStringLine(filePath, "description", description);
        vm.writeLine(filePath, "");

        for (uint256 i; i < targets.length; ++i) {
            vm.writeLine(filePath, string.concat("action[", i.toString(), "]"));
            _writeAddressLine(filePath, "target", targets[i]);
            _writeUintLine(filePath, "value", values[i]);
            _writeStringLine(filePath, "signature", signatures[i]);
            _writeBytesLine(filePath, "calldata", calldatas[i]);
            vm.writeLine(filePath, "");
        }

        vm.writeLine(filePath, "# Copy/paste arrays");
        vm.writeLine(filePath, string.concat("targets: [", _addressesCsv(targets), "]"));
        vm.writeLine(filePath, string.concat("values: [", _uintsCsv(values), "]"));
        vm.writeLine(filePath, string.concat("signatures: [", _stringsCsv(signatures), "]"));
        vm.writeLine(filePath, string.concat("calldatas: [", _bytesCsv(calldatas), "]"));
        vm.writeLine(filePath, "");
        _writeBytesLine(filePath, "proposeCalldata", proposeCalldata);

        console2.log("DAO proposal output written to");
        console2.log(filePath);
        console2.log("DAO");
        console2.logAddress(VrbsAddresses.DAO);
    }

    function _preflight(
        address newTokenImpl,
        address newCultureIndexImpl,
        address tokenSale
    ) internal view returns (bool acceptCultureOwnership) {
        _requireCode(newTokenImpl, "VRGDA_NEW_TOKEN_IMPL");
        _requireCode(newCultureIndexImpl, "VRGDA_NEW_CULTURE_INDEX_IMPL");
        _requireCode(tokenSale, "TOKEN_SALE_PROXY");

        _requireDaoExecutionWiring();
        _requireAuctionPausedAndSettled();
        _requireTokenCanCutOver();
        acceptCultureOwnership = _requireOwnersForAtomicCutover(tokenSale);
        _requirePointsEmitterSafe(tokenSale);

        IUpgradeManager manager = _manager();
        address oldTokenImpl = _implementationOf(VrbsAddresses.TOKEN);
        address oldCultureIndexImpl = _implementationOf(VrbsAddresses.CULTURE_INDEX);
        address oldAuctionImpl = _implementationOf(VrbsAddresses.AUCTION);
        address tokenSaleImpl = _implementationOf(tokenSale);

        require(manager.isRegisteredUpgrade(oldTokenImpl, newTokenImpl), "token upgrade not registered");
        require(manager.isRegisteredUpgrade(oldCultureIndexImpl, newCultureIndexImpl), "culture upgrade not registered");
        require(!manager.isRegisteredUpgrade(oldAuctionImpl, tokenSaleImpl), "auction => token sale is registered");

        IRevolutionTokenSaleRead sale = IRevolutionTokenSaleRead(tokenSale);
        require(sale.paused(), "token sale must still be paused before proposal execution");
        require(address(sale.revolutionToken()) == VrbsAddresses.TOKEN, "sale token mismatch");
        require(sale.revolutionPointsEmitter() == VrbsAddresses.POINTS_EMITTER, "sale points emitter mismatch");
        require(sale.WETH() == IAuctionHouseRead(VrbsAddresses.AUCTION).WETH(), "sale WETH mismatch");
        require(sale.getCurrentPrice() > 0, "sale current price is zero");

        uint256 tokenId;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        address bidder;
        bool settled;
        (tokenId, amount, startTime, endTime, bidder, settled) = _auctionState();
        tokenId;
        amount;
        startTime;
        endTime;
        bidder;
        require(settled, "auction state is not settled");

        require(IRevolutionTokenRead(VrbsAddresses.TOKEN).owner() == VrbsAddresses.EXECUTOR, "token owner is not executor");
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
            out = string.concat(out, i == 0 ? "" : ",", "\"", values[i], "\"");
        }
    }

    function _bytesCsv(bytes[] memory values) internal pure returns (string memory out) {
        for (uint256 i; i < values.length; ++i) {
            out = string.concat(out, i == 0 ? "" : ",", _bytesToHexString(values[i]));
        }
    }
}
