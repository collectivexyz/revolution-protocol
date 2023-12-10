// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { wadExp, wadLn, wadMul, wadDiv, unsafeWadDiv, wadPow } from "./SignedWadMath.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title Continuous Variable Rate Gradual Dutch Auction
/// @author transmissions11 <t11s@paradigm.xyz>
/// @author FrankieIsLost <frankie@paradigm.xyz>
/// @author Dan Robinson <dan@paradigm.xyz>
/// @notice Sell tokens roughly according to an issuance schedule.
contract VRGDAC is Initializable {
    /*//////////////////////////////////////////////////////////////
                            VRGDA PARAMETERS
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:revolution.storage.VRGDAC
    struct VRGDACStorage {
        int256 targetPrice;

        int256 tokensPerTimeUnit;

        int256 decayConstant;

        int256 priceDecayPercent;
    }

    // TODO calculate this keccak256(abi.encode(uint256(keccak256("revolution.storage.VRGDAC")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant VRGDACStorageLocation =
        0xe8b26c30fad74198956032a3533d903385d56dd795af560196f9c78d4af40d00;

    function _getVotesStorage() private pure returns (VRGDACStorage storage $) {
        assembly {
            $.slot := VRGDACStorageLocation
        }
    }

    /// @notice Sets target price and per time unit price decay for the VRGDA.
    /// @param _targetPrice The target price for a token if sold on pace, scaled by 1e18.
    /// @param _priceDecayPercent The percent price decays per unit of time with no sales, scaled by 1e18.
    /// @param _tokensPerTimeUnit The number of tokens to target selling in 1 full unit of time, scaled by 1e18.
    function __VRGDAC_init(int256 _targetPrice, int256 _priceDecayPercent, int256 _tokensPerTimeUnit) internal onlyInitializing {
        __VRGDAC_init_unchained(_targetPrice, _priceDecayPercent, _tokensPerTimeUnit);
    }

    function __VRGDAC_init_unchained(int256 _targetPrice, int256 _priceDecayPercent, int256 _tokensPerTimeUnit) internal onlyInitializing {
        int256 decayConstant = wadLn(1e18 - _priceDecayPercent);

        // The decay constant must be negative for VRGDAs to work.
        require(decayConstant < 0, "NON_NEGATIVE_DECAY_CONSTANT");

        // set storage variables
        VRGDACStorage storage $ = _getVotesStorage();
        $.targetPrice = _targetPrice;
        $.tokensPerTimeUnit = _tokensPerTimeUnit;
        $.priceDecayPercent = _priceDecayPercent;
        $.decayConstant = decayConstant;
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

    // given amount to pay and amount sold so far, returns # of tokens to sell - raw form
    function yToX(int256 timeSinceStart, int256 sold, int256 amount) public view virtual returns (int256) {
        VRGDACStorage storage $ = _getVotesStorage();

        int256 soldDifference = wadMul($.tokensPerTimeUnit, timeSinceStart) - sold;
        unchecked {
            return
                wadMul(
                    $.tokensPerTimeUnit,
                    wadDiv(
                        wadLn(
                            wadDiv(
                                wadMul(
                                    $.targetPrice,
                                    wadMul(
                                        $.tokensPerTimeUnit,
                                        wadExp(wadMul(soldDifference, wadDiv($.decayConstant, $.tokensPerTimeUnit)))
                                    )
                                ),
                                wadMul(
                                    $.targetPrice,
                                    wadMul(
                                        $.tokensPerTimeUnit,
                                        wadPow(1e18 - $.priceDecayPercent, wadDiv(soldDifference, $.tokensPerTimeUnit))
                                    )
                                ) - wadMul(amount, $.decayConstant)
                            )
                        ),
                        $.decayConstant
                    )
                );
        }
    }

    // given # of tokens sold, returns integral of price p(x) = p0 * (1 - k)^(x/r)
    function pIntegral(int256 timeSinceStart, int256 sold) internal view returns (int256) {
        VRGDACStorage storage $ = _getVotesStorage();

        return
            wadDiv(
                -wadMul(
                    wadMul($.targetPrice, $.tokensPerTimeUnit),
                    wadPow(1e18 - $.priceDecayPercent, timeSinceStart - unsafeWadDiv(sold, $.tokensPerTimeUnit)) -
                        wadPow(1e18 - $.priceDecayPercent, timeSinceStart)
                ),
                $.decayConstant
            );
    }
}
