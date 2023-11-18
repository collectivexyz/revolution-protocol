// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { LinearVRGDA } from "./libs/LinearVRGDA.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { toDaysWadUnsafe } from "./libs/SignedWadMath.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { NontransferableERC20 } from "./NontransferableERC20.sol";
import { ITokenEmitter } from "./interfaces/ITokenEmitter.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { TokenEmitterRewards } from "../protocol-rewards/abstract/TokenEmitter/TokenEmitterRewards.sol";

contract TokenEmitter is LinearVRGDA, ITokenEmitter, ReentrancyGuard, TokenEmitterRewards {
    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Log(string name, uint256 value);

    // Vars
    address private treasury;

    NontransferableERC20 public token;

    // solhint-disable-next-line not-rely-on-time
    uint256 public immutable startTime = block.timestamp;

    // approved contracts, owner, and a token contract address
    constructor(
        NontransferableERC20 _token,
        address _protocolRewards,
        address _mintFeeRecipient,
        address _treasury,
        int256 _targetPrice, // SCALED BY E18. Target price. This is somewhat arbitrary for governance emissions, since there is no "target price" for 1 governance share.
        int256 _priceDecayPercent, // SCALED BY E18. Price decay percent. This indicates how aggressively you discount governance when sales are not occurring.
        int256 _governancePerTimeUnit // SCALED BY E18. The number of tokens to target selling in 1 full unit of time.
    ) TokenEmitterRewards(_protocolRewards, _mintFeeRecipient) LinearVRGDA(_targetPrice, _priceDecayPercent, _governancePerTimeUnit) {
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
    function buyToken(address[] memory _addresses, uint[] memory _bps, address builder, address purchaseReferral, address deployer) public payable nonReentrant returns (uint256) {
        // ensure the same number of addresses and _bps
        require(_addresses.length == _bps.length, "Parallel arrays required");

        // Get value to send and handle mint fee
        uint256 msgValueRemaining = _handleRewardsAndGetValueToSend(
            msg.value,
            builder,
            purchaseReferral,
            deployer
        );

        uint totalTokens = getTokenAmountForMultiPurchase(msgValueRemaining);
        (bool success, ) = treasury.call{ value: msgValueRemaining }(new bytes(0));
        require(success, "Transfer failed.");

        // calculates how much total governance to give

        uint sum = 0;

        // calculates how much governance to give each address
        for (uint i = 0; i < _addresses.length; i++) {
            uint tokens = (totalTokens * _bps[i]) / 10_000;
            // transfer governance to address
            _mint(_addresses[i], tokens);
            sum += _bps[i];
        }

        require(sum == 10_000, "bps must add up to 10_000");
        return totalTokens;
    }

    // This returns a safe, underestimated amount of governance.
    function _getTokenAmountForSinglePurchase(uint256 payment, uint256 supply) public view returns (uint256) {
        // get the initial estimated amount of tokens - assuming we priced your entire purchase at supply + 1 (akin to buying 1 NFT)
        uint256 overestimatedAmount = UNSAFE_getOverestimateTokenAmount(payment, supply);

        // get the overestimated price - assuming we priced your entire purchase at supply + 1 (akin to buying 1 NFT)
        uint256 overestimatedPrice = getTokenPrice(supply + overestimatedAmount);

        // get the underestimated price - assuming you paid for the entire purchase at the price of the last token
        uint256 underestimatedAmount = payment / overestimatedPrice;

        return underestimatedAmount;
    }

    function getTokenAmountForMultiPurchase(uint256 payment) public view returns (uint256) {
        // payment is split up into chunks of numTokens
        // each chunk is estimated and the total is returned
        // chunk up the payments into 0.001 eth chunks

        //counter to keep track of how much eth is left in the payment
        uint256 remainingEth = payment;

        // the total amount of tokens to return
        uint256 tokenAmount = 0;

        // solhint-disable-next-line var-name-mixedcase
        uint256 INCREMENT_SIZE = 1e15;

        // loop through the payment and add the estimated amount of tokens to the total
        while (remainingEth > 0) {
            // if the remaining eth is less than the increment size, calculate the tokenAmount for the remaining eth
            if (remainingEth < INCREMENT_SIZE) {
                tokenAmount += _getTokenAmountForSinglePurchase(remainingEth, totalSupply() + tokenAmount);
                remainingEth = 0;
            }
            // otherwise, calculate tokenAmount for the increment size
            else {
                tokenAmount += _getTokenAmountForSinglePurchase(INCREMENT_SIZE, totalSupply() + tokenAmount);
                remainingEth -= INCREMENT_SIZE;
            }
        }
        return tokenAmount;
    }

    // This will return MORE GOVERNANCE than it should. Never reward the user with this; the DAO will get taken over.
    // solhint-disable-next-line func-name-mixedcase
    function UNSAFE_getOverestimateTokenAmount(uint256 payment, uint256 supply) public view returns (uint256) {
        uint256 priceForFirstToken = getTokenPrice(supply);
        uint256 initialEstimatedAmount = payment / priceForFirstToken;
        return initialEstimatedAmount;
    }

    function getTokenPrice(uint256 tokensSoldSoFar) public view returns (uint256) {
        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        uint256 price = getVRGDAPrice(toDaysWadUnsafe(block.timestamp - startTime), tokensSoldSoFar);

        return price;
    }
}
