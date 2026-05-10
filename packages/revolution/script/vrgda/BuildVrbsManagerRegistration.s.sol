// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { console2 } from "forge-std/console2.sol";

import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";

import { VrbsAddresses, VrbsMigrationHelpers, IOwnableRead } from "./VrbsMigrationHelpers.sol";

/// @notice Read-only helper that writes the manager-owner calls needed before the Vrbs DAO proposal.
contract BuildVrbsManagerRegistration is VrbsMigrationHelpers {
    function run() external {
        _requireBase();
        _requireVrbsContractsHaveCode();

        address newTokenImpl = vm.envAddress("VRGDA_NEW_TOKEN_IMPL");
        address newCultureIndexImpl = vm.envAddress("VRGDA_NEW_CULTURE_INDEX_IMPL");
        address tokenSaleImpl = vm.envAddress("TOKEN_SALE_IMPL");

        _requireCode(newTokenImpl, "VRGDA_NEW_TOKEN_IMPL");
        _requireCode(newCultureIndexImpl, "VRGDA_NEW_CULTURE_INDEX_IMPL");
        _requireCode(tokenSaleImpl, "TOKEN_SALE_IMPL");

        IUpgradeManager manager = _manager();
        address managerOwner = IOwnableRead(address(manager)).owner();
        address oldTokenImpl = _implementationOf(VrbsAddresses.TOKEN);
        address oldCultureIndexImpl = _implementationOf(VrbsAddresses.CULTURE_INDEX);
        address oldAuctionImpl = _implementationOf(VrbsAddresses.AUCTION);

        require(oldTokenImpl != newTokenImpl, "token already on new impl");
        require(oldCultureIndexImpl != newCultureIndexImpl, "culture index already on new impl");
        require(!manager.isRegisteredUpgrade(oldAuctionImpl, tokenSaleImpl), "auction => token sale already registered");

        bytes memory registerToken = abi.encodeWithSelector(
            IUpgradeManager.registerUpgrade.selector,
            oldTokenImpl,
            newTokenImpl
        );
        bytes memory registerCulture = abi.encodeWithSelector(
            IUpgradeManager.registerUpgrade.selector,
            oldCultureIndexImpl,
            newCultureIndexImpl
        );

        string memory filePath = _outputFile("manager-registration");
        vm.writeFile(filePath, "");
        vm.writeLine(filePath, "# Manager-owner calls required before the Vrbs DAO migration proposal");
        vm.writeLine(filePath, "# Do not register AuctionHouse => TokenSale.");
        vm.writeLine(filePath, "");
        _writeAddressLine(filePath, "Manager", address(manager));
        _writeAddressLine(filePath, "ManagerOwner", managerOwner);
        _writeAddressLine(filePath, "OldTokenImpl", oldTokenImpl);
        _writeAddressLine(filePath, "NewTokenImpl", newTokenImpl);
        _writeAddressLine(filePath, "OldCultureIndexImpl", oldCultureIndexImpl);
        _writeAddressLine(filePath, "NewCultureIndexImpl", newCultureIndexImpl);
        _writeAddressLine(filePath, "OldAuctionImpl", oldAuctionImpl);
        _writeAddressLine(filePath, "TokenSaleImpl", tokenSaleImpl);
        vm.writeLine(filePath, "");
        _writeAddressLine(filePath, "action[0].target", address(manager));
        _writeUintLine(filePath, "action[0].value", 0);
        _writeStringLine(filePath, "action[0].signature", "registerUpgrade(address,address)");
        _writeBytesLine(filePath, "action[0].calldata", abi.encode(oldTokenImpl, newTokenImpl));
        _writeBytesLine(filePath, "action[0].fullCalldata", registerToken);
        vm.writeLine(filePath, "");
        _writeAddressLine(filePath, "action[1].target", address(manager));
        _writeUintLine(filePath, "action[1].value", 0);
        _writeStringLine(filePath, "action[1].signature", "registerUpgrade(address,address)");
        _writeBytesLine(filePath, "action[1].calldata", abi.encode(oldCultureIndexImpl, newCultureIndexImpl));
        _writeBytesLine(filePath, "action[1].fullCalldata", registerCulture);

        console2.log("Manager registration output written to");
        console2.log(filePath);
    }
}
