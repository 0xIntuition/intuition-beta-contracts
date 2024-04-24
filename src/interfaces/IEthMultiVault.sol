// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IPermit2} from "./IPermit2.sol";

/// @title IVaultManager
/// @notice Interface for managing many ERC4626 style vaults in a single contract
interface IEthMultiVault {
    /* =================================================== */
    /*                   CONFIGS STRUCTS                   */
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
        /// @notice maximum length of the atom URI data that can be passed when creating atom vaults
        uint256 atomUriMaxLength;
        /// @notice decimal precision used for calculating share prices
        uint256 decimalPrecision;
        /// @notice minimum delay for timelocked transactions
        uint256 minDelay;
    }

    struct AtomConfig {
        /// @notice fee charged for purchasing vault shares for the atom wallet
        ///         upon creation
        uint256 atomWalletInitialDepositAmount;
        /// @notice fee paid to the protocol when depositing vault shares for the atom vault upon creation
        uint256 atomCreationProtocolFee;
    }

    struct TripleConfig {
        /// @notice fee paid to the protocol when depositing vault shares for the triple vault upon creation
        uint256 tripleCreationProtocolFee;
        /// @notice % of the Triple deposit amount that is used to purchase equity in the underlying atoms
        uint256 atomDepositFractionForTriple;
    }

    struct WalletConfig {
        /// @notice permit2
        IPermit2 permit2;
        /// @notice Entry Point contract address used for the erc4337 atom accounts
        address entryPoint;
        /// @notice AtomWallet Warden address, address that is the initial owner of all atom accounts
        address atomWarden;
        /// @notice AtomWalletBeacon contract address, which points to the AtomWallet implementation
        address atomWalletBeacon;
    }

    /* =================================================== */
    /*                    OTHER STRUCTS                    */
    /* =================================================== */

    struct VaultState {
        uint256 totalAssets;
        uint256 totalShares;
        // address -> balanceOf, amount of shares an account has in a vault
        mapping(address => uint256) balanceOf;
    }

    struct VaultFees {
        // entry fees are charged when depositing assets into the vault and they stay in the vault as assets
        // rather than going towards minting shares for the recipient
        // entry fee for vault 0 is considered the default entry fee
        uint256 entryFee;
        // exit fees are charged when redeeming shares from the vault and they stay in the vault as assets
        // rather than being sent to the receiver
        // exit fee for each vault, exit fee for vault 0 is considered the default exit fee
        uint256 exitFee;
        // protocol fees are charged both when depositing assets and redeeming shares from the vault and
        // they are sent to the protocol vault address, as defined in `generalConfig.protocolVault`
        // protocol fee for each vault, protocol fee for vault 0 is considered the default protocol fee
        uint256 protocolFee;
    }

    /// @notice Timelock struct
    struct Timelock {
        bytes data;
        uint256 readyTime;
        bool executed;
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
    event Deposited(
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
    event Redeemed(
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

    /// @notice emitted upon the transfer of fees to the protocol vault
    /// @param sender address of the sender
    /// @param protocolVault address of the protocol vault
    /// @param amount amount of fees transferred
    event FeesTransferred(address indexed sender, address indexed protocolVault, uint256 amount);

    /* =================================================== */
    /*                       FUNCTIONS                     */
    /* =================================================== */

    /// @notice returns the cost of creating an atom
    /// @return atomCost the cost of creating an atom
    function getAtomCost() external view returns (uint256);

    /// @notice returns the cost of creating a triple
    /// @return tripleCost the cost of creating a triple
    function getTripleCost() external view returns (uint256);

    /// @notice returns the total fees that would be charged for depositing 'assets' into a vault
    /// @param assets amount of `assets` to calculate fees on
    /// @param id vault id to get corresponding fees for
    /// @return totalFees total fees that would be charged for depositing 'assets' into a vault
    function getDepositFees(uint256 assets, uint256 id) external view returns (uint256);

    /// @param assets amount of `assets` to calculate fees on (should always be msg.value - protocolFees)
    /// @param id vault id to get corresponding fees for
    /// @return netUserAssets net assets that go towards minting shares for the user
    /// @return totalAssetsDelta changes in vault's total assets
    /// @return sharesForReceiver shares owed to receiver
    function getDepositValues(uint256 assets, uint256 id) external view returns (uint256, uint256, uint256);

    /// @notice returns the assets that would be returned to the receiver of the redeem and protocol fees
    /// @param shares amount of `shares` to calculate fees on
    /// @param id vault id to get corresponding fees for
    /// @return totalUserAssets total amount of assets user would receive if redeeming 'shares', not including fees
    /// @return redeemableAssets amount of assets that is redeemable by the receiver
    /// @return protocolFees amount of assets that would be sent to the protocol vault
    /// @return exitFees amount of assets that would be charged for the exit fee
    function getRedeemValues(uint256 shares, uint256 id) external view returns (uint256, uint256, uint256, uint256);

    /// @notice returns amount of assets that would be charged for the entry fee given an amount of 'assets' provided
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    /// @return feeAmount amount of assets that would be charged for the entry fee
    /// NOTE: if the vault being deposited on has a vault total shares of 0, the entry fee is not applied
    function entryFeeAmount(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice returns amount of assets that would be charged for the exit fee given an amount of 'assets' provided
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    /// @return feeAmount amount of assets that would be charged for the exit fee
    /// NOTE: if the vault  being redeemed from given the shares to redeem results in a total shares after of 0,
    ///       the exit fee is not applied
    function exitFeeAmount(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice returns amount of assets that would be charged by a vault on protocol fee given amount of 'assets'
    ///         provided
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    /// @return feeAmount amount of assets that would be charged by vault on protocol fee
    function protocolFeeAmount(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice returns atom deposit fraction given amount of 'assets' provided
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id
    /// @return feeAmount amount of assets that would be used as atom deposit fraction
    /// NOTE: only applies to triple vaults
    function atomDepositFractionAmount(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice Amount of shares that would be exchanged with the vault for the amount of assets provided
    function convertToShares(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice Amount of assets that would be exchanged with the vault for the amount of shares provided
    function convertToAssets(uint256 shares, uint256 id) external view returns (uint256);

    /// @notice returns the current share price for the given vault id
    /// @param id vault id to get corresponding share price for
    /// @return price current share price for the given vault id
    function currentSharePrice(uint256 id) external view returns (uint256);

    /// @notice Simulates the effects of depositing assets at the current block
    function previewDeposit(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice Simulates the effects of redeeming shares at the current block
    function previewRedeem(uint256 shares, uint256 id) external view returns (uint256);

    /// @notice Max amount of shares that can be redeemed from the 'owner' balance through a redeem call
    function maxRedeem(address owner, uint256 id) external view returns (uint256);

    /// @notice returns the corresponding hash for the given RDF triple, given the atoms that make up the triple
    /// @param subjectId the subject atom's vault id
    /// @param predicateId the predicate atom's vault id
    /// @param objectId the object atom's vault id
    /// @return hash the corresponding hash for the given RDF triple based on the atom vault ids
    function tripleHashFromAtoms(uint256 subjectId, uint256 predicateId, uint256 objectId)
        external
        pure
        returns (bytes32);

    /// @notice returns the corresponding hash for the given RDF triple, given the triple vault id
    /// @param id vault id of the triple
    /// @return hash the corresponding hash for the given RDF triple
    /// NOTE: only applies to triple vault IDs as input
    function tripleHash(uint256 id) external view returns (bytes32);

    /// @notice return true for triple vaults and false for atom vaults, designate if vault ID is a triple
    /// @param id id of the vault inputted
    function isTripleId(uint256 id) external view returns (bool);

    /// @notice return the underlying atom vault ids given a triple vault id
    /// @param id Vault ID
    function getTripleAtoms(uint256 id) external view returns (uint256, uint256, uint256);

    /// @notice returns the Triple ID for the given counter triple ID
    /// @param id Counter Triple ID
    function getCounterIdFromTriple(uint256 id) external returns (uint256);

    /// @notice mapping to designate if vault ID is a triple
    /// @param id Vault ID
    function isTriple(uint256 id) external view returns (bool);

    /// @notice return triple atom shares given triple id, atom id and account address
    /// @param id Vault ID
    /// @param atomId Id of the atom
    /// @param account Address of the account
    function tripleAtomShares(uint256 id, uint256 atomId, address account) external view returns (uint256);

    /// @notice returns the number of shares user has in the vault
    /// @param vaultId vault id of the vault
    /// @param receiver address of the receiver
    /// @return balance number of shares user has in the vault
    function getVaultBalance(uint256 vaultId, address receiver) external view returns (uint256);

    /// @notice returns the number of shares and assets (less fees) user has in the vault
    /// @param vaultId vault id of the vault
    /// @param receiver address of the receiver
    /// @return shares number of shares user has in the vault
    /// @return assets number of assets user has in the vault
    function getVaultStateForUser(uint256 vaultId, address receiver) external view returns (uint256, uint256);

    /// @notice returns the Atom Wallet address for the given atom data
    /// @param id vault id of the atom associated to the atom wallet
    /// @return atomWallet the address of the atom wallet
    /// NOTE: the create2 salt is based off of the vault ID
    function computeAtomWalletAddr(uint256 id) external view returns (address);

    /// @notice deploy a given atom wallet
    /// @param atomId vault id of atom
    /// @return atomWallet the address of the atom wallet
    /// NOTE: deploys an ERC4337 account (atom wallet) through a BeaconProxy. Reverts if the atom vault does not exist
    function deployAtomWallet(uint256 atomId) external returns (address);

    /// @notice Initializes the MultiVault contract
    /// @param _generalConfig General configuration struct
    /// @param _atomConfig Atom configuration struct
    /// @param _tripleConfig Triple configuration struct
    /// @param _walletConfig Wallet configuration struct
    /// @param _defaultVaultFees Default vault fees struct
    /// @dev This function is called only once (during contract deployment)
    function init(
        GeneralConfig memory _generalConfig,
        AtomConfig memory _atomConfig,
        TripleConfig memory _tripleConfig,
        WalletConfig memory _walletConfig,
        VaultFees memory _defaultVaultFees
    ) external;

    /// @notice Create an atom and return its vault id
    /// @param atomUri atom data to create atom with
    /// @return id vault id of the atom
    /// NOTE: This function will revert if called with less than `getAtomCost()` in `msg.value`
    function createAtom(bytes calldata atomUri) external payable returns (uint256);

    /// @notice Batch create atoms and return their vault ids
    /// @param atomUris atom data array to create atoms with
    /// @return ids vault ids array of the atoms
    /// NOTE: This function will revert if called with less than `getAtomCost()` * `atomUris.length` in `msg.value`
    function batchCreateAtom(bytes[] calldata atomUris) external payable returns (uint256[] memory);

    /// @notice create a triple and return its vault id
    /// @param subjectId vault id of the subject atom
    /// @param predicateId vault id of the predicate atom
    /// @param objectId vault id of the object atom
    /// @return id vault id of the triple
    /// NOTE: This function will revert if called with less than `getTripleCost()` in `msg.value`.
    ///       This function will revert if any of the atoms do not exist or if any ids are triple vaults.
    function createTriple(uint256 subjectId, uint256 predicateId, uint256 objectId)
        external
        payable
        returns (uint256);

    /// @notice batch create triples and return their vault ids
    /// @param subjectIds vault ids array of subject atoms
    /// @param predicateIds vault ids array of predicate atoms
    /// @param objectIds vault ids array of object atoms
    /// NOTE: This function will revert if called with less than `getTripleCost()` * `array.length` in `msg.value`.
    ///       This function will revert if any of the atoms do not exist or if any ids are triple vaults.
    function batchCreateTriple(
        uint256[] calldata subjectIds,
        uint256[] calldata predicateIds,
        uint256[] calldata objectIds
    ) external payable returns (uint256[] memory);

    /// @notice deposit eth into an atom vault and grant ownership of 'shares' to 'reciever'
    /// *payable msg.value amount of eth to deposit
    /// @dev assets parameter is omitted in favor of msg.value, unlike in ERC4626
    /// @param receiver the address to receive the shares
    /// @param id the vault ID of the atom
    /// @return shares the amount of shares minted
    /// NOTE: this function will revert if the minimum deposit amount of eth is not met and
    ///       if the vault ID does not exist/is not an atom.
    function depositAtom(address receiver, uint256 id) external payable returns (uint256);

    /// @notice redeem assets from an atom vault
    /// @param shares the amount of shares to redeem
    /// @param receiver the address to receiver the assets
    /// @param id the vault ID of the atom
    /// @return assets the amount of assets/eth withdrawn
    function redeemAtom(uint256 shares, address receiver, uint256 id) external returns (uint256);

    /// @notice deposits assets of underlying tokens into a triple vault and grants ownership of 'shares' to 'reciever'
    /// *payable msg.value amount of eth to deposit
    /// @dev assets parameter is omitted in favor of msg.value, unlike in ERC4626
    /// @param receiver the address to receive the shares
    /// @param id the vault ID of the triple
    /// @return shares the amount of shares minted
    /// NOTE: this function will revert if the minimum deposit amount of eth is not met and
    ///       if the vault ID does not exist/is not a triple.
    function depositTriple(address receiver, uint256 id) external payable returns (uint256);

    /// @notice redeems 'shares' number of shares from the triple vault and send 'assets' eth
    ///         from the multiVault to 'reciever' factoring in exit fees
    /// @param shares the amount of shares to redeem
    /// @param receiver the address to receiver the assets
    /// @param id the vault ID of the triple
    /// @return assets the amount of assets/eth withdrawn
    function redeemTriple(uint256 shares, address receiver, uint256 id) external returns (uint256);

    /// @dev pause the pausable contract methods
    function pause() external;

    /// @dev unpause the pausable contract methods
    function unpause() external;

    /// @dev schedule an operation to be executed after a delay
    /// @param operationId unique identifier for the operation
    /// @param data data to be executed
    function scheduleOperation(bytes32 operationId, bytes calldata data) external;

    /// @dev execute a scheduled operation
    /// @param operationId unique identifier for the operation
    /// @param data data to be executed
    function cancelOperation(bytes32 operationId, bytes calldata data) external;

    /// @dev set admin
    /// @param admin address of the new admin
    function setAdmin(address admin) external;

    /// @dev set protocol vault
    /// @param protocolVault address of the new protocol vault
    function setProtocolVault(address protocolVault) external;

    /// @dev sets the minimum deposit amount for atoms and triples
    /// @param minDeposit new minimum deposit amount
    function setMinDeposit(uint256 minDeposit) external;

    /// @dev sets the minimum share amount for atoms and triples
    /// @param minShare new minimum share amount
    function setMinShare(uint256 minShare) external;

    /// @dev sets the atom URI max length
    /// @param atomUriMaxLength new atom URI max length
    function setAtomUriMaxLength(uint256 atomUriMaxLength) external;

    /// @dev sets the atom share lock fee
    /// @param atomWalletInitialDepositAmount new atom share lock fee
    function setAtomWalletInitialDepositAmount(uint256 atomWalletInitialDepositAmount) external;

    /// @dev sets the atom creation fee
    /// @param atomCreationProtocolFee new atom creation fee
    function setAtomCreationProtocolFee(uint256 atomCreationProtocolFee) external;

    /// @dev sets fee charged in wei when creating a triple to protocol vault
    /// @param tripleCreationProtocolFee new fee in wei
    function setTripleCreationProtocolFee(uint256 tripleCreationProtocolFee) external;

    /// @dev sets the atom deposit fraction percentage for atoms used in triples
    ///      (number to be divided by `generalConfig.feeDenominator`)
    /// @param atomDepositFractionForTriple new atom deposit fraction percentage
    function setAtomDepositFractionForTriple(uint256 atomDepositFractionForTriple) external;

    /// @dev sets entry fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default entry fee, id = n changes fees for vault n specifically
    /// @dev entry fee cannot be set greater than `generalConfig.feeDenominator` (which represents 100%)
    /// @param id vault id to set entry fee for
    /// @param entryFee entry fee to set
    function setEntryFee(uint256 id, uint256 entryFee) external;

    /// @dev sets exit fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default exit fee, id = n changes fees for vault n specifically
    /// @dev admin cannot set the exit fee to be greater than `maxExitFeePercentage`, which is
    ///      set to be the 10% of `generalConfig.feeDenominator` (which represents 100%), to avoid
    ///      being able to prevent users from withdrawing their assets
    /// @param id vault id to set exit fee for
    /// @param exitFee exit fee to set
    function setExitFee(uint256 id, uint256 exitFee) external;

    /// @dev sets protocol fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default protocol fee, id = n changes fees for vault n specifically
    /// @dev protocol fee cannot be set greater than `generalConfig.feeDenominator` (which represents 100%)
    /// @param id vault id to set protocol fee for
    /// @param protocolFee protocol fee to set
    function setProtocolFee(uint256 id, uint256 protocolFee) external;
}
