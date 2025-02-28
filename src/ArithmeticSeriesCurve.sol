// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {BaseCurve} from "src/BaseCurve.sol";

/**
 * @title  ArithmeticSeriesCurve
 * @author 0xIntuition
 * @notice A simple linear bonding curve where price increases linearly with supply.
 *         Price formula: P(s) = basePrice + (s * priceIncrement)
 *         Total cost is calculated using the arithmetic series sum formula.
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
        // skip the previewWithdraw logic for now
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
        if (shares % 1e18 != 0) {
            revert FractionalSharesNotAllowed();
        }

        uint256 sharesToMint = shares / 1e18; // integer shares

        // 3. Now call your helper
        assets = calculateAssetsForDeposit(sharesToMint, totalShares);

        return assets;
    }

    /// @inheritdoc BaseCurve
    function convertToShares(uint256 assets, uint256, /*totalAssets*/ uint256 /*totalShares*/ )
        public
        view
        override
        returns (uint256 shares)
    {
        if (assets == 0) {
            revert ZeroAssets();
        }

        // 1. Prepare quadratic equation parameters.
        //    a, b, c correspond to the rearranged arithmetic-series sum formula.
        uint256 a = priceIncrement; // d in the typical formula
        uint256 b = 2 * BASE_PRICE - priceIncrement; // (2*A - d)
        uint256 c = 2 * assets; // 2S, where S = assets

        // 2. Compute the discriminant for the quadratic formula: b^2 + 4ac
        uint256 discriminant = (b * b) + (4 * a * c);

        // 3. sqrt(discriminant)
        uint256 sqrtD = Math.sqrt(discriminant);

        // 3. We'll compute n = [(-b + sqrtD) / (2a)].
        uint256 numerator = sqrtD - b;
        uint256 denominator = 2 * a;

        // 4. Check if numerator is evenly divisible by denominator
        //    If there's a remainder, that means partial shares.
        if (numerator % denominator != 0) {
            revert FractionalSharesNotAllowed();
        }

        // 5. Now we do the integer division safely, with no rounding loss
        uint256 n = numerator / denominator;

        // 6. Convert `n` back to 18-decimals and return.
        shares = n * 1e18;

        return shares;
    }

    /// @inheritdoc BaseCurve
    function convertToAssets(
        uint256 shares, // number of shares the user wants to burn (18-decimal)
        uint256 totalShares, // totalShares in the system (18-decimal)
        uint256 /* totalAssets */ // might be unused in a pure bonding-curve scenario
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
        //    That’s (currentSupply - sharesToRedeem).
        uint256 lowestTerm = BASE_PRICE + ((currentSupply - sharesToRedeem) * priceIncrement);

        // 6. Sum of arithmetic series = numberOfTerms * (firstTerm + lastTerm) / 2
        //    Here the 'numberOfTerms' is sharesToRedeem.
        assets = (sharesToRedeem * (highestTerm + lowestTerm)) / 2;

        return assets;
    }

    /// @inheritdoc BaseCurve
    function currentPrice(uint256 totalShares) public view override returns (uint256 sharePrice) {
        return BASE_PRICE + (totalShares * priceIncrement);
    }

    /**
     * @notice Helper function to calculate the sum of an arithmetic series
     * @param shares Desired number of shares to mint (needs to be a whole number - not in 18 decimals format)
     * @param totalShares Total number of shares in circulation
     * @return assets Total cost to mint the desired number of shares
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
