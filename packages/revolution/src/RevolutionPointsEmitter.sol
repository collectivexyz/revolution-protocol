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

import { toDaysWadUnsafe } from "./libs/SignedWadMath.sol";

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
     * @param _founderParams The founder reward parameters
     * @param _grantsParams The grants reward parameters
     */
    function initialize(
        address _initialOwner,
        address _weth,
        address _revolutionPoints,
        address _vrgda,
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
     * @notice A payable function that allows a user to buy tokens for a list of addresses and a list of basis points to split the token purchase between.
     * @param addresses The addresses to send purchased tokens to.
     * @param basisPointSplits The basis points of the purchase to send to each address.
     * @param protocolRewardsRecipients The addresses to pay the builder, purchaseRefferal, and deployer rewards to
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

        // Calculate value left after sharing protocol rewards
        uint256 msgValueRemaining = _handleRewardsAndGetValueToSend(
            msg.value,
            protocolRewardsRecipients.builder,
            protocolRewardsRecipients.purchaseReferral,
            protocolRewardsRecipients.deployer
        );

        BuyTokenPaymentShares memory buyTokenPaymentShares = _calculateBuyTokenPaymentShares(msgValueRemaining);

        // Calculate tokens to emit to founder
        int256 totalTokensForFounder = buyTokenPaymentShares.founderGovernancePayment > 0
            ? getTokenQuoteForEther(buyTokenPaymentShares.founderGovernancePayment)
            : int(0);

        // Calculate the amount of ether to pay the founder and owner
        PaymentDistribution memory paymentDistribution = _calculatePaymentDistribution(
            uint256(totalTokensForFounder),
            buyTokenPaymentShares
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
            _mint(founderAddress, uint256(totalTokensForFounder));
        }

        // Stores total bps, ensure it is 10_000 later
        uint256 bpsSum = 0;
        uint256 addressesLength = addresses.length;

        // Tokens to mint to buyers
        // ENSURE we do this after minting to founder, so that the total supply is correct
        int256 totalTokensForBuyers = buyTokenPaymentShares.buyersGovernancePayment > 0
            ? getTokenQuoteForEther(buyTokenPaymentShares.buyersGovernancePayment)
            : int(0);

        //Mint tokens to buyers
        for (uint256 i = 0; i < addressesLength; i++) {
            if (totalTokensForBuyers > 0) {
                // save cost basis and average purchase block for recipient
                _savePurchaseHistory(
                    addresses[i],
                    uint256((totalTokensForBuyers * int(basisPointSplits[i])) / 10_000),
                    (buyTokenPaymentShares.buyersGovernancePayment * basisPointSplits[i]) / 10_000
                );

                // transfer tokens to address
                _mint(addresses[i], uint256((totalTokensForBuyers * int(basisPointSplits[i])) / 10_000));
            }
            bpsSum = bpsSum + basisPointSplits[i];
        }

        if (bpsSum != 10_000) revert INVALID_BPS_SUM();

        emit PurchaseFinalized(
            msg.sender,
            msg.value,
            paymentDistribution.toPayOwner,
            msg.value - msgValueRemaining,
            uint256(totalTokensForBuyers),
            uint256(totalTokensForFounder),
            paymentDistribution.toPayFounder,
            buyTokenPaymentShares.grantsDirectPayment
        );

        return uint256(totalTokensForBuyers);
    }

    /**
     * @notice Save purchase history details for an account including tokens bought, ether sent to owner, and average purchase block
     * @param _account The account to save purchase history for
     * @param _tokensBought The amount of tokens bought for the account
     * @param _etherToOwnerForAccountPurchase The amount of ether spent to buy the tokens for the account (sent to owner)
     */
    function _savePurchaseHistory(
        address _account,
        uint256 _tokensBought,
        uint256 _etherToOwnerForAccountPurchase
    ) internal {
        AccountPurchaseHistory memory recipientHistory = purchaseHistory[_account];

        // save tokens minted to account purchase history
        purchaseHistory[_account].tokensBought = recipientHistory.tokensBought + _tokensBought;

        // save amount paid to owner for tokens for recipient
        purchaseHistory[_account].amountPaidToOwner =
            recipientHistory.amountPaidToOwner +
            _etherToOwnerForAccountPurchase;

        // calculate average purchase block based on proportion of amount paid to owner
        purchaseHistory[_account].averagePurchaseBlockWad =
            // numerator is average purchase block * total amount paid to owner + current block number * amount of ether spent
            (recipientHistory.averagePurchaseBlockWad *
                recipientHistory.amountPaidToOwner +
                block.number *
                _etherToOwnerForAccountPurchase) /
            // denominator is total amount paid to owner
            // need to ensure denominator is not 0 or can't be abused
            recipientHistory.amountPaidToOwner +
            _etherToOwnerForAccountPurchase;
    }

    /**
     * @notice Returns the amount of wei that would be spent to buy an amount of tokens. Does not take into account the protocol rewards.
     * @param amount the amount of tokens to buy.
     * @return spentY The cost in wei of the token purchase.
     */
    function buyTokenQuote(uint256 amount) public view returns (int spentY) {
        if (amount == 0) revert INVALID_AMOUNT();
        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        return
            vrgda.xToY({
                timeSinceStart: toDaysWadUnsafe(block.timestamp - startTime),
                sold: int(token.totalSupply()),
                amount: int(amount)
            });
    }

    /**
     * @notice Returns the amount of tokens that would be emitted for an amount of wei. Does not take into account the protocol rewards.
     * @param etherAmount the payment amount in wei.
     * @return gainedX The amount of tokens that would be emitted for the payment amount.
     */
    function getTokenQuoteForEther(uint256 etherAmount) public view returns (int gainedX) {
        if (etherAmount == 0) revert INVALID_PAYMENT();
        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        return
            vrgda.yToX({
                timeSinceStart: toDaysWadUnsafe(block.timestamp - startTime),
                sold: int(token.totalSupply()),
                amount: int(etherAmount)
            });
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
                sold: int(token.totalSupply()),
                amount: int(buyTokenPaymentShares.founderGovernancePayment)
            })
            : int(0);

        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        return
            vrgda.yToX({
                timeSinceStart: timeSinceStart,
                // Total supply is increased by the amount of tokens that would be minted for the founder first
                sold: int(token.totalSupply()) + forFounder,
                amount: int(buyTokenPaymentShares.buyersGovernancePayment)
            });
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
     * @notice Get the associated purchase data for an account including tokens bought, amount paid to owner, and average purchase block
     * @param _account The account to get purchase history for
     * @return AccountPurchaseHistory The purchase history for the account
     */
    function getAccountPurchaseHistory(
        address _account
    ) external view override returns (AccountPurchaseHistory memory) {
        return purchaseHistory[_account];
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
}
