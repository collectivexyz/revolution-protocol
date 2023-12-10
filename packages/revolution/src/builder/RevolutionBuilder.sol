// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/// @title The Revolution builder contract

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

// LICENSE
// RevolutionBuilder.sol is a modified version of Nouns Builder's Manager.sol:
// https://github.com/ourzora/nouns-protocol/blob/82e00ed34dd9b7c9e1ac5eea29f7f713d1084e68/src/manager/Manager.sol
//
// Manager.sol source code under the MIT license.

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import { RevolutionBuilderStorageV1 } from "./storage/RevolutionBuilderStorageV1.sol";
import { IRevolutionBuilder } from "../interfaces/IRevolutionBuilder.sol";
import { IVerbsToken } from "../interfaces/IVerbsToken.sol";
import { IVerbsDescriptor } from "../interfaces/IVerbsDescriptor.sol";
import { IVerbsAuctionHouse } from "../interfaces/IVerbsAuctionHouse.sol";
import { IVerbsDAOExecutor } from "../interfaces/IVerbsDAOExecutor.sol";
import { IVerbsDAO } from "../interfaces/IVerbsDAO.sol";


import { ERC1967Proxy } from "../libs/proxy/ERC1967Proxy.sol";

import { VersionedContract } from "../version/VersionedContract.sol";
import { IVersionedContract } from "../interfaces/IVersionedContract.sol";

