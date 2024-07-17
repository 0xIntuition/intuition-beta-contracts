// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {IPermit2} from "src/interfaces/IPermit2.sol";

/// @title IEthMultiVault
/// @author 0xIntuition
/// @notice Interface for managing many ERC4626 style vaults in a single contract
interface IEthMultiVault {
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

    /* =================================================== */
    /*                    OTHER STRUCTS                    */
    /* =================================================== */

    /// @notice Vault state struct
    struct VaultState {
        uint256 totalAssets;
        uint256 totalShares;
        // address -> balanceOf, amount of shares an account has in a vault
        mapping(address account => uint256 balance) balanceOf;
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

    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /// @notice Emitted when a receiver approves a sender to deposit assets on their behalf
    ///
    /// @param sender address of the sender
    /// @param receiver address of the receiver
    /// @param approved whether the sender is approved or not
    event SenderApproved(address indexed sender, address indexed receiver, bool approved);

    /// @notice Emitted when a receiver revokes a sender's approval to deposit assets on their behalf
    ///
    /// @param sender address of the sender
    /// @param receiver address of the receiver
    /// @param approved whether the sender is approved or not
    event SenderRevoked(address indexed sender, address indexed receiver, bool approved);

    /// @notice Emitted upon the minting of shares in the vault by depositing assets
    ///
    /// @param sender initializer of the deposit
    /// @param receiver beneficiary of the minted shares
    /// @param receiverTotalSharesInVault total shares held by the receiver in the vault
    /// @param senderAssetsAfterTotalFees total assets that go towards minting shares for the receiver
    /// @param sharesForReceiver total shares minted for the receiver
    /// @param entryFee total fee amount collected for entering the vault
    /// @param vaultId vault id of the vault being deposited into
    /// @param isTriple whether the vault is a triple vault or not
    /// @param isAtomWallet whether the receiver is an atom wallet or not
    event Deposited(
        address indexed sender,
        address indexed receiver,
        uint256 receiverTotalSharesInVault,
        uint256 senderAssetsAfterTotalFees,
        uint256 sharesForReceiver,
        uint256 entryFee,
        uint256 vaultId,
        bool isTriple,
        bool isAtomWallet
    );

    /// @notice Emitted upon the withdrawal of assets from the vault by redeeming shares
    ///
    /// @param sender initializer of the withdrawal (owner of the shares)
    /// @param receiver beneficiary of the withdrawn assets (can be different from the sender)
    /// @param senderTotalSharesInVault total shares held by the sender in the vault
    /// @param assetsForReceiver quantity of assets withdrawn by the receiver
    /// @param sharesRedeemedBySender quantity of shares redeemed by the sender
    /// @param exitFee total fee amount collected for exiting the vault
    /// @param vaultId vault id of the vault being redeemed from
    event Redeemed(
        address indexed sender,
        address indexed receiver,
        uint256 senderTotalSharesInVault,
        uint256 assetsForReceiver,
        uint256 sharesRedeemedBySender,
        uint256 exitFee,
        uint256 vaultId
    );

    /// @notice emitted upon creation of an atom
    ///
    /// @param creator address of the atom creator
    /// @param atomWallet address of the atom's associated abstract account
    /// @param atomData the atom's respective string
    /// @param vaultID the vault id of the atom
    event AtomCreated(address indexed creator, address indexed atomWallet, bytes atomData, uint256 vaultID);

    /// @notice emitted upon creation of a triple
    ///
    /// @param creator address of the triple creator
    /// @param subjectId the triple's respective subject atom
    /// @param predicateId the triple's respective predicate atom
    /// @param objectId the triple's respective object atom
    /// @param vaultID the vault id of the triple
    event TripleCreated(
        address indexed creator, uint256 subjectId, uint256 predicateId, uint256 objectId, uint256 vaultID
    );

    /// @notice emitted upon the transfer of fees to the protocol multisig
    ///
    /// @param sender address of the sender
    /// @param protocolMultisig address of the protocol multisig
    /// @param amount amount of fees transferred
    event FeesTransferred(address indexed sender, address indexed protocolMultisig, uint256 amount);

