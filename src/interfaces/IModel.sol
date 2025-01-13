// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {IPermit2} from "src/interfaces/IPermit2.sol";

interface IModel {
    /* =================================================== */
    /*                   CONFIGS STRUCTS                   */
    /* =================================================== */

    /// @dev General configuration struct
    struct GeneralConfig {
        /// @dev Admin address
        address admin;
        /// @dev Protocol multisig address
        address protocolMultisig;
        /// @dev Fees are calculated by amount * (fee / feeDenominator);
        uint256 feeDenominator;
        /// @dev minimum amount of assets that must be deposited into an atom/triple vault
        uint256 minDeposit;
        /// @dev number of shares minted to zero address upon vault creation to initialize the vault
        uint256 minShare;
        /// @dev maximum length of the atom URI data that can be passed when creating atom vaults
        uint256 atomUriMaxLength;
        /// @dev decimal precision used for calculating share prices
        uint256 decimalPrecision;
        /// @dev minimum delay for timelocked transactions
        uint256 minDelay;
    }

    /// @dev Bonding Curve configuration struct
    struct BondingCurveConfig {
        /// @dev registry address
        address registry;
        /// @dev default curve id
        uint256 defaultCurveId;
    }

    /// @dev Atom configuration struct
    struct AtomConfig {
        /// @dev fee charged for purchasing vault shares for the atom wallet
        ///      upon creation
        uint256 atomWalletInitialDepositAmount;
        /// @dev fee paid to the protocol when depositing vault shares for the atom vault upon creation
        uint256 atomCreationProtocolFee;
    }

    /// @dev Triple configuration struct
    struct TripleConfig {
        /// @dev fee paid to the protocol when depositing vault shares for the triple vault upon creation
        uint256 tripleCreationProtocolFee;
        /// @dev static fee going towards increasing the amount of assets in the underlying atom vaults
        uint256 atomDepositFractionOnTripleCreation;
        /// @dev % of the Triple deposit amount that is used to purchase equity in the underlying atoms
        uint256 atomDepositFractionForTriple;
    }

    /// @dev Atom wallet configuration struct
    struct WalletConfig {
        /// @dev permit2
        IPermit2 permit2;
        /// @dev Entry Point contract address used for the erc4337 atom accounts
        address entryPoint;
        /// @dev AtomWallet Warden address, address that is the initial owner of all atom accounts
        address atomWarden;
        /// @dev AtomWalletBeacon contract address, which points to the AtomWallet implementation
        address atomWalletBeacon;
    }

    /// @notice Vault fees struct
    struct VaultFees {
        /// @dev entry fees are charged when depositing assets into the vault and they stay in the vault as assets
        ///      rather than going towards minting shares for the recipient
        ///      entry fee for vault 0 is considered the default entry fee
        uint256 entryFee;
        /// @dev exit fees are charged when redeeming shares from the vault and they stay in the vault as assets
        ///      rather than being sent to the receiver
        ///      exit fee for each vault, exit fee for vault 0 is considered the default exit fee
        uint256 exitFee;
        /// @dev protocol fees are charged both when depositing assets and redeeming shares from the vault and
        ///      they are sent to the protocol multisig address, as defined in `generalConfig.protocolMultisig`
        ///      protocol fee for each vault, protocol fee for vault 0 is considered the default protocol fee
        uint256 protocolFee;
    }

    /// @notice Timelock struct
    struct Timelock {
        /// @dev data to be executed
        bytes data;
        /// @dev block number when the operation is ready
        uint256 readyTime;
        /// @dev whether the operation has been executed or not
        bool executed;
    }

    /// @notice Vault state struct
    struct VaultState {
        uint256 totalAssets;
        uint256 totalShares;
        // address -> balanceOf, amount of shares an account has in a vault
        mapping(address account => uint256 balance) balanceOf;
    }
}
