// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {UD60x18, ud60x18, convert, uMAX_UD60x18, uUNIT} from "@prb/math/UD60x18.sol";

import {BaseCurve} from "src/BaseCurve.sol";

/**
 * @title  ArithmeticSeriesCurve
 * @author 0xIntuition
 * @notice A linear bonding curve where price increases linearly with supply.
 *
 *         The price follows the formula:
 *         $$P(s) = \text{basePrice} + (s \cdot \text{priceIncrement})$$
 *         where:
 *         - $\text{basePrice}$ is the starting price for the first share (0.0001 ETH)
 *         - $\text{priceIncrement}$ is the amount price increases per share
 *         - $s$ is the total supply of shares
 *
 *         The cost to mint shares is calculated using the arithmetic series sum formula:
 *         $$\text{Cost} = n \cdot \frac{\text{firstTerm} + \text{lastTerm}}{2}$$
 *         where:
 *         - $n$ is the number of shares to mint
 *         - $\text{firstTerm}$ is the price of the first share to be minted: $\text{basePrice} + (s \cdot \text{priceIncrement})$
 *         - $\text{lastTerm}$ is the price of the last share to be minted: $\text{basePrice} + ((s + n - 1) \cdot \text{priceIncrement})$
 *
 *         When expanded for minting $n$ shares at current supply $s$, the formula becomes:
 *         $$\text{Cost} = n \cdot \frac{2 \cdot \text{basePrice} + (2s + n - 1) \cdot \text{priceIncrement}}{2}$$
 *
 *         This curve creates a predictable linear price increase with each share minted,
 *         starting from a non-zero base price.
 *
 * @dev    Uses fixed-point arithmetic for calculations with UD60x18
 * @dev    The discrete summation approach differs from the continuous integration approach used in
 *         ProgressiveCurve, resulting in slightly different pricing dynamics
 * @dev    The non-zero base price ensures that even the first share has a minimum cost
 */