    /// @notice emitted upon scheduling an operation
    ///
    /// @param operationId unique identifier for the operation
    /// @param data data to be executed
    /// @param readyTime block number when the operation is ready
    event OperationScheduled(bytes32 indexed operationId, bytes data, uint256 readyTime);

    /// @notice emitted upon cancelling an operation
    ///
    /// @param operationId unique identifier for the operation
    /// @param data data of the operation that was cancelled
    event OperationCancelled(bytes32 indexed operationId, bytes data);

    /// @notice emitted upon changing the admin
    ///
    /// @param newAdmin address of the new admin
    /// @param oldAdmin address of the old admin
    event AdminSet(address indexed newAdmin, address indexed oldAdmin);

    /// @notice emitted upon changing the protocol multisig
    ///
    /// @param newProtocolMultisig address of the new protocol multisig
    /// @param oldProtocolMultisig address of the old protocol multisig
    event protocolMultisigSet(address indexed newProtocolMultisig, address indexed oldProtocolMultisig);

    /// @notice emitted upon changing the minimum deposit amount
    ///
    /// @param newMinDeposit new minimum deposit amount
    /// @param oldMinDeposit old minimum deposit amount
    event MinDepositSet(uint256 newMinDeposit, uint256 oldMinDeposit);

    /// @notice emitted upon changing the minimum share amount
    ///
    /// @param newMinShare new minimum share amount
    /// @param oldMinShare old minimum share amount
    event MinShareSet(uint256 newMinShare, uint256 oldMinShare);

    /// @notice emitted upon changing the atom URI max length
    ///
    /// @param newAtomUriMaxLength new atom URI max length
    /// @param oldAtomUriMaxLength old atom URI max length
    event AtomUriMaxLengthSet(uint256 newAtomUriMaxLength, uint256 oldAtomUriMaxLength);

    /// @notice emitted upon changing the atom share lock fee
    ///
    /// @param newAtomWalletInitialDepositAmount new atom share lock fee
    /// @param oldAtomWalletInitialDepositAmount old atom share lock fee
    event AtomWalletInitialDepositAmountSet(
        uint256 newAtomWalletInitialDepositAmount, uint256 oldAtomWalletInitialDepositAmount
    );

    /// @notice emitted upon changing the atom creation fee
    ///
    /// @param newAtomCreationProtocolFee new atom creation fee
    /// @param oldAtomCreationProtocolFee old atom creation fee
    event AtomCreationProtocolFeeSet(uint256 newAtomCreationProtocolFee, uint256 oldAtomCreationProtocolFee);

    /// @notice emitted upon changing the triple creation fee
    ///
    /// @param newTripleCreationProtocolFee new triple creation fee
    /// @param oldTripleCreationProtocolFee old triple creation fee
    event TripleCreationProtocolFeeSet(uint256 newTripleCreationProtocolFee, uint256 oldTripleCreationProtocolFee);

    /// @notice emitted upon changing the atom deposit fraction on triple creation
    ///
    /// @param newAtomDepositFractionOnTripleCreation new atom deposit fraction on triple creation
    /// @param oldAtomDepositFractionOnTripleCreation old atom deposit fraction on triple creation
    event AtomDepositFractionOnTripleCreationSet(
        uint256 newAtomDepositFractionOnTripleCreation, uint256 oldAtomDepositFractionOnTripleCreation
    );

    /// @notice emitted upon changing the atom deposit fraction for triples
    ///
    /// @param newAtomDepositFractionForTriple new atom deposit fraction for triples
    /// @param oldAtomDepositFractionForTriple old atom deposit fraction for triples
    event AtomDepositFractionForTripleSet(
        uint256 newAtomDepositFractionForTriple, uint256 oldAtomDepositFractionForTriple
    );

    /// @notice emitted upon changing the entry fee
    ///
    /// @param id vault id to set entry fee for
    /// @param newEntryFee new entry fee for the vault
    /// @param oldEntryFee old entry fee for the vault
    event EntryFeeSet(uint256 id, uint256 newEntryFee, uint256 oldEntryFee);

