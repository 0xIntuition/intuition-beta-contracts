// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";

contract Exponential is EthMultiVaultExperimental {
    /// @notice Exponential denominator to control exponential growth scaling
    uint256 public expDenominator;

    /// @notice Sets the exponential denominator for controlling growth scaling
    /// @param newExpDenominator New value for the exponential denominator
    function setExpDenominator(uint256 newExpDenominator) external {
        expDenominator = newExpDenominator;
    }

    function currentSharePrice(uint256 id) external view override returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        uint256 totalAssets = vaults[id].totalAssets;

        uint256 price;

        // Linear growth formula when assets <= 1 ETH
        if (totalAssets <= 1e18) {
            price = supply == 0 ? 0 : (totalAssets * generalConfig.decimalPrecision) / supply;
        }
        // Customizable growth formula when assets > 1 ETH
        else {
            uint256 expPart = (totalAssets * sqrt(totalAssets)) / expDenominator;
            price = (expPart * generalConfig.decimalPrecision) / supply;
        }

        return price;
    }

    function convertToShares(uint256 assets, uint256 id) public view override returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        uint256 totalAssets = vaults[id].totalAssets;

        uint256 shares;

        if (totalAssets <= 1e18) {
            shares = supply == 0 ? assets : (assets * supply) / assets;
        } else {
            uint256 expPart = (assets * sqrt(assets)) / expDenominator;
            shares = (assets * supply) / expPart;
        }

        return shares;
    }

    function convertToAssets(uint256 shares, uint256 id) public view override returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        uint256 totalAssets = vaults[id].totalAssets;

        uint256 assets;

        if (totalAssets <= 1e18) {
            assets = supply == 0 ? shares : (shares * assets) / supply;
        } else {
            uint256 expPart = (assets * sqrt(assets)) / expDenominator;
            assets = (shares * expPart) / supply;
        }

        return assets;
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

        return z;
    }
}
