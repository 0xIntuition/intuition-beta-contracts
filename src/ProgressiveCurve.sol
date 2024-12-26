// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {BaseCurve} from "./BaseCurve.sol";
import {UD60x18, ud60x18} from "@prb/math/UD60x18.sol";

/**
 * @title  ProgressiveCurve
 * @author 0xIntuition
 * @notice Implementation of a progressive bonding curve where price increases linearly with each share
 */
contract ProgressiveCurve is BaseCurve {
    UD60x18 public immutable SLOPE; // 0.0025e18 -> 25 basis points, 0.0001e18 = 1 basis point, etc etc
    UD60x18 public immutable HALF_SLOPE;

    // Computed limits
    uint256 public immutable MAX_SHARES;
    uint256 public immutable MAX_ASSETS;

    constructor(string memory _name, uint256 slope18) BaseCurve(_name) {
        require(slope18 > 0, "PC: Slope must be > 0");

        SLOPE = UD60x18.wrap(slope18);
        HALF_SLOPE = SLOPE.div(UD60x18.wrap(2));

        // Find max values
        // powu(2) will overflow first, therefore maximum totalShares is sqrt(MAX_UD60x18)
        // Then the maximum assets is the total shares * slope / 2, because multiplication will overflow at this point
        UD60x18 MAX_UD60x18 = UD60x18.wrap(type(uint256).max / 1e18);
        MAX_SHARES = MAX_UD60x18.sqrt().unwrap();
        MAX_ASSETS = MAX_UD60x18.mul(HALF_SLOPE).unwrap();
    }

    // Total Assets is not used yet, but it will be for adjustment to resolve the domains as the numerator converted to share space
    function previewDeposit(uint256 assets, uint256 /*totalAssets*/, uint256 totalShares)
        public
        view
        override
        returns (uint256 shares)
    {
        require(assets > 0, "Asset amount must be greater than zero");

        UD60x18 currentSupplyOfShares = UD60x18.wrap(totalShares);

        return currentSupplyOfShares.powu(2).add(UD60x18.wrap(assets).div(HALF_SLOPE)).sqrt().sub(currentSupplyOfShares)
            .unwrap();
    }

    // Total assets is not used yet, but it will be for adjustment to resolve the domains as the denominator
    function previewRedeem(uint256 shares, uint256 totalShares, uint256 /*totalAssets*/)
        public
        view
        override
        returns (uint256 assets)
    {
        UD60x18 currentSupplyOfShares = UD60x18.wrap(totalShares);

        UD60x18 supplyOfSharesAfterRedeem = currentSupplyOfShares.sub(UD60x18.wrap(shares));

        return _convertToAssets(supplyOfSharesAfterRedeem, currentSupplyOfShares).unwrap();
    }

    // Total assets is not used yet, but it will be for adjustment to resolve the domains as the denominator
    function previewMint(uint256 shares, uint256 totalShares, uint256 /*totalAssets*/)
        public
        view
        override
        returns (uint256 assets)
    {
        return _convertToAssets(UD60x18.wrap(totalShares), UD60x18.wrap(totalShares + shares)).unwrap();
    }

    // Total assets is not used yet, but it will be for adjustment to resolve the domains as the denominator
    function previewWithdraw(uint256 assets, uint256 /*totalAssets*/, uint256 totalShares)
        public
        view
        override
        returns (uint256 shares)
    {
        UD60x18 currentSupplyOfShares = UD60x18.wrap(totalShares);
        return currentSupplyOfShares.sub(currentSupplyOfShares.powu(2).sub(UD60x18.wrap(assets).div(HALF_SLOPE)).sqrt())
            .unwrap();
    }

    function currentPrice(uint256 totalShares) public view override returns (uint256 sharePrice) {
        return UD60x18.wrap(totalShares).mul(SLOPE).unwrap();
    }

    function convertToShares(uint256 assets, uint256 totalAssets, uint256 totalShares)
        public
        view
        override
        returns (uint256 shares)
    {
        require(totalAssets >= assets, "PC: Under supply of assets");
        UD60x18 conversionPrice = UD60x18.wrap(totalShares).mul(HALF_SLOPE);
        return UD60x18.wrap(assets).div(conversionPrice).unwrap();
    }

    // Total assets is not used yet, but it will be for adjustment to resolve the domains as the denominator
    function convertToAssets(uint256 shares, uint256 totalShares, uint256 /*totalAssets*/)
        public
        view
        override
        returns (uint256 assets)
    {
        require(totalShares >= shares, "PC: Under supply of shares");
        UD60x18 conversionPrice = UD60x18.wrap(totalShares).mul(HALF_SLOPE);
        return UD60x18.wrap(shares).mul(conversionPrice).unwrap();
    }

    /**
     * @notice Computes assets as the area under a linear curve with a simplified form of the area of a trapezium,
     * f(x) = mx + c, and Area = 1/2 * (a + b) * h
     * where `a` and `b` can be both f(juniorSupply) or f(seniorSupply) depending if used in minting or redeeming.
     * Calculates area as (seniorSupply^2 - juniorSupply^2) * halfSlope, where halfSlope = (slope / 2)
     *
     * @param juniorSupply The smaller supply in the operation (the initial supply during mint,
     * or the final supply during a redeem operation).
     * @param seniorSupply The larger supply in the operation (the final supply during mint,
     * or the initial supply during a redeem operation).
     * @return assets The computed assets as an instance of UD60x18 (a fixed-point number).
     */
    function _convertToAssets(UD60x18 juniorSupply, UD60x18 seniorSupply) internal view returns (UD60x18 assets) {
        UD60x18 sqrDiff = seniorSupply.powu(2).sub(juniorSupply.powu(2));
        return sqrDiff.mul(HALF_SLOPE);
    }

    function maxShares() public view override returns (uint256) {
        return MAX_SHARES;
    }

    function maxAssets() public view override returns (uint256) {
        return MAX_ASSETS;
    }
}
