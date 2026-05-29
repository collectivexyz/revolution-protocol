// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import { IWETH } from "./interfaces/IWETH.sol";
import { IVRGDAC } from "./interfaces/IVRGDAC.sol";
import { IRevolutionPoints } from "./interfaces/IRevolutionPoints.sol";
import { IRevolutionPointsEmitter } from "./interfaces/IRevolutionPointsEmitter.sol";
import { IRevolutionBuilder } from "./interfaces/IRevolutionBuilder.sol";

import { RevolutionRewards } from "@cobuild/protocol-rewards/src/abstract/RevolutionRewards.sol";

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { RevolutionVersion } from "./version/RevolutionVersion.sol";
import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";
import { UUPS } from "@cobuild/utility-contracts/src/proxy/UUPS.sol";

import { toDaysWadUnsafe, wadDiv, wadMul } from "./libs/SignedWadMath.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract RevolutionPointsEmitter is
    IRevolutionPointsEmitter,
    RevolutionVersion,
    UUPS,
    ReentrancyGuardUpgradeable,
    RevolutionRewards,
    Ownable2StepUpgradeable,
    PausableUpgradeable
{
    // The address of the WETH contract
    address public WETH;

    // The token that is being minted.
    IRevolutionPoints public token;

    // The VRGDA contract
    IVRGDAC public vrgda;

    // solhint-disable-next-line not-rely-on-time
    uint256 public startTime;

    // The split of the purchase that is reserved for the founder in basis points
    uint256 public founderRateBps;

    // The split of (purchase proceeds * founderRateBps) that is sent to the founder as ether in basis points
    uint256 public founderEntropyRateBps;

    // The account or contract to pay the founder reward to
    address public founderAddress;

    // The timestamp in seconds after which the founders reward stops being paid
    uint256 public founderRewardsExpirationDate;

    // The account to pay grants funds to
    address public grantsAddress;

    // Split of purchase proceeds sent to the grants system as ether in basis points
    uint256 public grantsRateBps;

    // Historical purchases by account - tracks amount spent
    mapping(address => IRevolutionPointsEmitter.AccountPurchaseHistory) public purchaseHistory;

    /// --------------------------------------------------------
    ///                      PRICE FLOOR                      ///
    /// --------------------------------------------------------

    /// @notice Hard lower-bound on effective price per token (in wei).
    uint256 public minPriceWei;

    ///                                                          ///
    ///                         IMMUTABLES                       ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IUpgradeManager private immutable manager;

    ///                                                          ///
    ///                         CONSTRUCTOR                      ///
    ///                                                          ///

    /// @param _manager The contract upgrade manager address
    /// @param _protocolRewards The protocol rewards contract address
    /// @param _protocolFeeRecipient The protocol fee recipient address
    constructor(
        address _manager,
        address _protocolRewards,
        address _protocolFeeRecipient
    ) payable RevolutionRewards(_protocolRewards, _protocolFeeRecipient) initializer {
        if (_manager == address(0)) revert ADDRESS_ZERO();
        if (_protocolRewards == address(0)) revert ADDRESS_ZERO();
        if (_protocolFeeRecipient == address(0)) revert ADDRESS_ZERO();

        manager = IUpgradeManager(_manager);
    }

    ///                                                          ///
    ///                         INITIALIZER                      ///
    ///                                                          ///

    /**
     * @notice Initialize the points emitter
     * @param _initialOwner The initial owner of the points emitter
     * @param _weth The address of the WETH contract
     * @param _revolutionPoints The ERC-20 token contract address
     * @param _vrgda The VRGDA contract address
     * @param _minPriceWei The minimum price of the token in wei
     * @param _founderParams The founder reward parameters
     * @param _grantsParams The grants reward parameters
     */
    function initialize(
        address _initialOwner,
        address _weth,
        address _revolutionPoints,
        address _vrgda,
        uint256 _minPriceWei,
        IRevolutionBuilder.FounderParams calldata _founderParams,
        IRevolutionBuilder.GrantsParams calldata _grantsParams
    ) external initializer {
        if (msg.sender != address(manager)) revert NOT_MANAGER();
        if (_initialOwner == address(0)) revert ADDRESS_ZERO();
        if (_revolutionPoints == address(0)) revert ADDRESS_ZERO();
        if (_vrgda == address(0)) revert ADDRESS_ZERO();
        if (_weth == address(0)) revert ADDRESS_ZERO();

        if (_founderParams.totalRateBps > 10_000) revert INVALID_BPS();
        if (_founderParams.entropyRateBps > 10_000) revert INVALID_BPS();
        if (_founderParams.rewardsExpirationDate < block.timestamp) revert INVALID_REWARDS_TIMESTAMP();

        if (_grantsParams.totalRateBps > 10_000) revert INVALID_BPS();

        if (_grantsParams.totalRateBps + _founderParams.totalRateBps > 10_000) revert INVALID_BPS();

        if (_minPriceWei == 0) revert MIN_PRICE_ZERO();

        __Pausable_init();
        __ReentrancyGuard_init();

        // Set up ownable
        __Ownable_init(_initialOwner);

        // Set founder params if not already set
        // So an upgrade can't change the founder params
        if (founderAddress == address(0)) {
            founderAddress = _founderParams.founderAddress;
        }
        if (founderRewardsExpirationDate == 0) {
            founderRewardsExpirationDate = _founderParams.rewardsExpirationDate;
        }
        if (founderRateBps == 0) {
            founderRateBps = _founderParams.totalRateBps;
        }
        if (founderEntropyRateBps == 0) {
            founderEntropyRateBps = _founderParams.entropyRateBps;
        }

        grantsAddress = _grantsParams.grantsAddress;

        grantsRateBps = _grantsParams.totalRateBps;

        minPriceWei = _minPriceWei;

        vrgda = IVRGDAC(_vrgda);
        token = IRevolutionPoints(_revolutionPoints);
        WETH = _weth;

        // If we are upgrading, don't reset the start time
        if (startTime == 0) startTime = block.timestamp;
    }

    function _mint(address _to, uint256 _amount) private {
        token.mint(_to, _amount);
    }

    function totalSupply() public view returns (uint) {
        // returns total supply issued so far
        return token.totalSupply();
    }

    function decimals() public view returns (uint8) {
        // returns decimals
        return token.decimals();
    }

    function balanceOf(address _owner) public view returns (uint) {
        // returns balance of address
        return token.balanceOf(_owner);
    }

    /**
     * @notice Pause the contract.
     * @dev This function can only be called by the owner when the
     * contract is unpaused.
     */
    function pause() external override onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the points emitter.
     * @dev This function can only be called by the owner when the
     * contract is paused.
     */
    function unpause() external override onlyOwner {
        _unpause();
    }

    /**
     * @notice A function to calculate the shares of the purchase that go to the buyer's governance purchase, and the founder
     * @param msgValueRemaining The amount of ether left after protocol rewards are taken out
     * @return buyTokenPaymentShares A struct containing the shares of the purchase that go to the buyer's governance purchase, and the founder
     */
    function _calculateBuyTokenPaymentShares(
        uint256 msgValueRemaining
    ) internal view returns (BuyTokenPaymentShares memory buyTokenPaymentShares) {
        // Ether to send to the grants program
        buyTokenPaymentShares.grantsDirectPayment = (msgValueRemaining * grantsRateBps) / 10_000;

        // Founder no longer receives any rewards
        if (block.timestamp >= founderRewardsExpirationDate) {
            // Share of purchase amount reserved for buyers
            buyTokenPaymentShares.buyersGovernancePayment =
                msgValueRemaining -
                buyTokenPaymentShares.grantsDirectPayment;
        }

        // Founder should receive rewards
        if (block.timestamp < founderRewardsExpirationDate) {
            // Founder receives rewards per founderRateBps and founderEntropyRateBps
            uint256 founderRate = founderRateBps;

            // Share of purchase amount reserved for buyers
            buyTokenPaymentShares.buyersGovernancePayment =
                msgValueRemaining -
                ((msgValueRemaining * founderRate) / 10_000) -
                buyTokenPaymentShares.grantsDirectPayment;

            // Ether directly sent to founder
            buyTokenPaymentShares.founderDirectPayment =
                (msgValueRemaining * founderRate * founderEntropyRateBps) /
                10_000 /
                10_000;

            // Ether spent on founder governance tokens
            buyTokenPaymentShares.founderGovernancePayment =
                ((msgValueRemaining * founderRate) / 10_000) -
                buyTokenPaymentShares.founderDirectPayment;
        }
    }

    function _calculatePaymentDistribution(
        uint256 founderGovernanceTokens,
        IRevolutionPointsEmitter.BuyTokenPaymentShares memory buyTokenPaymentShares
    ) internal pure returns (PaymentDistribution memory distribution) {
        // Ether to pay owner() for selling us tokens
        distribution.toPayOwner = buyTokenPaymentShares.buyersGovernancePayment;
        // Ether to pay founder directly
        distribution.toPayFounder = buyTokenPaymentShares.founderDirectPayment;

        // If the founder is not receiving any tokens, but ETH should be spent to buy them tokens, just send the ETH to the founder
        if (founderGovernanceTokens == 0 && buyTokenPaymentShares.founderGovernancePayment > 0) {
            distribution.toPayFounder += buyTokenPaymentShares.founderGovernancePayment;
        } else {
            // If the founder is receiving tokens, add the founder's tokens payment to the owner's payment
            distribution.toPayOwner += buyTokenPaymentShares.founderGovernancePayment;
        }

        return distribution;
    }

    /**
     * @dev Helper that applies the price-floor logic and computes the final token allocations and ETH distribution.
     * @param timeSinceStart Days (wad) since emissions began.
     * @param buyTokenPaymentShares Struct returned by _calculateBuyTokenPaymentShares.
     * @return totalTokensForFounder Number of tokens to mint to the founder.
     * @return totalTokensForBuyers Number of tokens to mint collectively to buyers.
     * @return distribution  Struct describing how ETH is split between owner & founder.
     */
    function _applyPriceFloorAndGetDistribution(
        int256 timeSinceStart,
        BuyTokenPaymentShares memory buyTokenPaymentShares
    )
        internal
        view
        returns (uint256 totalTokensForFounder, uint256 totalTokensForBuyers, PaymentDistribution memory distribution)
    {
        // ------- Founder governance tokens (pre-clamp) -------
        int256 rawFounder = buyTokenPaymentShares.founderGovernancePayment > 0
            ? vrgda.yToX({
                timeSinceStart: timeSinceStart,
                sold: token.totalSupply().toInt256(),
                amount: buyTokenPaymentShares.founderGovernancePayment.toInt256()
            })
            : int256(0);

        // Maximum founder tokens allowed by price floor
        int256 maxFounder = int256(
            wadDiv(buyTokenPaymentShares.founderGovernancePayment.toInt256(), minPriceWei.toInt256())
        );

        int256 founderTokens = rawFounder > maxFounder ? maxFounder : rawFounder;

        // -------- Buyer governance tokens (pre-clamp) --------
        int256 rawBuyers = buyTokenPaymentShares.buyersGovernancePayment > 0
            ? vrgda.yToX({
                // Include clamped founder tokens in supply parameter
                timeSinceStart: timeSinceStart,
                sold: token.totalSupply().toInt256() + founderTokens,
                amount: buyTokenPaymentShares.buyersGovernancePayment.toInt256()
            })
            : int256(0);

        // Maximum buyer tokens allowed by price floor
        int256 maxBuyers = int256(
            wadDiv(buyTokenPaymentShares.buyersGovernancePayment.toInt256(), minPriceWei.toInt256())
        );

        int256 buyersTokens = rawBuyers > maxBuyers ? maxBuyers : rawBuyers;

        totalTokensForFounder = uint256(founderTokens);
        totalTokensForBuyers = uint256(buyersTokens);

        distribution = _calculatePaymentDistribution(totalTokensForFounder, buyTokenPaymentShares);
    }

    /**
     * @notice A payable function that allows a user to buy tokens for a list of addresses and a list of basis points to split the token purchase between.
     * @param addresses The addresses to send purchased tokens to.
     * @param basisPointSplits The basis points of the purchase to send to each address.
     * @param protocolRewardsRecipients The addresses to pay the builder, purchaseReferral, and deployer rewards to
     * @return tokensSoldWad The amount of tokens sold in wad units.
     */
    function buyToken(
        address[] calldata addresses,
        uint[] calldata basisPointSplits,
        ProtocolRewardAddresses calldata protocolRewardsRecipients
    ) public payable nonReentrant whenNotPaused returns (uint256 tokensSoldWad) {
        // Prevent owner and founderAddress from buying tokens directly, given they are recipient(s) of the funds
        if (msg.sender == owner() || msg.sender == founderAddress) revert FUNDS_RECIPIENT_CANNOT_BUY_TOKENS();

        // Transaction must send ether to buyTokens
        if (msg.value == 0) revert INVALID_PAYMENT();

        // Ensure the same number of addresses and bps
        if (addresses.length != basisPointSplits.length) revert PARALLEL_ARRAYS_REQUIRED();

        // Calculate payment shares for each recipient
        BuyTokenPaymentShares memory buyTokenPaymentShares = _calculateBuyTokenPaymentShares(
            msg.value - computeTotalReward(msg.value)
        );

        // -----------------------------------------------------
        //  PRICE FLOOR CALCULATION
        // -----------------------------------------------------

        int256 timeSinceStart = toDaysWadUnsafe(block.timestamp - startTime);

        // Calculate the amount of ether to pay the founder and owner
        (
            uint256 totalTokensForFounder,
            uint256 totalTokensForBuyers,
            PaymentDistribution memory paymentDistribution
        ) = _applyPriceFloorAndGetDistribution(timeSinceStart, buyTokenPaymentShares);

        // Stores total bps, ensure it is 10_000 later
        uint256 bpsSum = 0;
        uint256 addressesLength = addresses.length;

        // Save cost basis for recipients
        for (uint256 i = 0; i < addressesLength; i++) {
            _savePurchaseHistory(
                addresses[i],
                (totalTokensForBuyers * basisPointSplits[i]) / 10_000,
                (buyTokenPaymentShares.buyersGovernancePayment * basisPointSplits[i]) / 10_000
            );

            bpsSum = bpsSum + basisPointSplits[i];
        }

        if (bpsSum != 10_000) revert INVALID_BPS_SUM();

        // Share protocol rewards
        _handleRewardsAndGetValueToSend(
            msg.value,
            protocolRewardsRecipients.builder,
            protocolRewardsRecipients.purchaseReferral,
            protocolRewardsRecipients.deployer
        );

        // Transfer ETH to owner
        if (paymentDistribution.toPayOwner > 0) {
            _safeTransferETHWithFallback(owner(), paymentDistribution.toPayOwner);
        }

        // Transfer ETH to grants program
        if (buyTokenPaymentShares.grantsDirectPayment > 0) {
            _safeTransferETHWithFallback(grantsAddress, buyTokenPaymentShares.grantsDirectPayment);
        }

        // Transfer ETH to founder
        if (paymentDistribution.toPayFounder > 0) {
            _safeTransferETHWithFallback(founderAddress, paymentDistribution.toPayFounder);
        }

        // Mint tokens to founder
        if (totalTokensForFounder > 0) {
            _mint(founderAddress, totalTokensForFounder);
        }

        // Mint tokens to buyers
        if (totalTokensForBuyers > 0) {
            for (uint256 i = 0; i < addressesLength; i++) {
                _mint(addresses[i], (totalTokensForBuyers * basisPointSplits[i]) / 10_000);
            }
        }

        emit PurchaseFinalized(
            msg.sender,
            msg.value,
            paymentDistribution.toPayOwner,
            computeTotalReward(msg.value),
            totalTokensForBuyers,
            totalTokensForFounder,
            paymentDistribution.toPayFounder,
            buyTokenPaymentShares.grantsDirectPayment
        );

        return totalTokensForBuyers;
    }

    /**
     * @notice Save purchase history details for an account including tokens bought, ether sent to owner
     * @param _account The account to save purchase history for
     * @param _tokensBoughtForAccount The amount of tokens bought for the account
     * @param _etherToOwnerForAccount The amount of ether spent to buy the tokens for the account (sent to owner)
     */
    function _savePurchaseHistory(
        address _account,
        uint256 _tokensBoughtForAccount,
        uint256 _etherToOwnerForAccount
    ) internal {
        AccountPurchaseHistory memory recipientHistory = purchaseHistory[_account];

        // save tokens minted to account purchase history
        purchaseHistory[_account].tokensBought = recipientHistory.tokensBought + _tokensBoughtForAccount;

        // save amount paid to owner for tokens for recipient
        purchaseHistory[_account].amountPaidToOwner = recipientHistory.amountPaidToOwner + _etherToOwnerForAccount;
    }

    /**
     * @notice Returns the amount of wei that would be spent to buy an amount of tokens. Does not take into account the protocol rewards.
     * @param amount the amount of tokens to buy.
     * @return spentY The cost in wei of the token purchase.
     */
    function buyTokenQuote(uint256 amount) external view returns (int spentY) {
        if (amount == 0) revert INVALID_AMOUNT();
        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        int256 raw = vrgda.xToY({
            timeSinceStart: toDaysWadUnsafe(block.timestamp - startTime),
            sold: token.totalSupply().toInt256(),
            amount: amount.toInt256()
        });

        int256 minimum = wadMul(amount.toInt256(), minPriceWei.toInt256());

        return raw < minimum ? minimum : raw;
    }

    /**
     * @notice Returns the amount of tokens that would be emitted for an amount of wei. Does not take into account the protocol rewards.
     * @param etherAmount the payment amount in wei.
     * @return gainedX The amount of tokens that would be emitted for the payment amount.
     */
    function getTokenQuoteForEther(uint256 etherAmount) external view returns (int gainedX) {
        if (etherAmount == 0) revert INVALID_PAYMENT();
        int256 raw = vrgda.yToX({
            timeSinceStart: toDaysWadUnsafe(block.timestamp - startTime),
            sold: token.totalSupply().toInt256(),
            amount: etherAmount.toInt256()
        });

        int256 maxTokens = wadDiv(etherAmount.toInt256(), minPriceWei.toInt256());

        return raw > maxTokens ? maxTokens : raw;
    }

    /**
     * @notice Returns the amount of tokens that would be emitted to a buyer for the payment amount, taking into account the protocol rewards and founder rate.
     * @param paymentAmount the payment amount in wei.
     * @return gainedX The amount of tokens that would be emitted for the payment amount.
     */
    function getTokenQuoteForPayment(uint256 paymentAmount) external view returns (int gainedX) {
        if (paymentAmount == 0) revert INVALID_PAYMENT();

        BuyTokenPaymentShares memory buyTokenPaymentShares = _calculateBuyTokenPaymentShares(
            paymentAmount - computeTotalReward(paymentAmount)
        );

        int256 timeSinceStart = toDaysWadUnsafe(block.timestamp - startTime);

        // Founder gets paid governance shares first
        int256 forFounder = buyTokenPaymentShares.founderGovernancePayment > 0
            ? vrgda.yToX({
                timeSinceStart: timeSinceStart,
                sold: token.totalSupply().toInt256(),
                amount: buyTokenPaymentShares.founderGovernancePayment.toInt256()
            })
            : int(0);

        // -------------- Apply price floor --------------

        // Clamp founder tokens
        int256 maxFounder = wadDiv(buyTokenPaymentShares.founderGovernancePayment.toInt256(), minPriceWei.toInt256());
        forFounder = forFounder > maxFounder ? maxFounder : forFounder;

        // Buyer tokens raw
        int256 rawBuyers = vrgda.yToX({
            timeSinceStart: timeSinceStart,
            // Include clamped founder tokens in supply
            sold: token.totalSupply().toInt256() + forFounder,
            amount: buyTokenPaymentShares.buyersGovernancePayment.toInt256()
        });

        int256 maxBuyers = wadDiv(buyTokenPaymentShares.buyersGovernancePayment.toInt256(), minPriceWei.toInt256());

        int256 buyersTokens = rawBuyers > maxBuyers ? maxBuyers : rawBuyers;

        return buyersTokens;
    }

    /**
     * @notice Set the split of the payment that is reserved for grants program in basis points.
     * @dev Only callable by the owner.
     * @param _grantsRateBps New grants rate in basis points.
     */
    function setGrantsRateBps(uint256 _grantsRateBps) external onlyOwner nonReentrant {
        if (_grantsRateBps > 10_000) revert INVALID_BPS();
        if (_grantsRateBps + founderRateBps > 10_000) revert INVALID_BPS();

        emit GrantsRateBpsUpdated(grantsRateBps = _grantsRateBps);
    }

    /**
     * @notice Set the grants address to pay the grantsRate to. Can be a contract.
     * @dev Only callable by the owner.
     */
    function setGrantsAddress(address _grantsAddress) external override onlyOwner nonReentrant {
        emit GrantsAddressUpdated(grantsAddress = _grantsAddress);
    }

    /**
    @notice Transfer ETH/WETH from the contract
    @param _to The recipient address
    @param _amount The amount transferring
    */
    // Assumption + reason for ignoring: Since this function is called in the buyToken public function, but buyToken sends ETH to only owner and founderAddress, this function is safe
    // slither-disable-next-line arbitrary-send-eth
    function _safeTransferETHWithFallback(address _to, uint256 _amount) private {
        // Ensure the contract has enough ETH to transfer
        if (address(this).balance < _amount) revert INSUFFICIENT_BALANCE();

        // Used to store if the transfer succeeded
        bool success;

        assembly {
            // Transfer ETH to the recipient
            // Limit the call to 50,000 gas
            success := call(50000, _to, _amount, 0, 0, 0, 0)
        }

        // If the transfer failed:
        if (!success) {
            // Wrap as WETH
            IWETH(WETH).deposit{ value: _amount }();

            // Transfer WETH instead
            bool wethSuccess = IWETH(WETH).transfer(_to, _amount);

            // Ensure successful transfer
            if (!wethSuccess) revert WETH_TRANSFER_FAILED();
        }
    }

    /**
     * @notice Get the associated purchase data for an account including tokens bought, amount paid to owner
     * @param _account The account to get purchase history for
     * @return AccountPurchaseHistory The purchase history for the account
     */
    function getAccountPurchaseHistory(
        address _account
    ) external view override returns (AccountPurchaseHistory memory) {
        return purchaseHistory[_account];
    }

    ///                 PRICE FLOOR MANAGEMENT                  ///
    ///                                                          ///

    function setMinPriceWei(uint256 _newMinPriceWei) external onlyOwner nonReentrant {
        if (_newMinPriceWei == 0) revert MIN_PRICE_ZERO();

        minPriceWei = _newMinPriceWei;
        emit MinPriceUpdated(_newMinPriceWei);
    }

    ///                 POINTS EMITTER UPGRADE                   ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract and that the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner {
        // Ensure the new implementation is a registered upgrade
        if (!manager.isRegisteredUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }

    // Attach SafeCast helpers for uint256 ➜ int256 conversions
    using SafeCast for uint256;
}
