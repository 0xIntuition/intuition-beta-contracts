// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {BaseCurve} from "./BaseCurve.sol";
import {UD60x18, ud60x18} from "@prb/math/UD60x18.sol";

/**
 * @title  OffsetProgressiveCurve
 * @author 0xIntuition
 * @notice 🚀 Welcome to the SPICIEST bonding curve in the Intuition galaxy! While our LinearCurve
 *         is out there playing it safe, the ProgressiveCurve is here to turn up the HEAT on
 *         early staker rewards! 🌶️
 *
 *         This mathematical masterpiece uses a progressive pricing model where each new share
 *         costs more than the last. The price follows the formula:
 *         $$P(s) = m \cdot s$$
 *         where $m$ is our slope (measured in basis points) and $s$ is the total supply of shares.
 *         But wait, there's more! The actual cost to mint shares is calculated as the area under this
 *         curve, giving us:
 *         $$\text{Cost} = (s_2^2 - s_1^2) \cdot \frac{m}{2}$$
 *         where $s_1$ is the starting share supply and $s_2$ is the final share supply. 📐
 *
 *         Why is this so 🔥? Because it creates a natural pyramid of value that HEAVILY favors
 *         early stakers. The earlier you get in, the more your shares are worth compared to
 *         later participants. It's like the LinearCurve's fee-based appreciation got injected
 *         with pure rocket fuel! While fees still provide that sweet, sweet baseline appreciation,
 *         the progressive curve adds an aggressive incentivization mechanism that makes early
 *         staking absolutely JUICY. 💎
 *
 *         Think of it as DeFi's answer to the early bird special - except instead of getting
 *         the worm, you're getting exponentially more valuable shares! The perfect complement
 *         to our low-risk fee model, creating a two-pronged approach to value accrual that's
 *         simply *chef's kiss* 👨‍🍳
 *
 * @dev     Uses the prb-math library for performant, precise fixed point arithmetic with UD60x18
 * @dev     Fixed point precision used for all internal calculations, while return values are all
 *             represented as regular uint256s, and unwrapped.  I.e. we might use 123.456 internally
 *             and return 123.
 * @dev     The core equation:
 *             $$P(s) = m \cdot s$$
 *             and the cost equation:
 *             $$\text{Cost} = (s_2^2 - s_1^2) \cdot \frac{m}{2}$$
 *             comes from calculus - it's the integral of a linear price function. The area under a
 *             linear curve from point $s_1$ to $s_2$ gives us the total cost/return of minting/redeeming
 *             shares.
 * @dev     Inspired by the Solaxy.sol contract: https://github.com/M3tering/Solaxy/blob/main/src/Solaxy.sol
 *          and https://m3tering.whynotswitch.com/token-economics/mint-and-distribution.  * The key difference
 *          between the Solaxy contract and this one is that the economic state is handled by the EthMultiVault
 *          instead of directly in the curve implementation. *  Otherwise the only difference in the math is the
 *          inclusion of the OFFSET value, which we use to make the curve more gentle.
 */

