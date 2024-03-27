// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../libraries/Types.sol";
import {IPermit2} from "./IPermit2.sol";

/// @title IVaultManager
/// @author 0xIntuition
/// @notice Interface for managing many ERC4626 style vaults in a single contract
interface IEthMultiVault {
    /* =================================================== */
    /*                       CONFIGS                       */
    /* =================================================== */

    struct GeneralConfig {
        /// @notice Admin address
        address admin;
        /// @notice Intuition Protocol multisig address
        address protocolVault;
        /// @notice Fees are calculated by amount * (fee / feeDenominator);
        uint256 feeDenominator;
        /// @notice minimum amount of assets that must be deposited into an atom/triple vault
        uint256 minDeposit;
        /// @notice number of shares minted to zero address upon vault creation to initialize the vault
        uint256 minShare;
    }

    struct AtomConfig {
        /// @notice fee charged for purchasing vault shares for the atom wallet
        ///         upon creation
        uint256 atomShareLockFee;
        /// @notice fee paid to the protocol when depositing vault shares for the atom vault upon creation
        uint256 atomCreationFee;
    }

    struct TripleConfig {
        /// @notice fee paid to the protocol when depositing vault shares for the triple vault upon creation
        uint256 tripleCreationFee;
        /// @notice % of the Triple deposit amount that is used to purchase equity in the underlying atoms
        uint256 atomEquityFeeForTriple;
    }

    struct WalletConfig {
        /// @notice permit2
        IPermit2 permit2;
        /// @notice Entry Point contract address used for the erc4337 atom accounts
        address entryPoint;
        /// @notice AtomWallet Warden address, address that is the initial owner of all atom accounts
        address atomWarden;
    }

    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /// @notice Emitted upon the minting of shares in the vault by depositing assets
    /// @param sender initializer of the deposit
    /// @param receiver beneficiary of the minted shares
    /// @param vaultBalance total assets held in the vault
    /// @param assets total assets transferred
    /// @param shares total shares transferred
    /// @param id vault id
    event Deposit(
        address indexed sender,
        address indexed receiver,
        uint256 vaultBalance,
        uint256 assets,
        uint256 shares,
        uint256 id
    );

    /// @notice Emitted upon the withdrawal of assets from the vault by redeeming shares
    /// @param sender initializer of the withdrawal
    /// @param owner owner of the shares that were redeemed
    /// @param vaultBalance total assets held in the vault
    /// @param assets quantity of assets withdrawn
    /// @param shares quantity of shares redeemed
    /// @param exitFee total fee amount collected for exiting the vault
    /// @param id vault id
    event Withdraw(
        address indexed sender,
        address indexed owner,
        uint256 vaultBalance,
        uint256 assets,
        uint256 shares,
        uint256 exitFee,
        uint256 id
    );

    /// @notice emitted upon creation of an atom
    /// @param creator address of the atom creator
    /// @param atomWallet address of the atom's associated abstract account
    /// @param atomData the atom's respective string
    /// @param vaultID the vault id of the atom
    event AtomCreated(address indexed creator, address indexed atomWallet, bytes atomData, uint256 vaultID);

    /// @notice emitted upon creation of a triple
    /// @param creator address of the triple creator
    /// @param subjectId the triple's respective subject atom
    /// @param predicateId the triple's respective predicate atom
    /// @param objectId the triple's respective object atom
    /// @param vaultID the vault id of the triple
    event TripleCreated(
        address indexed creator, uint256 subjectId, uint256 predicateId, uint256 objectId, uint256 vaultID
    );

    /// @notice return the underlying atom vault ids given a triple vault id
    /// @param id Vault ID
    function getTripleAtoms(uint256 id) external view returns (uint256, uint256, uint256);

    /// @notice mapping to designate if vault ID is a triple
    /// @param id Vault ID
    function isTriple(uint256 id) external view returns (bool);

    /// @notice return triple atom shares given triple id, atom id and account address
    /// @param id Vault ID
    /// @param atomId Id of the atom
    /// @param account Address of the account
    function tripleAtomShares(uint256 id, uint256 atomId, address account) external view returns (uint256);

    /// @notice return true for triple vaults and false for atom vaults, designate if vault ID is a triple
    /// @param id id of the vault inputted
    function assertTriple(uint256 id) external view returns (bool);

    /// @notice returns the Triple ID for the given counter triple ID
    /// @param id Counter Triple ID
    function getCounterIdFromTriple(uint256 id) external returns (uint256);

    /// @notice returns the corresponding hash for the given RDF triple, given the atoms that make up the triple
    /// @param subject the subject atom
    /// @param predicate the predicate atom
    /// @param object the object atom
    /// @return hash the corresponding hash for the given RDF triple
    function tripleHashFromAtoms(bytes memory subject, bytes memory predicate, bytes memory object)
        external
        pure
        returns (bytes32);

    //// ERC4626 SHARE/ASSET CONVERSION HELPERS

    /// @notice Amount of shares that would be exchanged with the vault for the amount of assets provided
    function convertToShares(uint256 assets, uint256 id) external view returns (uint256 shares);

    /// @notice Amount of assets that would be exchanged with the vault for the amount of shares provided
    function convertToAssets(uint256 shares, uint256 id) external view returns (uint256 assets);

    //// PREVIEW HELPER FUNCTIONS

    /// @notice Simulates the effects of depositing assets at the current block
    function previewDeposit(uint256 assets, uint256 id) external view returns (uint256 shares);

    /// @notice Simulates the effects of redeeming shares at the current block
    function previewRedeem(uint256 shares, uint256 id) external view returns (uint256 assets, uint256 exitFees);

    //// REDEEM LIMIT

    /// @notice Max amount of shares that can be redeemed from the 'owner' balance through a redeem call
    function maxRedeem(address owner, uint256 id) external view returns (uint256 shares);
}
