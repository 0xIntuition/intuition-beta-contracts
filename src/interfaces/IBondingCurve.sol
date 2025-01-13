// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

interface IBondingCurve {
    /// @notice Emitted upon the minting of shares in the vault by depositing assets into a bonding curve
    ///
    /// @param sender address of the sender
    /// @param receiver address of the receiver
    /// @param receiverTotalSharesInVault total shares held by the receiver in the vault
    /// @param senderAssetsAfterTotalFees total assets that go towards minting shares for the receiver
    /// @param sharesForReceiver total shares minted for the receiver
    /// @param entryFee total fee amount collected for entering the vault
    /// @param vaultId vault id of the vault being deposited into
    /// @param isAtomWallet whether the receiver is an atom wallet or not
    event DepositedCurve(
        address indexed sender,
        address indexed receiver,
        uint256 receiverTotalSharesInVault,
        uint256 senderAssetsAfterTotalFees,
        uint256 sharesForReceiver,
        uint256 entryFee,
        uint256 vaultId,
        // bool isTriple,
        bool isAtomWallet
    );

    /// @notice Emitted upon the withdrawal of assets from the vault by redeeming shares from a bonding curve
    ///
    /// @param sender address of the sender
    /// @param receiver address of the receiver
    /// @param senderTotalSharesInVault total shares held by the sender in the vault
    /// @param assetsForReceiver quantity of assets withdrawn by the receiver
    /// @param sharesRedeemedBySender quantity of shares redeemed by the sender
    /// @param vaultId vault id of the vault being redeemed from
    /// @param curveId curve id of the curve being redeemed from
    event RedeemedCurve(
        address indexed sender,
        address indexed receiver,
        uint256 senderTotalSharesInVault,
        uint256 assetsForReceiver,
        uint256 sharesRedeemedBySender,
        // uint256 exitFee, <-- Omitted because of stack too deep
        uint256 vaultId,
        uint256 curveId
    );

    /// @notice emitted upon changing the share price of a curve
    ///
    /// @param vaultId vault id of the atom
    /// @param curveId curve id of the curve
    /// @param newSharePrice new share price of the curve
    /// @param oldSharePrice old share price of the curve (not needed but staying in parallel with production code)
    event SharePriceChangedCurve(
        uint256 indexed vaultId, uint256 indexed curveId, uint256 newSharePrice, uint256 oldSharePrice
    );

    /// @notice emitted upon the transfer of fees to the protocol multisig
    ///
    /// @param sender address of the sender
    /// @param protocolMultisig address of the protocol multisig
    /// @param amount amount of fees transferred
    event FeesTransferred(address indexed sender, address indexed protocolMultisig, uint256 amount);

    /// @notice returns amount of shares that would be exchanged by vault given amount of assets provided for a curve
    /// @param assets amount of assets to calculate shares on
    /// @param id vault id to get corresponding shares for
    /// @param curveId ID of the bonding curve
    /// @return shares amount of shares that would be exchanged by vault given amount of assets provided
    function convertToSharesCurve(uint256 assets, uint256 id, uint256 curveId) external view returns (uint256);

    /// @notice returns amount of assets that would be exchanged by vault given amount of shares provided for a curve
    /// @param shares amount of shares to calculate assets on
    /// @param id vault id to get corresponding assets for
    /// @param curveId ID of the bonding curve
    /// @return assets amount of assets that would be exchanged by vault given amount of shares provided
    function convertToAssetsCurve(uint256 shares, uint256 id, uint256 curveId) external view returns (uint256);
}
