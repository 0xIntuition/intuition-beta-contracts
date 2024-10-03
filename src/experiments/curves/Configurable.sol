// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Configurable is EthMultiVaultExperimental {
    using FixedPointMathLib for uint256;

    uint256 public incrementPrice;

    error InvalidIncrementPrice();

    constructor(uint256 _incrementPrice) {
        if (_incrementPrice == 0) {
            revert InvalidIncrementPrice();
        }

        incrementPrice = _incrementPrice;
    }

    function setIncrementPrice(uint256 _incrementPrice) external {
        if (_incrementPrice == 0) {
            revert InvalidIncrementPrice();
        }

        incrementPrice = _incrementPrice;
    }

    function currentSharePrice(uint256 id) external view override returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        uint256 totalAssets = vaults[id].totalAssets;

        uint256 basePrice = (totalAssets * generalConfig.decimalPrecision) / supply;
        uint256 price;

        if (totalAssets <= generalConfig.decimalPrecision) {
            price = supply == 0 ? 0 : basePrice;
        } else {
            uint256 totalIncrement = (totalAssets * generalConfig.decimalPrecision) / incrementPrice;
            price = basePrice + totalIncrement;
        }

        return price;
    }

    function convertToShares(uint256 assets, uint256 id) public view override returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        uint256 totalAssets = vaults[id].totalAssets;

        uint256 shares;

        if (totalAssets <= generalConfig.decimalPrecision) {
            shares = supply == 0 ? assets : assets.mulDiv(supply, totalAssets);
        } else {
            uint256 numerator = assets.mulDiv(supply * incrementPrice, 1);
            uint256 denominator = totalAssets.mulDiv(incrementPrice + supply, 1);
            shares = numerator / denominator;
        }

        return shares;
    }

    function convertToAssets(uint256 shares, uint256 id) public view override returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        uint256 totalAssets = vaults[id].totalAssets;

        uint256 assets;

        if (totalAssets <= generalConfig.decimalPrecision) {
            assets = supply == 0 ? shares : shares.mulDiv(totalAssets, supply);
        } else {
            uint256 numerator = shares.mulDiv(totalAssets * (incrementPrice + supply), 1);
            uint256 denominator = supply.mulDiv(incrementPrice, 1);
            assets = numerator / denominator;
        }

        return assets;
    }
}

// /**
//  * @title Configurable
//  * @notice Applies a standard linear bonding curve up to 1 ETH and handles zero shares/assets cases.
//  * Implements exponential growth for smoother share price increases beyond 1 ETH.
//  */
// contract Configurable is EthMultiVaultExperimental {
//     using FixedPointMathLib for uint256;

//     /// @notice Bonding Curve Configuration
//     BondingCurveConfig public bondingCurveConfig;

//     struct BondingCurveConfig {
//         uint256 a; // Scaling factor (e.g., 1e12 wei/share)
//         uint256 c; // Base price (e.g., 1e15 wei/share = 0.001 ETH/share)
//     }

//     /// @dev Emitted when the bonding curve configuration is updated
//     event BondingCurveConfigUpdated(uint256 a, uint256 c);

//     /// @dev Sets the Bonding Curve Configuration
//     ///
//     /// @param a Scaling factor
//     /// @param c Base price
//     function setBondingCurveConfig(uint256 a, uint256 c) external {
//         require(a > 0, "Scaling factor must be positive");
//         require(c > 0, "Base price must be positive");

//         bondingCurveConfig = BondingCurveConfig(a, c);
//         emit BondingCurveConfigUpdated(a, c);
//     }

//     /**
//      * @notice Calculates the current share price based on the bonding curve.
//      * @param id Vault ID
//      * @return price Current share price in wei
//      */
//     function currentSharePrice(uint256 id) public view override returns (uint256) {
//         uint256 supply = vaults[id].totalShares;
//         uint256 totalAssets = vaults[id].totalAssets;

//         uint256 a = bondingCurveConfig.a;
//         uint256 c = bondingCurveConfig.c;
//         uint256 scalingFactor = 1e6;  // Adjust this as needed for smoother scaling

