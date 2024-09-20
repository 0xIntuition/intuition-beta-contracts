// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";

/**
 * @title Polynomial
 * @notice Implements a simplified polynomial bonding curve for share pricing.
 */
contract Polynomial is EthMultiVaultExperimental {
    /// @notice Returns the current share price for a given vault.
    /// @param id The vault ID.
    /// @return The current share price adjusted by decimal precision.
    function currentSharePrice(uint256 id) external view override returns (uint256) {
        uint256 totalShares = vaults[id].totalShares;

        if (totalShares == 0) {
            // Starting price
            return generalConfig.decimalPrecision;
        }

        uint256 price = _calculatePrice(totalShares);

        return price;
    }

    /// @notice Converts a given amount of assets to shares based on the polynomial bonding curve.
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

    /// @notice Converts a given amount of shares to assets based on the polynomial bonding curve.
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

    /// @notice Calculates the price based on total shares using the simplified polynomial function.
    /// @param totalShares The total shares in the vault.
    /// @return The calculated price.
    function _calculatePrice(uint256 totalShares) internal view returns (uint256) {
        if (totalShares == 0) {
            // Return the starting price
            return generalConfig.decimalPrecision;
        }

        uint256 scaledShares = totalShares / 1e18;

        // Ensure scaledShares is at least 1 to prevent division by zero
        if (scaledShares == 0) {
            scaledShares = 1;
        }

        // Calculate the linear and quadratic components
        uint256 linearPrice = scaledShares * 1e18; // Linear component in wei
        uint256 quadraticPrice = (scaledShares * scaledShares * 1e18) / 1e18; // Quadratic component in wei

        uint256 price = linearPrice + quadraticPrice;

        return price;
    }
}
