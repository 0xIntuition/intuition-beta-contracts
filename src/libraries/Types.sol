// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Intuition Types Library
/// @author 0xIntuition
/// @notice Library containing types used throughout the Intuition core protocol
library Types {
    /*//////////// MultiVault //////////////////////////////////////////////////////////////////*/

    /// @notice Delegate Approval struct stored for each delegate
    struct DelegateApproval {
        // flag to indicate approval for all vaults if true then no vaultIds/amounts are required
        bool forAll;
        // selected vaultIds operator has been approved for
        uint256[] vaultIds;
        // associated amounts for each vaultId
        uint256[] amounts;
    }

    /*////////// TrustBonding //////////////////////////////////////////////////////////////////*/

    /// @notice The bonded trust struct stored for each bonder
    struct BondedTrust {
        // amount bonded
        uint256 amount;
        // time at which the bond expires
        uint256 endTime;
    }

    /// @notice Vault state
    struct VaultState {
        uint256 id;
        uint256 assets;
        uint256 shares;
    }
}
