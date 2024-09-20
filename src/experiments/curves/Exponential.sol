// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";

/// @title Exponential
/// @notice Implements an approximate exponential bonding curve for share pricing.
contract Exponential is EthMultiVaultExperimental {
    /// @notice Exponential denominator to control exponential growth scaling
    uint256 public expDenominator;

    constructor() {
        expDenominator = 1e36; // Adjusted for scaling
    }

    /// @notice Sets the exponential denominator for scaling
    /// @param _expDenominator The new exponential denominator
    function setExpDenominator(uint256 _expDenominator) external {
        require(_expDenominator > 0, "expDenominator must be positive");
        expDenominator = _expDenominator;
    }

    /// @notice Returns the current share price for a given vault.
    /// @param id The vault ID.
    /// @return The current share price adjusted by decimal precision.
    function currentSharePrice(uint256 id) external view override returns (uint256) {
        uint256 totalShares = vaults[id].totalShares;
        uint256 totalAssets = vaults[id].totalAssets;

        if (totalShares == 0) {
            // Starting price
            return generalConfig.decimalPrecision;
        }

        uint256 price;

        if (totalAssets <= 1e18) {
            // Linear growth when totalAssets ≤ 1 ETH
            price = (totalAssets * generalConfig.decimalPrecision) / totalShares;
        } else {
            // Exponential growth when totalAssets > 1 ETH
            // Approximate exponential growth using quadratic function
            uint256 scaledAssets = totalAssets / 1e18; // Scale down to prevent overflow
            uint256 expPart = (scaledAssets * scaledAssets * 1e18) / expDenominator;
            price = (expPart * generalConfig.decimalPrecision) / totalShares;
        }

        return price;
    }

    /// @notice Converts a given amount of assets to shares based on the bonding curve.
    /// @param assets The amount of assets to convert (in wei).
    /// @param id The vault ID.
    /// @return The amount of shares equivalent to the assets.
    function convertToShares(uint256 assets, uint256 id) public view override returns (uint256) {
        require(assets > 0, "Assets must be greater than zero");

        uint256 totalShares = vaults[id].totalShares;
        uint256 totalAssets = vaults[id].totalAssets;

        uint256 shares;

        if (totalAssets + assets <= 1e18) {
            // Linear segment
            if (totalShares == 0) {
                shares = assets; // Initial shares equal to assets
            } else {
                shares = (assets * totalShares) / totalAssets;
            }
        } else {
            // Exponential segment
            uint256 newTotalAssets = totalAssets + assets;

            uint256 oldPrice = _calculatePrice(totalAssets, totalShares);
            uint256 newPrice = _calculatePrice(newTotalAssets, totalShares + shares); // Approximate totalShares + shares

            uint256 averagePrice = (oldPrice + newPrice) / 2;
            if (averagePrice == 0) {
                averagePrice = generalConfig.decimalPrecision; // Avoid division by zero
            }

            shares = (assets * generalConfig.decimalPrecision) / averagePrice;
        }

        return shares;
    }

    /// @notice Converts a given amount of shares to assets based on the bonding curve.
    /// @param shares The amount of shares to convert.
    /// @param id The vault ID.
    /// @return The amount of assets equivalent to the shares.
    function convertToAssets(uint256 shares, uint256 id) public view override returns (uint256) {
        require(shares > 0, "Shares must be greater than zero");

        uint256 totalShares = vaults[id].totalShares;
        uint256 totalAssets = vaults[id].totalAssets;

        require(totalShares >= shares, "Not enough shares in the vault");

        uint256 assets;

        if (totalAssets <= 1e18) {
            // Linear segment
            assets = (shares * totalAssets) / totalShares;
        } else {
            // Exponential segment
            uint256 price = _calculatePrice(totalAssets, totalShares);
            assets = (shares * price) / generalConfig.decimalPrecision;
        }

        return assets;
    }

    /// @notice Calculates the price based on total assets and total shares.
    /// @param totalAssets The total assets in the vault.
    /// @param totalShares The total shares in the vault.
    /// @return The calculated price.
    function _calculatePrice(uint256 totalAssets, uint256 totalShares) internal view returns (uint256) {
        if (totalShares == 0) {
            return generalConfig.decimalPrecision;
        }

        uint256 price;

        if (totalAssets <= 1e18) {
            price = (totalAssets * generalConfig.decimalPrecision) / totalShares;
        } else {
            uint256 scaledAssets = totalAssets / 1e18; // Scale down to prevent overflow
            uint256 expPart = (scaledAssets * scaledAssets * 1e18) / expDenominator;
            price = (expPart * generalConfig.decimalPrecision) / totalShares;
        }

        return price;
    }
}