    /// @notice emitted upon changing the exit fee
    ///
    /// @param id vault id to set exit fee for
    /// @param newExitFee new exit fee for the vault
    /// @param oldExitFee old exit fee for the vault
    event ExitFeeSet(uint256 id, uint256 newExitFee, uint256 oldExitFee);

    /// @notice emitted upon changing the protocol fee
    ///
    /// @param id vault id to set protocol fee for
    /// @param newProtocolFee new protocol fee for the vault
    /// @param oldProtocolFee old protocol fee for the vault
    event ProtocolFeeSet(uint256 id, uint256 newProtocolFee, uint256 oldProtocolFee);

    /// @notice emitted upon changing the atomWarden
    ///
    /// @param newAtomWarden address of the new atomWarden
    /// @param oldAtomWarden address of the old atomWarden
    event AtomWardenSet(address indexed newAtomWarden, address indexed oldAtomWarden);

    /// @notice emitted upon deploying an atom wallet
    ///
    /// @param vaultId vault id of the atom
    /// @param atomWallet address of the atom wallet
    event AtomWalletDeployed(uint256 indexed vaultId, address indexed atomWallet);

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    /// @notice Initializes the EthMultiVault contract
    ///
    /// @param _generalConfig General configuration struct
    /// @param _atomConfig Atom configuration struct
    /// @param _tripleConfig Triple configuration struct
    /// @param _walletConfig Wallet configuration struct
    /// @param _defaultVaultFees Default vault fees struct
    ///
    /// NOTE: This function is called only once (during contract deployment)
    function init(
        GeneralConfig memory _generalConfig,
        AtomConfig memory _atomConfig,
        TripleConfig memory _tripleConfig,
        WalletConfig memory _walletConfig,
        VaultFees memory _defaultVaultFees
    ) external;

    /* =================================================== */
    /*               RESTRICTED FUNCTIONS                  */
    /* =================================================== */

    /// @dev pauses the pausable contract methods
    function pause() external;

    /// @dev unpauses the pausable contract methods
    function unpause() external;

    /// @dev schedule an operation to be executed after a delay
    ///
    /// @param operationId unique identifier for the operation
    /// @param data data to be executed
    function scheduleOperation(bytes32 operationId, bytes calldata data) external;

    /// @dev execute a scheduled operation
    ///
    /// @param operationId unique identifier for the operation
    /// @param data data to be executed
    function cancelOperation(bytes32 operationId, bytes calldata data) external;

    /// @dev set admin
    /// @param admin address of the new admin
    function setAdmin(address admin) external;

    /// @dev set protocol multisig
    /// @param protocolMultisig address of the new protocol multisig
    function setProtocolMultisig(address protocolMultisig) external;

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

    /// @dev sets fee charged in wei when creating a triple to protocol multisig
    /// @param tripleCreationProtocolFee new fee in wei
    function setTripleCreationProtocolFee(uint256 tripleCreationProtocolFee) external;

    /// @dev sets the atom deposit fraction on triple creation used to increase the amount of assets
    ///      in the underlying atom vaults on triple creation
    /// @param atomDepositFractionOnTripleCreation new atom deposit fraction on triple creation
    function setAtomDepositFractionOnTripleCreation(uint256 atomDepositFractionOnTripleCreation) external;

    /// @dev sets the atom deposit fraction percentage for atoms used in triples
    ///      (number to be divided by `generalConfig.feeDenominator`)
    /// @param atomDepositFractionForTriple new atom deposit fraction percentage
    function setAtomDepositFractionForTriple(uint256 atomDepositFractionForTriple) external;

    /// @dev sets entry fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default entry fee, id = n changes fees for vault n specifically
    /// @dev admin cannot set the entry fee to be greater than `maxEntryFeePercentage`, which is
    ///      set to be the 10% of `generalConfig.feeDenominator` (which represents 100%), to avoid
    ///      being able to prevent users from depositing assets with unreasonable fees
    ///
    /// @param id vault id to set entry fee for
    /// @param entryFee entry fee to set
    function setEntryFee(uint256 id, uint256 entryFee) external;

