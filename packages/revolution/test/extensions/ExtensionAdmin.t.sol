// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { BuilderExtensionsTest } from "./RevolutionBuilderExtensions.t.sol";
import { IRevolutionBuilder } from "../../src/interfaces/IRevolutionBuilder.sol";
import { RevolutionBuilderStorageV1 } from "../../src/builder/storage/RevolutionBuilderStorageV1.sol";
import { RevolutionBuilderTypesV1 } from "../../src/builder/types/RevolutionBuilderTypesV1.sol";
import { ICultureIndex } from "../../src/interfaces/ICultureIndex.sol";
import { RevolutionDAOStorageV1 } from "../../src/governance/RevolutionDAOInterfaces.sol";

contract ExtensionAdminTest is BuilderExtensionsTest {
    function setUp() public virtual override {
        super.setUp();
        super.setMockParams();

        super.deployMock();
    }

    // tests adding and removing an extension to the builder
    function test__AddAndRemoveExtension() public {
        string memory extensionName = "NewExtension";

        addBasicExtension(extensionName);

        assertTrue(manager.isRegisteredExtension(extensionName), "Extension should be valid");

        assertEq(
            manager.getExtensionImplementation(extensionName, RevolutionBuilderTypesV1.ImplementationType.DAO),
            manager.daoImpl(),
            "DAO implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(extensionName, RevolutionBuilderTypesV1.ImplementationType.Executor),
            manager.executorImpl(),
            "Executor implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(extensionName, RevolutionBuilderTypesV1.ImplementationType.VRGDAC),
            manager.vrgdaImpl(),
            "VRGDAC implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(extensionName, RevolutionBuilderTypesV1.ImplementationType.Descriptor),
            manager.descriptorImpl(),
            "Descriptor implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(extensionName, RevolutionBuilderTypesV1.ImplementationType.Auction),
            manager.auctionImpl(),
            "Auction implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(extensionName, RevolutionBuilderTypesV1.ImplementationType.CultureIndex),
            manager.cultureIndexImpl(),
            "CultureIndex implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(extensionName, RevolutionBuilderTypesV1.ImplementationType.MaxHeap),
            manager.maxHeapImpl(),
            "MaxHeap implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(
                extensionName,
                RevolutionBuilderTypesV1.ImplementationType.RevolutionPoints
            ),
            manager.revolutionPointsImpl(),
            "RevolutionPoints implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(
                extensionName,
                RevolutionBuilderTypesV1.ImplementationType.RevolutionPointsEmitter
            ),
            manager.revolutionPointsEmitterImpl(),
            "RevolutionPointsEmitter implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(
                extensionName,
                RevolutionBuilderTypesV1.ImplementationType.RevolutionToken
            ),
            manager.revolutionTokenImpl(),
            "RevolutionToken implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(
                extensionName,
                RevolutionBuilderTypesV1.ImplementationType.RevolutionVotingPower
            ),
            manager.revolutionVotingPowerImpl(),
            "RevolutionVotingPower implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(
                extensionName,
                RevolutionBuilderTypesV1.ImplementationType.SplitsCreator
            ),
            manager.splitsCreatorImpl(),
            "SplitsCreator implementation mismatch"
        );

        // check getExtensionBuilder
        assertEq(manager.getExtensionBuilder(extensionName), address(this), "Builder rewards address mismatch");

        string memory extensionToRemove = "NewExtension";
        vm.prank(address(revolutionDAO));
        manager.removeExtension(extensionToRemove);

        assertFalse(manager.isRegisteredExtension(extensionToRemove), "Extension should not be valid after removal");

        // assert address(0) for all implementations
        assertEq(
            manager.getExtensionImplementation(extensionToRemove, RevolutionBuilderTypesV1.ImplementationType.DAO),
            address(0),
            "DAO implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(extensionToRemove, RevolutionBuilderTypesV1.ImplementationType.Executor),
            address(0),
            "Executor implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(extensionToRemove, RevolutionBuilderTypesV1.ImplementationType.VRGDAC),
            address(0),
            "VRGDAC implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(
                extensionToRemove,
                RevolutionBuilderTypesV1.ImplementationType.Descriptor
            ),
            address(0),
            "Descriptor implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(extensionToRemove, RevolutionBuilderTypesV1.ImplementationType.Auction),
            address(0),
            "Auction implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(
                extensionToRemove,
                RevolutionBuilderTypesV1.ImplementationType.CultureIndex
            ),
            address(0),
            "CultureIndex implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(extensionToRemove, RevolutionBuilderTypesV1.ImplementationType.MaxHeap),
            address(0),
            "MaxHeap implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(
                extensionToRemove,
                RevolutionBuilderTypesV1.ImplementationType.RevolutionPoints
            ),
            address(0),
            "RevolutionPoints implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(
                extensionToRemove,
                RevolutionBuilderTypesV1.ImplementationType.RevolutionPointsEmitter
            ),
            address(0),
            "RevolutionPointsEmitter implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(
                extensionToRemove,
                RevolutionBuilderTypesV1.ImplementationType.RevolutionToken
            ),
            address(0),
            "RevolutionToken implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(
                extensionToRemove,
                RevolutionBuilderTypesV1.ImplementationType.RevolutionVotingPower
            ),
            address(0),
            "RevolutionVotingPower implementation mismatch"
        );
        assertEq(
            manager.getExtensionImplementation(
                extensionToRemove,
                RevolutionBuilderTypesV1.ImplementationType.SplitsCreator
            ),
            address(0),
            "SplitsCreator implementation mismatch"
        );

        // assert builder rewards address is address(0)
        assertEq(manager.getExtensionBuilder(extensionToRemove), address(0), "Builder rewards address mismatch");
    }

    function test__DeployExtension() public {
        string memory extensionName = "gnosis.avatar.executor";

        addBasicExtension(extensionName);

        address initialOwner = address(0x123);
        address weth = address(0x456);

        IRevolutionBuilder.ExtensionData memory extensionData = IRevolutionBuilder.ExtensionData({
            name: extensionName,
            executorInitializationData: ""
        });

        RevolutionBuilderStorageV1.DAOAddresses memory daoAddresses = manager.deployExtension(
            initialOwner,
            weth,
            revolutionTokenParams,
            auctionParams,
            govParams,
            cultureIndexParams,
            revolutionPointsParams,
            revolutionVotingPowerParams,
            extensionData
        );

        assertTrue(daoAddresses.dao != address(0), "DAO address should not be zero");
        assertTrue(daoAddresses.executor != address(0), "Executor address should not be zero");
        assertTrue(daoAddresses.vrgda != address(0), "VRGDA address should not be zero");
        assertTrue(daoAddresses.descriptor != address(0), "Descriptor address should not be zero");
        assertTrue(daoAddresses.auction != address(0), "Auction address should not be zero");
        assertTrue(daoAddresses.cultureIndex != address(0), "CultureIndex address should not be zero");
        assertTrue(daoAddresses.maxHeap != address(0), "MaxHeap address should not be zero");
        assertTrue(daoAddresses.revolutionPoints != address(0), "RevolutionPoints address should not be zero");
        assertTrue(
            daoAddresses.revolutionPointsEmitter != address(0),
            "RevolutionPointsEmitter address should not be zero"
        );
        assertTrue(daoAddresses.revolutionToken != address(0), "RevolutionToken address should not be zero");
        assertTrue(
            daoAddresses.revolutionVotingPower != address(0),
            "RevolutionVotingPower address should not be zero"
        );
        assertTrue(daoAddresses.splitsCreator != address(0), "SplitsCreator address should not be zero");

        // check extensionByToken is extensionName
        assertEq(
            manager.getExtensionByToken(daoAddresses.revolutionToken),
            extensionName,
            "Extension by token mismatch"
        );
    }

    function test__DeployInvalidExtension() public {
        string memory extensionName = "gnosis.avatar.executor";

        addBasicExtension(extensionName);

        address initialOwner = address(0x123);
        address weth = address(0x456);

        IRevolutionBuilder.ExtensionData memory extensionData = IRevolutionBuilder.ExtensionData({
            name: "invalid",
            executorInitializationData: ""
        });

        vm.expectRevert(abi.encodeWithSignature("INVALID_EXTENSION()"));
        RevolutionBuilderStorageV1.DAOAddresses memory daoAddresses = manager.deployExtension(
            initialOwner,
            weth,
            revolutionTokenParams,
            auctionParams,
            govParams,
            cultureIndexParams,
            revolutionPointsParams,
            revolutionVotingPowerParams,
            extensionData
        );

        assertTrue(daoAddresses.dao == address(0), "DAO address should not be zero");
    }
}