//         uint256 price;

//         if (totalAssets <= generalConfig.decimalPrecision) {
//             // Handle zero shares/assets case
//             if (supply == 0) {
//                 price = c; // Set to base price to avoid division by zero
//             } else {
//                 price = (totalAssets * generalConfig.decimalPrecision) / supply;
//             }
//         } else {
//             // Apply exponential bonding curve beyond 1 ETH
//             uint256 exponentialFactor = FixedPointMathLib.exp(supply / scalingFactor);
//             price = (a * exponentialFactor) / 1e18 + c;
//         }

//         return price;
//     }

//     /**
//      * @notice Converts a given amount of assets (ETH) to shares based on the bonding curve.
//      * @param assets Amount of ETH to convert
//      * @param id Vault ID
//      * @return shares Number of shares to mint
//      */
//     function convertToShares(uint256 assets, uint256 id) public view override returns (uint256 shares) {
//         BondingCurveConfig memory config = bondingCurveConfig;
//         uint256 supply = vaults[id].totalShares;
//         uint256 totalAssets = vaults[id].totalAssets;

//         require(assets > config.c, "Assets must be greater than base price");

//         if (totalAssets <= generalConfig.decimalPrecision) {
//             if (supply == 0) {
//                 // If no shares exist, mint shares based on base price
//                 shares = (assets * 1e18) / config.c;
//             } else {
//                 // price = (totalAssets * 1e18) / supply
//                 uint256 price = (totalAssets * generalConfig.decimalPrecision) / supply;
//                 shares = (assets * generalConfig.decimalPrecision) / price;
//             }
//         } else {
//             // price = a * exp(supply / scalingFactor) + c
//             uint256 exponentialFactor = FixedPointMathLib.exp(supply / 1e6);
//             uint256 price = (config.a * exponentialFactor) / 1e18 + config.c;
//             shares = (assets * generalConfig.decimalPrecision) / price;
//         }

//         // Ensure at least 1 share is minted if possible
//         if (shares == 0 && assets >= config.c) {
//             shares = 1;
//         }
//     }

//     /**
//      * @notice Converts a given amount of shares to assets (ETH) based on the bonding curve.
//      * @param shares Number of shares to convert
//      * @param id Vault ID
//      * @return assets Amount of ETH to return
//      */
//     function convertToAssets(uint256 shares, uint256 id) public view override returns (uint256 assets) {
//         BondingCurveConfig memory config = bondingCurveConfig;
//         uint256 supply = vaults[id].totalShares;
//         uint256 totalAssets = vaults[id].totalAssets;

//         if (totalAssets == 0 || supply == 0) {
//             assets = 0;
//         } else if (totalAssets <= generalConfig.decimalPrecision) {
//             // price = (totalAssets * 1e18) / supply
//             uint256 price = (totalAssets * generalConfig.decimalPrecision) / supply;
//             assets = (shares * price) / generalConfig.decimalPrecision;
//         } else {
//             // price = a * exp(supply / scalingFactor) + c
//             uint256 exponentialFactor = FixedPointMathLib.exp(supply / 1e6);
//             uint256 price = (config.a * exponentialFactor) / 1e18 + config.c;
//             assets = (shares * price) / generalConfig.decimalPrecision;
//         }
//     }
// }

// pragma solidity ^0.8.21;

// import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";
// import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// /**
//  * @title Configurable
//  * @notice Applies a standard linear bonding curve up to 1 ETH and handles zero shares/assets cases.
//  */
// contract Configurable is EthMultiVaultExperimental {
//     using FixedPointMathLib for uint256;

//     /// @notice Bonding Curve Configuration
//     BondingCurveConfig public bondingCurveConfig;

//     struct BondingCurveConfig {
//         uint256 a; // Scaling factor (e.g., 1e12 wei/share)
//         uint256 c; // Base price (e.g., 1e15 wei/share = 0.001 ETH/share)
//     }

