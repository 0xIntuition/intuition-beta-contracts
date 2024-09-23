// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";

/// @title SteppedCurve
/// @notice Implements a stepped bonding curve for share pricing.
contract SteppedCurve is EthMultiVaultExperimental {
    // The width of each step in Assets (e.g., 3.3e14)
    uint256 public stepWidth;

    // The height of each step in Shares (e.g., 1e6)
    uint256 public stepHeight;

    /// @notice Initializes the SteppedCurve with default stepWidth and stepHeight.
    constructor() {
        stepWidth = 3.3e14; // Set based on your test requirements
        stepHeight = 1e6;    // Set based on your test requirements
    }

    /// @notice Sets the step width for the bonding curve.
    /// @param _stepWidth The new step width in Assets.
    function setStepWidth(uint256 _stepWidth) external {
        stepWidth = _stepWidth;
    }

    /// @notice Sets the step height for the bonding curve.
    /// @param _stepHeight The new step height in Shares.
    function setStepHeight(uint256 _stepHeight) external {
        stepHeight = _stepHeight;
    }

    /// @notice Returns the current share price for a given vault.
    /// @param id The vault ID.
    /// @return The current share price adjusted by decimal precision.
    function currentSharePrice(uint256 id) external view override returns (uint256) {
        // Avoid division by zero
        require(stepHeight > 0, "Step height must be greater than zero");
        require(stepWidth > 0, "Step width must be greater than zero");

        // currentSharePrice = (stepWidth / stepHeight) * decimalPrecision
        uint256 price = (stepWidth * generalConfig.decimalPrecision) / stepHeight;
        return price;
    }

    /// @notice Converts a given amount of assets to shares based on the stepped bonding curve.
    /// @param assets The amount of assets to convert (in wei).
    /// @param id The vault ID.
    /// @return The amount of shares equivalent to the assets.
    function convertToShares(uint256 assets, uint256 id) public view override returns (uint256) {
        uint256 totalAssets = vaults[id].totalAssets;

        uint256 newTotalAssets = totalAssets + assets;
        uint256 currentSteps = totalAssets / stepWidth;
        uint256 newSteps = newTotalAssets / stepWidth;
        uint256 stepsCrossed = newSteps - currentSteps;

        // Ensure that stepsCrossed does not underflow
        require(stepsCrossed > 0, "No steps crossed");

        uint256 sharesToAward = stepsCrossed * stepHeight;

        return sharesToAward;
    }

    /// @notice Converts a given amount of shares to assets based on the stepped bonding curve.
    /// @param shares The amount of shares to convert.
    /// @param id The vault ID.
    /// @return The amount of assets equivalent to the shares.
    function convertToAssets(uint256 shares, uint256 id) public view override returns (uint256) {
        uint256 totalShares = vaults[id].totalShares;

        uint256 stepsToRedeem = shares / stepHeight;

        // Ensure that stepsToRedeem is greater than zero
        require(stepsToRedeem > 0, "Shares less than stepHeight");

        uint256 assetsToRedeem = stepsToRedeem * stepWidth;

        // Ensure that assetsToRedeem does not exceed totalAssets
        require(assetsToRedeem <= vaults[id].totalAssets, "Assets to redeem exceed totalAssets");

        return assetsToRedeem;
    }

    /// @notice Calculates the total height of steps for the given assets.
    ///
    /// @param assets The total assets in the vault.
    /// @return height The total height based on the number of steps.
    function _getStepHeight(uint256 assets) private view returns (uint256) {
        return (assets / stepWidth) * stepHeight;
    }

    /// @notice Calculates the total width of steps for the given shares.
    ///
    /// @param shares The total shares in the vault.
    /// @return width The total width based on the number of steps.
    function _getStepWidth(uint256 shares) private view returns (uint256) {
        return (shares / stepHeight) * stepWidth;
    }
}
