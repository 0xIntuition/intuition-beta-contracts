// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {IPermit2} from "src/interfaces/IPermit2.sol";

/// @title IVaultManager
/// @notice Interface for managing many ERC4626 style vaults in a single contract
interface IEthMultiVault {
    /* =================================================== */
    /*                   CONFIGS STRUCTS                   */
    /* =================================================== */

    /// @dev General configuration struct
    struct GeneralConfig {
        /// @dev Admin address
        address admin;
        /// @dev Protocol vault address
        address protocolVault;
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
        ///      they are sent to the protocol vault address, as defined in `generalConfig.protocolVault`
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

    /// @notice Emitted upon the minting of shares in the vault by depositing assets
    ///
    /// @param sender initializer of the deposit
    /// @param receiver beneficiary of the minted shares
    /// @param vaultBalance total assets held in the vault
    /// @param userAssetsAfterTotalFees total assets that go towards minting shares for the receiver
    /// @param sharesForReceiver total shares transferred
    /// @param entryFee total fee amount collected for entering the vault
    /// @param id vault id
    event Deposited(
        address indexed sender,
        address indexed receiver,
        uint256 vaultBalance,
        uint256 userAssetsAfterTotalFees,
        uint256 sharesForReceiver,
        uint256 entryFee,
        uint256 id
    );

    /// @notice Emitted upon the withdrawal of assets from the vault by redeeming shares
    ///
    /// @param sender initializer of the withdrawal
    /// @param owner owner of the shares that were redeemed
    /// @param vaultBalance total assets held in the vault
    /// @param assetsForReceiver quantity of assets withdrawn by the receiver
    /// @param shares quantity of shares redeemed
    /// @param exitFee total fee amount collected for exiting the vault
    /// @param id vault id
    event Redeemed(
        address indexed sender,
        address indexed owner,
        uint256 vaultBalance,
        uint256 assetsForReceiver,
        uint256 shares,
        uint256 exitFee,
        uint256 id
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

    /// @notice emitted upon the transfer of fees to the protocol vault
    ///
    /// @param sender address of the sender
    /// @param protocolVault address of the protocol vault
    /// @param amount amount of fees transferred
    event FeesTransferred(address indexed sender, address indexed protocolVault, uint256 amount);

    /* =================================================== */
    /*                       FUNCTIONS                     */
    /* =================================================== */

    function init(
        GeneralConfig memory _generalConfig,
        AtomConfig memory _atomConfig,
        TripleConfig memory _tripleConfig,
        WalletConfig memory _walletConfig,
        VaultFees memory _defaultVaultFees
    ) external;

    function deployAtomWallet(uint256 atomId) external returns (address);

    function createAtom(bytes calldata atomUri) external payable returns (uint256);

    function batchCreateAtom(bytes[] calldata atomUris) external payable returns (uint256[] memory);

    function createTriple(uint256 subjectId, uint256 predicateId, uint256 objectId)
        external
        payable
        returns (uint256);

    function batchCreateTriple(
        uint256[] calldata subjectIds,
        uint256[] calldata predicateIds,
        uint256[] calldata objectIds
    ) external payable returns (uint256[] memory);

    function depositAtom(address receiver, uint256 id) external payable returns (uint256);

    function redeemAtom(uint256 shares, address receiver, uint256 id) external returns (uint256);

    function depositTriple(address receiver, uint256 id) external payable returns (uint256);

    function redeemTriple(uint256 shares, address receiver, uint256 id) external returns (uint256);

    function pause() external;

    function unpause() external;

    function scheduleOperation(bytes32 operationId, bytes calldata data) external;

    function cancelOperation(bytes32 operationId, bytes calldata data) external;

    function setAdmin(address admin) external;

    function setProtocolVault(address protocolVault) external;

    function setMinDeposit(uint256 minDeposit) external;

    function setMinShare(uint256 minShare) external;

    function setAtomUriMaxLength(uint256 atomUriMaxLength) external;

    function setAtomWalletInitialDepositAmount(uint256 atomWalletInitialDepositAmount) external;

    function setAtomCreationProtocolFee(uint256 atomCreationProtocolFee) external;

    function setTripleCreationProtocolFee(uint256 tripleCreationProtocolFee) external;

    function setAtomDepositFractionForTriple(uint256 atomDepositFractionForTriple) external;

    function setEntryFee(uint256 id, uint256 entryFee) external;

    function setExitFee(uint256 id, uint256 exitFee) external;

    function setProtocolFee(uint256 id, uint256 protocolFee) external;

    function setAtomWarden(address atomWarden) external;

    function getAtomCost() external view returns (uint256);

    function getTripleCost() external view returns (uint256);

    function getDepositFees(uint256 assets, uint256 id) external view returns (uint256);

    function getDepositSharesAndFees(uint256 assets, uint256 id)
        external
        view
        returns (uint256, uint256, uint256, uint256);

    function getRedeemAssetsAndFees(uint256 shares, uint256 id)
        external
        view
        returns (uint256, uint256, uint256, uint256);

    function entryFeeAmount(uint256 assets, uint256 id) external view returns (uint256);

    function exitFeeAmount(uint256 assets, uint256 id) external view returns (uint256);

    function protocolFeeAmount(uint256 assets, uint256 id) external view returns (uint256);

    function atomDepositFractionAmount(uint256 assets, uint256 id) external view returns (uint256);

    function convertToShares(uint256 assets, uint256 id) external view returns (uint256);

    function convertToAssets(uint256 shares, uint256 id) external view returns (uint256);

    function currentSharePrice(uint256 id) external view returns (uint256);

    function previewDeposit(uint256 assets, uint256 id) external view returns (uint256);

    function previewRedeem(uint256 shares, uint256 id) external view returns (uint256);

    function maxRedeem(address owner, uint256 id) external view returns (uint256);

    function tripleHashFromAtoms(uint256 subjectId, uint256 predicateId, uint256 objectId)
        external
        pure
        returns (bytes32);

    function tripleHash(uint256 id) external view returns (bytes32);

    function isTripleId(uint256 id) external view returns (bool);

    function getTripleAtoms(uint256 id) external view returns (uint256, uint256, uint256);

    function getCounterIdFromTriple(uint256 id) external returns (uint256);

    function isTriple(uint256 id) external view returns (bool);

    function tripleAtomShares(uint256 id, uint256 atomId, address account) external view returns (uint256);

    function getVaultStateForUser(uint256 vaultId, address receiver) external view returns (uint256, uint256);

    function computeAtomWalletAddr(uint256 id) external view returns (address);

    function getAtomWarden() external view returns (address);
}