contract ArithmeticSeriesCurve is BaseCurve {
    /// @notice Maximum number of shares supported by the curve
    uint256 public immutable MAX_SHARES;

    /// @notice Maximum number of assets supported by the curve
    uint256 public immutable MAX_ASSETS;

    /// @notice Base price for the first share as a UD60x18 value
    UD60x18 public immutable BASE_PRICE;

    /// @notice Price increase per share minted (or decrease per share redeemed) as a UD60x18 value
    UD60x18 public immutable PRICE_INCREMENT;

    /// @notice Half of price increment, used in calculations
    UD60x18 public immutable HALF_PRICE_INCREMENT;

    /// @notice Error message for insufficient shares in the vault
    error InsufficientSharesInVault();

    /// @notice Error message for zero assets
    error ZeroAssets();

    /// @notice Error message for zero shares
    error ZeroShares();

    /// @notice Error message for negative discriminant in quadratic formula
    error NegativeDiscriminant();

    /// @notice Error message for invalid price increment
    error InvalidPriceIncrement();

    /**
     * @notice Constructs a new ArithmeticSeriesCurve
     * @param _name Name of the curve
     * @param _priceIncrement Amount price increases per share (in wei)
     * @param _basePrice The base starting price for the first share (i.e 0.0001 ether)
     */
    constructor(string memory _name, uint256 _priceIncrement, uint256 _basePrice) BaseCurve(_name) {
        // Convert constants to UD60x18
        UD60x18 basePrice = convert(_basePrice);
        UD60x18 priceIncrement = convert(_priceIncrement);

        if (priceIncrement.unwrap() == 0 || priceIncrement.gt(basePrice.mul(convert(2)))) {
            revert InvalidPriceIncrement();
        }

        BASE_PRICE = basePrice;
        PRICE_INCREMENT = priceIncrement;
        HALF_PRICE_INCREMENT = priceIncrement.div(convert(2));

        MAX_SHARES = 1e48;
        MAX_ASSETS = 1e48;
    }

    /// @inheritdoc BaseCurve
    function maxShares() public view override returns (uint256) {
        return MAX_SHARES;
    }

    /// @inheritdoc BaseCurve
    function maxAssets() public view override returns (uint256) {
        return MAX_ASSETS;
    }

    /// @inheritdoc BaseCurve
    function previewDeposit(uint256 assets, uint256 totalAssets, uint256 totalShares)
        public
        view
        override
        returns (uint256 shares)
    {
        return convertToShares(assets, totalAssets, totalShares);
    }

    /// @inheritdoc BaseCurve
    function previewRedeem(uint256 shares, uint256 totalShares, uint256 totalAssets)
        public
        view
        override
        returns (uint256 assets)
    {
        return convertToAssets(shares, totalShares, totalAssets);
    }

    /// @inheritdoc BaseCurve
    function previewWithdraw(uint256 assets, uint256 totalAssets, uint256 totalShares)
        public
        view
        override
        returns (uint256 shares)
    {
        if (assets == 0) {
            revert ZeroAssets();
        }
        
        // Convert to UD60x18 for precise calculation
        UD60x18 assetsUD = convert(assets);
        UD60x18 totalSharesUD = convert(totalShares);
        
        // Solve for sharesToRedeem using quadratic formula
        // The equation is: priceIncrement * x² - (2*BASE_PRICE + (2*totalSharesUD - 1)*priceIncrement) * x + 2*assets = 0
        
        UD60x18 a = PRICE_INCREMENT;
        UD60x18 b = BASE_PRICE.mul(convert(2)).add(totalSharesUD.mul(convert(2)).sub(convert(1)).mul(PRICE_INCREMENT));
        UD60x18 c = assetsUD.mul(convert(2));
        
        // Calculate discriminant = b² - 4ac
        UD60x18 discriminant = b.pow(convert(2)).sub(convert(4).mul(a).mul(c));
        
        // Ensure discriminant is non-negative (solution exists)
        if (discriminant.lt(convert(0))) {
            revert NegativeDiscriminant();
        }
        
        UD60x18 sqrtDisc = discriminant.sqrt();
        
        // Using quadratic formula: x = (b - sqrt(b² - 4ac))/(2a)
        // We use (b - sqrt) rather than (b + sqrt) to get the smaller positive root
        if (sqrtDisc.gt(b)) {
            revert InsufficientSharesInVault(); // Not enough assets to fulfill request
        }
        
        UD60x18 sharesToRedeemUD = b.sub(sqrtDisc).div(a.mul(convert(2)));
        
        // Verify the solution is valid
        if (sharesToRedeemUD.gt(totalSharesUD)) {
            revert InsufficientSharesInVault();
        }
        
        // Convert to uint256 and ensure we round up to get at least the requested assets
        uint256 sharesToRedeem = sharesToRedeemUD.ceil().unwrap();
        
        // Final validation - make sure these shares actually give enough assets
        UD60x18 resultingAssets = _convertToAssets(convert(sharesToRedeem), totalSharesUD);
        if (resultingAssets.lt(assetsUD)) {
            // If still not enough, add a small increment
            sharesToRedeem += 1;
        }
        
        return sharesToRedeem;
    }

    /// @inheritdoc BaseCurve
    function previewMint(uint256 shares, uint256 totalShares, uint256 /*totalAssets*/ )
        public
        view
        override
        returns (uint256 assets)
    {
        if (shares == 0) {
            revert ZeroShares();
        }

        // Convert to UD60x18 for precise calculation
        UD60x18 sharesToMintUD = convert(shares);
        UD60x18 totalSharesUD = convert(totalShares);
        
        // Calculate assets needed to mint these shares
        UD60x18 assetsUD = _calculateAssetsForDeposit(sharesToMintUD, totalSharesUD);
        
        // Convert back to uint256
        return assetsUD.ceil().unwrap();
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply of shares
    /// @dev Let $a$ = amount of assets to deposit
    /// @dev Let $b$ = basePrice
    /// @dev Let $p$ = priceIncrement
    /// @dev Solves the quadratic equation to find shares:
    /// $$p \cdot n^2 + (2 \cdot p \cdot s - p + 2 \cdot b) \cdot n - 2 \cdot a = 0$$
    /// @dev where $n$ is the number of shares to mint
    function convertToShares(
        uint256 assets, // number of assets the user wants to deposit (18-decimal)
        uint256, /*totalAssets*/
        uint256 totalShares // totalShares in the vault (18-decimal)
    ) public view override returns (uint256 shares) {
        if (assets == 0) {
            revert ZeroAssets();
        }
        
        // Convert to UD60x18 for precise calculation
        UD60x18 assetsUD = convert(assets);
        UD60x18 totalSharesUD = convert(totalShares);

        // Define quadratic coefficients:
        // a = priceIncrement
        // b = 2*BASE_PRICE - priceIncrement + 2*totalShares*priceIncrement
        UD60x18 a = PRICE_INCREMENT;
        UD60x18 b = BASE_PRICE.mul(convert(2)).sub(PRICE_INCREMENT).add(totalSharesUD.mul(convert(2)).mul(PRICE_INCREMENT));

        // Compute discriminant = b^2 + 8*a*assets.
        UD60x18 discriminant = b.pow(convert(2)).add(convert(8).mul(a).mul(assetsUD));
        UD60x18 sqrtDisc = discriminant.sqrt();

        // Ensure the square root is large enough.
        if (sqrtDisc.lt(b)) {
            return 0; // No solution or too small to be meaningful
        }

        // Calculate sharesToMint = (sqrtDisc - b) / (2*a)
        UD60x18 sharesToMintUD = sqrtDisc.sub(b).div(a.mul(convert(2)));
        
        // Convert back to uint256, using floor to ensure we don't mint more than assets paid for
        return sharesToMintUD.floor().unwrap();
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply of shares
    /// @dev Let $r$ = shares to redeem
    /// @dev Let $b$ = basePrice
    /// @dev Let $p$ = priceIncrement
    /// @dev assets:
    /// $$\text{assets} = r \cdot \frac{\text{highestTerm} + \text{lowestTerm}}{2}$$
    /// @dev where:
    /// $$\text{highestTerm} = b + ((s - 1) \cdot p)$$
    /// $$\text{lowestTerm} = b + ((s - r) \cdot p)$$
    function convertToAssets(
        uint256 shares, // number of shares the user wants to burn
        uint256 totalShares, // totalShares in the vault
        uint256 /* totalAssets */
    ) public view override returns (uint256 assets) {
        if (shares == 0) {
            revert ZeroShares();
        }

        // Convert to UD60x18 for precise calculation
        UD60x18 sharesToRedeemUD = convert(shares);
        UD60x18 totalSharesUD = convert(totalShares);

        // Ensure the user cannot redeem more shares than exist in the vault
        if (sharesToRedeemUD.gt(totalSharesUD)) {
            revert InsufficientSharesInVault();
        }

        // Calculate assets using our helper function
        UD60x18 assetsUD = _convertToAssets(sharesToRedeemUD, totalSharesUD);
        
        // Convert back to uint256
        return assetsUD.floor().unwrap();
    }

    /**
     * @notice Helper function to calculate assets returned when redeeming shares
     * @param sharesToRedeem Number of shares to redeem as UD60x18
     * @param totalShares Total shares in circulation as UD60x18
     * @return assetsUD Amount of assets returned as UD60x18
     */
    function _convertToAssets(UD60x18 sharesToRedeem, UD60x18 totalShares) internal view returns (UD60x18 assetsUD) {
        // Calculate highest term price: BASE_PRICE + ((totalShares - 1) * PRICE_INCREMENT)
        UD60x18 highestTerm = BASE_PRICE.add(totalShares.sub(convert(1)).mul(PRICE_INCREMENT));
        
        // Calculate lowest term price: BASE_PRICE + ((totalShares - sharesToRedeem) * PRICE_INCREMENT)
        UD60x18 lowestTerm = BASE_PRICE.add(totalShares.sub(sharesToRedeem).mul(PRICE_INCREMENT));
        
        // Sum of arithmetic series = numberOfTerms * (firstTerm + lastTerm) / 2
        assetsUD = sharesToRedeem.mul(highestTerm.add(lowestTerm)).div(convert(2));
        
        return assetsUD;
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply of shares
    /// @dev Let $b$ = basePrice
    /// @dev Let $p$ = priceIncrement
    /// @dev sharePrice:
    /// $$\text{sharePrice} = b + (s \cdot p)$$
    /// @dev This is the basic linear price function where the price increases linearly with the total supply
    /// @dev starting from a non-zero base price
    function currentPrice(uint256 totalShares) public view override returns (uint256 sharePrice) {
        UD60x18 totalSharesUD = convert(totalShares);
        UD60x18 price = BASE_PRICE.add(totalSharesUD.mul(PRICE_INCREMENT));
        return price.unwrap();
    }

    /**
     * @notice Helper function to calculate the sum of an arithmetic series
     * @param shares Desired number of shares to mint as UD60x18
     * @param totalShares Total number of shares in circulation as UD60x18
     * @return assetsUD Total cost to mint the desired number of shares as UD60x18
     * @dev Let $s$ = current total supply of shares
     * @dev Let $n$ = shares to mint
     * @dev Let $b$ = basePrice
     * @dev Let $p$ = priceIncrement
     * @dev assets:
     * $$\text{assets} = n \cdot \frac{\text{firstTerm} + \text{lastTerm}}{2}$$
     * @dev where:
     * $$\text{firstTerm} = b + (s \cdot p)$$
     * $$\text{lastTerm} = b + ((s + n - 1) \cdot p)$$
     * @dev which simplifies to:
     * $$\text{assets} = n \cdot \frac{2b + (2s + n - 1) \cdot p}{2}$$
     */
    function _calculateAssetsForDeposit(UD60x18 shares, UD60x18 totalShares) internal view returns (UD60x18 assetsUD) {
        if (shares.unwrap() == 0) {
            revert ZeroShares();
        }

        // Cost of the first share: BASE_PRICE + (totalShares * PRICE_INCREMENT)
        UD60x18 firstTerm = BASE_PRICE.add(totalShares.mul(PRICE_INCREMENT));

        // Cost of the last share: BASE_PRICE + ((totalShares + shares - 1) * PRICE_INCREMENT)
        UD60x18 lastTerm = BASE_PRICE.add(totalShares.add(shares).sub(convert(1)).mul(PRICE_INCREMENT));

        // Total cost using the sum of arithmetic series formula: shares * (firstTerm + lastTerm) / 2
        assetsUD = shares.mul(firstTerm.add(lastTerm)).div(convert(2));

        return assetsUD;
    }

    /**
     * @notice Public wrapper for _calculateAssetsForDeposit that accepts uint256 inputs
     * @param shares Desired number of shares to mint (in uint256)
     * @param totalShares Total number of shares in circulation (in uint256)
     * @return Total cost to mint the desired number of shares
     */
    function calculateAssetsForDeposit(uint256 shares, uint256 totalShares) public view returns (uint256) {
        UD60x18 sharesUD = convert(shares);
        UD60x18 totalSharesUD = convert(totalShares);
        
        return _calculateAssetsForDeposit(sharesUD, totalSharesUD).unwrap();
    }
}
