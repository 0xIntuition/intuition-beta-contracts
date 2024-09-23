// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity ^0.8.21;

// import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";

// /// @title LogarithmicStepCurve
// /// @notice Implements a logarithmic stepped bonding curve for share pricing.
// contract LogarithmicStepCurve is EthMultiVaultExperimental {
//     // Scaling factor for logarithmic calculations
//     uint256 public scale; // Adjusted to 3.3e9

//     // Offset to adjust the logarithmic curve
//     uint256 public offset; // Suggested value is 1

//     // The height of each step in Shares
//     uint256 public stepHeight; // Suggested value is 1e6

//     // The width of each step in Assets
//     uint256 public stepWidth; // Suggested value is 3.3e14

//     /// @notice Initializes the LogarithmicStepCurve with default parameters.
//     constructor() {
//         scale = 3.3e9;      // Adjusted scale to align with stepWidth and stepHeight
//         offset = 1;
//         stepHeight = 1e6;   // Align with test expectations
//         stepWidth = 3.3e14; // Align with test expectations
//     }

//     /// @notice Sets the scale for the logarithmic curve.
//     /// @param _scale The new scale value.
//     function setScale(uint256 _scale) external {
//         scale = _scale;
//     }

//     /// @notice Sets the offset for the logarithmic curve.
//     /// @param _offset The new offset value.
//     function setOffset(uint256 _offset) external {
//         offset = _offset;
//     }

//     /// @notice Sets the step height in shares.
//     /// @param _stepHeight The new step height.
//     function setStepHeight(uint256 _stepHeight) external {
//         stepHeight = _stepHeight;
//     }

//     /// @notice Sets the step width in assets.
//     /// @param _stepWidth The new step width.
//     function setStepWidth(uint256 _stepWidth) external {
//         stepWidth = _stepWidth;
//     }

//     /// @notice Returns the current share price for a given vault.
//     /// @param id The vault ID.
//     /// @return The current share price adjusted by decimal precision.
//     function currentSharePrice(uint256 id) external view override returns (uint256) {
//         uint256 totalShares = vaults[id].totalShares;

//         require(totalShares > 0, "No shares exist for this vault");

//         // Calculate the current step based on totalShares
//         uint256 currentStep = totalShares / stepHeight;

//         // Assets at the start of the current step
//         uint256 assetsAtStartOfStep = _assetsAtStep(currentStep);

//         // Assets at the end of the current step
//         uint256 assetsAtEndOfStep = _assetsAtStep(currentStep + 1);

//         // Assets required to acquire one more stepHeight of shares
//         uint256 assetsForNextStep = assetsAtEndOfStep - assetsAtStartOfStep;

//         // Price per share in the current step
//         uint256 pricePerShare = (assetsForNextStep * generalConfig.decimalPrecision) / stepHeight;

//         return pricePerShare;
//     }

//     /// @notice Converts a given amount of assets to shares based on the logarithmic stepped bonding curve.
//     /// @param assets The amount of assets to convert (in wei).
//     /// @param id The vault ID.
//     /// @return The amount of shares equivalent to the assets.
//     function convertToShares(uint256 assets, uint256 id) public view override returns (uint256) {
//         uint256 totalAssets = vaults[id].totalAssets;

//         // Apply logarithmic curve logic
//         uint256 newTotalAssets = totalAssets + assets;
//         uint256 lnOld = _ln(totalAssets + (offset * 1e18));
//         uint256 lnNew = _ln(newTotalAssets + (offset * 1e18));
//         uint256 deltaLn = lnNew - lnOld;

//         // Calculate shares to grant based on deltaLn and scale
//         uint256 sharesToGrant = (deltaLn * scale) / 1e18;

//         // Apply stepped curve logic
//         uint256 stepCount = (sharesToGrant / stepHeight) + 1;
//         sharesToGrant = stepCount * stepHeight;

//         return sharesToGrant;
//     }

//     /// @notice Converts a given amount of shares to assets based on the logarithmic stepped bonding curve.
//     /// @param shares The amount of shares to convert.
//     /// @param id The vault ID.
//     /// @return The amount of assets equivalent to the shares.
//     function convertToAssets(uint256 shares, uint256 id) public view override returns (uint256) {
//         uint256 totalShares = vaults[id].totalShares;
//         uint256 totalAssets = vaults[id].totalAssets;

//         require(shares <= totalShares, "Cannot redeem more shares than available");
//         require(totalShares > 0, "Total shares must be greater than zero");

//         if (shares == totalShares) {
//             return totalAssets; // All shares are redeemed, return all assets
//         }

//         // Calculate the steps involved
//         uint256 stepCount = shares / stepHeight;
//         require(stepCount > 0, "Shares less than stepHeight");

//         // Calculate assets corresponding to the steps
//         uint256 assetsAtRedeemedStep = _assetsAtStep(stepCount);
//         uint256 assetsAtNextStep = _assetsAtStep(stepCount + 1);

//         uint256 assetsToRedeem = assetsAtNextStep - assetsAtRedeemedStep;

//         return assetsToRedeem;
//     }

//     /// @notice Calculates the total assets at a given step using the logarithmic function.
//     ///
//     /// @param step The step number.
//     /// @return assets The total assets at the given step.
//     function _assetsAtStep(uint256 step) private view returns (uint256) {
//         // Reverse engineer the assets at a given step using the logarithmic function
//         uint256 lnAssets = (step * stepWidth * 1e18) / scale;
//         uint256 assets = _exp(lnAssets) - (offset * 1e18);
//         return assets;
//     }

//     /// @notice Approximates the exponential function using a series expansion.
//     ///
//     /// @param x The input value scaled by 1e18.
//     /// @return The exponential of x, scaled by 1e18.
//     function _exp(uint256 x) private pure returns (uint256) {
//         // Approximate the exponential function using a series expansion
//         // This is a simplified example and may need a more accurate implementation
//         uint256 sum = 1e18; // Initialize with the first term of the series
//         uint256 term = 1e18; // The initial term (x^0 / 0!)

//         for (uint256 i = 1; i < 10; i++) {
//             term = (term * x) / (i * 1e18);
//             sum += term;
//         }

//         return sum;
//     }

//     /// @notice Calculates the natural logarithm using a series approximation.
//     ///
//     /// @param x The input value scaled by 1e18.
//     /// @return The natural logarithm of x, scaled by 1e18.
//     function _ln(uint256 x) private pure returns (uint256) {
//         // Approximate ln(x) using a series expansion (Taylor series around x=1)
//         // This is a simplified example and may need a more accurate implementation
//         require(x > 0, "LN input must be positive");

//         uint256 y = ((x - 1e18) * 1e18) / (x + 1e18); // y = (x - 1) / (x + 1)
//         uint256 y2 = (y * y) / 1e18; // y^2
//         uint256 sum = y; // Initialize sum with the first term
//         uint256 term = y; // Current term

//         for (uint256 i = 3; i < 20; i += 2) {
//             term = (term * y2) / 1e18;
//             sum += (term / i);
//         }

//         return 2 * sum;
//     }
// }
