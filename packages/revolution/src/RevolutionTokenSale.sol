// SPDX-License-Identifier: GPL-3.0

/// @title RevolutionTokenSale
/// @notice Greenfield VRGDA buy-now minter for Revolution ERC-721 tokens.

pragma solidity ^0.8.22;

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { UUPS } from "@cobuild/utility-contracts/src/proxy/UUPS.sol";
import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";
import { RevolutionRewards } from "@cobuild/protocol-rewards/src/abstract/RevolutionRewards.sol";

import { ICultureIndex } from "./interfaces/ICultureIndex.sol";
import { IRevolutionToken } from "./interfaces/IRevolutionToken.sol";
import { IRevolutionPointsEmitter } from "./interfaces/IRevolutionPointsEmitter.sol";
import { IRevolutionTokenSale } from "./interfaces/IRevolutionTokenSale.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { RevolutionVersion } from "./version/RevolutionVersion.sol";
import { toDaysWadUnsafe, unsafeWadDiv, wadExp, wadLn, wadMul } from "./libs/SignedWadMath.sol";

contract RevolutionTokenSale is
    IRevolutionTokenSale,
    RevolutionVersion,
    UUPS,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    RevolutionRewards
{
    /// @notice Maximum supported buy-now pool size.
    uint256 public constant MAX_POOL_SIZE = 10;

    uint256 private constant WAD = 1e18;

    /// @dev wadExp lower bound from SignedWadMath; values below this return ~0.
    int256 private constant MIN_EXP_INPUT = -41_446_531_673_892_822_313;

    /// @notice Maximum sold count that can be safely converted to a signed wad for VRGDA pricing.
    uint256 public constant MAX_SOLD_BY_VRGDA = uint256(type(int256).max) / WAD - 1;

    /// @notice The Revolution ERC721 token contract.
    IRevolutionToken public revolutionToken;

    /// @notice The RevolutionPoints emitter contract.
    IRevolutionPointsEmitter public revolutionPointsEmitter;

    /// @notice The address of the WETH contract.
    address public WETH;

    /// @notice Floor price for a buy-now sale.
    uint256 public minPriceWei;

    /// @notice Split of purchase proceeds reserved for the creator in basis points.
    uint256 public creatorRateBps;

    /// @notice All-time minimum creator split in basis points.
    uint256 public minCreatorRateBps;

    /// @notice Split of creator proceeds sent directly as ETH in basis points.
    uint256 public entropyRateBps;

    /// @notice The account to pay grants funds to.
    address public grantsAddress;

    /// @notice Split of purchase proceeds sent to grants as ETH in basis points.
    uint256 public grantsRateBps;

    /// @notice Time anchor used to calculate VRGDA elapsed time.
    uint256 public saleStartTime;

    /// @notice Number of successful VRGDA NFT purchases since cutover.
    uint256 public soldByVRGDA;

    /// @notice Optional interval for price updates. 0 means continuous pricing.
    uint256 public priceUpdateInterval;

    /// @notice Number of top CultureIndex pieces selectable by buyNow.
    uint256 public poolSize;

    /// @notice Target price for a token if sold on pace, scaled as a signed wad.
    int256 public targetPrice;

    /// @notice Percent price decays per unit of time with no sales, scaled by 1e18.
    int256 public priceDecayPercent;

    /// @notice Number of NFTs targeted per day, scaled by 1e18.
    int256 public tokensPerTimeUnit;

    /// @dev Precomputed ln(1 - priceDecayPercent), scaled by 1e18.
    int256 public decayConstant;

    /// @dev Upper exponent bound for current targetPrice to avoid wadExp / wadMul overflow.
    int256 public maxXBound;

    /// @notice The new revolution member's acceptance speech.
    mapping(uint256 => AcceptanceManifesto) public manifestos;

    /// @notice Historical data for token sales.
    mapping(uint256 => SaleHistory) public sales;

    /// @notice The contract upgrade manager.
    IUpgradeManager public immutable manager;

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

    /**
     * @notice Initialize the sale contract and pause it for shadow checks before launch.
     */
    function initialize(
        address _revolutionToken,
        address _revolutionPointsEmitter,
        address _initialOwner,
        address _weth,
        TokenSaleParams calldata _tokenSaleParams
    ) external initializer {
        if (_revolutionToken == address(0)) revert ADDRESS_ZERO();
        if (_revolutionPointsEmitter == address(0)) revert ADDRESS_ZERO();
        if (_initialOwner == address(0)) revert ADDRESS_ZERO();
        if (_weth == address(0)) revert ADDRESS_ZERO();

        __Pausable_init();
        __ReentrancyGuard_init();
        __Ownable_init(_initialOwner);

        _pause();

        revolutionToken = IRevolutionToken(_revolutionToken);
        revolutionPointsEmitter = IRevolutionPointsEmitter(_revolutionPointsEmitter);
        WETH = _weth;

        if (_tokenSaleParams.creatorRateBps < _tokenSaleParams.minCreatorRateBps) revert CREATOR_RATE_TOO_LOW();
        if (_tokenSaleParams.entropyRateBps > 10_000) revert INVALID_BPS();
        if (_tokenSaleParams.grantsParams.totalRateBps > 10_000) revert INVALID_BPS();
        if (_tokenSaleParams.grantsParams.totalRateBps + _tokenSaleParams.creatorRateBps > 10_000) revert INVALID_BPS();
        if (_tokenSaleParams.minPriceWei == 0) revert INVALID_PRICE();

        minPriceWei = _tokenSaleParams.minPriceWei;
        creatorRateBps = _tokenSaleParams.creatorRateBps;
        minCreatorRateBps = _tokenSaleParams.minCreatorRateBps;
        entropyRateBps = _tokenSaleParams.entropyRateBps;
        grantsRateBps = _tokenSaleParams.grantsParams.totalRateBps;
        grantsAddress = _tokenSaleParams.grantsParams.grantsAddress;
        saleStartTime = _tokenSaleParams.saleStartTime;
        _validateSoldByVRGDA(_tokenSaleParams.soldByVRGDA);
        soldByVRGDA = _tokenSaleParams.soldByVRGDA;
        priceUpdateInterval = _tokenSaleParams.priceUpdateInterval;

        _setPoolSize(_tokenSaleParams.poolSize);
        _setVRGDAParams(_tokenSaleParams.vrgdaParams);
    }

    /**
     * @notice Buy one of the currently selectable top CultureIndex pieces.
     * @param pieceId The selected CultureIndex piece ID. Must be in the current top `poolSize`.
     * @param recipient The address that receives the minted ERC721.
     * @param maxPrice Buyer slippage guard; reverts if the current price is higher.
     * @param referral Optional purchase referral for protocol rewards and creator governance purchase.
     */
    function buyNow(
        uint256 pieceId,
        address recipient,
        uint256 maxPrice,
        address referral
    ) external payable nonReentrant whenNotPaused returns (uint256 tokenId, uint256 price) {
        if (recipient == address(0)) revert ADDRESS_ZERO();

        price = getCurrentPrice();
        if (price > maxPrice) revert MAX_PRICE_EXCEEDED();
        if (msg.value < price) revert INSUFFICIENT_PAYMENT();

        tokenId = revolutionToken.mintFromPiece(recipient, pieceId, poolSize);
        soldByVRGDA += 1;

        ICultureIndex.ArtPiece memory artPiece = revolutionToken.getArtPieceById(tokenId);

        manifestos[tokenId] = AcceptanceManifesto({ member: recipient, speech: "" });

        (PaidToCreators memory paidToCreators, PaymentShares memory paymentShares) = _settlePurchase(
            price,
            referral,
            artPiece
        );

        sales[tokenId] = SaleHistory({
            amount: price,
            buyer: msg.sender,
            recipient: recipient,
            amountPaidToOwner: paymentShares.owner,
            settledBlockWad: block.number * 1e18,
            pieceId: pieceId
        });

        uint256 refundAmount = msg.value - price;
        if (refundAmount > 0) _safeTransferETHWithFallback(msg.sender, refundAmount);

        emit TokenPurchased(
            tokenId,
            pieceId,
            msg.sender,
            recipient,
            price,
            referral,
            paidToCreators.points,
            paidToCreators.eth
        );

        // Legacy-compatible event name for consumers that previously watched auction settlements.
        emit AuctionSettled(tokenId, recipient, price, paidToCreators.points, paidToCreators.eth);
    }

    /**
     * @notice Current buy-now price for the next sale.
     */
    function getCurrentPrice() public view returns (uint256) {
        return getPrice(soldByVRGDA);
    }

    /**
     * @notice Buy-now price for a hypothetical sold count.
     */
    function getPrice(uint256 sold) public view returns (uint256) {
        uint256 rawPrice = _getVRGDAPrice(_timeSinceStartWad(), sold);
        return rawPrice > minPriceWei ? rawPrice : minPriceWei;
    }

    /**
     * @notice Returns top selectable pieces and the current buy-now price.
     */
    function getAvailablePieces(uint256 count) external view returns (uint256[] memory pieceIds, uint256 price) {
        pieceIds = revolutionToken.cultureIndex().getTopPieceIds(count);
        price = getCurrentPrice();
    }

    /**
     * @notice Get historic sale data for a token.
     */
    function getPastSale(uint256 tokenId) external view returns (SaleHistory memory) {
        return sales[tokenId];
    }

    /**
     * @notice Allows a member to update their manifesto.
     */
    function updateManifesto(uint256 tokenId, string calldata newSpeech) external {
        AcceptanceManifesto memory manifesto = manifestos[tokenId];

        if (bytes(newSpeech).length > 12_096) revert MANIFESTO_TOO_LONG();
        if (msg.sender != manifesto.member) revert NOT_INITIAL_TOKEN_OWNER();

        manifestos[tokenId].speech = newSpeech;

        emit ManifestoUpdated(tokenId, msg.sender, newSpeech);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setMinPriceWei(uint256 _minPriceWei) external onlyOwner {
        if (_minPriceWei == 0) revert INVALID_PRICE();
        minPriceWei = _minPriceWei;
        emit MinPriceUpdated(_minPriceWei);
    }

    function setPoolSize(uint256 _poolSize) external onlyOwner {
        _setPoolSize(_poolSize);
    }

    function setPriceUpdateInterval(uint256 _priceUpdateInterval) external onlyOwner {
        priceUpdateInterval = _priceUpdateInterval;
        emit PriceUpdateIntervalUpdated(_priceUpdateInterval);
    }

    function setVRGDAParams(VRGDAParams calldata _vrgdaParams) external onlyOwner whenPaused {
        _setVRGDAParams(_vrgdaParams);
    }

    function setSaleStartTime(uint256 _saleStartTime) external onlyOwner whenPaused {
        saleStartTime = _saleStartTime;
        emit SaleStartTimeUpdated(_saleStartTime);
    }

    function setSoldByVRGDA(uint256 _soldByVRGDA) external onlyOwner whenPaused {
        _validateSoldByVRGDA(_soldByVRGDA);
        soldByVRGDA = _soldByVRGDA;
        emit SoldByVRGDAUpdated(_soldByVRGDA);
    }

    function setCreatorRateBps(uint256 _creatorRateBps) external onlyOwner {
        if (_creatorRateBps < minCreatorRateBps) revert CREATOR_RATE_TOO_LOW();
        if (_creatorRateBps > 10_000) revert INVALID_BPS();
        if (_creatorRateBps + grantsRateBps > 10_000) revert INVALID_BPS();

        creatorRateBps = _creatorRateBps;
        emit CreatorRateBpsUpdated(_creatorRateBps);
    }

    function setMinCreatorRateBps(uint256 _minCreatorRateBps) external onlyOwner {
        if (_minCreatorRateBps > creatorRateBps) revert MIN_CREATOR_RATE_ABOVE_CREATOR_RATE();
        if (_minCreatorRateBps > 10_000) revert INVALID_BPS();
        if (_minCreatorRateBps <= minCreatorRateBps) revert MIN_CREATOR_RATE_NOT_INCREASED();

        minCreatorRateBps = _minCreatorRateBps;
        emit MinCreatorRateBpsUpdated(_minCreatorRateBps);
    }

    function setEntropyRateBps(uint256 _entropyRateBps) external onlyOwner {
        if (_entropyRateBps > 10_000) revert INVALID_BPS();

        entropyRateBps = _entropyRateBps;
        emit EntropyRateBpsUpdated(_entropyRateBps);
    }

    function setGrantsRateBps(uint256 _grantsRateBps) external override onlyOwner nonReentrant {
        if (_grantsRateBps > 10_000) revert INVALID_BPS();
        if (_grantsRateBps + creatorRateBps > 10_000) revert INVALID_BPS();

        grantsRateBps = _grantsRateBps;
        emit GrantsRateBpsUpdated(_grantsRateBps);
    }

    function setGrantsAddress(address _grantsAddress) external override onlyOwner nonReentrant {
        grantsAddress = _grantsAddress;
        emit GrantsAddressUpdated(_grantsAddress);
    }

    function _setPoolSize(uint256 _poolSize) internal {
        if (_poolSize == 0 || _poolSize > MAX_POOL_SIZE) revert INVALID_POOL_SIZE();
        poolSize = _poolSize;
        emit PoolSizeUpdated(_poolSize);
    }

    function _setVRGDAParams(VRGDAParams calldata _vrgdaParams) internal {
        if (
            _vrgdaParams.targetPrice <= 0 ||
            _vrgdaParams.priceDecayPercent <= 0 ||
            _vrgdaParams.priceDecayPercent >= 1e18 ||
            _vrgdaParams.tokensPerTimeUnit <= 0
        ) revert INVALID_VRGDA_PARAMS();

        targetPrice = _vrgdaParams.targetPrice;
        priceDecayPercent = _vrgdaParams.priceDecayPercent;
        tokensPerTimeUnit = _vrgdaParams.tokensPerTimeUnit;
        decayConstant = wadLn(1e18 - _vrgdaParams.priceDecayPercent);
        if (decayConstant >= 0) revert INVALID_VRGDA_PARAMS();

        maxXBound = wadLn(type(int256).max / _vrgdaParams.targetPrice);

        emit VRGDAParamsUpdated(
            _vrgdaParams.targetPrice,
            _vrgdaParams.priceDecayPercent,
            _vrgdaParams.tokensPerTimeUnit
        );
    }

    function _validateSoldByVRGDA(uint256 sold) internal pure {
        if (sold > MAX_SOLD_BY_VRGDA) revert INVALID_SOLD_COUNT();
    }

    function _timeSinceStartWad() internal view returns (int256) {
        uint256 elapsed = block.timestamp > saleStartTime ? block.timestamp - saleStartTime : 0;
        uint256 interval = priceUpdateInterval;
        if (interval != 0) elapsed -= elapsed % interval;
        return toDaysWadUnsafe(elapsed);
    }

    function _getVRGDAPrice(int256 timeSinceStart, uint256 sold) internal view returns (uint256) {
        _validateSoldByVRGDA(sold);

        unchecked {
            // sold is the number sold so far; VRGDA prices the next token, sold + 1.
            int256 soldWad = int256((sold + 1) * WAD);
            int256 targetSaleTime = unsafeWadDiv(soldWad, tokensPerTimeUnit);
            int256 exponent = wadMul(decayConstant, timeSinceStart - targetSaleTime);

            if (exponent <= MIN_EXP_INPUT) return 0;
            if (exponent >= maxXBound) return type(uint256).max;

            int256 price = wadMul(targetPrice, wadExp(exponent));
            return price > 0 ? uint256(price) : 0;
        }
    }

    function _calculatePaymentSharesMinusReward(
        uint256 _amount
    ) internal view returns (PaymentShares memory paymentShares) {
        uint256 valueRemaining = _amount - computeTotalReward(_amount);

        paymentShares.grants = (valueRemaining * grantsRateBps) / 10_000;
        paymentShares.owner = valueRemaining - ((valueRemaining * creatorRateBps) / 10_000) - paymentShares.grants;
        paymentShares.creatorDirectScaled = valueRemaining * entropyRateBps * creatorRateBps;
        paymentShares.creatorGovernance =
            ((valueRemaining * creatorRateBps) / 10_000) -
            (paymentShares.creatorDirectScaled / 10_000 / 10_000);
    }

    function _settlePurchase(
        uint256 price,
        address referral,
        ICultureIndex.ArtPiece memory artPiece
    ) internal returns (PaidToCreators memory paidToCreators, PaymentShares memory paymentShares) {
        paymentShares = _calculatePaymentSharesMinusReward(price);

        if (price > 0) {
            _handleRewardsAndGetValueToSend(price, address(0), referral, artPiece.sponsor);

            ICultureIndex.CreatorBps[] memory creators = artPiece.creators;
            uint256 numCreators = creators.length;

            uint256[] memory vrgdaSplits = new uint256[](numCreators);
            address[] memory vrgdaReceivers = new address[](numCreators);

            if (paymentShares.owner > 0) _safeTransferETHWithFallback(owner(), paymentShares.owner);
            if (paymentShares.grants > 0) _safeTransferETHWithFallback(grantsAddress, paymentShares.grants);

            for (uint256 i; i < numCreators; ++i) {
                vrgdaReceivers[i] = creators[i].creator;
                vrgdaSplits[i] = creators[i].bps;

                uint256 paymentAmount = (paymentShares.creatorDirectScaled * creators[i].bps) /
                    10_000 /
                    10_000 /
                    10_000;

                if (paymentAmount > 0) {
                    paidToCreators.eth += paymentAmount;
                    _safeTransferETHWithFallback(creators[i].creator, paymentAmount);
                }
            }

            if (paymentShares.creatorGovernance > 0) {
                paidToCreators.points = revolutionPointsEmitter.buyToken{ value: paymentShares.creatorGovernance }(
                    vrgdaReceivers,
                    vrgdaSplits,
                    IRevolutionPointsEmitter.ProtocolRewardAddresses({
                        builder: address(0),
                        purchaseReferral: referral,
                        deployer: artPiece.sponsor
                    })
                );
            }
        }
    }

    /// @notice Transfer ETH/WETH from the contract.
    function _safeTransferETHWithFallback(address _to, uint256 _amount) private {
        if (address(this).balance < _amount) revert("Insufficient balance");

        bool success;
        assembly {
            success := call(30000, _to, _amount, 0, 0, 0, 0)
        }

        if (!success) {
            IWETH(WETH).deposit{ value: _amount }();
            bool wethSuccess = IWETH(WETH).transfer(_to, _amount);
            if (!wethSuccess) revert("WETH transfer failed");
        }
    }

    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner whenPaused {
        if (!manager.isRegisteredUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
