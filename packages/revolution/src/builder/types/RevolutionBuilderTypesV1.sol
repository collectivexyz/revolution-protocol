// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

/// @title RevolutionBuilderTypesV1
/// @author rocketman
/// @notice The external Base Metadata errors and functions
interface RevolutionBuilderTypesV1 {
    /// @notice Stores deployed addresses for a given token's DAO
    struct DAOAddresses {
        /// @notice Address for deployed metadata contract
        address descriptor;
        /// @notice Address for deployed auction contract
        address auction;
        /// @notice Address for deployed auction contract
        address revolutionPointsEmitter;
        /// @notice Address for deployed auction contract
        address revolutionPoints;
        /// @notice Address for deployed cultureIndex contract
        address cultureIndex;
        /// @notice Address for deployed executor (treasury) contract
        address executor;
        /// @notice Address for deployed DAO contract
        address dao;
        /// @notice Address for deployed ERC-721 token contract
        address revolutionToken;
        /// @notice Address for deployed MaxHeap contract
        address maxHeap;
        /// @notice Address for deployed RevolutionVotingPower contract
        address revolutionVotingPower;
        /// @notice Address for deployed VRGDA contract
        address vrgda;
        /// @notice Address for the deployed splits factory contract
        address splitsCreator;
    }

    struct InitialProxySetup {
        address revolutionToken;
        address executor;
        address revolutionVotingPower;
        address revolutionPointsEmitter;
        address dao;
        bytes32 salt;
    }

    enum ImplementationType {
        DAO,
        Executor,
        VRGDAC,
        Descriptor,
        Auction,
        CultureIndex,
        MaxHeap,
        RevolutionPoints,
        RevolutionPointsEmitter,
        RevolutionToken,
        RevolutionVotingPower,
        SplitsCreator
    }
}
