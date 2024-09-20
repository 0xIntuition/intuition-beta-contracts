// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";

/**
 * @title Quadratic
 * @notice Implements a quadratic bonding curve for share pricing.
 */
contract Quadratic is EthMultiVaultExperimental {
    /// @notice The increment price that controls the rate of price increase
    uint256 public incrementPrice;

    constructor() {
        incrementPrice = 1e18; // Initial increment price (1 ETH)
    }

    /// @notice Sets the increment price for the bonding curve
    /// @param _incrementPrice The new increment price
    function setIncrementPrice(uint256 _incrementPrice) external {
        require(_incrementPrice > 0, "Increment price must be positive");
        incrementPrice = _incrementPrice;
    }

    /// @notice Returns the current share price for a given vault.
    /// @param id The vault ID.
    /// @return The current share price adjusted by decimal precision.
    function currentSharePrice(uint256 id) external view override returns (uint256) {
        uint256 totalShares = vaults[id].totalShares;

        if (totalShares == 0) {
            // Starting price
            return generalConfig.decimalPrecision; // e.g., 1e18
        }

        uint256 price = _calculatePrice(totalShares);

        return price;
    }

    /// @notice Converts a given amount of assets to shares based on the quadratic bonding curve.
    /// @param assets The amount of assets to convert (in wei).
    /// @param id The vault ID.
    /// @return The amount of shares equivalent to the assets.
    function convertToShares(uint256 assets, uint256 id) public view override returns (uint256) {
        require(assets > 0, "Assets must be greater than zero");

        uint256 totalShares = vaults[id].totalShares;

        uint256 shares;
        uint256 oldPrice = _calculatePrice(totalShares);

        // Check to prevent division by zero
        require(oldPrice > 0, "Old price is zero, cannot convert shares");

        // Estimate new total shares
        uint256 estimatedNewShares = totalShares + (assets * generalConfig.decimalPrecision) / oldPrice;
        uint256 newPrice = _calculatePrice(estimatedNewShares);

        // Average price approximation
        uint256 averagePrice = (oldPrice + newPrice) / 2;
        if (averagePrice == 0) {
            averagePrice = generalConfig.decimalPrecision; // Avoid division by zero
        }

        shares = (assets * generalConfig.decimalPrecision) / averagePrice;

        return shares;
    }

    /// @notice Converts a given amount of shares to assets based on the quadratic bonding curve.
    /// @param shares The amount of shares to convert.
    /// @param id The vault ID.
    /// @return The amount of assets equivalent to the shares.
    function convertToAssets(uint256 shares, uint256 id) public view override returns (uint256) {
        require(shares > 0, "Shares must be greater than zero");

        uint256 totalShares = vaults[id].totalShares;

        require(totalShares >= shares, "Not enough shares in the vault");

        uint256 oldPrice = _calculatePrice(totalShares);
        uint256 newPrice = _calculatePrice(totalShares - shares);

        // Average price approximation
        uint256 averagePrice = (oldPrice + newPrice) / 2;
        if (averagePrice == 0) {
            averagePrice = generalConfig.decimalPrecision; // Avoid division by zero
        }

        uint256 assets = (shares * averagePrice) / generalConfig.decimalPrecision;

        return assets;
    }

    /// @notice Calculates the price based on total shares using the quadratic function.
    /// @param totalShares The total shares in the vault.
    /// @return The calculated price.
    function _calculatePrice(uint256 totalShares) internal view returns (uint256) {
        if (totalShares == 0) {
            // Return the starting price
            return generalConfig.decimalPrecision; // e.g., 1e18
        }

        // Scale down totalShares to prevent overflow when squaring
        uint256 scaledShares = totalShares / 1e18; // Convert wei to ether units

        // Ensure scaledShares is at least 1 to prevent division by zero
        if (scaledShares == 0) {
            scaledShares = 1;
        }

        // Calculate the price: price = (scaledShares)^2 * incrementPrice
        uint256 price = (scaledShares * scaledShares * incrementPrice) / 1e18; // Adjust back to wei units

        // Removed redundant scaling
        // price = price * 1e18;

        return price;
    }

    /// @notice Calculates x raised to the power of y (x^y), where y is an integer exponent.
    /// @param x The base.
    /// @param y The exponent.
    /// @return The result of x^y.
    function _pow(uint256 x, uint256 y) internal pure returns (uint256) {
        require(y > 0, "Exponent must be positive");

        uint256 result = 1;

        while (y > 0) {
            if (y % 2 == 1) {
                result *= x;
            }
            x *= x;
            y /= 2;
        }

        return result;
    }
}
