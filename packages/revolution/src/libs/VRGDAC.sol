// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { wadExp, wadLn, wadMul, wadDiv, unsafeWadDiv, wadPow } from "./SignedWadMath.sol";

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
        return pIntegral(timeSinceStart, sold + amount) - pIntegral(timeSinceStart, sold);
    }

    event LogValue(string key, int256 value);

    // the difference between the amount of tokens sold and the amount of tokens that should have been sold
    // r * t - x_start
    function soldDifference(int256 timeSinceStart, int256 sold) public virtual returns (int256) {
        int256 soldDif = wadMul(perTimeUnit, timeSinceStart) - sold;

        emit LogValue("soldDif", soldDif);

        return soldDif;
    }

    //the soldDif over the per time unit
    // (r * t - x_start) / r
    function soldDifferenceOverTimeUnit(int256 timeSinceStart, int256 sold) public virtual returns (int256) {
        int difOverR = wadDiv(soldDifference(timeSinceStart, sold), perTimeUnit);

        // emit LogValue("difOverR", difOverR);

        return difOverR;
    }

    // the decay rate to the power of the sold difference over the per time unit
    // (1 - k) ^ (r * t - x_start)
    function decayRate_PowerOf_SoldDifference_Over_TimeUnit(
        int256 timeSinceStart,
        int256 sold
    ) public virtual returns (int256) {
        int256 one_Minus_k = 1e18 - priceDecayPercent;

        // emit LogValue("one_Minus_k", one_Minus_k);

        int256 decayRateExp = wadPow(one_Minus_k, soldDifferenceOverTimeUnit(timeSinceStart, sold));

        // emit LogValue("decayRateExp", decayRateExp);

        return decayRateExp;
    }

    // the target price times the decayRateExp times the per time unit
    // p0 * (1 - k) ^ (r * t - x_start) * r
    function targetPrice_Times_DecayRateExp_Times_PerTimeUnit(
        int256 timeSinceStart,
        int256 sold
    ) public virtual returns (int256) {
        int decayRateExp = decayRate_PowerOf_SoldDifference_Over_TimeUnit(timeSinceStart, sold);

        int256 p0_r_decayRateExp = wadMul(targetPrice, wadMul(perTimeUnit, decayRateExp));

        // emit LogValue("p0_r_decayRateExp", p0_r_decayRateExp);

        return p0_r_decayRateExp;
    }

    // the amount (ether) to pay times the decay constant
    // x * ln (1 - k)
    function amountToPay_Times_DecayConstant(int256 amount) public virtual returns (int256) {
        int256 amountToPay_decay = wadMul(amount, decayConstant);

        // emit LogValue("amountToPay_decay", amountToPay_decay);

        return amountToPay_decay;
    }

    // the difference between the target price times the decayRateExp times the per time unit and the amount (ether) to pay times the decay constant
    // p0 * (1 - k) ^ (r * t - x_start) * r - x * ln (1 - k)
    function differenceBetweenTargetPriceAndAmountToPay(
        int256 timeSinceStart,
        int256 sold,
        int256 amount
    ) public virtual returns (int256) {
        int256 p0_r_decayRateExp = targetPrice_Times_DecayRateExp_Times_PerTimeUnit(timeSinceStart, sold);

        int256 amountToPay_decay = amountToPay_Times_DecayConstant(amount);

        int256 difference = p0_r_decayRateExp - amountToPay_decay;

        // emit LogValue("difference_targetPrice_payment", difference);

        return difference;
    }

    // the sold dif times the decay constant
    // (r * t - x_start) * ln (1 - k)
    function soldDifference_Times_DecayConstant(int256 timeSinceStart, int256 sold) public virtual returns (int256) {
        int256 soldDif = soldDifference(timeSinceStart, sold);

        int256 soldDif_decay = wadMul(soldDif, decayConstant);

        emit LogValue("soldDif_decay", soldDif_decay); // this is hugely negative -9e22

        return soldDif_decay;
    }

    // soldDif_decay over the per time unit
    // (r * t - x_start) * ln (1 - k) / r
    function e_soldDifference_Times_DecayConstant_Over_PerTimeUnit(
        int256 timeSinceStart,
        int256 sold
    ) public virtual returns (int256) {
        int256 soldDif_decay = soldDifference_Times_DecayConstant(timeSinceStart, sold);

        int256 soldDif_decay_over_r = wadDiv(soldDif_decay, perTimeUnit);

        emit LogValue("soldDif_decay_over_r", soldDif_decay_over_r); // this is hugely negative -9e19

        int256 e_soldDif_decay_over_r = wadExp(soldDif_decay_over_r); // this is 0 !!

        emit LogValue("e_soldDif_decay_over_r", e_soldDif_decay_over_r);

        return e_soldDif_decay_over_r;
    }

    // given amount to pay and amount sold so far, returns # of tokens to sell - raw form
    function test_yToX(int256 timeSinceStart, int256 sold, int256 amount) public virtual returns (int256) {
        //top level emits
        emit LogValue("timeSinceStart", timeSinceStart);
        emit LogValue("sold", sold);
        emit LogValue("amount", amount);
        emit LogValue("perTimeUnit", perTimeUnit);
        emit LogValue("decayConstant", decayConstant);
        emit LogValue("=====================", 0);

        int256 soldDif = soldDifference(timeSinceStart, sold);

        int256 difference_targetPrice_payment = differenceBetweenTargetPriceAndAmountToPay(
            timeSinceStart,
            sold,
            amount
        );

        int e_soldDif_decay_over_r = e_soldDifference_Times_DecayConstant_Over_PerTimeUnit(timeSinceStart, sold);

        return
            wadDiv(
                wadMul(
                    perTimeUnit,
                    wadLn( // ln of 0 is undefined
                        wadDiv(
                            wadMul(targetPrice, wadMul(perTimeUnit, e_soldDif_decay_over_r)),
                            difference_targetPrice_payment
                        )
                    )
                ),
                decayConstant
            );
    }

    // given amount to pay and amount sold so far, returns # of tokens to sell - raw form
    function yToX(int256 timeSinceStart, int256 sold, int256 amount) public view virtual returns (int256) {
        int256 soldDifference = wadMul(perTimeUnit, timeSinceStart) - sold;

        return
            wadDiv(
                wadMul(
                    perTimeUnit,
                    wadLn(
                        wadDiv(
                            wadMul(
                                targetPrice,
                                wadMul(perTimeUnit, wadExp(wadDiv(wadMul(soldDifference, decayConstant), perTimeUnit)))
                            ),
                            wadMul(
                                targetPrice,
                                wadMul(
                                    perTimeUnit,
                                    wadPow(1e18 - priceDecayPercent, wadDiv(soldDifference, perTimeUnit))
                                )
                            ) - wadMul(amount, decayConstant)
                        )
                    )
                ),
                decayConstant
            );
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
    function yToX_t11s_Paradigm(
        int256 timeSinceStart,
        int256 sold,
        int256 amount
    ) public view virtual returns (int256) {
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
        return wadMul(targetPrice, wadPow(1e18 - priceDecayPercent, timeSinceStart - unsafeWadDiv(sold, perTimeUnit)));
    }
}