//     /// @dev Emitted when the bonding curve configuration is updated
//     event BondingCurveConfigUpdated(uint256 a, uint256 c);

//     /// @dev Sets the Bonding Curve Configuration
//     ///
//     /// @param a Scaling factor
//     /// @param c Base price
//     function setBondingCurveConfig(uint256 a, uint256 c) external {
//         require(a > 0, "Scaling factor must be positive");
//         require(c > 0, "Base price must be positive");

//         bondingCurveConfig = BondingCurveConfig(a, c);
//         emit BondingCurveConfigUpdated(a, c);
//     }

//     /**
//      * @notice Calculates the current share price based on the bonding curve.
//      * @param id Vault ID
//      * @return price Current share price in wei
//      */
//     function currentSharePrice(uint256 id) public view override returns (uint256) {
//         uint256 supply = vaults[id].totalShares;
//         uint256 totalAssets = vaults[id].totalAssets;

//         uint256 a = bondingCurveConfig.a;
//         uint256 c = bondingCurveConfig.c;

//         uint256 price;

//         if (totalAssets <= generalConfig.decimalPrecision) {
//             // Handle zero shares/assets case
//             if (supply == 0) {
//                 price = c; // Set to base price to avoid division by zero
//             } else {
//                 price = (totalAssets * generalConfig.decimalPrecision) / supply;
//             }
//         } else {
//             // Apply linear bonding curve beyond 1 ETH
//             price = a.mulDiv(supply, 1e18) + c;
//         }

//         return price;
//     }

//     /**
//      * @notice Converts a given amount of assets (ETH) to shares based on the bonding curve.
//      * @param assets Amount of ETH to convert
//      * @param id Vault ID
//      * @return shares Number of shares to mint
//      */
//     function convertToShares(uint256 assets, uint256 id) public view override returns (uint256 shares) {
//         BondingCurveConfig memory config = bondingCurveConfig;
//         uint256 supply = vaults[id].totalShares;
//         uint256 totalAssets = vaults[id].totalAssets;

//         require(assets > config.c, "Assets must be greater than base price");

//         if (totalAssets <= generalConfig.decimalPrecision) {
//             if (supply == 0) {
//                 // If no shares exist, mint shares based on base price
//                 // shares = assets / c
//                 shares = assets.mulDiv(1e18, config.c);
//             } else {
//                 // price = (assets * 1e18) / shares
//                 uint256 price = (totalAssets * generalConfig.decimalPrecision) / supply;
//                 shares = assets.mulDiv(generalConfig.decimalPrecision, price);
//             }
//         } else {
//             // price = a * supply + c
//             uint256 price = config.a.mulDiv(supply, 1e18) + config.c;
//             shares = assets.mulDiv(generalConfig.decimalPrecision, price);
//         }

//         // Ensure at least 1 share is minted if possible
//         if (shares == 0 && assets >= config.c) {
//             shares = 1;
//         }
//     }

//     /**
//      * @notice Converts a given amount of shares to assets (ETH) based on the bonding curve.
//      * @param shares Number of shares to convert
//      * @param id Vault ID
//      * @return assets Amount of ETH to return
//      */
//     function convertToAssets(uint256 shares, uint256 id) public view override returns (uint256 assets) {
//         BondingCurveConfig memory config = bondingCurveConfig;
//         uint256 supply = vaults[id].totalShares;
//         uint256 totalAssets = vaults[id].totalAssets;

//         if (totalAssets == 0 || supply == 0) {
//             assets = 0;
//         } else if (totalAssets <= generalConfig.decimalPrecision) {
//             // price = (assets * 1e18) / shares
//             uint256 price = (totalAssets * generalConfig.decimalPrecision) / supply;
//             assets = shares.mulDiv(price, generalConfig.decimalPrecision);
//         } else {
//             // price = a * supply + c
//             uint256 price = config.a.mulDiv(supply, 1e18) + config.c;
//             assets = shares.mulDiv(price, generalConfig.decimalPrecision);
//         }
//     }
// }
