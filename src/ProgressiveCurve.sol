// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {BaseCurve} from "./BaseCurve.sol";
import {UD60x18, ud60x18, convert, uMAX_UD60x18, uUNIT} from "@prb/math/UD60x18.sol";

/**
 * @title  ProgressiveCurve
 * @author 0xIntuition
 * @notice A bonding curve implementation that uses a progressive pricing model where
 *         each new share costs more than the last.
 *
 *         The price follows the formula:
 *         $$P(s) = m \cdot s$$
 *         where:
 *         - $m$ is the slope (in basis points)
 *         - $s$ is the total supply of shares
 *
 *         The cost to mint shares is calculated as the area under this curve:
 *         $$\text{Cost} = (s_2^2 - s_1^2) \cdot \frac{m}{2}$$
 *         where $s_1$ is the starting share supply and $s_2$ is the final share supply.
 *
 *         This curve creates stronger incentives for early stakers compared to the LinearCurve,
 *         while maintaining fee-based appreciation.
 *
 * @dev    Uses the prb-math library for fixed point arithmetic with UD60x18
 * @dev    Fixed point precision used for all internal calculations, while return values are all
 *             represented as regular uint256s, and unwrapped.  I.e. we might use 123.456 internally
 *             and return 123.
 * @dev    The core equation:
 *             $$P(s) = m \cdot s$$
 *             and the cost equation:
 *             $$\text{Cost} = (s_2^2 - s_1^2) \cdot \frac{m}{2}$$
 *             comes from calculus - it's the integral of a linear price function. The area under a
 *             linear curve from point $s_1$ to $s_2$ gives us the total cost/return of minting/redeeming
 *             shares.
 * @dev    Inspired by the Solaxy.sol contract: https://github.com/M3tering/Solaxy/blob/main/src/Solaxy.sol
 *          and https://m3tering.whynotswitch.com/token-economics/mint-and-distribution.  * The key difference
 *          between the Solaxy contract and this one is that the economic state is handled by the EthMultiVault
 *          instead of directly in the curve implementation. *  Otherwise the math is identical.
 */