    /// @dev sets exit fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default exit fee, id = n changes fees for vault n specifically
    /// @dev admin cannot set the exit fee to be greater than `maxExitFeePercentage`, which is
    ///      set to be the 10% of `generalConfig.feeDenominator` (which represents 100%), to avoid
    ///      being able to prevent users from withdrawing their assets
    ///
    /// @param id vault id to set exit fee for
    /// @param exitFee exit fee to set
    function setExitFee(uint256 id, uint256 exitFee) external;

    /// @dev sets protocol fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default protocol fee, id = n changes fees for vault n specifically
    /// @dev admin cannot set the protocol fee to be greater than `maxProtocolFeePercentage`, which is
    ///      set to be the 10% of `generalConfig.feeDenominator` (which represents 100%), to avoid
    ///      being able to prevent users from depositing or withdrawing their assets with unreasonable fees
    ///
    /// @param id vault id to set protocol fee for
    /// @param protocolFee protocol fee to set
    function setProtocolFee(uint256 id, uint256 protocolFee) external;

    /// @dev sets the atomWarden address
    /// @param atomWarden address of the new atomWarden
    function setAtomWarden(address atomWarden) external;

    /* =================================================== */
    /*                MUTATIVE FUNCTIONS                   */
    /* =================================================== */

    /// @notice deploy a given atom wallet
    /// @param atomId vault id of atom
    /// @return atomWallet the address of the atom wallet
    /// NOTE: deploys an ERC4337 account (atom wallet) through a BeaconProxy. Reverts if the atom vault does not exist
    function deployAtomWallet(uint256 atomId) external returns (address);

    /// @notice approve a sender to deposit assets on behalf of the receiver
    /// @param sender address of the sender
    function approveSender(address sender) external;

    /// @notice revoke a sender's approval to deposit assets on behalf of the receiver
    /// @param sender address of the sender
    function revokeSender(address sender) external;

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
    ///
    /// @param subjectId vault id of the subject atom
    /// @param predicateId vault id of the predicate atom
    /// @param objectId vault id of the object atom
    ///
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
    ///         *payable msg.value amount of eth to deposit
    /// @dev assets parameter is omitted in favor of msg.value, unlike in ERC4626
    ///
    /// @param receiver the address to receive the shares
    /// @param id the vault ID of the atom
    ///
    /// @return shares the amount of shares minted
    /// NOTE: this function will revert if the minimum deposit amount of eth is not met and
    ///       if the vault ID does not exist/is not an atom.
    function depositAtom(address receiver, uint256 id) external payable returns (uint256);

    /// @notice redeem assets from an atom vault
    ///
    /// @param shares the amount of shares to redeem
    /// @param receiver the address to receiver the assets
    /// @param id the vault ID of the atom
    ///
    /// @return assets the amount of assets/eth withdrawn
    /// NOTE: Emergency redemptions without any fees being charged are always possible, even if the contract is paused
    ///       See `getRedeemAssetsAndFees` for more details on the fees charged
    function redeemAtom(uint256 shares, address receiver, uint256 id) external returns (uint256);

    /// @notice deposits assets of underlying tokens into a triple vault and grants ownership of 'shares' to 'receiver'
    ///         *payable msg.value amount of eth to deposit
    /// @dev assets parameter is omitted in favor of msg.value, unlike in ERC4626
    ///
    /// @param receiver the address to receive the shares
    /// @param id the vault ID of the triple
    ///
    /// @return shares the amount of shares minted
    /// NOTE: this function will revert if the minimum deposit amount of eth is not met and
    ///       if the vault ID does not exist/is not a triple.
    function depositTriple(address receiver, uint256 id) external payable returns (uint256);

