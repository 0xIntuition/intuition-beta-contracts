// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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
 * @dev    Uses standard integer math for calculations
 * @dev    The discrete summation approach differs from the continuous integration approach used in
 *         ProgressiveCurve, resulting in slightly different pricing dynamics
 * @dev    The non-zero base price ensures that even the first share has a minimum cost
 */
contract ArithmeticSeriesCurve is BaseCurve {
    using Math for uint256;

    /// @notice Decimal precision used for the curve calculations
    uint256 public constant DECIMAL_PRECISION = 1e18;

    /// @notice Maximum number of shares supported by the curve
    uint256 public constant MAX_SHARES = type(uint256).max;

    /// @notice Maximum number of assets supported by the curve
    uint256 public constant MAX_ASSETS = type(uint256).max;

    /// @notice Base price for the first share
    uint256 public constant BASE_PRICE = 0.0001 ether;

    /// @notice Price increase per share minted (or decrease per share redeemed)
    uint256 public priceIncrement;

    /// @notice Error message for when fractional shares are attempted to be minted or redeemed
    error FractionalSharesNotAllowed();

    /// @notice Error message for invalid price increment
    error InvalidPriceIncrement();

    /// @notice Error message for insufficient shares in the vault
    error InsufficientSharesInVault();

    /// @notice Error message for zero assets
    error ZeroAssets();

    /// @notice Error message for zero shares
    error ZeroShares();

    /**
     * @notice Constructs a new ArithmeticSeriesCurve
     * @param _name Name of the curve
     * @param _priceIncrement Amount price increases per share
     */
    constructor(string memory _name, uint256 _priceIncrement) BaseCurve(_name) {
        if (_priceIncrement == 0 || _priceIncrement > 2 * BASE_PRICE) {
            revert InvalidPriceIncrement();
        }

        priceIncrement = _priceIncrement;
    }

    /// @inheritdoc BaseCurve
    function maxShares() public pure override returns (uint256) {
        return MAX_SHARES;
    }

    /// @inheritdoc BaseCurve
    function maxAssets() public pure override returns (uint256) {
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
        
        // Convert totalShares to integer supply
        uint256 currentSupply = totalShares / DECIMAL_PRECISION;
        
        // Solve for sharesToRedeem using quadratic formula
        // The equation is: priceIncrement * x² - (2*BASE_PRICE + (2*currentSupply - 1)*priceIncrement) * x + 2*assets = 0
        
        uint256 a = priceIncrement;
        uint256 b = 2 * BASE_PRICE + (2 * currentSupply - 1) * priceIncrement;
        uint256 c = 2 * assets;
        
        // Calculate discriminant = b² - 4ac
        uint256 discriminant = b * b - 4 * a * c;
        uint256 sqrtDisc = Math.sqrt(discriminant);
        
        // Using quadratic formula: x = (b - sqrt(b² - 4ac))/(2a)
        // We use (b - sqrt) rather than (b + sqrt) to get the smaller positive root
        if (sqrtDisc > b) {
            revert InsufficientSharesInVault(); // Not enough assets to fulfill request
        }
        
        uint256 numerator = b - sqrtDisc;
        uint256 denominator = 2 * a;
        
        // Ensure the result is an integer
        if (numerator % denominator != 0) {
            // Round up to ensure user gets at least the requested assets
            numerator = numerator + denominator - (numerator % denominator);
        }
        
        uint256 sharesToRedeem = numerator / denominator;
        
        // Verify the solution is valid
        if (sharesToRedeem > currentSupply) {
            revert InsufficientSharesInVault();
        }
        
        // Convert back to 18-decimal format
        shares = sharesToRedeem * DECIMAL_PRECISION;
        
        return shares;
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

        // 1. Disallow fractional shares if not permitted
        if (shares % DECIMAL_PRECISION != 0) {
            revert FractionalSharesNotAllowed();
        }

        uint256 sharesToMint = shares / DECIMAL_PRECISION; // integer shares

        // 3. Now call your helper
        assets = calculateAssetsForDeposit(sharesToMint, totalShares);

        return assets;
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
        // Convert totalShares from 18-decimal to whole shares.
        uint256 S = totalShares / DECIMAL_PRECISION;

        // Define quadratic coefficients:
        // a = priceIncrement
        // b = 2*BASE_PRICE - priceIncrement + 2*S*priceIncrement
        uint256 a = priceIncrement;
        uint256 b = 2 * BASE_PRICE - priceIncrement + 2 * S * priceIncrement;

        // Compute discriminant = b^2 + 8*a*assets.
        uint256 discriminant = b * b + 8 * a * assets;
        uint256 sqrtDisc = Math.sqrt(discriminant);

        // Ensure the square root is large enough.
        if (sqrtDisc < b) {
            revert FractionalSharesNotAllowed(); // Should never happen if assets > 0.
        }

        uint256 numerator = sqrtDisc - b;
        uint256 denominator = 2 * a;

        // Ensure the result is an integer.
        if (numerator % denominator != 0) {
            revert FractionalSharesNotAllowed();
        }

        uint256 n = numerator / denominator;

        // Return n converted back to 18-decimal format.
        shares = n * DECIMAL_PRECISION;

        return shares;
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
        uint256 shares, // number of shares the user wants to burn (18-decimal)
        uint256 totalShares, // totalShares in the vault (18-decimal)
        uint256 /* totalAssets */
    ) public view override returns (uint256 assets) {
        if (shares == 0) {
            revert ZeroShares();
        }

        // 1. Convert totalShares to an integer supply (ignore fractional part for simplicity)
        uint256 currentSupply = totalShares / DECIMAL_PRECISION;

        // 2. Convert 'shares' (in 18 decimals) to an integer and revert if there's a remainder
        if (shares % DECIMAL_PRECISION != 0) {
            revert FractionalSharesNotAllowed();
        }
        uint256 sharesToRedeem = shares / DECIMAL_PRECISION;

        // 3. Ensure the user cannot redeem more shares than exist in the vault
        if (sharesToRedeem > currentSupply) {
            revert InsufficientSharesInVault();
        }

        // 4. Cost of the *highest* share being redeemed:
        //    The share index is (currentSupply - 1), so its price is:
        uint256 highestTerm = BASE_PRICE + ((currentSupply - 1) * priceIncrement);

        // 5. Cost of the *lowest* share being redeemed:
        //    That's (currentSupply - sharesToRedeem).
        uint256 lowestTerm = BASE_PRICE + ((currentSupply - sharesToRedeem) * priceIncrement);

        // 6. Sum of arithmetic series = numberOfTerms * (firstTerm + lastTerm) / 2
        //    Here the 'numberOfTerms' is sharesToRedeem.
        assets = (sharesToRedeem * (highestTerm + lowestTerm)) / 2;

        return assets;
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
        return BASE_PRICE + (totalShares * priceIncrement);
    }

    /**
     * @notice Helper function to calculate the sum of an arithmetic series
     * @param shares Desired number of shares to mint (needs to be a whole number - NOT in 18 the decimals format)
     * @param totalShares Total number of shares in circulation
     * @return assets Total cost to mint the desired number of shares
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
    function calculateAssetsForDeposit(uint256 shares, uint256 totalShares) public view returns (uint256) {
        if (shares == 0) {
            revert ZeroShares();
        }

        // Total supply of whole shares
        uint256 currentSupply = totalShares / DECIMAL_PRECISION;

        // Cost of the first share
        uint256 firstTerm = BASE_PRICE + (currentSupply * priceIncrement);

        // Cost of the last share
        uint256 lastTerm = BASE_PRICE + (currentSupply + shares - 1) * priceIncrement;

        // Total cost using the sum of arithmetic series formula
        uint256 totalCost = (shares * (firstTerm + lastTerm)) / 2;

        return totalCost;
    }
}
