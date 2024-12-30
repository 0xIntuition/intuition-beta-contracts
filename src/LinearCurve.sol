// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {BaseCurve} from "./BaseCurve.sol";

/**
 * @title  LinearCurve
 * @author 0xIntuition
 * @notice Models a linear curve where shares and assets maintain a 1:1 relationship.
 *         This is the simplest curve possible, used as a baseline implementation.
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
        require(assets + totalAssets < MAX_ASSETS, "LC: Exceeds max assets");

        shares = assets; // 1:1 relationship

        // Deposit Adjustment:
        uint256 totalAssetsInShareSpace = totalAssets; // 1 : 1 relationship
        shares = super._adjust(shares, totalShares, totalAssetsInShareSpace);

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
        require(totalShares < MAX_SHARES, "LC: Exceeds max shares");

        assets = shares; // 1:1 relationship

        // Redeem Adjustment:
        uint256 totalSharesInAssetsSpace = totalShares; // 1 : 1 relationship
        assets = super._adjust(assets, totalAssets, totalSharesInAssetsSpace);

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
        require(shares + totalShares < MAX_SHARES, "LC: Exceeds max shares");

        assets = shares; // 1:1 relationship

        // Mint Adjustment:
        uint256 totalSharesInAssetSpace = totalShares; // 1 : 1 relationship
        assets = super._adjust(assets, totalAssets, totalSharesInAssetSpace);

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
        require(totalAssets < MAX_ASSETS, "LC: Exceeds max assets");

        shares = assets; // 1:1 relationship

        // Withdraw Adjustment:
        uint256 totalAssetsInShareSpace = totalAssets; // 1 : 1 relationship
        shares = super._adjust(shares, totalShares, totalAssetsInShareSpace);

        return shares;
    }

    function convertToShares(uint256 assets, uint256 totalAssets, uint256 /*totalShares*/ )
        public
        pure
        override
        returns (uint256 shares)
    {
        require(totalAssets >= assets, "LC: Under supply of assets");
        return assets;
    }

    function convertToAssets(uint256 shares, uint256 totalShares, uint256 /*totalAssets*/ )
        public
        pure
        override
        returns (uint256 assets)
    {
        require(totalShares >= shares, "LC: Under supply of shares");
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