contract OffsetProgressiveCurve is BaseCurve {
    /// @notice The slope of the curve, in basis points.  This is the rate at which the price of shares increases.
    /// @dev 0.0025e18 -> 25 basis points, 0.0001e18 = 1 basis point, etc etc
    /// @dev If minDeposit is 0.003 ether, this value would need to be 0.00007054e18 to avoid returning 0 shares for minDeposit assets
    UD60x18 public immutable SLOPE;

    /// @notice The offset of the curve.  This value is used to snip off a portion of the beginning of the curve, realigning it to the
    /// origin.  For more details, see the preview functions.
    UD60x18 public immutable OFFSET;

    /// @notice The half of the slope, used for calculations.
    UD60x18 public immutable HALF_SLOPE;

    /// @dev Since powu(2) will overflow first (see slope equation), maximum totalShares is sqrt(MAX_UD60x18)
    uint256 public immutable MAX_SHARES;

    /// @dev The maximum assets is totalShares * slope / 2, because multiplication (see slope equation) would overflow beyond that point.
    uint256 public immutable MAX_ASSETS;

    /// @notice Constructs a new ProgressiveCurve with the given name and slope
    /// @param _name The name of the curve (i.e. "Progressive Curve #465")
    /// @param slope18 The slope of the curve, in basis points (i.e. 0.0025e18)
    /// @dev Computes maximum values given constructor arguments
    /// @dev Computes Slope / 2 as commonly used constant
    constructor(string memory _name, uint256 slope18, uint256 offset18) BaseCurve(_name) {
        require(slope18 > 0, "PC: Slope must be > 0");

        SLOPE = UD60x18.wrap(slope18);
        HALF_SLOPE = SLOPE.div(UD60x18.wrap(2));
        OFFSET = UD60x18.wrap(offset18);
        // Find max values
        // powu(2) will overflow first, therefore maximum totalShares is sqrt(MAX_UD60x18)
        // Then the maximum assets is the total shares * slope / 2, because multiplication will overflow at this point
        UD60x18 MAX_UD60x18 = UD60x18.wrap(type(uint256).max / 1e18);
        MAX_SHARES = MAX_UD60x18.sqrt().unwrap();
        MAX_ASSETS = MAX_UD60x18.mul(HALF_SLOPE).unwrap();
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
        public
        view
        override
        returns (uint256 shares)
    {
        require(assets > 0, "Asset amount must be greater than zero");

        UD60x18 currentSupplyOfShares = UD60x18.wrap(totalShares).add(OFFSET);

        return currentSupplyOfShares.powu(2).add(UD60x18.wrap(assets).div(HALF_SLOPE)).sqrt().sub(currentSupplyOfShares)
            .unwrap();
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
        UD60x18 currentSupplyOfShares = UD60x18.wrap(totalShares).add(OFFSET);

        UD60x18 supplyOfSharesAfterRedeem = currentSupplyOfShares.sub(UD60x18.wrap(shares));

        return _convertToAssets(supplyOfSharesAfterRedeem, currentSupplyOfShares).unwrap();
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
        public
        view
        override
        returns (uint256 assets)
    {
        return _convertToAssets(UD60x18.wrap(totalShares), UD60x18.wrap(totalShares + shares).add(OFFSET)).unwrap();
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
        public
        view
        override
        returns (uint256 shares)
    {
        UD60x18 currentSupplyOfShares = UD60x18.wrap(totalShares).add(OFFSET);
        return currentSupplyOfShares.sub(currentSupplyOfShares.powu(2).sub(UD60x18.wrap(assets).div(HALF_SLOPE)).sqrt())
            .unwrap();
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
        return UD60x18.wrap(totalShares).add(OFFSET).mul(SLOPE).unwrap();
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = the current total supply of shares
    /// @dev Let $\frac{m}{2}$ = half of the slope
    /// @dev Let $a$ = quantity of assets to convert to shares
    /// @dev shares:
    /// $$\text{shares} = \frac{a}{s \cdot m/2}$$
    /// @dev Or to say that another way:
    /// $$\text{shares} = \frac{2a}{s \cdot m}$$
    function convertToShares(uint256 assets, uint256, /*totalAssets*/ uint256 totalShares)
        public
        view
        override
        returns (uint256 shares)
    {
        UD60x18 conversionPrice = UD60x18.wrap(totalShares).add(OFFSET).mul(HALF_SLOPE);
        return UD60x18.wrap(assets).div(conversionPrice).unwrap();
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply of shares
    /// @dev Let $\frac{m}{2}$ = half of the slope
    /// @dev Let $n$ = quantity of shares to convert to assets
    /// @dev conversion price:
    /// $$\text{price} = s \cdot \frac{m}{2}$$
    /// @dev where $\frac{m}{2}$ is average price per share
    /// @dev assets:
    /// $$\text{assets} = n \cdot (s \cdot \frac{m}{2})$$
    /// @dev Or to say that another way:
    /// $$\text{assets} = n \cdot s \cdot \frac{m}{2}$$
    function convertToAssets(uint256 shares, uint256 totalShares, uint256 /*totalAssets*/ )
        public
        view
        override
        returns (uint256 assets)
    {
        require(totalShares >= shares, "PC: Under supply of shares");
        UD60x18 conversionPrice = UD60x18.wrap(totalShares).add(OFFSET).mul(HALF_SLOPE);
        return UD60x18.wrap(shares).mul(conversionPrice).unwrap();
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
     * @dev This method is identical to the ProgressiveCurve because it works entirely with relative values, which are already
     * offset by the invoking methods.
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
    function maxShares() public view override returns (uint256) {
        return MAX_SHARES;
    }

    /// @inheritdoc BaseCurve
    function maxAssets() public view override returns (uint256) {
        return MAX_ASSETS;
    }
}
