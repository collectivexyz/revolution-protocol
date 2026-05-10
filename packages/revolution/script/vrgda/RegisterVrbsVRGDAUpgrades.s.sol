// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { console2 } from "forge-std/console2.sol";

import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";

import { VrbsAddresses, VrbsMigrationHelpers, IOwnableRead } from "./VrbsMigrationHelpers.sol";

/// @notice Broadcasts the exact upgrade registrations required by the live Vrbs Token and CultureIndex proxies.
/// @dev Must be run by the manager owner. It never registers AuctionHouse => TokenSale.
contract RegisterVrbsVRGDAUpgrades is VrbsMigrationHelpers {
    function run() external {
        _requireBase();
        _requireVrbsContractsHaveCode();

        uint256 key = vm.envUint("PRIVATE_KEY");
        address caller = vm.addr(key);
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

        require(managerOwner == caller, "caller is not manager owner; use BuildVrbsManagerRegistration instead");
        require(oldTokenImpl != newTokenImpl, "token already on new impl");
        require(oldCultureIndexImpl != newCultureIndexImpl, "culture index already on new impl");
        require(!manager.isRegisteredUpgrade(oldAuctionImpl, tokenSaleImpl), "auction => token sale already registered");

        console2.log("CALLER / MANAGER OWNER");
        console2.logAddress(caller);
        console2.log("MANAGER");
        console2.logAddress(address(manager));
        console2.log("OLD TOKEN IMPL");
        console2.logAddress(oldTokenImpl);
        console2.log("NEW TOKEN IMPL");
        console2.logAddress(newTokenImpl);
        console2.log("OLD CULTURE INDEX IMPL");
        console2.logAddress(oldCultureIndexImpl);
        console2.log("NEW CULTURE INDEX IMPL");
        console2.logAddress(newCultureIndexImpl);

        vm.startBroadcast(key);

        if (!manager.isRegisteredUpgrade(oldTokenImpl, newTokenImpl)) {
            manager.registerUpgrade(oldTokenImpl, newTokenImpl);
        }
        if (!manager.isRegisteredUpgrade(oldCultureIndexImpl, newCultureIndexImpl)) {
            manager.registerUpgrade(oldCultureIndexImpl, newCultureIndexImpl);
        }

        vm.stopBroadcast();

        require(manager.isRegisteredUpgrade(oldTokenImpl, newTokenImpl), "token upgrade not registered");
        require(manager.isRegisteredUpgrade(oldCultureIndexImpl, newCultureIndexImpl), "culture upgrade not registered");
        require(!manager.isRegisteredUpgrade(oldAuctionImpl, tokenSaleImpl), "auction => token sale unexpectedly registered");

        string memory filePath = _outputFile("registered-upgrades");
        vm.writeFile(filePath, "");
        _writeAddressLine(filePath, "Manager", address(manager));
        _writeAddressLine(filePath, "OldTokenImpl", oldTokenImpl);
        _writeAddressLine(filePath, "NewTokenImpl", newTokenImpl);
        _writeAddressLine(filePath, "OldCultureIndexImpl", oldCultureIndexImpl);
        _writeAddressLine(filePath, "NewCultureIndexImpl", newCultureIndexImpl);

        console2.log("Upgrade registration complete; output written to");
        console2.log(filePath);
    }
}
