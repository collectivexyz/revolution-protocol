// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.22;

import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { SuperTokenV1Library, ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import { UUPS } from "@cobuild/utility-contracts/src/proxy/UUPS.sol";
import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";
import { RevolutionVersion } from "../version/RevolutionVersion.sol";
import { RevolutionGrantsStorage } from "./storage/RevolutionGrantsStorage.sol";

contract RevolutionGrants is
    RevolutionVersion,
    UUPS,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable,
    RevolutionGrantsStorage
{
    using SuperTokenV1Library for ISuperToken;
    ISuperToken private superToken;
    ISuperfluidPool private pool;
    PoolConfig private poolConfig =
        PoolConfig({ transferabilityForUnitsOwner: false, distributionFromAnyAddress: false });

    constructor(ISuperToken _superToken) {
        superToken = _superToken;
        pool = superToken.createPool(address(this), poolConfig);
    }

    // Use updateMemberUnits to assign units to a member
    function updateMemberUnits(address member, uint128 units) public {
        superToken.updateMemberUnits(pool, member, units);
    }

    function distributeFlow(int96 flowRate) public {
        superToken.distributeFlow(address(this), pool, flowRate);
    }
}
