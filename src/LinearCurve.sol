// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {BaseCurve} from "./BaseCurve.sol";

/**
 * @title  LinearCurve
 * @author 0xIntuition
 * @notice A simple 1:1 price model implemented as a bonding curve. This curve maintains
 *         a direct linear relationship between assets and shares, where the conversion
 *         follows the formula:
 *         $$f(x) = x$$
 *         where:
 *         - $x$ represents either assets or shares to be converted
 *         - $f(x)$ returns the corresponding amount in the target unit
 *
 * @notice The price mechanism relies on fee accumulation rather than supply-based pricing.
 *         As fees are collected, they are distributed proportionally across all shareholders,
 *         creating gradual appreciation in share value. This provides a conservative
 *         incentivization model where early participants benefit from fee accumulation
 *         over time.
 *
 * @notice This implementation offers a low-volatility approach to value accrual,
 *         suitable for scenarios where predictable, steady returns are preferred
 *         over dynamic pricing mechanisms.
 *
 * @dev This curve is not currently used in the EthMultiVault implementation to preserve
 *      audited code. It serves as a reference implementation demonstrating how traditional
 *      pro-rata share pricing can be adapted to the bonding curve architecture for future
 *      versions.
 */
contract LinearCurve is BaseCurve {
    /// @dev Maximum number of shares that can be handled by the curve.
    uint256 public constant MAX_SHARES = type(uint256).max;

    /// @dev Maximum number of assets that can be handled by the curve.
    uint256 public constant MAX_ASSETS = type(uint256).max;

    /// @notice Constructor for the Linear Curve.
    /// @param _name The name of the curve.
    constructor(string memory _name) BaseCurve(_name) {}

    /// @inheritdoc BaseCurve
    /// @notice Computes the 1:1 relationship between assets <--> shares.
    function previewDeposit(uint256 assets, uint256 totalAssets, uint256 totalShares)
        public
        view
        override
        returns (uint256 shares)
    {
        if (assets == 0) return 0;

        shares = assets; // 1:1 relationship

        return shares;
    }

    /// @inheritdoc BaseCurve
    /// @notice Computes the 1:1 relationship between assets <--> shares.
    function previewRedeem(uint256 shares, uint256 totalShares, uint256 totalAssets)
        public
        view
        override
        returns (uint256 assets)
    {
        if (shares == 0) return 0;

        assets = shares; // 1:1 relationship

        return assets;
    }

    /// @inheritdoc BaseCurve
    /// @notice Computes the 1:1 relationship between assets <--> shares.
    function previewMint(uint256 shares, uint256 totalShares, uint256 totalAssets)
        public
        view
        override
        returns (uint256 assets)
    {
        if (shares == 0) return 0;

        assets = shares; // 1:1 relationship

        return assets;
    }

    /// @inheritdoc BaseCurve
    /// @notice Computes the 1:1 relationship between assets <--> shares.
    function previewWithdraw(uint256 assets, uint256 totalAssets, uint256 totalShares)
        public
        view
        override
        returns (uint256 shares)
    {
        if (assets == 0) return 0;

        shares = assets; // 1:1 relationship

        return shares;
    }

    /// @inheritdoc BaseCurve
    /// @notice Computes the 1:1 relationship between assets <--> shares.
    function convertToShares(uint256 assets, uint256, /*totalAssets*/ uint256 /*totalShares*/ )
        public
        pure
        override
        returns (uint256 shares)
    {
        return assets;
    }

    /// @inheritdoc BaseCurve
    /// @notice Computes the 1:1 relationship between assets <--> shares.
    function convertToAssets(uint256 shares, uint256, /*totalShares*/ uint256 /*totalAssets*/ )
        public
        pure
        override
        returns (uint256 assets)
    {
        return shares;
    }

    /// @inheritdoc BaseCurve
    /// @notice In a linear curve, the base price will always be 1.  Pool ratio adjustments are dealt with in the EthMultiVault itself.
    function currentPrice(uint256 /*totalShares*/ ) public pure override returns (uint256 sharePrice) {
        return 1;
    }

    /// @inheritdoc BaseCurve
    function maxShares() public view override returns (uint256) {
        return MAX_SHARES;
    }

    /// @inheritdoc BaseCurve
    function maxAssets() public view override returns (uint256) {
        return MAX_ASSETS;
    }
}