contract ProgressiveCurve is BaseCurve {
    /// @notice The slope of the curve, in basis points.  This is the rate at which the price of shares increases.
    /// @dev 0.0025e18 -> 25 basis points, 0.0001e18 = 1 basis point, etc etc
    /// @dev If minDeposit is 0.003 ether, this value would need to be 0.00007054e18 to avoid returning 0 shares for minDeposit assets
    UD60x18 public SLOPE;

    /// @notice The half of the slope, used for calculations.
    UD60x18 public HALF_SLOPE;

    /// @dev Since powu(2) will overflow first (see slope equation), maximum totalShares is sqrt(MAX_UD60x18)
    uint256 public MAX_SHARES;

    /// @dev The maximum assets is totalShares * slope / 2, because multiplication (see slope equation) would overflow beyond that point.
    uint256 public MAX_ASSETS;

    /// @notice Constructs a new ProgressiveCurve with the given name and slope
    /// @param _name The name of the curve (i.e. "Progressive Curve #465")
    /// @param slope18 The slope of the curve, in basis points (i.e. 0.0025e18)
    /// @dev Computes maximum values given constructor arguments
    /// @dev Computes Slope / 2 as commonly used constant
    constructor(string memory _name, uint256 slope18) BaseCurve(_name) {
        require(slope18 > 0, "PC: Slope must be > 0");

        SLOPE = UD60x18.wrap(slope18);
        HALF_SLOPE = UD60x18.wrap(slope18 / 2);

        // Find max values
        // powu(2) will overflow first, therefore maximum totalShares is sqrt(MAX_UD60x18)
        // Then the maximum assets is the total shares * slope / 2, because multiplication will overflow at this point
        UD60x18 MAX_SQRT = UD60x18.wrap(uMAX_UD60x18 / uUNIT);
        MAX_SHARES = MAX_SQRT.sqrt().unwrap();
        MAX_ASSETS = MAX_SQRT.mul(HALF_SLOPE).unwrap();
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply
    /// @dev Let $a$ = amount of assets to deposit
    /// @dev Let $\frac{m}{2}$ = half of the slope
    /// @dev shares:
    /// $$\text{shares} = \sqrt{s^2 + \frac{a}{m/2}} - s$$
    /// @dev or to say that another way:
    /// $$\text{shares} = \sqrt{s^2 + \frac{2a}{m}} - s$$
    function previewDeposit(uint256 assets, uint256, /*totalAssets*/ uint256 totalShares)
        external
        view
        override
        returns (uint256 shares)
    {
        require(assets > 0, "Asset amount must be greater than zero");

        UD60x18 currentSupplyOfShares = convert(totalShares);

        return convert(currentSupplyOfShares.powu(2).add(convert(assets).div(HALF_SLOPE)).sqrt().sub(currentSupplyOfShares));
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = initial total supply of shares
    /// @dev Let $r$ = shares to redeem
    /// @dev Let $\frac{m}{2}$ = half of the slope
    /// @dev assets:
    /// $$\text{assets} = (s^2 - (s-r)^2) \cdot \frac{m}{2}$$
    /// @dev this can be expanded to:
    /// $$\text{assets} = (s^2 - (s^2 - 2sr + r^2)) \cdot \frac{m}{2}$$
    /// @dev which simplifies to:
    /// $$\text{assets} = (2sr - r^2) \cdot \frac{m}{2}$$
    function previewRedeem(uint256 shares, uint256 totalShares, uint256 /*totalAssets*/ )
        public
        view
        override
        returns (uint256 assets)
    {
        UD60x18 currentSupplyOfShares = convert(totalShares);

        UD60x18 supplyOfSharesAfterRedeem = currentSupplyOfShares.sub(convert(shares));

        return convert(_convertToAssets(supplyOfSharesAfterRedeem, currentSupplyOfShares));
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply of shares
    /// @dev Let $n$ = new shares to mint
    /// @dev Let $\frac{m}{2}$ = half of the slope
    /// @dev assets:
    /// $$\text{assets} = ((s + n)^2 - s^2) \cdot \frac{m}{2}$$
    /// @dev which can be expanded to:
    /// $$\text{assets} = (s^2 + 2sn + n^2 - s^2) \cdot \frac{m}{2}$$
    /// @dev which simplifies to:
    /// $$\text{assets} = (2sn + n^2) \cdot \frac{m}{2}$$
    function previewMint(uint256 shares, uint256 totalShares, uint256 /*totalAssets*/ )
        external
        view
        override
        returns (uint256 assets)
    {
        return convert(_convertToAssets(convert(totalShares), convert(totalShares + shares)));
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply of shares
    /// @dev Let $a$ = assets to withdraw
    /// @dev Let $\frac{m}{2}$ = half of the slope
    /// @dev shares:
    /// $$\text{shares} = s - \sqrt{s^2 - \frac{a}{m/2}}$$
    /// @dev or to say that another way:
    /// $$\text{shares} = s - \sqrt{s^2 - \frac{2a}{m}}$$
    function previewWithdraw(uint256 assets, uint256, /*totalAssets*/ uint256 totalShares)
        external
        view
        override
        returns (uint256 shares)
    {
        UD60x18 currentSupplyOfShares = convert(totalShares);
        return convert(currentSupplyOfShares.sub(currentSupplyOfShares.powu(2).sub(convert(assets).div(HALF_SLOPE)).sqrt()));
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = initial total supply of shares
    /// @dev Let $r$ = shares to redeem
    /// @dev Let $\frac{m}{2}$ = half of the slope
    /// @dev assets:
    /// $$\text{assets} = (s^2 - (s-r)^2) \cdot \frac{m}{2}$$
    /// @dev this can be expanded to:
    /// $$\text{assets} = (s^2 - (s^2 - 2sr + r^2)) \cdot \frac{m}{2}$$
    /// @dev which simplifies to:
    /// $$\text{assets} = (2sr - r^2) \cdot \frac{m}{2}$$
    function previewRedeem(uint256 shares, uint256 totalShares, uint256 /*totalAssets*/ )
        external
        view
        override
        returns (uint256 assets)
    {
        UD60x18 currentSupplyOfShares = UD60x18.wrap(totalShares);

        UD60x18 supplyOfSharesAfterRedeem = currentSupplyOfShares.sub(UD60x18.wrap(shares));

        return _convertToAssets(supplyOfSharesAfterRedeem, currentSupplyOfShares).unwrap();
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply of shares
    /// @dev Let $m$ = the slope of the curve
    /// @dev sharePrice:
    /// $$\text{sharePrice} = s \cdot m$$
    /// @dev This is the basic linear price function where the price increases linearly with the total supply
    /// @dev And the slope ($m$) determines how quickly the price increases
    /// @dev TLDR: Each new share costs more than the last
    function currentPrice(uint256 totalShares) public view override returns (uint256 sharePrice) {
        return convert(totalShares).mul(SLOPE).unwrap();
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply of shares
    /// @dev Let $a$ = assets to convert to shares
    /// @dev Let $\frac{m}{2}$ = half of the slope
    /// @dev shares:
    /// $$\text{shares} = \frac{a}{s \cdot m/2}$$
    /// @dev Or to say that another way:
    /// $$\text{shares} = \frac{2a}{s \cdot m}$$
    function convertToShares(uint256 assets, uint256, /*totalAssets*/ uint256 totalShares)
        external
        view
        override
        returns (uint256 shares)
    {
        require(assets > 0, "Asset amount must be greater than zero");
        UD60x18 currentSupplyOfShares = convert(totalShares);
        return convert(currentSupplyOfShares.powu(2).add(convert(assets).div(HALF_SLOPE)).sqrt().sub(currentSupplyOfShares));
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply of shares
    /// @dev Let $n$ = quantity of shares to convert to assets
    /// @dev conversion price:
    /// $$\text{price} = s \cdot \frac{m}{2}$$
    /// @dev where $\frac{m}{2}$ is average price per share
    /// @dev assets:
    /// $$\text{assets} = n \cdot (s \cdot \frac{m}{2})$$
    /// @dev Or to say that another way:
    /// $$\text{assets} = n \cdot s \cdot \frac{m}{2}$$
    function convertToAssets(uint256 shares, uint256 totalShares, uint256 /*totalAssets*/ )
        external
        view
        override
        returns (uint256 assets)
    {
        require(totalShares >= shares, "PC: Under supply of shares");
        UD60x18 currentSupplyOfShares = convert(totalShares);
        UD60x18 supplyOfSharesAfterRedeem = currentSupplyOfShares.sub(convert(shares));
        return convert(_convertToAssets(supplyOfSharesAfterRedeem, currentSupplyOfShares));
    }

    /**
     * @notice Computes assets as the area under a linear curve with a simplified form of the area of a trapezium:
     * $$f(x) = mx + c$$
     * $$\text{Area} = \frac{1}{2} \cdot (a + b) \cdot h$$
     * where $a$ and $b$ can be both $f(\text{juniorSupply})$ or $f(\text{seniorSupply})$ depending if used in minting or redeeming.
     * Calculates area as:
     * $$(\text{seniorSupply}^2 - \text{juniorSupply}^2) \cdot \text{halfSlope}$$
     * where:
     * $$\text{halfSlope} = \frac{\text{slope}}{2}$$
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

    /// @inheritdoc BaseCurve
    function maxShares() external view override returns (uint256) {
        return MAX_SHARES;
    }

    /// @inheritdoc BaseCurve
    function maxAssets() external view override returns (uint256) {
        return MAX_ASSETS;
    }
}
