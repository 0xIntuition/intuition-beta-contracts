// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";

/// @title TwoStepLinear
/// @notice Bonding curve with a linear price increase up to 1 ETH, after which the price increases at double the rate.
contract TwoStepLinear is EthMultiVaultExperimental {
    uint256 public constant FIRST_STEP_LIMIT = 1e18; // 1 ETH in wei
    uint256 public constant FIRST_STEP_SHARES_PER_ASSET = 1e18; // 1 share per ETH
    uint256 public constant SECOND_STEP_SHARES_PER_ASSET = 5e17; // 0.5 shares per ETH (price doubles)

    /// @notice Returns the current share price for a given vault.
    /// @param id The vault ID.
    /// @return The current share price in wei.
    function currentSharePrice(uint256 id) external view override returns (uint256) {
        uint256 totalAssets = vaults[id].totalAssets;

        if (totalAssets < FIRST_STEP_LIMIT) {
            // Price per share is 1e18 wei per share (1 ETH per share)
            return 1e18; // 1 ETH per share
        } else {
            // Price per share is 2e18 wei per share (2 ETH per share)
            return 2e18; // 2 ETH per share
        }
    }

    /// @notice Converts a given amount of assets to shares based on the bonding curve.
    /// @param assets The amount of assets to convert (in wei).
    /// @param id The vault ID.
    /// @return The amount of shares equivalent to the assets (in wei).
    function convertToShares(uint256 assets, uint256 id) public view override returns (uint256) {
        uint256 totalAssets = vaults[id].totalAssets;

        uint256 shares;
        if (totalAssets >= FIRST_STEP_LIMIT) {
            // All assets are in the second segment
            shares = (assets * SECOND_STEP_SHARES_PER_ASSET) / 1e18;
        } else if (totalAssets + assets <= FIRST_STEP_LIMIT) {
            // All assets are in the first segment
            shares = (assets * FIRST_STEP_SHARES_PER_ASSET) / 1e18;
        } else {
            // Assets span both segments
            uint256 assetsInFirstSegment = FIRST_STEP_LIMIT - totalAssets;
            uint256 assetsInSecondSegment = assets - assetsInFirstSegment;

            uint256 sharesInFirstSegment = (assetsInFirstSegment * FIRST_STEP_SHARES_PER_ASSET) / 1e18;
            uint256 sharesInSecondSegment = (assetsInSecondSegment * SECOND_STEP_SHARES_PER_ASSET) / 1e18;

            shares = sharesInFirstSegment + sharesInSecondSegment;
        }

        return shares;
    }

    /// @notice Converts a given amount of shares to assets based on the bonding curve.
    /// @param shares The amount of shares to convert (in wei).
    /// @param id The vault ID.
    /// @return The amount of assets equivalent to the shares (in wei).
    function convertToAssets(uint256 shares, uint256 id) public view override returns (uint256) {
        uint256 totalShares = vaults[id].totalShares;

        uint256 assets;
        uint256 sharesAtFirstLimit = (FIRST_STEP_LIMIT * FIRST_STEP_SHARES_PER_ASSET) / 1e18;

        if (totalShares <= sharesAtFirstLimit) {
            // All shares are in the first segment
            assets = (shares * 1e18) / FIRST_STEP_SHARES_PER_ASSET;
        } else if (totalShares - shares >= sharesAtFirstLimit) {
            // All shares are in the second segment
            assets = (shares * 1e18) / SECOND_STEP_SHARES_PER_ASSET;
        } else {
            // Shares span both segments
            uint256 sharesInSecondSegment = totalShares - sharesAtFirstLimit;
            uint256 sharesInFirstSegment = shares - sharesInSecondSegment;

            uint256 assetsInFirstSegment = (sharesInFirstSegment * 1e18) / FIRST_STEP_SHARES_PER_ASSET;
            uint256 assetsInSecondSegment = (sharesInSecondSegment * 1e18) / SECOND_STEP_SHARES_PER_ASSET;

            assets = assetsInFirstSegment + assetsInSecondSegment;
        }

        return assets;
    }
}
