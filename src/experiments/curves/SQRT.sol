// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";

/// @title SQRT
/// @notice Implements a square root bonding curve for share pricing.
contract SQRT is EthMultiVaultExperimental {
    /// @notice The base price per share
    uint256 public basePrice;

    /// @notice The increment price that controls the rate of price increase
    uint256 public incrementPrice;

    constructor() {
        basePrice = 1e18; // Initial base price (1 ETH)
        incrementPrice = 1e18; // Initial increment price (1 ETH)
    }

    /// @notice Sets the base price for the bonding curve
    /// @param _basePrice The new base price
    function setBasePrice(uint256 _basePrice) external {
        require(_basePrice > 0, "Base price must be positive");
        basePrice = _basePrice;
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
            return basePrice;
        }

        uint256 price = _calculatePrice(totalShares);

        return price;
    }

    /// @notice Converts a given amount of assets to shares based on the square root bonding curve.
    /// @param assets The amount of assets to convert (in wei).
    /// @param id The vault ID.
    /// @return The amount of shares equivalent to the assets.
    function convertToShares(uint256 assets, uint256 id) public view override returns (uint256) {
        require(assets > 0, "Assets must be greater than zero");

        uint256 totalShares = vaults[id].totalShares;

        uint256 shares;
        uint256 oldPrice = _calculatePrice(totalShares);

        // Estimate new total shares
        uint256 estimatedNewShares = totalShares + (assets * generalConfig.decimalPrecision) / oldPrice;
        uint256 newPrice = _calculatePrice(estimatedNewShares);

        // Average price approximation
        uint256 averagePrice = (oldPrice + newPrice) / 2;
        if (averagePrice == 0) {
            averagePrice = basePrice; // Avoid division by zero
        }

        shares = (assets * generalConfig.decimalPrecision) / averagePrice;

        return shares;
    }

    /// @notice Converts a given amount of shares to assets based on the square root bonding curve.
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
            averagePrice = basePrice; // Avoid division by zero
        }

        uint256 assets = (shares * averagePrice) / generalConfig.decimalPrecision;

        return assets;
    }

    /// @notice Calculates the price based on total shares using the square root function.
    /// @param totalShares The total shares in the vault.
    /// @return The calculated price.
    function _calculatePrice(uint256 totalShares) internal view returns (uint256) {
        // Scale down totalShares to prevent overflow
        uint256 scaledShares = totalShares / 1e18; // Convert wei to ether units

        uint256 sqrtValue = sqrt(scaledShares * 1e18); // sqrt in wei units

        // Calculate the price: price = basePrice + (sqrtValue * incrementPrice) / 1e18
        uint256 price = basePrice + ((sqrtValue * incrementPrice) / 1e18);

        return price;
    }

    /// @dev Integer square root function (Babylonian method)
    function sqrt(uint256 x) public pure returns (uint256) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        uint256 y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }

        return y;
    }
}
