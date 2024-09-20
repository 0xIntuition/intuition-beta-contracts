// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";

contract Logarithmic is EthMultiVaultExperimental {
    // Increasing this makes the curve more gentle, decreasing it makes it more dramatic
    uint256 public scale; // Suggested value is 2e18

    // Increasing this makes the curve start more gentle and lower makes it more dramatic initially
    uint256 public offset; // Suggested value is 1

    constructor() {
        scale = 2e18;
        offset = 1;
    }

    function setScale(uint256 _scale) external {
        scale = _scale;
    }

    function setOffset(uint256 _offset) external {
        offset = _offset;
    }

    function convertToShares(uint256 assets, uint256 id) public view override returns (uint256) {
        uint256 totalAssets = vaults[id].totalAssets;

        uint256 newTotalAssets = totalAssets + assets;
        uint256 lnOld = _ln(totalAssets + offset);
        uint256 lnNew = _ln(newTotalAssets + offset);
        uint256 deltaLn = lnNew - lnOld;
        uint256 sharesToGrant = deltaLn * scale / 1e18; // Adjust for scaling.
        return sharesToGrant / 1e18;
    }

    function currentSharePrice(uint256 id) external view override returns (uint256) {
        uint256 totalAssets = vaults[id].totalAssets;
        uint256 totalShares = vaults[id].totalShares;

        if (totalShares == 0) {
            return 0;
        }

        // Calculate the derivative dA/dS = (A + offset) * 1e18 / scale
        // Adjusted for the generalConfig.decimalPrecision
        uint256 numerator = (totalAssets + offset) * generalConfig.decimalPrecision * 1e18;
        uint256 price = numerator / scale;

        return price;
    }

    function convertToAssets(uint256 shares, uint256 id) public view override returns (uint256) {
        uint256 totalShares = vaults[id].totalShares;
        uint256 totalAssets = vaults[id].totalAssets;

        require(shares <= totalShares, "Cannot redeem more shares than available");
        require(totalShares > 0, "Total shares must be greater than zero");

        if (shares == totalShares) {
            return totalAssets; // All shares are redeemed, return all assets
        }

        // Applying the logarithmic model to determine the assets equivalent to the given shares
        uint256 remainingShares = totalShares - shares;
        uint256 lnTotalShares = _ln(totalShares + offset);
        uint256 lnRemainingShares = _ln(remainingShares + offset);

        // Calculate the percentage of assets remaining after the shares redemption
        uint256 assetsRemaining = (totalAssets * lnRemainingShares) / lnTotalShares;
        uint256 assetsToRedeem = totalAssets - assetsRemaining;

        return assetsToRedeem;
    }

    /// @notice Calculate the natural logarithm using the Taylor series approximation for 1 + x.
    ///
    /// @param x Value to calculate the natural logarithm for
    /// @return logarithm The natural logarithm of the given value
    function _ln(uint256 x) private pure returns (uint256) {
        uint256 z = (x * 1e18) / (x + 2e18);
        uint256 zSquared = (z * z) / 1e18;
        uint256 zCubed = (zSquared * z) / 1e18;
        // Summing the first few terms of the Taylor series
        return (z + (zSquared / 2) + (zCubed / 3)) * 1e18;
    }
}
