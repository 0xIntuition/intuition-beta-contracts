// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {BaseCurve} from "./BaseCurve.sol";

/**
 * @title  LinearCurve
 * @author 0xIntuition
 * @notice 🎯 The OG, battle-tested share price model, now reborn as a bonding curve!
 *         This magnificent specimen takes the legacy share price logic - a time-honored 1:1
 *         relationship between assets and shares - and wraps it in our shiny new bonding curve
 *         architecture. While it's currently chillin' on the sidelines of our ETHMultiVault
 *         implementation (we see you, future integrations 👀), this curve is the unsung hero
 *         of low-risk incentivization.
 *
 * @notice Here's the secret sauce: instead of fancy mathematical gymnastics, this curve relies
 *         on the pure, unadulterated power of fees to affect share price. When fees roll in,
 *         they're distributed proportionally across all shareholders, creating a gentle upward
 *         pressure on share value. It's like watching paint dry, but the paint is made of MONEY! 💰
 *
 * @notice This creates an incredibly based, low-risk incentivization model where early stakers
 *         benefit from the natural accumulation of fees over time. No wild price swings, no
 *         complex formulas - just steady, reliable value accrual. It's the Toyota Corolla of
 *         bonding curves: not flashy, but it'll get you there every single time! 🚗
 *
 * @dev This curve is not actually used in this version of the EthMultiVault, so as to avoid changing
 *      audited code.  It is left here to demonstrate the design pattern of curves for V2.  This curve
 *      replaces the legacy "pro-rata" logic by wrapping it in the Bonding Curve architecture.
 */
contract LinearCurve is BaseCurve {
    /// @dev UD60x18 Max
    uint256 public immutable MAX_SHARES = type(uint256).max / 1e18;

    /// @dev UD60x18 Max
    uint256 public immutable MAX_ASSETS = type(uint256).max / 1e18;

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
