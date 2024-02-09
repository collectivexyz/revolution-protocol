// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

interface IVRGDAC {
    /**
     * @notice Initializes the VRGDAC contract
     * @param initialOwner The initial owner of the contract
     * @param targetPrice The target price for a token if sold on pace, scaled by 1e18.
     * @param priceDecayPercent The percent price decays per unit of time with no sales, scaled by 1e18.
     * @param perTimeUnit The number of tokens to target selling in 1 full unit of time, scaled by 1e18.
     */
    function initialize(
        address initialOwner,
        int256 targetPrice,
        int256 priceDecayPercent,
        int256 perTimeUnit
    ) external;

    function yToX(int256 timeSinceStart, int256 sold, int256 amount) external view returns (int256);

    function xToY(int256 timeSinceStart, int256 sold, int256 amount) external view returns (int256);
}
