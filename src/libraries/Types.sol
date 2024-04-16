// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

/// @title Types Library
/// @notice Library containing types used in the EthMultiVault contract
library Types {
    /// @notice Vault state
    struct VaultState {
        uint256 id;
        uint256 assets;
        uint256 shares;
    }
}
