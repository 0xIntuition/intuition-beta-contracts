// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";
import {Errors} from "src/libraries/Errors.sol";

contract SquareRoot is EthMultiVaultExperimental {
    using FixedPointMathLib for uint256;

    /// @notice The increment price variable that controls the rate of price increase
    uint256 public incrementPrice;

    /// @notice Event emitted when increment price is set
    /// @param incrementPrice new increment price
    event IncrementPriceSet(uint256 incrementPrice);

    /// @notice Error thrown when the new increment price provided is not positive
    error IncrementPriceMustBePositive();

    /// @notice Initializes the SquareRoot curve with default increment price
    constructor() {
        incrementPrice = 1e9;
    }

    /// @notice sets the increment price for the bonding curve
    /// @param _incrementPrice new increment price
    function setIncrementPrice(uint256 _incrementPrice) external {
        if (_incrementPrice == 0) {
            revert IncrementPriceMustBePositive();
        }

        incrementPrice = _incrementPrice;

        emit IncrementPriceSet(_incrementPrice);
    }

    /// @notice returns the current share price for the given vault id
    /// @param id vault id to get corresponding share price for
    /// @return price current share price for the given vault id
    function currentSharePrice(uint256 id) public view override returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        uint256 totalAssets = vaults[id].totalAssets;

        uint256 price;

        uint256 linearPart = supply == 0 ? 0 : (totalAssets * generalConfig.decimalPrecision) / supply;

        if (totalAssets <= 1 ether) {
            price = linearPart;
        } else {
            uint256 sqrtPart = _sqrt(totalAssets) * incrementPrice;
            price = linearPart + sqrtPart;
        }

        return price;
    }

    /// @notice returns amount of shares that would be exchanged by vault given amount of 'assets' provided
    ///
    /// @param assets amount of assets to calculate shares on
    /// @param id vault id to get corresponding shares for
    ///
    /// @return shares amount of shares that would be exchanged by vault given amount of 'assets' provided
    function convertToShares(uint256 assets, uint256 id) public view override returns (uint256) {
        uint256 price = currentSharePrice(id);
        require(price > 0, "SquareRoot: Share price is zero");

        uint256 shares = FixedPointMathLib.mulDiv(assets, generalConfig.decimalPrecision, price);
        return shares;
    }

    /// @notice returns amount of assets that would be exchanged by vault given amount of 'shares' provided
    ///
    /// @param shares amount of shares to calculate assets on
    /// @param id vault id to get corresponding assets for
    ///
    /// @return assets amount of assets that would be exchanged by vault given amount of 'shares' provided
    function convertToAssets(uint256 shares, uint256 id) public view override returns (uint256) {
        uint256 price = currentSharePrice(id);
        require(price > 0, "SquareRoot: Share price is zero");

        uint256 assets = FixedPointMathLib.mulDiv(shares, price, generalConfig.decimalPrecision);
        return assets;
    }

    /// @notice Integer square root function (Babylonian method)
    /// @param x The number to calculate the square root of
    /// @return y The square root of x
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        uint256 y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }

        return y;
    }

    /* =================================================== */
    /*                 INTERNAL METHODS                    */
    /* =================================================== */

    /// @dev redeem shares out of a given vault.
    ///      Changes the vault's total assets, total shares and balanceOf mappings to reflect the withdrawal
    ///
    /// @param id the vault ID of the atom or triple
    /// @param sender the address to redeem the shares from
    /// @param receiver the address to receive the assets
    /// @param shares the amount of shares to redeem
    ///
    /// @return assetsForReceiver the amount of assets/eth to be transferred to the receiver
    /// @return protocolFee the amount of protocol fees deducted
    function _redeem(uint256 id, address sender, address receiver, uint256 shares)
        internal
        override
        returns (uint256, uint256)
    {
        if (shares == 0) {
            revert Errors.EthMultiVault_DepositOrWithdrawZeroShares();
        }

        if (maxRedeem(sender, id) < shares) {
            revert Errors.EthMultiVault_InsufficientSharesInVault();
        }

        if (vaults[id].totalShares - shares < generalConfig.minShare) {
            revert Errors.EthMultiVault_InsufficientRemainingSharesInVault(vaults[id].totalShares - shares);
        }

        (uint256 assetsForReceiver, uint256 protocolFee) = _calculateRedeem(id, shares);

        // Ensure that assets + protocolFee does not exceed totalAssets
        require(assetsForReceiver + protocolFee <= vaults[id].totalAssets, "SquareRoot: Redeem exceeds total assets");

        // set vault totals (assets and shares)
        _setVaultTotals(
            id,
            vaults[id].totalAssets - (assetsForReceiver + protocolFee), // totalAssetsDelta
            vaults[id].totalShares - shares // totalSharesDelta
        );

        // burn shares, then transfer assets to receiver
        _burn(sender, id, shares);

        emit Redeemed(sender, receiver, vaults[id].balanceOf[sender], assetsForReceiver, shares, 0, id);

        return (assetsForReceiver, protocolFee);
    }

    /// @dev Internal function to calculate assets and protocol fees during redemption
    function _calculateRedeem(uint256 id, uint256 shares) public view returns (uint256, uint256) {
        uint256 assetsForReceiver = convertToAssets(shares, id);
        uint256 protocolFee = protocolFeeAmount(assetsForReceiver, id);
        return (assetsForReceiver, protocolFee);
    }
}
