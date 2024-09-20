// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";

contract SteppedCurve is EthMultiVaultExperimental {
    // The width of each step in Assets
    uint256 public stepWidth;

    // The height of each step in Shares
    uint256 public stepHeight;

    constructor() {
        stepWidth = 1e18;
        stepHeight = 1e18;
    }

    function setStepWidth(uint256 _stepWidth) external {
        stepWidth = _stepWidth;
    }

    function setStepHeight(uint256 _stepHeight) external {
        stepHeight = _stepHeight;
    }

    function currentSharePrice(uint256 id) external view override returns (uint256) {
        // Avoid division by zero
        require(stepHeight > 0, "Step height must be greater than zero");

        uint256 totalAssets = vaults[id].totalAssets;
        uint256 totalShares = vaults[id].totalShares;

        uint256 vaultStepWidth = _getStepWidth(totalShares);
        uint256 vaultStepHeight = _getStepHeight(totalAssets);

        // The current share price is the ratio of stepWidth to stepHeight
        // Adjusted by the decimal precision used in the system
        uint256 price = (vaultStepWidth * generalConfig.decimalPrecision) / vaultStepHeight;
        return price;
    }

    function convertToShares(uint256 assets, uint256 id) public view override returns (uint256) {
        uint256 totalAssets = vaults[id].totalAssets;

        uint256 newTotalAssets = totalAssets + assets;
        uint256 currentHeight = _getStepHeight(totalAssets);
        uint256 newHeight = _getStepHeight(newTotalAssets);
        uint256 sharesToAward = (newHeight - currentHeight) + (newTotalAssets % stepWidth);
        return sharesToAward;
    }

    function convertToAssets(uint256 shares, uint256 id) public view override returns (uint256) {
        uint256 totalShares = vaults[id].totalShares;

        uint256 newTotalShares = totalShares - shares;
        uint256 currentWidth = _getStepWidth(totalShares);
        uint256 newWidth = _getStepWidth(newTotalShares);
        uint256 assetsToRedeem = (currentWidth - newWidth) + (newTotalShares % stepHeight);
        return assetsToRedeem;
    }

    /// @notice Get the height of the step for the given assets
    ///
    /// @param assets Quantity of assets to stake into the curve
    /// @return height Total height of the steps for the given assets
    function _getStepHeight(uint256 assets) private view returns (uint256) {
        return ((stepWidth + assets) / stepWidth) * stepHeight;
    }

    /// @notice Get the width of the step for the given shares
    ///
    /// @param shares Quantity of shares to redeem from the curve
    /// @return width Total width of the steps for the given shares
    function _getStepWidth(uint256 shares) private view returns (uint256) {
        return ((stepHeight + shares) / stepHeight) * stepWidth;
    }
}
