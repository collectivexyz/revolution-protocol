// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { LinearVRGDA } from "./libs/LinearVRGDA.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { toDaysWadUnsafe } from "solmate/src/utils/SignedWadMath.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import { NontransferableERC20 } from "./NontransferableERC20.sol";
import { ITokenEmitter } from "./interfaces/ITokenEmitter.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TokenEmitter is LinearVRGDA, ITokenEmitter, AccessControlEnumerable, ReentrancyGuard {
    //TODO: make treasury editable. Remember to remove the old treasury from admin status and add the new one when changing it in the function.

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
        address _treasury,
        int256 _targetPrice, // SCALED BY E18. Target price. This is somewhat arbitrary for governance emissions, since there is no "target price" for 1 governance share.
        int256 _priceDecayPercent, // SCALED BY E18. Price decay percent. This indicates how aggressively you discount governance when sales are not occurring.
        int256 _governancePerTimeUnit // SCALED BY E18. The number of tokens to target selling in 1 full unit of time.
    ) LinearVRGDA(_targetPrice, _priceDecayPercent, _governancePerTimeUnit) {
        treasury = _treasury;

        token = _token;

        // TODO: remove this once we don't need to move so fast
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function _mint(address _to, uint _amount) private {
        token.mint(_to, _amount);
    }

    function totalSupply() public view returns (uint) {
        // returns total supply of issued so far
        return token.totalSupply();
    }

    function balanceOf(address _owner) public view returns (uint) {
        // returns balance of address
        return token.balanceOf(_owner);
    }

    // solhint-disable-next-line func-name-mixedcase
    function UNSAFE_updateTreasury(address _newTreasury) public onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = _newTreasury;
    }

    // takes a list of addresses and a list of payout percentages
    function buyToken(
        address[] memory _addresses,
        uint[] memory _percentages,
        uint256
    ) public payable nonReentrant returns (uint256) {
        // ensure the same number of addresses and percentages
        require(_addresses.length == _percentages.length, "Parallel arrays required");

        uint totalTokens = getTokenAmountForMultiPurchase(msg.value);
        (bool success, ) = treasury.call{ value: msg.value }("");
        require(success, "Transfer failed.");

        // calculates how much total governance to give

        uint sum = 0;

        // calculates how much governance to give each address
        for (uint i = 0; i < _addresses.length; i++) {
            uint tokens = (totalTokens * _percentages[i]) / 100;
            // transfer governance to address
            _mint(_addresses[i], tokens);
            sum += _percentages[i];
        }

        require(sum == 100, "Percentages must add up to 100");
        return totalTokens;
    }

    // This returns a safe, underestimated amount of governance.
    function _getTokenAmountForSinglePurchase(uint256 payment, uint256 supply) public view returns (uint256) {
        uint256 initialEstimatedAmount = UNSAFE_getOverestimateTokenAmount(payment, supply);
        uint256 overestimatedPrice = getTokenPrice(supply + initialEstimatedAmount);
        uint256 underestimatedAmount = payment / overestimatedPrice;
        return underestimatedAmount;
    }

    function getTokenAmountForMultiPurchase(uint256 payment) public view returns (uint256) {
        // payment is split up into chunks of numTokens
        // each chunk is estimated and the total is returned
        // chunk up the payments into 0.01eth chunks

        uint256 remainingEth = payment;
        uint256 total = 0;
        // solhint-disable-next-line var-name-mixedcase
        uint256 INCREMENT_SIZE = 1e18;
        while (remainingEth > 0) {
            if (remainingEth < INCREMENT_SIZE) {
                total += _getTokenAmountForSinglePurchase(remainingEth, totalSupply() + total);
                remainingEth = 0;
            } else {
                total += _getTokenAmountForSinglePurchase(INCREMENT_SIZE, totalSupply() + total);
                remainingEth -= INCREMENT_SIZE;
            }
        }
        return total;
    }

    // This will return MORE GOVERNANCE than it should. Never reward the user with this; the DAO will get taken over.
    // solhint-disable-next-line func-name-mixedcase
    function UNSAFE_getOverestimateTokenAmount(uint256 payment, uint256 supply) public view returns (uint256) {
        uint256 initialPrice = getTokenPrice(supply);
        uint256 initialEstimatedAmount = payment / initialPrice;
        return initialEstimatedAmount;
    }

    function getTokenPrice(uint256 currentTotalSupply) public view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        uint256 price = getVRGDAPrice(toDaysWadUnsafe(block.timestamp - startTime), currentTotalSupply);
        // TODO make test that price never hits zero
        return price;
    }

    function transferTokenAdmin(address _newOwner) public onlyRole(DEFAULT_ADMIN_ROLE) {
        token.transferAdmin(_newOwner);
    }
}
