// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import { wadExp, wadLn, wadMul, wadDiv, unsafeWadDiv, wadPow } from "./SignedWadMath.sol";
import { VersionedContract } from "@cobuild/utility-contracts/src/version/VersionedContract.sol";
import { IUpgradeManager } from "@cobuild/utility-contracts/src/interfaces/IUpgradeManager.sol";
import { UUPS } from "@cobuild/utility-contracts/src/proxy/UUPS.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IVRGDAC } from "../interfaces/IVRGDAC.sol";

/// @title Continuous Variable Rate Gradual Dutch Auction
/// @author transmissions11 <t11s@paradigm.xyz>
/// @author FrankieIsLost <frankie@paradigm.xyz>
/// @author Dan Robinson <dan@paradigm.xyz>
/// @notice Sell tokens roughly according to an issuance schedule.
contract VRGDAC is IVRGDAC, VersionedContract, UUPS, OwnableUpgradeable {
    ///                                                          ///
    ///                         IMMUTABLES                       ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IUpgradeManager private immutable manager;

    /*//////////////////////////////////////////////////////////////
                            VRGDA PARAMETERS
    //////////////////////////////////////////////////////////////*/

    int256 public targetPrice;

    int256 public perTimeUnit;

    int256 public decayConstant;

    int256 public priceDecayPercent;

    // e ** x bound for the p function in wad form
    int256 public maxXBound;

    ///                                                          ///
    ///                         CONSTRUCTOR                      ///
    ///                                                          ///

    /// @param _manager The contract upgrade manager address
    constructor(address _manager) payable initializer {
        manager = IUpgradeManager(_manager);
    }

    ///                                                          ///
    ///                           ERRORS                         ///
    ///                                                          ///

    /// @notice Reverts for invalid manager initialization
    error SENDER_NOT_MANAGER();

    /// @notice Reverts for address zero
    error INVALID_ADDRESS_ZERO();

    ///                                                          ///
    ///                         INITIALIZER                      ///
    ///                                                          ///

    /// @notice Sets target price and per time unit price decay for the VRGDA.
    /// @param _initialOwner The initial owner of the contract
    /// @param _targetPrice The target price for a token if sold on pace, scaled by 1e18.
    /// @param _priceDecayPercent The percent price decays per unit of time with no sales, scaled by 1e18.
    /// @param _perTimeUnit The number of tokens to target selling in 1 full unit of time, scaled by 1e18.
    function initialize(
        address _initialOwner,
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _perTimeUnit
    ) public initializer {
        if (msg.sender != address(manager)) revert SENDER_NOT_MANAGER();
        if (_initialOwner == address(0)) revert INVALID_ADDRESS_ZERO();

        __Ownable_init(_initialOwner);

        targetPrice = _targetPrice;

        perTimeUnit = _perTimeUnit;

        priceDecayPercent = _priceDecayPercent;

        decayConstant = wadLn(1e18 - _priceDecayPercent);

        maxXBound = wadLn((type(int256).max / _targetPrice) / 1e18);

        // The decay constant must be negative for VRGDAs to work.
        require(decayConstant < 0, "NON_NEGATIVE_DECAY_CONSTANT");
    }

    /*//////////////////////////////////////////////////////////////
                              PRICING LOGIC
    //////////////////////////////////////////////////////////////*/

    // y to pay
    // given # of tokens sold and # to buy, returns amount to pay
    function xToY(int256 timeSinceStart, int256 sold, int256 amount) public view virtual returns (int256) {
        return pIntegral(timeSinceStart, sold + amount) - pIntegral(timeSinceStart, sold);
    }

    // given # of tokens sold, returns integral of price p(x) = p0 * (1 - k)^(t - x/r)
    function pIntegral(int256 timeSinceStart, int256 sold) internal view returns (int256) {
        return
            wadDiv(
                -wadMul(
                    wadMul(targetPrice, perTimeUnit),
                    wadPow(1e18 - priceDecayPercent, timeSinceStart - unsafeWadDiv(sold, perTimeUnit)) -
                        wadPow(1e18 - priceDecayPercent, timeSinceStart)
                ),
                decayConstant
            );
    }

    // from https://gist.github.com/transmissions11/485a6e2deb89236202bd2f59796262fd
    // given amount to pay for tokens, returns # of tokens to sell - raw form
    function yToX(int256 timeSinceStart, int256 sold, int256 amount) public view virtual returns (int256) {
        return
            wadMul(
                -wadDiv(
                    wadLn(1e18 - wadMul(amount, wadDiv(decayConstant, wadMul(perTimeUnit, p(timeSinceStart, sold))))),
                    decayConstant
                ),
                perTimeUnit
            );
    }

    function p(int256 timeSinceStart, int256 sold) internal view returns (int256) {
        // we want to make sure we don't hit the precision limits of wadPow and permanently brick the vrgda

        // wadPow -> x ** y == e ** (ln(x) * y)
        // so ln(x) * y is what goes into wadExp per the SignedWadMath function
        // divide by 1e18 because wadMath
        int256 x = (wadLn(1e18 - priceDecayPercent) * (timeSinceStart - unsafeWadDiv(sold, perTimeUnit))) / 1e18; // when this overflows, we just want to floor / max it

        // We want to make sure that the wadExp parameter is not too large or too small
        // If it is too large or too small, we will sacrifice precision to keep the VRGDA functional
        // until it can get back on schedule

        // From SignedWadMath.sol by t11s //

        // When the result is < 0.5 we return zero. This happens when
        // x <= floor(log(0.5*10^-18) * 1e18) ~ -42e18
        // When this case is reached, we want to return 1 instead of 0 to avoid breaking the VRGDA
        // Intuitively, when we are way behind schedule eg: not enough tokens sold, the price for them is tiny
        // Instead of returning 0 as the price, we return 1
        if (x <= -41446531673892822313) {
            //don't allow 0 as the 2nd parameter to wadMul
            int256 p_x_min = wadMul(targetPrice, 1);
            // if p_x_min is 0, return 1 instead so we don't break the VRGDA
            // nothing in this function depends on the amount of tokens being purchased, so we can return 1
            if (p_x_min == 0) {
                return 1;
            }
            return p_x_min;
        }

        // When the result of wadExp is > (2**255 - 1) / 1e18 we can not represent it as an
        // int. This happens when x >= floor(log((2**255 - 1) / 1e18) * 1e18) ~ 135.
        // When this case is reached, we want to return the max possible value instead of reverting

        // Intuitively, when we are way ahead of schedule eg: too many tokens sold, the price for them is huge
        // Need to make sure this doesn't overflow, given we're multiplying targetPrice * maxPrice * perTimeUnit
        // Solve for x where the overflow occurs according to the formula
        // p_0 * (e ** x) = (2 ** 255 - 1)
        // Divide by 1e18 to get the x value for wadExp
        // x = ln( (2 ** 255 - 1) / targetPrice) / 1e18
        if (x >= maxXBound) {
            // When ahead of schedule drastically
            // Return the max possible price value given we are about to also multiply by perTimeUnit
            return (type(int256).max / perTimeUnit);
        }

        int256 p_x = wadMul(
            targetPrice,
            wadPow(1e18 - priceDecayPercent, timeSinceStart - unsafeWadDiv(sold, perTimeUnit))
        );
        // if p_x is 0, return 1 instead so we don't break the VRGDA
        // nothing in this function depends on the amount of tokens being purchased, so we can return 1
        if (p_x == 0) {
            return 1;
        }
        return p_x;
    }

    ///                                                          ///
    ///                        VRGDA UPGRADE                     ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract and that the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner {
        // Ensure the new implementation is a registered upgrade
        if (!manager.isRegisteredUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
