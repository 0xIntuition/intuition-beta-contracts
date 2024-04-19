// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @title Intuition Types Library
/// @author 0xIntuition
/// @notice Library containing types used throughout the Intuition core protocol
library Types {
    /// @notice Vault state
    struct VaultState {
        uint256 id;
        uint256 assets;
        uint256 shares;
    }
}
