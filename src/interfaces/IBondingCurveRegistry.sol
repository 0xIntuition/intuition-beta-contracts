// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/**
 * @title  IBondingCurveRegistry
 * @author 0xIntuition
 * @notice Interface for the BondingCurveRegistry contract. Routes access to the curves associated with atoms & triples.
 */
interface IBondingCurveRegistry {
    /// @notice Preview how many shares would be minted for a deposit of assets
    /// @param assets Quantity of assets to deposit
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param id Curve ID to use for the calculation
    /// @return shares The number of shares that would be minted
    function previewDeposit(uint256 assets, uint256 totalAssets, uint256 totalShares, uint256 id)
        external
        view
        returns (uint256 shares);

    /// @notice Preview how many assets would be returned for burning a specific amount of shares
    /// @param shares Quantity of shares to burn
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param id Curve ID to use for the calculation
    /// @return assets The number of assets that would be returned
    function previewRedeem(uint256 shares, uint256 totalShares, uint256 totalAssets, uint256 id)
        external
        view
        returns (uint256 assets);

    /// @notice Preview how many shares would be redeemed for a withdrawal of assets
    /// @param assets Quantity of assets to withdraw
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param id Curve ID to use for the calculation
    /// @return shares The number of shares that would need to be redeemed
    function previewWithdraw(uint256 assets, uint256 totalAssets, uint256 totalShares, uint256 id)
        external
        view
        returns (uint256 shares);

    /// @notice Preview how many assets would be required to mint a specific amount of shares
    /// @param shares Quantity of shares to mint
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param id Curve ID to use for the calculation
    /// @return assets The number of assets that would be required to mint the shares
    function previewMint(uint256 shares, uint256 totalShares, uint256 totalAssets, uint256 id)
        external
        view
        returns (uint256 assets);

    /// @notice Convert assets to shares at a specific point on the curve
    /// @param assets Quantity of assets to convert to shares
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param id Curve ID to use for the calculation
    /// @return shares The number of shares equivalent to the given assets
    function convertToShares(uint256 assets, uint256 totalAssets, uint256 totalShares, uint256 id)
        external
        view
        returns (uint256 shares);

    /// @notice Convert shares to assets at a specific point on the curve
    /// @param shares Quantity of shares to convert to assets
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param id Curve ID to use for the calculation
    /// @return assets The number of assets equivalent to the given shares
    function convertToAssets(uint256 shares, uint256 totalShares, uint256 totalAssets, uint256 id)
        external
        view
        returns (uint256 assets);

    /// @notice Get the current price of a share
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param id Curve ID to use for the calculation
    /// @return sharePrice The current price of a share
    function currentPrice(uint256 totalShares, uint256 id) external view returns (uint256 sharePrice);

    /// @notice Get the name of a curve
    /// @param id Curve ID to query
    /// @return name The name of the curve
    function getCurveName(uint256 id) external view returns (string memory name);

    /// @notice Get the maximum number of shares a curve can handle
    /// @param id Curve ID to query
    /// @return maxShares The maximum number of shares
    function getCurveMaxShares(uint256 id) external view returns (uint256 maxShares);

    /// @notice Get the maximum number of assets a curve can handle
    /// @param id Curve ID to query
    /// @return maxAssets The maximum number of assets
    function getCurveMaxAssets(uint256 id) external view returns (uint256 maxAssets);

    /// @notice Get the number of curves registered in the registry
    /// @return count The number of curves registered
    function count() external view returns (uint256);

    /// @notice Get the admin address
    /// @return The address of the admin
    function admin() external view returns (address);

    /// @notice Get the curve address for a given ID
    /// @param id The curve ID to query
    /// @return The address of the curve
    function curveAddresses(uint256 id) external view returns (address);

    /// @notice Get the curve ID for a given address
    /// @param curve The curve address to query
    /// @return The ID of the curve
    function curveIds(address curve) external view returns (uint256);
}
