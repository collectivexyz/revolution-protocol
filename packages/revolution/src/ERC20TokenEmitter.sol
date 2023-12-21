// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { TokenEmitterRewards } from "@cobuild/protocol-rewards/src/abstract/TokenEmitter/TokenEmitterRewards.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { VRGDAC } from "./libs/VRGDAC.sol";
import { toDaysWadUnsafe } from "./libs/SignedWadMath.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { NontransferableERC20Votes } from "./NontransferableERC20Votes.sol";
import { IERC20TokenEmitter } from "./interfaces/IERC20TokenEmitter.sol";

import { IRevolutionBuilder } from "./interfaces/IRevolutionBuilder.sol";

contract ERC20TokenEmitter is
    IERC20TokenEmitter,
    ReentrancyGuardUpgradeable,
    TokenEmitterRewards,
    Ownable2StepUpgradeable,
    PausableUpgradeable
{
    // treasury address to pay funds to
    address public treasury;

    // The token that is being minted.
    NontransferableERC20Votes public token;

    // The VRGDA contract
    VRGDAC public vrgdac;

    // solhint-disable-next-line not-rely-on-time
    uint256 public startTime;

    /**
     * @notice A running total of the amount of tokens emitted.
     */
    int256 public emittedTokenWad;

    // The split of the purchase that is reserved for the creator of the Verb in basis points
    uint256 public creatorRateBps;

    // The split of (purchase proceeds * creatorRate) that is sent to the creator as ether in basis points
    uint256 public entropyRateBps;

    // The account or contract to pay the creator reward to
    address public creatorsAddress;

    ///                                                          ///
    ///                         IMMUTABLES                       ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IRevolutionBuilder private immutable manager;

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
    ) payable TokenEmitterRewards(_protocolRewards, _protocolFeeRecipient) initializer {
        manager = IRevolutionBuilder(_manager);
    }

    ///                                                          ///
    ///                         INITIALIZER                      ///
    ///                                                          ///

    /**
     * @notice Initialize the token emitter
     * @param _initialOwner The initial owner of the token emitter
     * @param _erc20Token The ERC-20 token contract address
     * @param _vrgdac The VRGDA contract address
     * @param _treasury The treasury address to pay funds to
     * @param _creatorsAddress The address to pay the creator reward to
     */
    function initialize(
        address _initialOwner,
        address _erc20Token,
        address _treasury,
        address _vrgdac,
        address _creatorsAddress
    ) external initializer {
        require(msg.sender == address(manager), "Only manager can initialize");

        __Pausable_init();
        __ReentrancyGuard_init();

        require(_treasury != address(0), "Invalid treasury address");

        // Set up ownable
        __Ownable_init(_initialOwner);

        treasury = _treasury;
        creatorsAddress = _creatorsAddress;
        vrgdac = VRGDAC(_vrgdac);
        token = NontransferableERC20Votes(_erc20Token);
        startTime = block.timestamp;
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
     * @notice Unpause the token emitter.
     * @dev This function can only be called by the owner when the
     * contract is paused.
     */
    function unpause() external override onlyOwner {
        _unpause();
    }

    /**
     * @notice A function to calculate the shares of the purchase that go to the buyer's governance purchase, and the creators
     * @param msgValueRemaining The amount of ether left after protocol rewards are taken out
     * @return buyTokenPaymentShares A struct containing the shares of the purchase that go to the buyer's governance purchase, and the creators
     */
    function _calculateBuyTokenPaymentShares(
        uint256 msgValueRemaining
    ) internal view returns (BuyTokenPaymentShares memory buyTokenPaymentShares) {
        // Calculate share of purchase amount reserved for buyers
        buyTokenPaymentShares.buyersShare = msgValueRemaining - ((msgValueRemaining * creatorRateBps) / 10_000);

        // Calculate ether directly sent to creators
        buyTokenPaymentShares.creatorsDirectPayment =
            (msgValueRemaining * creatorRateBps * entropyRateBps) /
            10_000 /
            10_000;

        // Calculate ether spent on creators governance tokens
        buyTokenPaymentShares.creatorsGovernancePayment =
            ((msgValueRemaining * creatorRateBps) / 10_000) -
            buyTokenPaymentShares.creatorsDirectPayment;
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
        // Prevent treasury and creatorsAddress from buying tokens directly, given they are recipient(s) of the funds
        require(msg.sender != treasury && msg.sender != creatorsAddress, "Funds recipient cannot buy tokens");

        // Transaction must send ether to buyTokens
        require(msg.value > 0, "Must send ether");

        // Ensure the same number of addresses and bps
        require(addresses.length == basisPointSplits.length, "Parallel arrays required");

        // Calculate value left after sharing protocol rewards
        uint256 msgValueRemaining = _handleRewardsAndGetValueToSend(
            msg.value,
            protocolRewardsRecipients.builder,
            protocolRewardsRecipients.purchaseReferral,
            protocolRewardsRecipients.deployer
        );

        BuyTokenPaymentShares memory buyTokenPaymentShares = _calculateBuyTokenPaymentShares(msgValueRemaining);

        // Calculate tokens to emit to creators
        int totalTokensForCreators = buyTokenPaymentShares.creatorsGovernancePayment > 0
            ? getTokenQuoteForEther(buyTokenPaymentShares.creatorsGovernancePayment)
            : int(0);

        // Update total tokens emitted for this purchase with tokens for creators
        if (totalTokensForCreators > 0) emittedTokenWad += totalTokensForCreators;

        // Tokens to emit to buyers
        int totalTokensForBuyers = buyTokenPaymentShares.buyersShare > 0
            ? getTokenQuoteForEther(buyTokenPaymentShares.buyersShare)
            : int(0);

        // Update total tokens emitted for this purchase with tokens for buyers
        if (totalTokensForBuyers > 0) emittedTokenWad += totalTokensForBuyers;

        //Deposit treasury funds, and eth used to buy creators gov. tokens to treasury
        (bool success, ) = treasury.call{
            value: buyTokenPaymentShares.buyersShare + buyTokenPaymentShares.creatorsGovernancePayment
        }(new bytes(0));
        require(success, "Transfer failed.");

        //Transfer ETH to creators
        if (buyTokenPaymentShares.creatorsDirectPayment > 0) {
            (success, ) = creatorsAddress.call{ value: buyTokenPaymentShares.creatorsDirectPayment }(new bytes(0));
            require(success, "Transfer failed.");
        }

        //Mint tokens to creators
        if (totalTokensForCreators > 0 && creatorsAddress != address(0)) {
            _mint(creatorsAddress, uint256(totalTokensForCreators));
        }

        // Stores total bps, ensure it is 10_000 later
        uint256 bpsSum = 0;

        //Mint tokens to buyers
        for (uint256 i = 0; i < addresses.length; i++) {
            if (totalTokensForBuyers > 0) {
                // transfer tokens to address
                _mint(addresses[i], uint256((totalTokensForBuyers * int(basisPointSplits[i])) / 10_000));
            }
            bpsSum += basisPointSplits[i];
        }

        require(bpsSum == 10_000, "bps must add up to 10_000");

        emit PurchaseFinalized(
            msg.sender,
            msg.value,
            buyTokenPaymentShares.buyersShare + buyTokenPaymentShares.creatorsGovernancePayment,
            msg.value - msgValueRemaining,
            uint256(totalTokensForBuyers),
            uint256(totalTokensForCreators),
            buyTokenPaymentShares.creatorsDirectPayment
        );

        return uint256(totalTokensForBuyers);
    }

    /**
     * @notice Returns the amount of wei that would be spent to buy an amount of tokens. Does not take into account the protocol rewards.
     * @param amount the amount of tokens to buy.
     * @return spentY The cost in wei of the token purchase.
     */
    function buyTokenQuote(uint256 amount) public view returns (int spentY) {
        require(amount > 0, "Amount must be greater than 0");
        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        return
            vrgdac.xToY({
                timeSinceStart: toDaysWadUnsafe(block.timestamp - startTime),
                sold: emittedTokenWad,
                amount: int(amount)
            });
    }

    /**
     * @notice Returns the amount of tokens that would be emitted for an amount of wei. Does not take into account the protocol rewards.
     * @param etherAmount the payment amount in wei.
     * @return gainedX The amount of tokens that would be emitted for the payment amount.
     */
    function getTokenQuoteForEther(uint256 etherAmount) public view returns (int gainedX) {
        require(etherAmount > 0, "Ether amount must be greater than 0");
        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        return
            vrgdac.yToX({
                timeSinceStart: toDaysWadUnsafe(block.timestamp - startTime),
                sold: emittedTokenWad,
                amount: int(etherAmount)
            });
    }

    /**
     * @notice Returns the amount of tokens that would be emitted for the payment amount, taking into account the protocol rewards.
     * @param paymentAmount the payment amount in wei.
     * @return gainedX The amount of tokens that would be emitted for the payment amount.
     */
    function getTokenQuoteForPayment(uint256 paymentAmount) external view returns (int gainedX) {
        require(paymentAmount > 0, "Payment amount must be greater than 0");
        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        return
            vrgdac.yToX({
                timeSinceStart: toDaysWadUnsafe(block.timestamp - startTime),
                sold: emittedTokenWad,
                amount: int(((paymentAmount - computeTotalReward(paymentAmount)) * (10_000 - creatorRateBps)) / 10_000)
            });
    }

    /**
     * @notice Set the split of (purchase * creatorRate) that is sent to the creator as ether in basis points.
     * @dev Only callable by the owner.
     * @param _entropyRateBps New entropy rate in basis points.
     */
    function setEntropyRateBps(uint256 _entropyRateBps) external onlyOwner {
        require(_entropyRateBps <= 10_000, "Entropy rate must be less than or equal to 10_000");

        emit EntropyRateBpsUpdated(entropyRateBps = _entropyRateBps);
    }

    /**
     * @notice Set the split of the payment that is reserved for creators in basis points.
     * @dev Only callable by the owner.
     * @param _creatorRateBps New creator rate in basis points.
     */
    function setCreatorRateBps(uint256 _creatorRateBps) external onlyOwner {
        require(_creatorRateBps <= 10_000, "Creator rate must be less than or equal to 10_000");

        emit CreatorRateBpsUpdated(creatorRateBps = _creatorRateBps);
    }

    /**
     * @notice Set the creators address to pay the creatorRate to. Can be a contract.
     * @dev Only callable by the owner.
     */
    function setCreatorsAddress(address _creatorsAddress) external override onlyOwner nonReentrant {
        require(_creatorsAddress != address(0), "Invalid address");

        emit CreatorsAddressUpdated(creatorsAddress = _creatorsAddress);
    }
}
