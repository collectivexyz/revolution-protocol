// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { IRevolutionBuilder } from "./IRevolutionBuilder.sol";
import { IGrantsRevenueStream } from "./IGrantsRevenueStream.sol";
import { IVRGDAC } from "./IVRGDAC.sol";
import { IRewardSplits } from "@cobuild/protocol-rewards/src/interfaces/IRewardSplits.sol";

interface IRevolutionPointsEmitter is IGrantsRevenueStream, IRewardSplits {
    ///                                                          ///
    ///                           ERRORS                         ///
    ///                                                          ///

    /// @dev Reverts if the function caller is not the manager.
    error NOT_MANAGER();

    /// @dev Reverts if address 0 is passed but not allowed
    error ADDRESS_ZERO();

    /// @dev Reverts if invalid BPS is passed
    error INVALID_BPS();

    /// @dev Reverts if BPS does not add up to 10_000
    error INVALID_BPS_SUM();

    /// @dev Reverts if payment amount is 0
    error INVALID_PAYMENT();

    /// @dev Reverts if amount is 0
    error INVALID_AMOUNT();

    /// @dev Reverts if there is an array length mismatch
    error PARALLEL_ARRAYS_REQUIRED();

    /// @dev Reverts if the buyToken sender is the owner or creatorsAddress
    error FUNDS_RECIPIENT_CANNOT_BUY_TOKENS();

    /// @dev Reverts if insufficient balance to transfer
    error INSUFFICIENT_BALANCE();

    /// @dev Reverts if the WETH transfer fails
    error WETH_TRANSFER_FAILED();

    /// @dev Reverts if invalid rewards timestamp is passed
    error INVALID_REWARDS_TIMESTAMP();

    struct BuyTokenPaymentShares {
        uint256 buyersGovernancePayment;
        uint256 founderDirectPayment;
        uint256 founderGovernancePayment;
        uint256 grantsDirectPayment;
    }

    // To find amount of ether to pay founder and owner after calculating the amount of points to emit
    struct PaymentDistribution {
        uint256 toPayOwner;
        uint256 toPayFounder;
    }

    struct ProtocolRewardAddresses {
        address builder;
        address purchaseReferral;
        address deployer;
    }

    struct AccountPurchaseHistory {
        // The amount of tokens bought
        uint256 tokensBought;
        // The amount paid to owner()
        uint256 amountPaidToOwner;
    }

    function buyToken(
        address[] calldata addresses,
        uint[] calldata bps,
        ProtocolRewardAddresses calldata protocolRewardsRecipients
    ) external payable returns (uint256);

    function WETH() external view returns (address);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function founderAddress() external view returns (address);

    function startTime() external view returns (uint256);

    function vrgda() external view returns (IVRGDAC);

    function founderRateBps() external view returns (uint256);

    function founderEntropyRateBps() external view returns (uint256);

    function founderRewardsExpirationDate() external view returns (uint256);

    function getTokenQuoteForPayment(uint256 paymentAmount) external returns (int256);

    function getTokenQuoteForEther(uint256 etherAmount) external returns (int256);

    function pause() external;

    function unpause() external;

    function getAccountPurchaseHistory(address account) external view returns (AccountPurchaseHistory memory);

    event PurchaseFinalized(
        address indexed buyer,
        uint256 payment,
        uint256 ownerAmount,
        uint256 protocolRewardsAmount,
        uint256 buyerTokensEmitted,
        uint256 founderTokensEmitted,
        uint256 founderDirectPayment,
        uint256 grantsDirectPayment
    );

    /**
     * @notice Initialize the points emitter
     * @param initialOwner The initial owner of the points emitter
     * @param weth The address of the WETH contract.
     * @param revolutionPoints The ERC-20 token contract address
     * @param vrgda The VRGDA contract address
     * @param founderParams The founder rewards parameters
     * @param grantsParams The grants rewards parameters
     */
    function initialize(
        address initialOwner,
        address weth,
        address revolutionPoints,
        address vrgda,
        IRevolutionBuilder.FounderParams calldata founderParams,
        IRevolutionBuilder.GrantsParams calldata grantsParams
    ) external;
}