/// @title RevolutionBuilder
/// @notice The Revolution DAO deployer and upgrade manager
contract RevolutionBuilder is
    IRevolutionBuilder,
    VersionedContract,
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    RevolutionBuilderStorageV1
{
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The token implementation address
    address public immutable tokenImpl;

    /// @notice The descriptor implementation address
    address public immutable descriptorImpl;

    /// @notice The auction house implementation address
    address public immutable auctionImpl;

    /// @notice The executor implementation address
    address public immutable executorImpl;

    /// @notice The dao implementation address
    address public immutable daoImpl;

    /// @notice The erc20TokenEmitter implementation address
    address public immutable erc20TokenEmitterImpl;

    /// @notice The cultureIndex implementation address
    address public immutable cultureIndexImpl;

    /// @notice The erc20Token implementation address
    address public immutable erc20TokenImpl;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    constructor(
        address _tokenImpl,
        address _descriptorImpl,
        address _auctionImpl,
        address _executorImpl,
        address _daoImpl,
        address _erc20TokenEmitterImpl,
        address _cultureIndexImpl,
        address _erc20TokenImpl
    ) payable initializer {
        tokenImpl = _tokenImpl;
        descriptorImpl = _descriptorImpl;
        auctionImpl = _auctionImpl;
        executorImpl = _executorImpl;
        daoImpl = _daoImpl;
        erc20TokenEmitterImpl = _erc20TokenEmitterImpl;
        cultureIndexImpl = _cultureIndexImpl;
        erc20TokenImpl = _erc20TokenImpl;
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Initializes ownership of the manager contract
    /// @param _newOwner The owner address to set (will be transferred to the Builder DAO once its deployed)
    function initialize(address _newOwner) external initializer {
        // Ensure an owner is specified
        require(_newOwner != address(0), "Owner address cannot be 0x0");

        // Set the contract owner
        __Ownable_init(_newOwner);
    }

    ///                                                          ///
    ///                           DAO DEPLOY                     ///
    ///                                                          ///

    /// @notice Deploys a DAO with custom token, auction, and governance settings
    /// @param _initialOwner The initial owner address
    /// @param _tokenParams The ERC-721 token settings
    /// @param _auctionParams The auction settings
    /// @param _govParams The governance settings
    function deploy(
        address _initialOwner,
        ERC721TokenParams calldata _tokenParams,
        AuctionParams calldata _auctionParams,
        GovParams calldata _govParams,
        CultureIndexParams calldata _cultureIndexParams,
        ERC20TokenParams calldata _erc20TokenParams,
        ERC20TokenEmitterParams calldata _erc20TokenEmitterParams
    )
        external
        returns (
            address token,
            address descriptor,
            address auction,
            address executor,
            address dao,
            address erc20Token,
            address cultureIndex,
            address erc20TokenEmitter
        )
    {
        // Used to store the address of the first (or only) founder
        // This founder is responsible for adding token artwork and launching the first auction -- they're also free to transfer this responsiblity
        address founder;

        // Ensure at least one founder is provided
        require((founder = _initialOwner) != address(0), "Initial owner cannot be 0x0");

        // Deploy the DAO's ERC-721 governance token
        token = address(new ERC1967Proxy(tokenImpl, ""));

        // Use the token address to precompute the DAO's remaining addresses
        bytes32 salt = bytes32(uint256(uint160(token)) << 96);

        // Deploy the remaining DAO contracts
        descriptor = address(new ERC1967Proxy{ salt: salt }(descriptorImpl, ""));
        auction = address(new ERC1967Proxy{ salt: salt }(auctionImpl, ""));
        executor = address(new ERC1967Proxy{ salt: salt }(executorImpl, ""));
        dao = address(new ERC1967Proxy{ salt: salt }(daoImpl, ""));
        cultureIndex = address(new ERC1967Proxy{ salt: salt }(cultureIndexImpl, ""));
        erc20Token = address(new ERC1967Proxy{ salt: salt }(erc20TokenImpl, ""));
        erc20TokenEmitter = address(new ERC1967Proxy{ salt: salt }(erc20TokenEmitter, ""));

        daoAddressesByToken[token] = DAOAddresses({
            descriptor: descriptor,
            auction: auction,
            executor: executor,
            dao: dao,
            erc20TokenEmitter: erc20TokenEmitter,
            cultureIndex: cultureIndex,
            erc20Token: erc20Token
        });

        // Initialize each instance with the provided settings
        IVerbsToken(token).initialize({
            minter: auction,
            descriptor: descriptor,
            initialOwner: founder,
            cultureIndex: cultureIndex,
            tokenParams: _tokenParams
        });
        // IVerbsDescriptor(descriptor).initialize({ initStrings: _tokenParams.initStrings, token: token });
        // IVerbsAuctionHouse(auction).initialize({
        //     token: token,
        //     founder: founder,
        //     executor: executor,
        //     duration: _auctionParams.duration,
        //     reservePrice: _auctionParams.reservePrice
        // });
        // IVerbsDAOExecutor(executor).initialize({ dao: dao, timelockDelay: _govParams.timelockDelay });
        // IVerbsDAO(dao).initialize({
        //     executor: executor,
        //     token: token,
        //     vetoer: _govParams.vetoer,
        //     votingDelay: _govParams.votingDelay,
        //     votingPeriod: _govParams.votingPeriod,
        //     proposalThresholdBps: _govParams.proposalThresholdBps,
        //     quorumThresholdBps: _govParams.quorumThresholdBps
        // });

        emit DAODeployed({
            token: token,
            descriptor: descriptor,
            auction: auction,
            executor: executor,
            dao: dao,
            erc20TokenEmitter: erc20TokenEmitter,
            cultureIndex: cultureIndex,
            erc20Token: erc20Token
        });
    }

    ///                                                          ///
    ///                         DAO ADDRESSES                    ///
    ///                                                          ///

    /// @notice A DAO's contract addresses from its token
    /// @param _token The ERC-721 token address
    /// @return descriptor Descriptor deployed address
    /// @return auction Auction deployed address
    /// @return executor Executor deployed address
    /// @return dao DAO deployed address
    /// @return cultureIndex CultureIndex deployed address
    /// @return erc20Token ERC-20 token deployed address
    /// @return erc20TokenEmitter ERC-20 token emitter deployed address
    function getAddresses(
        address _token
    )
        public
        view
        returns (
            address descriptor,
            address auction,
            address executor,
            address dao,
            address cultureIndex,
            address erc20Token,
            address erc20TokenEmitter
        )
    {
        DAOAddresses storage addresses = daoAddressesByToken[_token];

        descriptor = addresses.descriptor;
        auction = addresses.auction;
        executor = addresses.executor;
        dao = addresses.dao;

        cultureIndex = addresses.cultureIndex;
        erc20Token = addresses.erc20Token;
        erc20TokenEmitter = addresses.erc20TokenEmitter;
    }

    ///                                                          ///
    ///                          DAO UPGRADES                    ///
    ///                                                          ///

    /// @notice If an implementation is registered by the Builder DAO as an optional upgrade
    /// @param _baseImpl The base implementation address
    /// @param _upgradeImpl The upgrade implementation address
    function isRegisteredUpgrade(address _baseImpl, address _upgradeImpl) external view returns (bool) {
        return isUpgrade[_baseImpl][_upgradeImpl];
    }

    /// @notice Called by the Builder DAO to offer implementation upgrades for created DAOs
    /// @param _baseImpl The base implementation address
    /// @param _upgradeImpl The upgrade implementation address
    function registerUpgrade(address _baseImpl, address _upgradeImpl) external onlyOwner {
        isUpgrade[_baseImpl][_upgradeImpl] = true;

        emit UpgradeRegistered(_baseImpl, _upgradeImpl);
    }

    /// @notice Called by the Builder DAO to remove an upgrade
    /// @param _baseImpl The base implementation address
    /// @param _upgradeImpl The upgrade implementation address
    function removeUpgrade(address _baseImpl, address _upgradeImpl) external onlyOwner {
        delete isUpgrade[_baseImpl][_upgradeImpl];

        emit UpgradeRemoved(_baseImpl, _upgradeImpl);
    }

    /// @notice Safely get the contract version of a target contract.
    /// @dev Assume `target` is a contract
    /// @return Contract version if found, empty string if not.
    function _safeGetVersion(address target) internal view returns (string memory) {
        try IVersionedContract(target).contractVersion() returns (string memory version) {
            return version;
        } catch {
            return "";
        }
    }

    function getDAOVersions(address token) external view returns (DAOVersionInfo memory) {
        (address descriptor, address auction, address executor, address dao, address cultureIndex, address erc20Token, address erc20TokenEmitter) = getAddresses(token);
        return
            DAOVersionInfo({
                token: _safeGetVersion(token),
                descriptor: _safeGetVersion(descriptor),
                auction: _safeGetVersion(auction),
                executor: _safeGetVersion(executor),
                dao: _safeGetVersion(dao),
                erc20Token: _safeGetVersion(erc20Token),
                cultureIndex: _safeGetVersion(cultureIndex),
                erc20TokenEmitter: _safeGetVersion(erc20TokenEmitter)
            });
    }

    function getLatestVersions() external view returns (DAOVersionInfo memory) {
        return
            DAOVersionInfo({
                token: _safeGetVersion(tokenImpl),
                descriptor: _safeGetVersion(descriptorImpl),
                auction: _safeGetVersion(auctionImpl),
                executor: _safeGetVersion(executorImpl),
                dao: _safeGetVersion(daoImpl),
                cultureIndex: _safeGetVersion(cultureIndexImpl),
                erc20Token: _safeGetVersion(erc20TokenImpl),
                erc20TokenEmitter: _safeGetVersion(erc20TokenEmitterImpl)
            });
    }

    ///                                                          ///
    ///                         MANAGER UPGRADE                  ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {}
}