    /// @notice redeems 'shares' number of shares from the triple vault and send 'assets' eth
    ///         from the contract to 'reciever' factoring in exit fees
    ///
    /// @param shares the amount of shares to redeem
    /// @param receiver the address to receiver the assets
    /// @param id the vault ID of the triple
    ///
    /// @return assets the amount of assets/eth withdrawn
    /// NOTE: Emergency redemptions without any fees being charged are always possible, even if the contract is paused
    ///       See `getRedeemAssetsAndFees` for more details on the fees charged
    function redeemTriple(uint256 shares, address receiver, uint256 id) external returns (uint256);

    /* =================================================== */
    /*                    VIEW FUNCTIONS                   */
    /* =================================================== */

    /// @notice returns the cost of creating an atom
    /// @return atomCost the cost of creating an atom
    function getAtomCost() external view returns (uint256);

    /// @notice returns the cost of creating a triple
    /// @return tripleCost the cost of creating a triple
    function getTripleCost() external view returns (uint256);

    /// @notice returns the total fees that would be charged for depositing 'assets' into a vault
    ///
    /// @param assets amount of `assets` to calculate fees on
    /// @param id vault id to get corresponding fees for
    ///
    /// @return totalFees total fees that would be charged for depositing 'assets' into a vault
    function getDepositFees(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice returns the shares for recipient and other important values when depositing 'assets' into a vault
    ///
    /// @param assets amount of `assets` to calculate fees on (should always be msg.value - protocolFee)
    /// @param id vault id to get corresponding fees for
    ///
    /// @return totalAssetsDelta changes in vault's total assets
    /// @return sharesForReceiver changes in vault's total shares (shares owed to receiver)
    /// @return userAssetsAfterTotalFees amount of assets that goes towards minting shares for the receiver
    /// @return entryFee amount of assets that would be charged for the entry fee
    function getDepositSharesAndFees(uint256 assets, uint256 id)
        external
        view
        returns (uint256, uint256, uint256, uint256);

    /// @notice returns the assets for receiver and other important values when redeeming 'shares' from a vault
    ///
    /// @param shares amount of `shares` to calculate fees on
    /// @param id vault id to get corresponding fees for
    ///
    /// @return totalUserAssets total amount of assets user would receive if redeeming 'shares', not including fees
    /// @return assetsForReceiver amount of assets that is redeemable by the receiver
    /// @return protocolFee amount of assets that would be sent to the protocol multisig
    /// @return exitFee amount of assets that would be charged for the exit fee
    function getRedeemAssetsAndFees(uint256 shares, uint256 id)
        external
        view
        returns (uint256, uint256, uint256, uint256);

    /// @notice returns amount of assets that would be charged for the entry fee given an amount of 'assets' provided
    ///
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    ///
    /// @return feeAmount amount of assets that would be charged for the entry fee
    /// NOTE: if the vault being deposited on has a vault total shares of 0, the entry fee is not applied
    function entryFeeAmount(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice returns amount of assets that would be charged for the exit fee given an amount of 'assets' provided
    ///
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    ///
    /// @return feeAmount amount of assets that would be charged for the exit fee
    /// NOTE: if the vault  being redeemed from given the shares to redeem results in a total shares after of 0,
    ///       the exit fee is not applied
    function exitFeeAmount(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice returns amount of assets that would be charged by a vault on protocol fee given amount of 'assets'
    ///         provided
    ///
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    ///
    /// @return feeAmount amount of assets that would be charged by vault on protocol fee
    function protocolFeeAmount(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice returns atom deposit fraction given amount of 'assets' provided
    ///
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id
    ///
    /// @return feeAmount amount of assets that would be used as atom deposit fraction
    /// NOTE: only applies to triple vaults
    function atomDepositFractionAmount(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice returns the current share price for the given vault id
    /// @param id vault id to get corresponding share price for
    /// @return price current share price for the given vault id
    function currentSharePrice(uint256 id) external view returns (uint256);

    /// @notice returns max amount of shares that can be redeemed from the 'owner' balance through a redeem call
    ///
    /// @param owner address of the account to get max redeemable shares for
    /// @param id vault id to get corresponding shares for
    ///
    /// @return shares amount of shares that can be redeemed from the 'owner' balance through a redeem call
    function maxRedeem(address owner, uint256 id) external view returns (uint256);

    /// @notice returns amount of shares that would be exchanged by vault given amount of 'assets' provided
    ///
    /// @param assets amount of assets to calculate shares on
    /// @param id vault id to get corresponding shares for
    ///
    /// @return shares amount of shares that would be exchanged by vault given amount of 'assets' provided
    function convertToShares(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice returns amount of assets that would be exchanged by vault given amount of 'shares' provided
    ///
    /// @param shares amount of shares to calculate assets on
    /// @param id vault id to get corresponding assets for
    ///
    /// @return assets amount of assets that would be exchanged by vault given amount of 'shares' provided
    function convertToAssets(uint256 shares, uint256 id) external view returns (uint256);

    /// @notice simulates the effects of the deposited amount of 'assets' and returns the estimated
    ///         amount of shares that would be minted from the deposit of `assets`
    ///
    /// @param assets amount of assets to calculate shares on
    /// @param id vault id to get corresponding shares for
    ///
    /// @return shares amount of shares that would be minted from the deposit of `assets`
    /// NOTE: this function pessimistically estimates the amount of shares that would be minted from the
    ///       input amount of assets so if the vault is empty before the deposit the caller receives more
    ///       shares than returned by this function, reference internal _depositIntoVault logic for details
    function previewDeposit(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice simulates the effects of the redemption of `shares` and returns the estimated
    ///         amount of assets estimated to be returned to the receiver of the redeem
    ///
    /// @param shares amount of shares to calculate assets on
    /// @param id vault id to get corresponding assets for
    ///
    /// @return assets amount of assets estimated to be returned to the receiver
    function previewRedeem(uint256 shares, uint256 id) external view returns (uint256);

    /// @notice returns the corresponding hash for the given RDF triple, given the triple vault id
    /// @param id vault id of the triple
    /// @return hash the corresponding hash for the given RDF triple
    /// NOTE: only applies to triple vault IDs as input
    function tripleHash(uint256 id) external view returns (bytes32);

    /// @notice returns whether the supplied vault id is a triple
    /// @param id vault id to check
    /// @return bool whether the supplied vault id is a triple
    function isTripleId(uint256 id) external view returns (bool);

    /// @notice returns the atoms that make up a triple/counter-triple
    /// @param id vault id of the triple/counter-triple
    /// @return tuple(atomIds) the atoms that make up the triple/counter-triple
    /// NOTE: only applies to triple vault IDs as input
    function getTripleAtoms(uint256 id) external view returns (uint256, uint256, uint256);

    /// @notice returns the corresponding hash for the given RDF triple, given the atoms that make up the triple
    ///
    /// @param subjectId the subject atom's vault id
    /// @param predicateId the predicate atom's vault id
    /// @param objectId the object atom's vault id
    ///
    /// @return hash the corresponding hash for the given RDF triple based on the atom vault ids
    function tripleHashFromAtoms(uint256 subjectId, uint256 predicateId, uint256 objectId)
        external
        pure
        returns (bytes32);

    /// @notice returns the counter id from the given triple id
    /// @param id vault id of the triple
    /// @return counterId the counter vault id from the given triple id
    /// NOTE: only applies to triple vault IDs as input
    function getCounterIdFromTriple(uint256 id) external returns (uint256);

    /// @notice returns the address of the atom warden
    function getAtomWarden() external view returns (address);

    /// @notice returns the number of shares and assets (less fees) user has in the vault
    ///
    /// @param vaultId vault id of the vault
    /// @param receiver address of the receiver
    ///
    /// @return shares number of shares user has in the vault
    /// @return assets number of assets user has in the vault
    function getVaultStateForUser(uint256 vaultId, address receiver) external view returns (uint256, uint256);

    /// @notice returns the Atom Wallet address for the given atom data
    /// @param id vault id of the atom associated to the atom wallet
    /// @return atomWallet the address of the atom wallet
    /// NOTE: the create2 salt is based off of the vault ID
    function computeAtomWalletAddr(uint256 id) external view returns (address);
}
