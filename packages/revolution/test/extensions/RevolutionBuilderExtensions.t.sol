// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { RevolutionBuilderTest } from "../RevolutionBuilder.t.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { RevolutionBuilderStorageV1 } from "../../src/builder/storage/RevolutionBuilderStorageV1.sol";
import { RevolutionBuilderTypesV1 } from "../../src/builder/types/RevolutionBuilderTypesV1.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { RevolutionDAOStorageV1 } from "../../src/governance/RevolutionDAOInterfaces.sol";

contract BuilderExtensionsTest is RevolutionBuilderTest {
    function setUp() public virtual override {
        super.setUp();
        super.setMockParams();

        super.deployMock();
    }

    function addBasicExtension(string memory extensionName) public {
        RevolutionBuilderTypesV1.DAOAddresses memory daoAddresses = RevolutionBuilderTypesV1.DAOAddresses({
            dao: manager.daoImpl(),
            executor: manager.executorImpl(),
            vrgda: manager.vrgdaImpl(),
            descriptor: manager.descriptorImpl(),
            auction: manager.auctionImpl(),
            cultureIndex: manager.cultureIndexImpl(),
            maxHeap: manager.maxHeapImpl(),
            revolutionPoints: manager.revolutionPointsImpl(),
            revolutionPointsEmitter: manager.revolutionPointsEmitterImpl(),
            revolutionToken: manager.revolutionTokenImpl(),
            revolutionVotingPower: manager.revolutionVotingPowerImpl(),
            splitsCreator: manager.splitsCreatorImpl()
        });

        vm.prank(address(revolutionDAO));
        manager.registerExtension(extensionName, address(this), daoAddresses);
    }
}
