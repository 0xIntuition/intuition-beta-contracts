// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";

/// @title Cubic
/// @notice Implements a cubic bonding curve for share pricing.
contract Cubic is EthMultiVaultExperimental {
    /// @notice Denominator to control the scaling of the cubic function
    uint256 public cubicDenominator;

    constructor() {
        cubicDenominator = 1e54; // Adjusted for scaling to prevent overflows
    }

    /// @notice Sets the cubic denominator for scaling
    /// @param _cubicDenominator The new cubic denominator
    function setCubicDenominator(uint256 _cubicDenominator) external {
        require(_cubicDenominator > 0, "Cubic denominator must be positive");
        cubicDenominator = _cubicDenominator;
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

        uint256 price = _calculatePrice(totalAssets, totalShares);

        return price;
    }

    /// @notice Converts a given amount of assets to shares based on the cubic bonding curve.
    /// @param assets The amount of assets to convert (in wei).
    /// @param id The vault ID.
    /// @return The amount of shares equivalent to the assets.
    function convertToShares(uint256 assets, uint256 id) public view override returns (uint256) {
        require(assets > 0, "Assets must be greater than zero");

        uint256 totalShares = vaults[id].totalShares;
        uint256 totalAssets = vaults[id].totalAssets;

        uint256 shares;

        uint256 newTotalAssets = totalAssets + assets;

        uint256 oldPrice = _calculatePrice(totalAssets, totalShares);
        uint256 newPrice = _calculatePrice(newTotalAssets, totalShares); // Shares haven't increased yet

        // Average price over the interval (simplified approximation)
        uint256 averagePrice = (oldPrice + newPrice) / 2;

        if (averagePrice == 0) {
            averagePrice = generalConfig.decimalPrecision; // Avoid division by zero
        }

        shares = (assets * generalConfig.decimalPrecision) / averagePrice;

        return shares;
    }

    /// @notice Converts a given amount of shares to assets based on the cubic bonding curve.
    /// @param shares The amount of shares to convert.
    /// @param id The vault ID.
    /// @return The amount of assets equivalent to the shares.
    function convertToAssets(uint256 shares, uint256 id) public view override returns (uint256) {
        require(shares > 0, "Shares must be greater than zero");

        uint256 totalShares = vaults[id].totalShares;
        uint256 totalAssets = vaults[id].totalAssets;

        require(totalShares >= shares, "Not enough shares in the vault");

        uint256 price = _calculatePrice(totalAssets, totalShares);

        uint256 assets = (shares * price) / generalConfig.decimalPrecision;

        return assets;
    }

    /// @notice Calculates the price based on total assets and total shares using a cubic function.
    /// @param totalAssets The total assets in the vault.
    /// @param totalShares The total shares in the vault.
    /// @return The calculated price.
    function _calculatePrice(uint256 totalAssets, uint256 totalShares) internal view returns (uint256) {
        if (totalShares == 0) {
            return generalConfig.decimalPrecision;
        }

        // Scale down totalAssets to prevent overflow when cubing
        uint256 scaledAssets = totalAssets / 1e18; // Convert wei to ether units

        // Calculate the cubic part: scaledAssets^3
        uint256 cubicPart = (scaledAssets * scaledAssets * scaledAssets * 1e18) / cubicDenominator;

        uint256 price = (cubicPart * generalConfig.decimalPrecision) / totalShares;

        return price;
    }
}
