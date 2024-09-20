// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @title Smooth
/// @notice Implements a bonding curve where each share is minted at an incrementally higher price.
contract Smooth is EthMultiVaultExperimental {
    /// @notice The base price per share when total supply is zero.
    uint256 public basePrice;

    /// @notice The price increment per share.
    uint256 public incrementPrice;

    constructor() {
        basePrice = 1e18; // Initial base price (1 ETH)
        incrementPrice = 1e16; // Price increment per share (0.01 ETH)
    }

    /// @notice Sets the base price.
    /// @param _basePrice The new base price.
    function setBasePrice(uint256 _basePrice) external {
        require(_basePrice > 0, "Base price must be positive");
        basePrice = _basePrice;
    }

    /// @notice Sets the increment price.
    /// @param _incrementPrice The new increment price.
    function setIncrementPrice(uint256 _incrementPrice) external {
        require(_incrementPrice > 0, "Increment price must be positive");
        incrementPrice = _incrementPrice;
    }

    /// @notice Returns the current price per share (price of the next share to be minted).
    /// @param id The vault ID.
    /// @return The current price per share.
    function currentSharePrice(uint256 id) external view override returns (uint256) {
        uint256 totalShares = vaults[id].totalShares / 1e18;
        uint256 price = basePrice + totalShares * incrementPrice;
        return price;
    }

    /// @notice Converts a given amount of assets to the equivalent number of shares.
    /// @param assets The amount of assets to convert.
    /// @param id The vault ID.
    /// @return shares The number of shares equivalent to the assets.function convertToShares(uint256 assets, uint256 id) public view override returns (uint256 shares) {
    function convertToShares(uint256 assets, uint256 id) public view override returns (uint256 shares) {
        require(assets > 0, "Assets must be greater than zero");
        uint256 totalSupplyShares = vaults[id].totalShares / 1e18;

        uint256 a = incrementPrice;
        uint256 b = 2 * basePrice + (2 * totalSupplyShares - 1) * incrementPrice;
        uint256 c = 2 * assets;

        // Calculate discriminant: discriminant = b^2 + 4ac
        uint256 discriminant = b * b + 4 * a * c;
        uint256 sqrtDiscriminant = Math.sqrt(discriminant);

        // Calculate n: n = (sqrtDiscriminant - b) / (2a)
        uint256 n = (sqrtDiscriminant - b) / (2 * a);

        shares = n * 1e18;

        return shares;
    }

    /// @notice Converts a given number of shares to the equivalent amount of assets.
    /// @param shares The number of shares to convert.
    /// @param id The vault ID.
    /// @return assets The amount of assets equivalent to the shares.
    function convertToAssets(uint256 shares, uint256 id) public view override returns (uint256 assets) {
        require(shares > 0, "Shares must be greater than zero");
        uint256 totalShares = vaults[id].totalShares / 1e18;

        uint256 N = shares / 1e18;
        uint256 S = totalShares;

        uint256 firstPrice = basePrice + S * incrementPrice;
        uint256 lastPrice = basePrice + (S + N - 1) * incrementPrice;

        uint256 totalCost = N * (firstPrice + lastPrice) / 2;

        assets = totalCost;
        return assets;
    }
}
