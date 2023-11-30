// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { VRGDAC } from "./libs/VRGDAC.sol";
import { toDaysWadUnsafe, wadDiv, wadMul } from "./libs/SignedWadMath.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { NontransferableERC20Votes } from "./NontransferableERC20Votes.sol";
import { ITokenEmitter } from "./interfaces/ITokenEmitter.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { TokenEmitterRewards } from "@collectivexyz/protocol-rewards/src/abstract/TokenEmitter/TokenEmitterRewards.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenEmitter is VRGDAC, ITokenEmitter, ReentrancyGuard, TokenEmitterRewards, Ownable {
    // treasury address to pay funds to
    address private treasury;

    // The token that is being emitted.
    NontransferableERC20Votes public token;

    // solhint-disable-next-line not-rely-on-time
    uint public immutable startTime = block.timestamp;

    // The amount of tokens that have been emitted in wad units.
    int256 emittedTokenWad;

    // The split of the purchase that is reserved for the creator of the Verb in basis points
    uint256 public creatorRateBps;

    // The split of (purchase proceeds * creatorRate) that is sent to the creator as ether in basis points
    uint256 public entropyRateBps;

    // The account or contract to pay the creator reward to
    address public creatorsAddress;

    // approved contracts, owner, and a token contract address
    constructor(
        address _initialOwner,
        NontransferableERC20Votes _token,
        address _protocolRewards,
        address _protocolFeeRecipient,
        address _treasury,
        int _targetPrice, // The target price for a token if sold on pace, scaled by 1e18.
        int _priceDecayPercent, // The percent price decays per unit of time with no sales, scaled by 1e18.
        int _tokensPerTimeUnit // The number of tokens to target selling in 1 full unit of time, scaled by 1e18.
    ) TokenEmitterRewards(_protocolRewards, _protocolFeeRecipient) VRGDAC(_targetPrice, _priceDecayPercent, _tokensPerTimeUnit) Ownable(_initialOwner) {
        treasury = _treasury;

        token = _token;
    }

    function _mint(address _to, uint _amount) private {
        token.mint(_to, _amount);
    }

    function totalSupply() public view returns (uint) {
        // returns total supply issued so far
        return token.totalSupply();
    }

    function balanceOf(address _owner) public view returns (uint) {
        // returns balance of address
        return token.balanceOf(_owner);
    }

    // takes a list of addresses and a list of payout percentages as basis points
    function buyToken(
        address[] memory _addresses,
        uint[] memory _bps,
        address builder,
        address purchaseReferral,
        address deployer
    ) public payable nonReentrant returns (uint tokensSoldWad) {
        // ensure the same number of addresses and _bps
        require(_addresses.length == _bps.length, "Parallel arrays required");

        // Get value left after protocol rewards
        uint msgValueRemaining = _handleRewardsAndGetValueToSend(msg.value, builder, purchaseReferral, deployer);
        
        //Share of purchase amount to send to treasury
        uint256 toPayTreasury = (msgValueRemaining * (10_000 - creatorRateBps)) / 10_000;

        //Share of purchase amount to pay creators with
        uint256 toPayCreators = msgValueRemaining - toPayTreasury;
        //Ether directly sent to creators
        uint256 creatorDirectPayment = (toPayCreators * entropyRateBps) / 10_000;
        //Tokens to emit to creators
        int totalTokensForCreators = getTokenQuoteForPaymentWad(toPayCreators - creatorDirectPayment);

        int totalTokensForBuyers = getTokenQuoteForPaymentWad(toPayTreasury);
        (bool success, ) = treasury.call{ value: toPayTreasury }(new bytes(0));
        require(success, "Transfer failed.");
        emittedTokenWad += totalTokensForBuyers;

        if (creatorDirectPayment > 0) {
            (success, ) = creatorsAddress.call{ value: creatorDirectPayment }(new bytes(0));
            require(success, "Transfer failed.");
        }

        if(totalTokensForCreators > 0) {
            _mint(creatorsAddress, uint(totalTokensForCreators));
            emittedTokenWad += totalTokensForCreators;
        }

        uint sum = 0;

        // calculates how many tokens to give each address
        for (uint i = 0; i < _addresses.length; i++) {
            //todo seems dangerous with rouding, fix it up
            int tokens = wadDiv(wadMul(totalTokensForBuyers, int(_bps[i] * 1e18)), 10_000 * 1e18 * 1e18);
            // transfer tokens to address
            _mint(_addresses[i], uint(tokens));
            sum += _bps[i];
        }

        require(sum == 10_000, "bps must add up to 10_000");

        emit PurchaseFinalized(msg.sender, msg.value, toPayTreasury, msg.value - msgValueRemaining, uint(totalTokensForBuyers), uint(totalTokensForCreators), creatorDirectPayment);

        return uint(totalTokensForBuyers);
    }

    function buyTokenQuote(uint amount) public view returns (int spentY) {
        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        return xToY({ timeSinceStart: toDaysWadUnsafe(block.timestamp - startTime), sold: emittedTokenWad, amount: int(amount) });
    }

    function getTokenQuoteForPaymentWad(uint paymentWei) public view returns (int gainedX) {
        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        return yToX({ timeSinceStart: toDaysWadUnsafe(block.timestamp - startTime), sold: emittedTokenWad, amount: int(paymentWei) });
    }

    function getTokenQuoteForPayment(uint paymentWei) public view returns (int gainedX) {
        return wadDiv(getTokenQuoteForPaymentWad(paymentWei), 1e36);
    }

    /**
     * @notice Set the split of (purchase * creatorRate) that is sent to the creator as ether in basis points.
     * @dev Only callable by the owner.
     * @param _entropyRateBps New entropy rate in basis points.
     */
    function setEntropyRateBps(uint256 _entropyRateBps) external onlyOwner {
        require(_entropyRateBps <= 10_000, "Entropy rate must be less than or equal to 10_000");
        require(_entropyRateBps >= 0, "Entropy rate must be greater than or equal to 0");

        entropyRateBps = _entropyRateBps;
        emit EntropyRateBpsUpdated(_entropyRateBps);
    }

    /**
     * @notice Set the split of the payment that is reserved for creators in basis points.
     * @dev Only callable by the owner.
     * @param _creatorRateBps New creator rate in basis points.
     */
    function setCreatorRateBps(uint256 _creatorRateBps) external onlyOwner {
        require(_creatorRateBps <= 10_000, "Creator rate must be less than or equal to 10_000");
        require(_creatorRateBps >= 0, "Creator rate must be greater than or equal to 0");
        creatorRateBps = _creatorRateBps;

        emit CreatorRateBpsUpdated(_creatorRateBps);
    }

    /**
     * @notice Set the creators address to pay the creatorRate to. Can be a contract.
     * @dev Only callable by the owner when not locked.
     */
    function setCreatorsAddress(address _creatorsAddress) external override onlyOwner nonReentrant {
        creatorsAddress = _creatorsAddress;

        emit CreatorsAddressUpdated(_creatorsAddress);
    }
}
