// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {
    wadExp,
    wadLn,
    wadMul,
    wadDiv,
    unsafeWadMul,
    unsafeWadDiv,
    toWadUnsafe,
    wadPow
} from "./SignedWadMath.sol";

/// @title Continuous Variable Rate Gradual Dutch Auction
/// @author transmissions11 <t11s@paradigm.xyz>
/// @author FrankieIsLost <frankie@paradigm.xyz>
/// @author Dan Robinson <dan@paradigm.xyz>
/// @notice Sell tokens roughly according to an issuance schedule.
contract VRGDAC {
    /*//////////////////////////////////////////////////////////////
                            VRGDA PARAMETERS
    //////////////////////////////////////////////////////////////*/

    int256 public immutable targetPrice;
    
    int256 public immutable perTimeUnit;

    int256 public immutable decayConstant;

    int256 public immutable priceDecayPercent;

    /// @notice Sets target price and per time unit price decay for the VRGDA.
    /// @param _targetPrice The target price for a token if sold on pace, scaled by 1e18.
    /// @param _priceDecayPercent The percent price decays per unit of time with no sales, scaled by 1e18.
    /// @param _perTimeUnit The number of tokens to target selling in 1 full unit of time, scaled by 1e18.
    constructor(int256 _targetPrice, int256 _priceDecayPercent, int256 _perTimeUnit) {
        targetPrice = _targetPrice;

        perTimeUnit = _perTimeUnit;

        priceDecayPercent = _priceDecayPercent;

        decayConstant = wadLn(1e18 - _priceDecayPercent);

        // The decay constant must be negative for VRGDAs to work.
        require(decayConstant < 0, "NON_NEGATIVE_DECAY_CONSTANT");
    }

    /*//////////////////////////////////////////////////////////////
                              PRICING LOGIC
    //////////////////////////////////////////////////////////////*/


    // y to pay
    // given # of tokens sold and # to buy, returns amount to pay
    function xToY(int256 timeSinceStart, int256 sold, int256 amount) public view virtual returns (int256) {
        unchecked {
            return pIntegral(timeSinceStart, sold + amount) - pIntegral(timeSinceStart, sold);
        }
    }

    // y to pay alt
    function xToYAlt(int256 timeSinceStart, int256 sold, int256 amount) public view virtual returns (int256) {

        //initial setups
        int256 ONEminusK = 1e18 - priceDecayPercent;
        int256 P0xR = wadMul(targetPrice, perTimeUnit);
        int256 ln1mK = wadLn(ONEminusK);

        //exponents
        int256 XSTARTdR = wadDiv(sold, perTimeUnit);
        int256 XSTARTpXBOUGHTdR = wadDiv(sold + amount, perTimeUnit);

        int256 coefficient = wadDiv(P0xR, ln1mK);

        int256 parenthesis = wadPow(ONEminusK, timeSinceStart - XSTARTdR) - wadPow(ONEminusK, timeSinceStart - XSTARTpXBOUGHTdR);

        return wadMul(coefficient, parenthesis);
    }

    // // given amount to pay and amount sold so far, returns # of tokens to sell
    function yToXOld(int256 timeSinceStart, int256 sold, int256 amount) public view virtual returns (int256) {
        unchecked {
            return wadMul(
                -wadDiv(
                    wadLn(1e18 - wadMul(amount, wadDiv(decayConstant, wadMul(perTimeUnit, p(timeSinceStart, sold))))),
                    decayConstant
                ),
                perTimeUnit
            );
        }
    }

    // // given amount to pay and amount sold so far, returns # of tokens to sell
    function yToX(int256 timeSinceStart, int256 sold, int256 amount) public view virtual returns (int256) {
        unchecked {
            return wadMul(
                perTimeUnit,
                wadDiv(
                    wadLn(wadDiv(
                        wadMul(targetPrice, wadMul(perTimeUnit, wadExp(wadMul(wadMul(perTimeUnit, timeSinceStart) - sold, wadDiv(decayConstant, perTimeUnit))))),
                        wadMul(targetPrice, wadMul(perTimeUnit, wadPow(decayConstant, wadDiv(wadMul(perTimeUnit, timeSinceStart) - sold, perTimeUnit)))) - wadMul(amount, decayConstant)
                    )),
                    decayConstant
                )
            );
        }
    }

    // given # of tokens sold, returns integral of price p(x) = p0 * (1 - k)^(x/r)
    function pIntegral(int256 timeSinceStart, int256 sold) internal view returns (int256) {
        return wadDiv(
            -wadMul(
                wadMul(targetPrice, perTimeUnit),
                wadPow(1e18 - priceDecayPercent, timeSinceStart - unsafeWadDiv(sold, perTimeUnit)) - wadPow(1e18 - priceDecayPercent, timeSinceStart)
            ),
            decayConstant
        );
    }

    // // given # of tokens sold, returns price p(x) = p0 * (1 - k)^(t - (x/r)) - (x/r) makes it a linearvrgda issuance
    function p(int256 timeSinceStart, int256 sold) internal view returns (int256) {
        return wadMul(targetPrice, wadPow(1e18 - priceDecayPercent, timeSinceStart - unsafeWadDiv(sold, perTimeUnit)));
    }
}