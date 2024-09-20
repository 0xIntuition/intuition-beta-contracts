// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity ^0.8.21;

// import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";

// /// @title LogarithmicStepCurve
// /// @notice Implements a logarithmic stepped bonding curve for share pricing.
// contract LogarithmicStepCurve is EthMultiVaultExperimental {
//     // Increasing this makes the curve more gentle, decreasing it makes it more dramatic
//     uint256 public scale; // Suggested value is 2e18

//     // Increasing this makes the curve start more gentle and lower makes it more dramatic initially
//     uint256 public offset; // Suggested value is 1e18

//     // Increasing this makes the steps taller, decreasing it makes them shorter
//     uint256 public stepHeight; // Suggested unit is ether

//     // Increasing this makes the steps wider, decreasing it makes them narrower
//     uint256 public stepWidth; // Suggested unit is ether

//     constructor() {
//         scale = 2e18;
//         offset = 1e18; // Changed from 1 to 1e18 for consistency with fixed-point arithmetic
//         stepHeight = 1e18;
//         stepWidth = 1e18;
//     }

//     /// @notice Sets the scale for the bonding curve
//     /// @param _scale The new scale
//     function setScale(uint256 _scale) external {
//         scale = _scale;
//     }

//     /// @notice Sets the offset for the bonding curve
//     /// @param _offset The new offset
//     function setOffset(uint256 _offset) external {
//         offset = _offset;
//     }

//     /// @notice Sets the step height for the bonding curve
//     /// @param _stepHeight The new step height
//     function setStepHeight(uint256 _stepHeight) external {
//         stepHeight = _stepHeight;
//     }

//     /// @notice Sets the step width for the bonding curve
//     /// @param _stepWidth The new step width
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
//         uint256 currentStep = (totalShares * 1e18) / stepHeight;

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

//     /// @notice Converts a given amount of assets to shares based on the logarithmic step bonding curve.
//     /// @param assets The amount of assets to convert (in wei).
//     /// @param id The vault ID.
//     /// @return The amount of shares equivalent to the assets.
//     function convertToShares(uint256 assets, uint256 id) public view override returns (uint256) {
//         uint256 totalAssets = vaults[id].totalAssets;

//         // Apply logarithmic curve logic
//         uint256 newTotalAssets = totalAssets + assets;
//         uint256 lnOld = _ln(totalAssets + offset);
//         uint256 lnNew = _ln(newTotalAssets + offset);
//         uint256 deltaLn = lnNew - lnOld;
//         uint256 sharesToGrant = (deltaLn * scale) / 1e18;

//         // Apply stepped curve logic
//         uint256 stepCount = (sharesToGrant / stepWidth) + 1;
//         sharesToGrant = stepCount * stepHeight;

//         // Add safeguard to prevent division by zero
//         require(sharesToGrant >= 1e18, "Shares to grant too low");

//         return sharesToGrant / 1e18;
//     }

//     /// @notice Converts a given amount of shares to assets based on the logarithmic step bonding curve.
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
//         uint256 stepCount = totalShares / stepHeight;
//         uint256 remainingShares = totalShares - shares;
//         uint256 remainingSteps = remainingShares / stepHeight;

//         // Calculate assets corresponding to the steps
//         uint256 assetsAtCurrentStep = _assetsAtStep(stepCount);
//         uint256 assetsAtRemainingStep = _assetsAtStep(remainingSteps);

//         require(assetsAtCurrentStep >= assetsAtRemainingStep, "Invalid asset calculation");

//         uint256 assetsToRedeem = assetsAtCurrentStep - assetsAtRemainingStep;

//         return assetsToRedeem;
//     }

//     /// @notice Calculates the assets at a given step using the logarithmic function.
//     /// @param step The current step.
//     /// @return The assets corresponding to the given step.
//     function _assetsAtStep(uint256 step) private view returns (uint256) {
//         // Reverse engineer the assets at a given step using the logarithmic function
//         uint256 lnAssets = (step * stepWidth * 1e18) / scale;
//         uint256 assets = _exp(lnAssets) - offset;
//         return assets;
//     }

//     /// @notice Approximates the exponential function using a Taylor series expansion.
//     /// @param x The exponent value in fixed-point (1e18) format.
//     /// @return The exponential of x.
//     function _exp(uint256 x) private pure returns (uint256) {
//         // Initialize with the first term of the series (1)
//         uint256 sum = 1e18;
//         uint256 term = 1e18;

//         for (uint256 i = 1; i < 20; i++) {
//             // term = term * x / (i * 1e18)
//             term = (term * x) / (i * 1e18);
//             sum += term;

//             // Break early if term becomes insignificant to save gas
//             if (term < 1) break;
//         }

//         return sum;
//     }

//     /// @notice Calculates the natural logarithm using a series approximation.
//     /// @param x The value to calculate the natural logarithm for (fixed-point, 1e18).
//     /// @return The natural logarithm of the given value.
//     function _ln(uint256 x) private pure returns (uint256) {
//         // Ensure x is greater than zero to prevent division by zero
//         require(x > 0, "Cannot calculate ln of non-positive number");

//         // Calculate y = (x - 1e18) / (x + 1e18) in fixed-point
//         uint256 y = ( (x - 1e18) * 1e18 ) / (x + 1e18);
//         uint256 y2 = (y * y) / 1e18;
//         uint256 sum = y;
//         uint256 term = y;

//         for (uint256 i = 3; i < 20; i += 2) {
//             // term = term * y2 / 1e18
//             term = (term * y2) / 1e18;
//             sum += term / i;

//             // Break early if term becomes insignificant to save gas
//             if (term / i < 1) break;
//         }

//         // Return 2 * sum in fixed-point
//         return (2 * sum) / 1e18;
//     }

//     /// @notice Calculates the price based on total shares using the logarithmic step function.
//     /// @param totalShares The total shares in the vault.
//     /// @return The calculated price.
//     function _calculatePrice(uint256 totalShares) internal view returns (uint256) {
//         if (totalShares == 0) {
//             // Return the starting price
//             return generalConfig.decimalPrecision; // e.g., 1e18
//         }

//         // Scale down totalShares to prevent overflow
//         uint256 scaledShares = totalShares / 1e18; // Convert wei to ether units

//         // Ensure scaledShares is at least 1 to prevent zero
//         if (scaledShares == 0) {
//             scaledShares = 1;
//         }

//         // Calculate the variable part: variablePart = scaledShares * incrementPrice * xFactor
//         // Since incrementPrice and xFactor are in wei units, adjust for scaling
//         uint256 variablePart = (scaledShares * incrementPrice * xFactor) / 1e18; // Adjust back to wei units

//         // Removed redundant scaling
//         // uint256 price = variablePart * 1e18;
//         uint256 price = variablePart;

//         return price;
//     }
// }
