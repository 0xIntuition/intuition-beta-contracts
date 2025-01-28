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
 *         Here's the secret sauce: instead of fancy mathematical gymnastics, this curve relies 
 *         on the pure, unadulterated power of fees to affect share price. When fees roll in, 
 *         they're distributed proportionally across all shareholders, creating a gentle upward 
 *         pressure on share value. It's like watching paint dry, but the paint is made of MONEY! 💰
 *
 *         This creates an incredibly based, low-risk incentivization model where early stakers 
 *         benefit from the natural accumulation of fees over time. No wild price swings, no 
 *         complex formulas - just steady, reliable value accrual. It's the Toyota Corolla of 
 *         bonding curves: not flashy, but it'll get you there every single time! 🚗
 */
contract LinearCurve is BaseCurve {
    // For linear curve, max values are the same since it's 1:1
    uint256 public immutable MAX_SHARES = type(uint256).max / 1e18;
    uint256 public immutable MAX_ASSETS = type(uint256).max / 1e18;

    constructor(string memory _name) BaseCurve(_name) {}

    /// @inheritdoc BaseCurve
    // Compute the shares that will be minted by depositing a quantity of assets, adjusted for the pool's total assets and shares
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
    // Compute the assets that will be returned by redeeming a quantity of shares, adjusted for the pool's total assets and shares
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
    // Compute the assets that will be required to mint a quantity of shares, adjusted for the pool's total assets and shares
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
    // Compute the shares that will be redeemed for a withdrawal of assets, adjusted for the pool's total assets and shares
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

    function convertToShares(uint256 assets, uint256 totalAssets, uint256 /*totalShares*/ )
        public
        pure
        override
        returns (uint256 shares)
    {
        return assets;
    }

    function convertToAssets(uint256 shares, uint256 totalShares, uint256 /*totalAssets*/ )
        public
        pure
        override
        returns (uint256 assets)
    {
        return shares;
    }

    function currentPrice(uint256 /*totalShares*/ ) public pure override returns (uint256 sharePrice) {
        return 1;
    }

    function maxShares() public view override returns (uint256) {
        return MAX_SHARES;
    }

    function maxAssets() public view override returns (uint256) {
        return MAX_ASSETS;
    }
}
