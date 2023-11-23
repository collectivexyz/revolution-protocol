// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { VRGDAC } from "./libs/VRGDAC.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { toDaysWadUnsafe, wadDiv, wadMul } from "./libs/SignedWadMath.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { NontransferableERC20 } from "./NontransferableERC20.sol";
import { ITokenEmitter } from "./interfaces/ITokenEmitter.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { TokenEmitterRewards } from "@collectivexyz/protocol-rewards/src/abstract/TokenEmitter/TokenEmitterRewards.sol";

contract TokenEmitter is VRGDAC, ITokenEmitter, ReentrancyGuard, TokenEmitterRewards {
    // Vars
    address private treasury;

    NontransferableERC20 public token;

    // solhint-disable-next-line not-rely-on-time
    uint public immutable startTime = block.timestamp;

    // approved contracts, owner, and a token contract address
    constructor(
        NontransferableERC20 _token,
        address _protocolRewards,
        address _protocolFeeRecipient,
        address _treasury,
        int _targetPrice, // The target price for a token if sold on pace, scaled by 1e18.
        int _priceDecayPercent, // The percent price decays per unit of time with no sales, scaled by 1e18.
        int _tokensPerTimeUnit // The number of tokens to target selling in 1 full unit of time, scaled by 1e18.
    ) TokenEmitterRewards(_protocolRewards, _protocolFeeRecipient) VRGDAC(_targetPrice, _priceDecayPercent, _tokensPerTimeUnit) {
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
    ) public payable nonReentrant returns (uint) {
        // ensure the same number of addresses and _bps
        require(_addresses.length == _bps.length, "Parallel arrays required");

        // Get value to send and handle mint fee
        uint msgValueRemaining = _handleRewardsAndGetValueToSend(msg.value, builder, purchaseReferral, deployer);

        uint totalTokens = uint(getTokenQuoteForPayment(msgValueRemaining));
        (bool success, ) = treasury.call{ value: msgValueRemaining }(new bytes(0));
        require(success, "Transfer failed.");

        uint sum = 0;

        // calculates how many tokens to give each address
        for (uint i = 0; i < _addresses.length; i++) {
            //todo seems dangerous with rouding, fix it up
            uint tokens = (totalTokens * _bps[i]) / 10_000;
            // transfer tokens to address
            _mint(_addresses[i], uint(tokens));
            sum += _bps[i];
        }

        require(sum == 10_000, "bps must add up to 10_000");
        return totalTokens;
    }

    function buyTokenQuote(uint amount) public view returns (int spentY) {
        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        return xToY({
            timeSinceStart: toDaysWadUnsafe(block.timestamp - startTime),
            sold: wadMul(int256(totalSupply()), 1e36),
            amount: int(amount)
        });
    }

    function getTokenQuoteForPayment(uint paymentWei) public view returns (int gainedX) {
        // Note: By using toDaysWadUnsafe(block.timestamp - startTime) we are establishing that 1 "unit of time" is 1 day.
        // solhint-disable-next-line not-rely-on-time
        return wadDiv(yToX({
            timeSinceStart: toDaysWadUnsafe(block.timestamp - startTime),
            sold: wadMul(int256(totalSupply()), 1e36),
            amount: int(paymentWei)
        }), 1e36);
    }
}
