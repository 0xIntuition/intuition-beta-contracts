// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IEntryPoint} from "account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {LibZip} from "solady/utils/LibZip.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {AtomWallet} from "src/AtomWallet.sol";
import {Errors} from "src/libraries/Errors.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";

import {ProgressiveCurve} from "src/ProgressiveCurve.sol";
import {IBaseCurve} from "src/interfaces/IBaseCurve.sol";
import {IBondingCurveRegistry} from "src/interfaces/IBondingCurveRegistry.sol";

/**
 * @title  EthMultiVault
 * @author 0xIntuition
 * @notice Core contract of the Intuition protocol. Manages the creation and management of vaults
 *         associated with atoms & triples.
 * @notice A sophisticated vault management system that implements a dual-layer
 *         semantic data structure through "atoms" and "triples", reminiscent of
 *         RDF (Resource Description Framework) concepts.
 *
 * @notice Core protocol component managing the relationship between semantic data
 *         structures and their economic representations through vault mechanics.
 *         Implements ERC4626-style accounting with progressive bonding curves.
 *
 * @notice    ## Key Components:
 *     1. Vault Management
 *        - ETH deposits/withdrawals through ERC4626-style vault accounting
 *        - Progressive bonding curves for price discovery
 *        - Supports both standard pro-rata vaults and curve-specific vaults, for backwards compatibility.
 *
 *     2. Semantic Structure
 *        - Atoms: Base-level vaults representing individual semantic units
 *        - Triples: Composite vaults linking three atoms in subject-predicate-object relationships
 *        - Each vault type maintains independent state and fee structures
 *
 *     3. Security Features
 *        - Timelocked admin operations
 *        - Reentrancy protection
 *        - Pausable functionality
 *        - Granular fee controls with maximum caps
 *        - Approval system for delegated deposits
 *
 *     4. Smart Account Integration
 *        - Deploys ERC4337-compatible atom wallets
 *        - BeaconProxy pattern for upgradeable wallet implementations
 *        - Maintains initialization deposits for wallet operations
 *
 *     5. Fee Structure
 *        - Entry, exit, and protocol fees
 *        - Configurable per vault
 *        - Separate fee structures for atom/triple creation
 *        - Proportional deposit distribution for triple-related operations
 *
 * @dev ## Please note: 
 *      This implementation of the EthMultiVault is messy for a reason.  We wanted to keep all of
 *      the audited code in place, while also enabling users to interact with Bonding Curve vaults.  For this
 *      reason, there are separate functions for all Bonding Curve related activity.  While this bloats the
 *      code size, it ensures that users can still use the audited pathways in the code if they wish, while also
 *      enabling them to engage in more economically exciting activities like the Progressive Curve.
 * @dev The V2 of this contract will merge these pathways into one, providing a cleaner and more straightforward
 *      interface for depositing and redeeming.
 */

contract EthMultiVault is IEthMultiVault, Initializable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using FixedPointMathLib for uint256;
    using LibZip for bytes;

    /* =================================================== */
    /*                  STATE VARIABLES                    */
    /* =================================================== */

    // Operation identifiers
    bytes32 public constant SET_ADMIN = keccak256("setAdmin");
    bytes32 public constant SET_EXIT_FEE = keccak256("setExitFee");

    /// @notice Configuration structs
    GeneralConfig public generalConfig;
    AtomConfig public atomConfig;
    TripleConfig public tripleConfig;
    WalletConfig public walletConfig;

    /// @notice ID of the last vault to be created
    uint256 public count;

    /// @notice Mapping of vault ID to vault state
    // Vault ID -> Vault State
    mapping(uint256 vaultId => VaultState vaultState) public vaults;

    /// @notice Mapping of vault ID to vault fees
    // Vault ID -> Vault Fees
    mapping(uint256 vaultId => VaultFees vaultFees) public vaultFees;

    /// @notice Mapping of receiver to sender to determine if a sender is allowed to deposit assets on behalf of a receiver
    // Receiver -> Sender -> Is Approved
    mapping(address receiver => mapping(address sender => bool isApproved)) public approvals;

    /// @notice RDF (Resource Description Framework)
    // mapping of vault ID to atom data
    // Vault ID -> Atom Data
    mapping(uint256 atomId => bytes atomData) public atoms;

    // mapping of atom hash to atom vault ID
    // Hash -> Atom ID
    mapping(bytes32 atomHash => uint256 atomId) public atomsByHash;

    // mapping of triple vault ID to the underlying atom IDs that make up the triple
    // Triple ID -> VaultIDs of atoms that make up the triple
    mapping(uint256 tripleId => uint256[3] tripleAtomIds) public triples;

    // mapping of triple hash to triple vault ID
    // Hash -> Triple ID
    mapping(bytes32 tripleHash => uint256 tripleId) public triplesByHash;

    // mapping of triple vault IDs to determine whether a vault is a triple or not
    // Vault ID -> (Is Triple)
    mapping(uint256 vaultId => bool isTriple) public isTriple;

    /// @notice Timelock mapping (operation hash -> timelock struct)
    mapping(bytes32 operationHash => Timelock timelock) public timelocks;

    /// @notice Bonding Curve Vaults (termId -> curveId -> vaultState)
    mapping(uint256 vaultId => mapping(uint256 curveId => VaultState vaultState)) public bondingCurveVaults;

    /// @notice Bonding Curve Configurations
    BondingCurveConfig public bondingCurveConfig;

    /// @dev Gap for upgrade safety
    uint256[48] private __gap;

    /* =================================================== */
    /*                    MODIFIERS                        */
    /* =================================================== */

    /// @notice Modifier to restrict a function to the admin
    modifier onlyAdmin() {
        if (msg.sender != generalConfig.admin) {
            revert Errors.EthMultiVault_AdminOnly();
        }
        _;
    }

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
    /// @dev This function is called only once (during contract deployment)
    function init(
        GeneralConfig memory _generalConfig,
        AtomConfig memory _atomConfig,
        TripleConfig memory _tripleConfig,
        WalletConfig memory _walletConfig,
        VaultFees memory _defaultVaultFees,
        BondingCurveConfig memory _bondingCurveConfig
    ) external initializer {
        __ReentrancyGuard_init();
        __Pausable_init();

        generalConfig = _generalConfig;
        atomConfig = _atomConfig;
        tripleConfig = _tripleConfig;
        walletConfig = _walletConfig;
        bondingCurveConfig = _bondingCurveConfig;
        vaultFees[0] = VaultFees({
            entryFee: _defaultVaultFees.entryFee,
            exitFee: _defaultVaultFees.exitFee,
            protocolFee: _defaultVaultFees.protocolFee
        });
    }

    /* =================================================== */
    /*                     FALLBACK                        */
    /* =================================================== */

    /// @notice contract does not accept ETH donations
    receive() external payable {
        revert Errors.EthMultiVault_ReceiveNotAllowed();
    }

    /// @notice fallback function to decompress the calldata and call the appropriate function
    fallback() external payable {
        LibZip.cdFallback();
    }

    /* =================================================== */
    /*               RESTRICTED FUNCTIONS                  */
    /* =================================================== */

    /// @dev pauses the pausable contract methods
    function pause() external onlyAdmin {
        _pause();
    }

    /// @dev unpauses the pausable contract methods
    function unpause() external onlyAdmin {
        _unpause();
    }

    /// @dev schedule an operation to be executed after a delay
    ///
    /// @param operationId unique identifier for the operation
    /// @param data data to be executed
    function scheduleOperation(bytes32 operationId, bytes calldata data) external onlyAdmin {
        uint256 minDelay = generalConfig.minDelay;

        // Generate the operation hash
        bytes32 operationHash = keccak256(abi.encodePacked(operationId, data, minDelay));

        // Check timelock constraints and schedule the operation
        if (timelocks[operationHash].readyTime != 0) {
            revert Errors.EthMultiVault_OperationAlreadyScheduled();
        }

        // calculate the time when the operation can be executed
        uint256 readyTime = block.timestamp + minDelay;

        timelocks[operationHash] = Timelock({data: data, readyTime: readyTime, executed: false});

        emit OperationScheduled(operationId, data, readyTime);
    }

    /// @dev cancel a scheduled operation
    ///
    /// @param operationId unique identifier for the operation
    /// @param data data of the operation to be cancelled
    function cancelOperation(bytes32 operationId, bytes calldata data) external onlyAdmin {
        // Generate the operation hash
        bytes32 operationHash = keccak256(abi.encodePacked(operationId, data, generalConfig.minDelay));

        // Check timelock constraints and cancel the operation
        Timelock memory timelock = timelocks[operationHash];

        if (timelock.readyTime == 0) {
            revert Errors.EthMultiVault_OperationNotScheduled();
        }
        if (timelock.executed) {
            revert Errors.EthMultiVault_OperationAlreadyExecuted();
        }

        delete timelocks[operationHash];

        emit OperationCancelled(operationId, data);
    }

    /// @dev set admin
    /// @param admin address of the new admin
    function setAdmin(address admin) external onlyAdmin {
        address oldAdmin = generalConfig.admin;

        // Generate the operation hash
        bytes memory data = abi.encodeWithSelector(EthMultiVault.setAdmin.selector, admin);
        bytes32 opHash = keccak256(abi.encodePacked(SET_ADMIN, data, generalConfig.minDelay));

        // Check timelock constraints
        _validateTimelock(opHash);

        // Execute the operation
        generalConfig.admin = admin;

        // Mark the operation as executed
        timelocks[opHash].executed = true;

        emit AdminSet(admin, oldAdmin);
    }

    /// @dev set protocol multisig
    /// @param protocolMultisig address of the new protocol multisig
    function setProtocolMultisig(address protocolMultisig) external onlyAdmin {
        address oldProtocolMultisig = generalConfig.protocolMultisig;

        generalConfig.protocolMultisig = protocolMultisig;

        emit protocolMultisigSet(protocolMultisig, oldProtocolMultisig);
    }

    /// @dev sets the minimum deposit amount for atoms and triples
    /// @param minDeposit new minimum deposit amount
    function setMinDeposit(uint256 minDeposit) external onlyAdmin {
        uint256 oldMinDeposit = generalConfig.minDeposit;

        generalConfig.minDeposit = minDeposit;

        emit MinDepositSet(minDeposit, oldMinDeposit);
    }

    /// @dev sets the minimum share amount for atoms and triples
    /// @param minShare new minimum share amount
    function setMinShare(uint256 minShare) external onlyAdmin {
        uint256 oldMinShare = generalConfig.minShare;

        generalConfig.minShare = minShare;

        emit MinShareSet(minShare, oldMinShare);
    }

    /// @dev sets the atom URI max length
    /// @param atomUriMaxLength new atom URI max length
    function setAtomUriMaxLength(uint256 atomUriMaxLength) external onlyAdmin {
        uint256 oldAtomUriMaxLength = generalConfig.atomUriMaxLength;

        generalConfig.atomUriMaxLength = atomUriMaxLength;

        emit AtomUriMaxLengthSet(atomUriMaxLength, oldAtomUriMaxLength);
    }

    /// @dev sets the atom share lock fee
    /// @param atomWalletInitialDepositAmount new atom share lock fee
    function setAtomWalletInitialDepositAmount(uint256 atomWalletInitialDepositAmount) external onlyAdmin {
        uint256 oldAtomWalletInitialDepositAmount = atomConfig.atomWalletInitialDepositAmount;

        atomConfig.atomWalletInitialDepositAmount = atomWalletInitialDepositAmount;

        emit AtomWalletInitialDepositAmountSet(atomWalletInitialDepositAmount, oldAtomWalletInitialDepositAmount);
    }

    /// @dev sets the atom creation fee
    /// @param atomCreationProtocolFee new atom creation fee
    function setAtomCreationProtocolFee(uint256 atomCreationProtocolFee) external onlyAdmin {
        uint256 oldAtomCreationProtocolFee = atomConfig.atomCreationProtocolFee;

        atomConfig.atomCreationProtocolFee = atomCreationProtocolFee;

        emit AtomCreationProtocolFeeSet(atomCreationProtocolFee, oldAtomCreationProtocolFee);
    }

    /// @dev sets fee charged in wei when creating a triple to protocol multisig
    /// @param tripleCreationProtocolFee new fee in wei
    function setTripleCreationProtocolFee(uint256 tripleCreationProtocolFee) external onlyAdmin {
        uint256 oldTripleCreationProtocolFee = tripleConfig.tripleCreationProtocolFee;

        tripleConfig.tripleCreationProtocolFee = tripleCreationProtocolFee;

        emit TripleCreationProtocolFeeSet(tripleCreationProtocolFee, oldTripleCreationProtocolFee);
    }

    /// @dev sets the atom deposit fraction on triple creation used to increase the amount of assets
    ///      in the underlying atom vaults on triple creation
    /// @param atomDepositFractionOnTripleCreation new atom deposit fraction on triple creation
    function setAtomDepositFractionOnTripleCreation(uint256 atomDepositFractionOnTripleCreation) external onlyAdmin {
        uint256 oldAtomDepositFractionOnTripleCreation = tripleConfig.atomDepositFractionOnTripleCreation;

        tripleConfig.atomDepositFractionOnTripleCreation = atomDepositFractionOnTripleCreation;

        emit AtomDepositFractionOnTripleCreationSet(
            atomDepositFractionOnTripleCreation, oldAtomDepositFractionOnTripleCreation
        );
    }

    /// @dev sets the atom deposit fraction percentage for atoms used in triples
    ///      (number to be divided by `generalConfig.feeDenominator`)
    /// @param atomDepositFractionForTriple new atom deposit fraction percentage
    function setAtomDepositFractionForTriple(uint256 atomDepositFractionForTriple) external onlyAdmin {
        uint256 maxAtomDepositFractionForTriple = generalConfig.feeDenominator * 9 / 10; // 90% of the fee denominator

        if (atomDepositFractionForTriple > maxAtomDepositFractionForTriple) {
            revert Errors.EthMultiVault_InvalidAtomDepositFractionForTriple();
        }

        uint256 oldAtomDepositFractionForTriple = tripleConfig.atomDepositFractionForTriple;

        tripleConfig.atomDepositFractionForTriple = atomDepositFractionForTriple;

        emit AtomDepositFractionForTripleSet(atomDepositFractionForTriple, oldAtomDepositFractionForTriple);
    }

    /// @dev sets entry fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default entry fee, id = n changes fees for vault n specifically
    /// @dev admin cannot set the entry fee to be greater than `maxEntryFeePercentage`, which is
    ///      set to be the 10% of `generalConfig.feeDenominator` (which represents 100%), to avoid
    ///      being able to prevent users from depositing assets with unreasonable fees
    ///
    /// @param id vault id to set entry fee for
    /// @param entryFee entry fee to set
    function setEntryFee(uint256 id, uint256 entryFee) external onlyAdmin {
        uint256 maxEntryFeePercentage = generalConfig.feeDenominator / 10;

        if (entryFee > maxEntryFeePercentage) {
            revert Errors.EthMultiVault_InvalidEntryFee();
        }

        uint256 oldEntryFee = vaultFees[id].entryFee;

        vaultFees[id].entryFee = entryFee;

        emit EntryFeeSet(id, entryFee, oldEntryFee);
    }

    /// @dev sets exit fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default exit fee, id = n changes fees for vault n specifically
    /// @dev admin cannot set the exit fee to be greater than `maxExitFeePercentage`, which is
    ///      set to be the 10% of `generalConfig.feeDenominator` (which represents 100%), to avoid
    ///      being able to prevent users from withdrawing their assets
    ///
    /// @param id vault id to set exit fee for
    /// @param exitFee exit fee to set
    function setExitFee(uint256 id, uint256 exitFee) external onlyAdmin {
        uint256 maxExitFeePercentage = generalConfig.feeDenominator / 10;

        if (exitFee > maxExitFeePercentage) {
            revert Errors.EthMultiVault_InvalidExitFee();
        }

        uint256 oldExitFee = vaultFees[id].exitFee;

        // Generate the operation hash
        bytes memory data = abi.encodeWithSelector(EthMultiVault.setExitFee.selector, id, exitFee);
        bytes32 opHash = keccak256(abi.encodePacked(SET_EXIT_FEE, data, generalConfig.minDelay));

        // Check timelock constraints
        _validateTimelock(opHash);

        // Execute the operation
        vaultFees[id].exitFee = exitFee;

        // Mark the operation as executed
        timelocks[opHash].executed = true;

        emit ExitFeeSet(id, exitFee, oldExitFee);
    }

    /// @dev sets protocol fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default protocol fee, id = n changes fees for vault n specifically
    /// @dev admin cannot set the protocol fee to be greater than `maxProtocolFeePercentage`, which is
    ///      set to be the 10% of `generalConfig.feeDenominator` (which represents 100%), to avoid
    ///      being able to prevent users from depositing or withdrawing their assets with unreasonable fees
    ///
    /// @param id vault id to set protocol fee for
    /// @param protocolFee protocol fee to set
    function setProtocolFee(uint256 id, uint256 protocolFee) external onlyAdmin {
        uint256 maxProtocolFeePercentage = generalConfig.feeDenominator / 10;

        if (protocolFee > maxProtocolFeePercentage) {
            revert Errors.EthMultiVault_InvalidProtocolFee();
        }

        uint256 oldProtocolFee = vaultFees[id].protocolFee;

        vaultFees[id].protocolFee = protocolFee;

        emit ProtocolFeeSet(id, protocolFee, oldProtocolFee);
    }

    /// @dev sets the atomWarden address
    /// @param atomWarden address of the new atomWarden
    function setAtomWarden(address atomWarden) external onlyAdmin {
        address oldAtomWarden = walletConfig.atomWarden;

        walletConfig.atomWarden = atomWarden;

        emit AtomWardenSet(atomWarden, oldAtomWarden);
    }

    /* =================================================== */
    /*                MUTATIVE FUNCTIONS                   */
    /* =================================================== */

    /* -------------------------- */
    /*         Atom Wallet        */
    /* -------------------------- */

    /// @notice deploy a given atom wallet
    /// @param atomId vault id of atom
    /// @return atomWallet the address of the atom wallet
    /// @dev deploys an ERC4337 account (atom wallet) through a BeaconProxy. Reverts if the atom vault does not exist
    function deployAtomWallet(uint256 atomId) external whenNotPaused returns (address) {
        if (atomId == 0 || atomId > count) {
            revert Errors.EthMultiVault_VaultDoesNotExist();
        }

        if (isTripleId(atomId)) {
            revert Errors.EthMultiVault_VaultNotAtom();
        }

        // compute salt for create2
        bytes32 salt = bytes32(atomId);

        // get contract deployment data
        bytes memory data = _getDeploymentData();

        address predictedAtomWalletAddress = computeAtomWalletAddr(atomId);

        uint256 codeLengthBefore = predictedAtomWalletAddress.code.length;

        address deployedAtomWalletAddress;

        // deploy atom wallet with create2:
        // value sent in wei,
        // memory offset of `code` (after first 32 bytes where the length is),
        // length of `code` (first 32 bytes of code),
        // salt for create2
        assembly {
            deployedAtomWalletAddress := create2(0, add(data, 0x20), mload(data), salt)
        }

        if (deployedAtomWalletAddress == address(0)) {
            if (codeLengthBefore == 0) {
                revert Errors.EthMultiVault_DeployAccountFailed();
            } else {
                return predictedAtomWalletAddress;
            }
        }

        emit AtomWalletDeployed(atomId, deployedAtomWalletAddress);

        return predictedAtomWalletAddress;
    }

    /* -------------------------- */
    /*         Approvals          */
    /* -------------------------- */

    /// @notice approve a sender to deposit assets on behalf of the receiver
    /// @param sender address to approve
    function approveSender(address sender) external {
        address receiver = msg.sender;

        if (receiver == sender) {
            revert Errors.EthMultiVault_CannotApproveSelf();
        }

        if (approvals[receiver][sender]) {
            revert Errors.EthMultiVault_SenderAlreadyApproved();
        }

        approvals[receiver][sender] = true;

        emit SenderApproved(receiver, sender, true);
    }

    /// @notice revoke a sender's approval to deposit assets on behalf of the receiver
    /// @param sender address to revoke
    function revokeSender(address sender) external {
        address receiver = msg.sender;

        if (receiver == sender) {
            revert Errors.EthMultiVault_CannotRevokeSelf();
        }

        if (!approvals[receiver][sender]) {
            revert Errors.EthMultiVault_SenderNotApproved();
        }

        approvals[receiver][sender] = false;

        emit SenderRevoked(receiver, sender, false);
    }

    /* -------------------------- */
    /*         Create Atom        */
    /* -------------------------- */

    /// @notice Create an atom and return its vault id
    /// @param atomUri atom data to create atom with
    /// @return id vault id of the atom
    /// @dev This function will revert if called with less than `getAtomCost()` in `msg.value`
    function createAtom(bytes calldata atomUri) external payable nonReentrant whenNotPaused returns (uint256) {
        if (msg.value < getAtomCost()) {
            revert Errors.EthMultiVault_InsufficientBalance();
        }

        // create atom and get the protocol deposit fee
        (uint256 id, uint256 protocolDepositFee) = _createAtom(atomUri, msg.value);

        uint256 totalFeesForProtocol = atomConfig.atomCreationProtocolFee + protocolDepositFee;
        _transferFeesToProtocolMultisig(totalFeesForProtocol);

        return id;
    }

    /// @notice Batch create atoms and return their vault ids
    /// @param atomUris atom data array to create atoms with
    /// @return ids vault ids array of the atoms
    /// @dev This function will revert if called with less than `getAtomCost()` * `atomUris.length` in `msg.value`
    function batchCreateAtom(bytes[] calldata atomUris)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256[] memory)
    {
        uint256 length = atomUris.length;
        if (msg.value < getAtomCost() * length) {
            revert Errors.EthMultiVault_InsufficientBalance();
        }

        uint256 valuePerAtom = msg.value / length;
        uint256 protocolDepositFeeTotal;
        uint256[] memory ids = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 protocolDepositFee;
            (ids[i], protocolDepositFee) = _createAtom(atomUris[i], valuePerAtom);

            // add protocol deposit fees to total
            protocolDepositFeeTotal += protocolDepositFee;
        }

        uint256 totalFeesForProtocol = atomConfig.atomCreationProtocolFee * length + protocolDepositFeeTotal;
        _transferFeesToProtocolMultisig(totalFeesForProtocol);

        return ids;
    }

    /// @notice Internal utility function to create an atom and handle vault creation
    ///
    /// @param atomUri The atom data to create an atom with
    /// @param value The value sent with the transaction
    ///
    /// @return id The new vault ID created for the atom
    function _createAtom(bytes calldata atomUri, uint256 value) internal returns (uint256, uint256) {
        if (atomUri.length > generalConfig.atomUriMaxLength) {
            revert Errors.EthMultiVault_AtomUriTooLong();
        }

        uint256 atomCost = getAtomCost();

        // check if atom already exists based on hash
        bytes32 hash = keccak256(atomUri);
        if (atomsByHash[hash] != 0) {
            revert Errors.EthMultiVault_AtomExists(atomUri);
        }

        // calculate user deposit amount
        uint256 userDeposit = value - atomCost;

        // create a new atom vault
        uint256 id = _createVault();

        // calculate protocol deposit fee
        uint256 protocolDepositFee = protocolFeeAmount(userDeposit, id);

        // calculate user deposit after protocol fees
        uint256 userDepositAfterprotocolFee = userDeposit - protocolDepositFee;

        // deposit user funds into vault and mint shares for the user and shares for the admin to initialize the vault
        _depositOnVaultCreation(
            id,
            msg.sender, // receiver
            userDepositAfterprotocolFee
        );

        // get atom wallet address for the corresponding atom
        address atomWallet = computeAtomWalletAddr(id);

        // deposit atomWalletInitialDepositAmount amount of assets and mint the shares for the atom wallet
        _depositOnVaultCreation(
            id,
            atomWallet, // receiver
            atomConfig.atomWalletInitialDepositAmount
        );

        // map the new vault ID to the atom data
        atoms[id] = atomUri;

        // map the resultant atom hash to the new vault ID
        atomsByHash[hash] = id;

        emit AtomCreated(msg.sender, atomWallet, atomUri, id);

        return (id, protocolDepositFee);
    }

    /* -------------------------- */
    /*        Create Triple       */
    /* -------------------------- */

    /// @notice create a triple and return its vault id
    ///
    /// @param subjectId vault id of the subject atom
    /// @param predicateId vault id of the predicate atom
    /// @param objectId vault id of the object atom
    ///
    /// @return id vault id of the triple
    /// @dev This function will revert if called with less than `getTripleCost()` in `msg.value`.
    ///       This function will revert if any of the atoms do not exist or if any ids are triple vaults.
    function createTriple(uint256 subjectId, uint256 predicateId, uint256 objectId)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (msg.value < getTripleCost()) {
            revert Errors.EthMultiVault_InsufficientBalance();
        }

        // create triple and get the protocol deposit fee
        (uint256 id, uint256 protocolDepositFee) = _createTriple(subjectId, predicateId, objectId, msg.value);

        uint256 totalFeesForProtocol = tripleConfig.tripleCreationProtocolFee + protocolDepositFee;
        _transferFeesToProtocolMultisig(totalFeesForProtocol);

        return id;
    }

    /// @notice batch create triples and return their vault ids
    ///
    /// @param subjectIds vault ids array of subject atoms
    /// @param predicateIds vault ids array of predicate atoms
    /// @param objectIds vault ids array of object atoms
    ///
    /// @dev This function will revert if called with less than `getTripleCost()` * `array.length` in `msg.value`.
    ///       This function will revert if any of the atoms do not exist or if any ids are triple vaults.
    function batchCreateTriple(
        uint256[] calldata subjectIds,
        uint256[] calldata predicateIds,
        uint256[] calldata objectIds
    ) external payable nonReentrant whenNotPaused returns (uint256[] memory) {
        if (subjectIds.length != predicateIds.length || subjectIds.length != objectIds.length) {
            revert Errors.EthMultiVault_ArraysNotSameLength();
        }

        uint256 length = subjectIds.length;
        uint256 tripleCost = getTripleCost();
        if (msg.value < tripleCost * length) {
            revert Errors.EthMultiVault_InsufficientBalance();
        }

        uint256 valuePerTriple = msg.value / length;
        uint256 protocolDepositFeeTotal;
        uint256[] memory ids = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 protocolDepositFee;
            (ids[i], protocolDepositFee) = _createTriple(subjectIds[i], predicateIds[i], objectIds[i], valuePerTriple);

            // add protocol deposit fees to total
            protocolDepositFeeTotal += protocolDepositFee;
        }

        uint256 totalFeesForProtocol = tripleConfig.tripleCreationProtocolFee * length + protocolDepositFeeTotal;
        _transferFeesToProtocolMultisig(totalFeesForProtocol);

        return ids;
    }

    /// @notice Internal utility function to create a triple
    ///
    /// @param subjectId vault id of the subject atom
    /// @param predicateId vault id of the predicate atom
    /// @param objectId vault id of the object atom
    /// @param value The amount of ETH the user has sent minus the base triple cost
    ///
    /// @return id The new vault ID of the created triple
    /// @return protocolDepositFee The calculated protocol fee for the deposit
    function _createTriple(uint256 subjectId, uint256 predicateId, uint256 objectId, uint256 value)
        internal
        returns (uint256, uint256)
    {
        uint256[3] memory tripleAtomIds = [subjectId, predicateId, objectId];

        for (uint256 i = 0; i < 3; i++) {
            // make sure atoms exist, if not, revert
            if (tripleAtomIds[i] == 0 || tripleAtomIds[i] > count) {
                revert Errors.EthMultiVault_AtomDoesNotExist(tripleAtomIds[i]);
            }

            // make sure that each id is not a triple vault id
            if (isTripleId(tripleAtomIds[i])) {
                revert Errors.EthMultiVault_VaultIsTriple(tripleAtomIds[i]);
            }
        }

        // check if triple already exists
        bytes32 hash = tripleHashFromAtoms(subjectId, predicateId, objectId);

        if (triplesByHash[hash] != 0) {
            revert Errors.EthMultiVault_TripleExists(subjectId, predicateId, objectId);
        }

        // calculate user deposit amount
        uint256 userDeposit = value - getTripleCost();

        // create a new positive triple vault
        uint256 id = _createVault();

        // calculate protocol deposit fee
        uint256 protocolDepositFee = protocolFeeAmount(userDeposit, id);

        // calculate user deposit after protocol fees
        uint256 userDepositAfterprotocolFee = userDeposit - protocolDepositFee;

        // map the resultant triple hash to the new vault ID of the triple
        triplesByHash[hash] = id;

        // map the triple's vault ID to the underlying atom vault IDs
        triples[id] = [subjectId, predicateId, objectId];

        // set this new triple's vault ID as true in the IsTriple mapping as well as its counter
        isTriple[id] = true;

        uint256 atomDepositFraction = atomDepositFractionAmount(userDepositAfterprotocolFee, id);

        // give the user shares in the positive triple vault
        _depositOnVaultCreation(
            id,
            msg.sender, // receiver
            userDepositAfterprotocolFee - atomDepositFraction
        );

        // deposit assets into each underlying atom vault and mint shares for the receiver
        if (atomDepositFraction > 0) {
            _depositAtomFraction(
                id,
                msg.sender, // receiver
                atomDepositFraction
            );
        }

        if (tripleConfig.atomDepositFractionOnTripleCreation > 0) {
            for (uint256 i = 0; i < 3; i++) {
                uint256 atomId = tripleAtomIds[i];
                // increase the total assets in each underlying atom vault
                _setVaultTotals(
                    atomId,
                    vaults[atomId].totalAssets + (tripleConfig.atomDepositFractionOnTripleCreation / 3),
                    vaults[atomId].totalShares
                );
            }
        }

        emit TripleCreated(msg.sender, subjectId, predicateId, objectId, id);

        return (id, protocolDepositFee);
    }

    /* -------------------------- */
    /*    Deposit/Redeem Atom     */
    /* -------------------------- */

    /// @notice deposit eth into an atom vault and grant ownership of 'shares' to 'reciever'
    ///         *payable msg.value amount of eth to deposit
    /// @dev assets parameter is omitted in favor of msg.value, unlike in ERC4626
    ///
    /// @param receiver the address to receive the shares
    /// @param id the vault ID of the atom
    ///
    /// @return shares the amount of shares minted
    /// @dev this function will revert if the minimum deposit amount of eth is not met and
    ///       if the vault ID does not exist/is not an atom.
    function depositAtom(address receiver, uint256 id) external payable nonReentrant whenNotPaused returns (uint256) {
        if (msg.sender != receiver && !approvals[receiver][msg.sender]) {
            revert Errors.EthMultiVault_SenderNotApproved();
        }

        if (id == 0 || id > count) {
            revert Errors.EthMultiVault_VaultDoesNotExist();
        }

        if (isTripleId(id)) {
            revert Errors.EthMultiVault_VaultNotAtom();
        }

        if (msg.value < generalConfig.minDeposit) {
            revert Errors.EthMultiVault_MinimumDeposit();
        }

        uint256 protocolFee = protocolFeeAmount(msg.value, id);
        uint256 userDepositAfterprotocolFee = msg.value - protocolFee;

        // deposit eth into vault and mint shares for the receiver
        uint256 shares = _deposit(receiver, id, userDepositAfterprotocolFee);

        _transferFeesToProtocolMultisig(protocolFee);

        return shares;
    }

    /// @notice deposit eth into an atom vault and grant ownership of 'shares' to 'reciever'
    ///         *payable msg.value amount of eth to deposit
    /// @dev assets parameter is omitted in favor of msg.value, unlike in ERC4626
    ///
    /// @param receiver the address to receive the shares
    /// @param atomId the vault ID of the atom
    /// @param curveId the vault ID of the curve
    ///
    /// @return shares the amount of shares minted
    /// @dev this function will revert if the minimum deposit amount of eth is not met and
    ///       if the vault ID does not exist/is not an atom.
    /// @dev This method is entirely separate from depositAtom, because we wanted to leave the audited pathways intact.
    ///      This serves as an intermediary solution to enable users to interact with bonding curve vaults before
    ///      performing an audit of the full refactor (V2).
    function depositAtomCurve(address receiver, uint256 atomId, uint256 curveId)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (msg.sender != receiver && !approvals[receiver][msg.sender]) {
            revert Errors.EthMultiVault_SenderNotApproved();
        }

        if (atomId == 0 || atomId > count) {
            revert Errors.EthMultiVault_VaultDoesNotExist();
        }

        if (isTripleId(atomId)) {
            revert Errors.EthMultiVault_VaultNotAtom();
        }

        if (msg.value < generalConfig.minDeposit) {
            revert Errors.EthMultiVault_MinimumDeposit();
        }

        uint256 protocolFee = protocolFeeAmount(msg.value, atomId);
        uint256 userDepositAfterprotocolFee = msg.value - protocolFee;

        // deposit eth into vault and mint shares for the receiver
        uint256 shares = _depositCurve(receiver, atomId, curveId, userDepositAfterprotocolFee);

        _transferFeesToProtocolMultisig(protocolFee);

        return shares;
    }

    /// @notice redeem shares from an atom vault for assets
    ///
    /// @param shares the amount of shares to redeem
    /// @param receiver the address to receiver the assets
    /// @param id the vault ID of the atom
    ///
    /// @return assets the amount of assets/eth withdrawn
    /// @dev Emergency redemptions without any fees being charged are always possible, even if the contract is paused
    ///       See `getRedeemAssetsAndFees` for more details on the fees charged
    function redeemAtom(uint256 shares, address receiver, uint256 id) external nonReentrant returns (uint256) {
        if (id == 0 || id > count) {
            revert Errors.EthMultiVault_VaultDoesNotExist();
        }

        if (isTripleId(id)) {
            revert Errors.EthMultiVault_VaultNotAtom();
        }

        /*
            withdraw shares from vault, returning the amount of
            assets to be transferred to the receiver
        */
        (uint256 assets, uint256 protocolFee) = _redeem(id, msg.sender, receiver, shares);

        // transfer eth to receiver factoring in fees/shares
        (bool success,) = payable(receiver).call{value: assets}("");
        if (!success) {
            revert Errors.EthMultiVault_TransferFailed();
        }

        _transferFeesToProtocolMultisig(protocolFee);

        return assets;
    }

    /// @notice redeem shares from a bonding curve atom vault for assets
    ///
    /// @param shares the amount of shares to redeem
    /// @param receiver the address to receiver the assets
    /// @param atomId the vault ID of the atom
    /// @param curveId the vault ID of the curve
    ///
    /// @return assets the amount of assets/eth withdrawn
    /// @dev This method is entirely separate from redeemAtom, because we wanted to leave the audited pathways intact.
    ///      This serves as an intermediary solution to enable users to interact with bonding curve vaults before
    ///      performing an audit of the full refactor (V2).
    function redeemAtomCurve(uint256 shares, address receiver, uint256 atomId, uint256 curveId)
        external
        nonReentrant
        returns (uint256)
    {
        if (atomId == 0 || atomId > count) {
            revert Errors.EthMultiVault_VaultDoesNotExist();
        }

        if (isTripleId(atomId)) {
            revert Errors.EthMultiVault_VaultNotAtom();
        }

        /*
            withdraw shares from vault, returning the amount of
            assets to be transferred to the receiver
        */
        (uint256 assets, uint256 protocolFee) = _redeemCurve(atomId, curveId, msg.sender, receiver, shares);

        // transfer eth to receiver factoring in fees/shares
        (bool success,) = payable(receiver).call{value: assets}("");
        if (!success) {
            revert Errors.EthMultiVault_TransferFailed();
        }

        _transferFeesToProtocolMultisig(protocolFee);

        return assets;
    }

    /* -------------------------- */
    /*   Deposit/Redeem Triple    */
    /* -------------------------- */

    /// @notice deposits assets of underlying tokens into a triple vault and grants ownership of 'shares' to 'receiver'
    ///         *payable msg.value amount of eth to deposit
    /// @dev assets parameter is omitted in favor of msg.value, unlike in ERC4626
    ///
    /// @param receiver the address to receive the shares
    /// @param id the vault ID of the triple
    ///
    /// @return shares the amount of shares minted
    /// @dev this function will revert if the minimum deposit amount of eth is not met and
    ///       if the vault ID does not exist/is not a triple.
    function depositTriple(address receiver, uint256 id)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (msg.sender != receiver && !approvals[receiver][msg.sender]) {
            revert Errors.EthMultiVault_SenderNotApproved();
        }

        if (!isTripleId(id)) {
            revert Errors.EthMultiVault_VaultNotTriple();
        }

        if (_hasCounterStake(id, receiver)) {
            revert Errors.EthMultiVault_HasCounterStake();
        }

        if (msg.value < generalConfig.minDeposit) {
            revert Errors.EthMultiVault_MinimumDeposit();
        }

        uint256 protocolFee = protocolFeeAmount(msg.value, id);
        uint256 userDepositAfterprotocolFee = msg.value - protocolFee;

        // deposit eth into vault and mint shares for the receiver
        uint256 shares = _deposit(receiver, id, userDepositAfterprotocolFee);

        // distribute atom shares for all 3 atoms that underly the triple
        uint256 atomDepositFraction = atomDepositFractionAmount(userDepositAfterprotocolFee, id);

        // deposit assets into each underlying atom vault and mint shares for the receiver
        if (atomDepositFraction > 0) {
            _depositAtomFraction(id, receiver, atomDepositFraction);
        }

        _transferFeesToProtocolMultisig(protocolFee);

        return shares;
    }

    /// @notice deposit eth into a bonding curve triple vault and grant ownership of 'shares' to 'receiver'
    ///         *payable msg.value amount of eth to deposit
    /// @dev assets parameter is omitted in favor of msg.value, unlike in ERC4626
    ///
    /// @param receiver the address to receive the shares
    /// @param tripleId the vault ID of the triple
    /// @param curveId the vault ID of the curve
    ///
    /// @return shares the amount of shares minted
    /// @dev This method is entirely separate from depositTriple, because we wanted to leave the audited pathways intact.
    ///      This serves as an intermediary solution to enable users to interact with bonding curve vaults before
    ///      performing an audit of the full refactor (V2).
    function depositTripleCurve(address receiver, uint256 tripleId, uint256 curveId)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (msg.sender != receiver && !approvals[receiver][msg.sender]) {
            revert Errors.EthMultiVault_SenderNotApproved();
        }

        if (!isTripleId(tripleId)) {
            revert Errors.EthMultiVault_VaultNotTriple();
        }

        if (_hasCounterStakeCurve(tripleId, curveId, receiver)) {
            revert Errors.EthMultiVault_HasCounterStake();
        }

        if (msg.value < generalConfig.minDeposit) {
            revert Errors.EthMultiVault_MinimumDeposit();
        }

        uint256 protocolFee = protocolFeeAmount(msg.value, tripleId);
        uint256 userDepositAfterprotocolFee = msg.value - protocolFee;

        // deposit eth into vault and mint shares for the receiver
        uint256 shares = _depositCurve(receiver, tripleId, curveId, userDepositAfterprotocolFee);

        // distribute atom shares for all 3 atoms that underly the triple
        uint256 atomDepositFraction = atomDepositFractionAmount(userDepositAfterprotocolFee, tripleId);

        // deposit assets into each underlying atom vault and mint shares for the receiver
        if (atomDepositFraction > 0) {
            _depositAtomFractionCurve(tripleId, curveId, receiver, atomDepositFraction);
        }

        _transferFeesToProtocolMultisig(protocolFee);

        return shares;
    }

    /// @notice redeems 'shares' number of shares from the triple vault and send 'assets' eth
    ///         from the contract to 'reciever' factoring in exit fees
    ///
    /// @param shares the amount of shares to redeem
    /// @param receiver the address to receiver the assets
    /// @param id the vault ID of the triple
    ///
    /// @return assets the amount of assets/eth withdrawn
    /// @dev Emergency redemptions without any fees being charged are always possible, even if the contract is paused
    ///       See `getRedeemAssetsAndFees` for more details on the fees charged
    function redeemTriple(uint256 shares, address receiver, uint256 id) external nonReentrant returns (uint256) {
        if (!isTripleId(id)) {
            revert Errors.EthMultiVault_VaultNotTriple();
        }

        /*
            withdraw shares from vault, returning the amount of
            assets to be transferred to the receiver
        */
        (uint256 assets, uint256 protocolFee) = _redeem(id, msg.sender, receiver, shares);

        // transfer eth to receiver factoring in fees/shares
        (bool success,) = payable(receiver).call{value: assets}("");
        if (!success) {
            revert Errors.EthMultiVault_TransferFailed();
        }

        _transferFeesToProtocolMultisig(protocolFee);

        return assets;
    }

    /// @notice redeem shares from a bonding curve triple vault for assets
    ///
    /// @param shares the amount of shares to redeem
    /// @param receiver the address to receiver the assets
    /// @param tripleId the vault ID of the triple
    /// @param curveId the vault ID of the curve
    ///
    /// @return assets the amount of assets/eth withdrawn
    /// @dev This method is entirely separate from redeemTriple, because we wanted to leave the audited pathways intact.
    ///      This serves as an intermediary solution to enable users to interact with bonding curve vaults before
    ///      performing an audit of the full refactor (V2).
    function redeemTripleCurve(uint256 shares, address receiver, uint256 tripleId, uint256 curveId)
        external
        nonReentrant
        returns (uint256)
    {
        if (!isTripleId(tripleId)) {
            revert Errors.EthMultiVault_VaultNotTriple();
        }

        /*
            withdraw shares from vault, returning the amount of
            assets to be transferred to the receiver
        */
        (uint256 assets, uint256 protocolFee) = _redeemCurve(tripleId, curveId, msg.sender, receiver, shares);

        // transfer eth to receiver factoring in fees/shares
        (bool success,) = payable(receiver).call{value: assets}("");
        if (!success) {
            revert Errors.EthMultiVault_TransferFailed();
        }

        _transferFeesToProtocolMultisig(protocolFee);

        return assets;
    }

    /* =================================================== */
    /*                 INTERNAL METHODS                    */
    /* =================================================== */

    /// @dev transfer fees to the protocol multisig
    /// @param value the amount of eth to transfer
    function _transferFeesToProtocolMultisig(uint256 value) internal {
        if (value == 0) return;

        (bool success,) = payable(generalConfig.protocolMultisig).call{value: value}("");
        if (!success) {
            revert Errors.EthMultiVault_TransferFailed();
        }

        emit FeesTransferred(msg.sender, generalConfig.protocolMultisig, value);
    }

    /// @dev divides amount across the three atoms composing the triple and issues shares to
    ///      the receiver. Doesn't charge additional protocol fees, but it does charge entry fees on each deposit
    ///      into an atom vault.
    ///
    /// @param id the vault ID of the triple
    /// @param receiver the address to receive the shares
    /// @param amount the amount of eth to deposit
    ///
    /// @dev assumes funds have already been transferred to this contract
    function _depositAtomFraction(uint256 id, address receiver, uint256 amount) internal {
        // load atom IDs
        uint256[3] memory atomsIds;
        (atomsIds[0], atomsIds[1], atomsIds[2]) = getTripleAtoms(id);

        // floor div, so perAtom is slightly less than 1/3 of total input amount
        uint256 perAtom = amount / 3;

        // distribute proportional shares to each atom
        for (uint256 i = 0; i < 3; i++) {
            // deposit assets into each atom vault and mint shares for the receiver
            _deposit(receiver, atomsIds[i], perAtom);
        }
    }

    function _depositAtomFractionCurve(uint256 tripleId, uint256 curveId, address receiver, uint256 amount) internal {
        // load atom IDs
        uint256[3] memory atomsIds;
        (atomsIds[0], atomsIds[1], atomsIds[2]) = getTripleAtoms(tripleId);

        // floor div, so perAtom is slightly less than 1/3 of total input amount
        uint256 perAtom = amount / 3;

        // distribute proportional shares to each atom
        for (uint256 i = 0; i < 3; i++) {
            // deposit assets into each atom vault and mint shares for the receiver
            _depositCurve(receiver, atomsIds[i], curveId, perAtom);
        }
    }

    /// @dev deposit assets into a vault upon creation.
    ///      Changes the vault's total assets, total shares and balanceOf mappings to reflect the deposit.
    ///      Additionally, initializes a counter vault with ghost shares.
    ///
    /// @param id the vault ID of the atom or triple
    /// @param receiver the address to receive the shares
    /// @param assets the amount of eth to deposit
    function _depositOnVaultCreation(uint256 id, address receiver, uint256 assets) internal {
        bool isAtomWallet = receiver == computeAtomWalletAddr(id);

        // ghost shares minted to the admin upon vault creation for all newly created vaults
        uint256 ghostShares = generalConfig.minShare;

        uint256 sharesForReceiver = assets;

        // changes in vault's total assets and total shares (because ratio is 1:1 on vault creation)
        uint256 totalDelta = isAtomWallet ? sharesForReceiver : sharesForReceiver + ghostShares;

        // set vault totals for the vault
        _setVaultTotals(id, vaults[id].totalAssets + totalDelta, vaults[id].totalShares + totalDelta);

        // mint `sharesOwed` shares to sender factoring in fees
        _mint(receiver, id, sharesForReceiver);

        // mint `ghostShares` shares to admin to initialize the vault
        if (!isAtomWallet) {
            _mint(generalConfig.admin, id, ghostShares);
        }

        /// Initialize the counter triple vault with ghost shares if it is a triple creation flow
        if (isTripleId(id)) {
            uint256 counterVaultId = getCounterIdFromTriple(id);

            // set vault totals
            _setVaultTotals(
                counterVaultId,
                vaults[counterVaultId].totalAssets + ghostShares,
                vaults[counterVaultId].totalShares + ghostShares
            );

            // mint `ghostShares` shares to admin to initialize the vault
            _mint(generalConfig.admin, counterVaultId, ghostShares);
        }

        emit Deposited(
            msg.sender,
            receiver,
            vaults[id].balanceOf[receiver],
            assets, // userAssetsAfterTotalFees
            totalDelta, // sharesForReceiver
            0, // entryFee is not charged on vault creation
            id,
            isTripleId(id),
            isAtomWallet
        );
    }

    /// @notice Internal function to encapsulate the common deposit logic for both atoms and triples
    ///
    /// @param receiver the address to receive the shares
    /// @param id the vault ID of the atom or triple
    /// @param value the amount of eth to deposit
    ///
    /// @return sharesForReceiver the amount of shares minted
    function _deposit(address receiver, uint256 id, uint256 value) internal returns (uint256) {
        if (previewDeposit(value, id) == 0) {
            revert Errors.EthMultiVault_DepositOrWithdrawZeroShares();
        }

        (uint256 totalAssetsDelta, uint256 sharesForReceiver, uint256 userAssetsAfterTotalFees, uint256 entryFee) =
            getDepositSharesAndFees(value, id);

        if (totalAssetsDelta == 0) {
            revert Errors.EthMultiVault_InsufficientDepositAmountToCoverFees();
        }

        // set vault totals (assets and shares)
        _setVaultTotals(
            id,
            vaults[id].totalAssets + totalAssetsDelta,
            vaults[id].totalShares + sharesForReceiver // totalSharesDelta
        );

        // mint `sharesOwed` shares to sender factoring in fees
        _mint(receiver, id, sharesForReceiver);

        emit Deposited(
            msg.sender,
            receiver,
            vaults[id].balanceOf[receiver],
            userAssetsAfterTotalFees,
            sharesForReceiver,
            entryFee,
            id,
            isTripleId(id),
            false
        );

        return sharesForReceiver;
    }

    function _depositCurve(address receiver, uint256 id, uint256 curveId, uint256 value) internal returns (uint256) {
        if (previewDepositCurve(value, id, curveId) == 0) {
            revert Errors.EthMultiVault_DepositOrWithdrawZeroShares();
        }

        if (value + bondingCurveVaults[id][curveId].totalAssets > _registry().getCurveMaxAssets(curveId)) {
            revert Errors.EthMultiVault_DepositExceedsMaxAssets();
        }

        (uint256 totalAssetsDelta, uint256 sharesForReceiver, uint256 userAssetsAfterTotalFees, uint256 entryFee) =
            getDepositSharesAndFeesCurve(value, id, curveId);

        if (totalAssetsDelta == 0) {
            revert Errors.EthMultiVault_InsufficientDepositAmountToCoverFees();
        }

        // Increment pro rata vault ledger instead of curve vault ledger by fees
        if (entryFee > 0) {
            _setVaultTotals(id, vaults[id].totalAssets + entryFee, vaults[id].totalShares);
        }

        // Increment curve vault ledger by amount of assets left over after fees
        _increaseCurveVaultTotals(id, curveId, userAssetsAfterTotalFees, sharesForReceiver);

        // mint `sharesOwed` shares to sender factoring in fees
        _mintCurve(receiver, id, curveId, sharesForReceiver);

        // This will be revised after syncing with BE
        emit DepositedCurve(
            msg.sender,
            receiver,
            bondingCurveVaults[id][curveId].balanceOf[receiver],
            userAssetsAfterTotalFees,
            sharesForReceiver,
            entryFee,
            id,
            // isTripleId(id), // <-- Omitted because of stack too deep
            false
        );

        return sharesForReceiver;
    }

    /// @dev redeem shares out of a given vault.
    ///      Changes the vault's total assets, total shares and balanceOf mappings to reflect the withdrawal
    ///
    /// @param id the vault ID of the atom or triple
    /// @param sender the address to redeem the shares from
    /// @param receiver the address to receive the assets
    /// @param shares the amount of shares to redeem
    ///
    /// @return assetsForReceiver the amount of assets/eth to be transferred to the receiver
    /// @return protocolFee the amount of protocol fees deducted
    function _redeem(uint256 id, address sender, address receiver, uint256 shares)
        internal
        returns (uint256, uint256)
    {
        if (shares == 0) {
            revert Errors.EthMultiVault_DepositOrWithdrawZeroShares();
        }

        if (maxRedeem(sender, id) < shares) {
            revert Errors.EthMultiVault_InsufficientSharesInVault();
        }

        // uint256 remainingShares = vaults[id].totalShares - shares;
        if (vaults[id].totalShares - shares < generalConfig.minShare) {
            revert Errors.EthMultiVault_InsufficientRemainingSharesInVault(vaults[id].totalShares - shares);
        }

        (, uint256 assetsForReceiver, uint256 protocolFee, uint256 exitFee) = getRedeemAssetsAndFees(shares, id);

        // set vault totals (assets and shares)
        _setVaultTotals(
            id,
            vaults[id].totalAssets - (assetsForReceiver + protocolFee), // totalAssetsDelta
            vaults[id].totalShares - shares // totalSharesDelta
        );

        // burn shares, then transfer assets to receiver
        _burn(sender, id, shares);

        emit Redeemed(sender, receiver, vaults[id].balanceOf[sender], assetsForReceiver, shares, exitFee, id);

        return (assetsForReceiver, protocolFee);
    }

    /// @dev redeem shares out of a given bonding curve vault.
    ///      Changes the vault's total assets, total shares and balanceOf mappings to reflect the withdrawal
    ///
    /// @param id the vault ID of the atom or triple
    /// @param curveId the vault ID of the curve
    /// @param sender the address to redeem the shares from
    /// @param receiver the address to receive the assets
    /// @param shares the amount of shares to redeem
    ///
    /// @return assetsForReceiver the amount of assets/eth to be transferred to the receiver
    /// @return protocolFee the amount of protocol fees deducted
    function _redeemCurve(uint256 id, uint256 curveId, address sender, address receiver, uint256 shares)
        internal
        returns (uint256, uint256)
    {
        if (shares == 0) {
            revert Errors.EthMultiVault_DepositOrWithdrawZeroShares();
        }

        if (maxRedeemCurve(sender, id, curveId) < shares) {
            revert Errors.EthMultiVault_InsufficientSharesInVault();
        }

        (, uint256 assetsForReceiver, uint256 protocolFee, uint256 exitFee) =
            getRedeemAssetsAndFeesCurve(shares, id, curveId);


        // Increment pro rata vault ledger instead of curve vault ledger by fees
        if (exitFee > 0) {
            _setVaultTotals(id, vaults[id].totalAssets + exitFee, vaults[id].totalShares);
        }

        // Decrement curve vault ledger by amount of assets left over after fees
        _decreaseCurveVaultTotals(id, curveId, assetsForReceiver + protocolFee + exitFee, shares);


        // burn shares, then transfer assets to receiver
        _burnCurve(sender, id, curveId, shares);


        // Omitting this because of stack too deep, we can figure out what BE actually needs and trim this.
        emit RedeemedCurve(
            sender,
            receiver,
            bondingCurveVaults[id][curveId].balanceOf[sender],
            assetsForReceiver,
            shares, /*exitFee,*/
            id,
            curveId
        );


        return (assetsForReceiver, protocolFee);
    }

    /// @dev mint vault shares of vault ID `id` to address `to`
    ///
    /// @param to address to mint shares to
    /// @param id vault ID to mint shares for
    /// @param amount amount of shares to mint
    function _mint(address to, uint256 id, uint256 amount) internal {
        vaults[id].balanceOf[to] += amount;
    }

    function _mintCurve(address to, uint256 id, uint256 curveId, uint256 amount) internal {
        bondingCurveVaults[id][curveId].balanceOf[to] += amount;
    }

    /// @dev burn `amount` vault shares of vault ID `id` from address `from`
    ///
    /// @param from address to burn shares from
    /// @param id vault ID to burn shares from
    /// @param amount amount of shares to burn
    function _burn(address from, uint256 id, uint256 amount) internal {
        if (from == address(0)) revert Errors.EthMultiVault_BurnFromZeroAddress();

        uint256 fromBalance = vaults[id].balanceOf[from];
        if (fromBalance < amount) {
            revert Errors.EthMultiVault_BurnInsufficientBalance();
        }

        unchecked {
            vaults[id].balanceOf[from] = fromBalance - amount;
        }
    }

    function _burnCurve(address from, uint256 id, uint256 curveId, uint256 amount) internal {
        if (from == address(0)) revert Errors.EthMultiVault_BurnFromZeroAddress();

        uint256 fromBalance = bondingCurveVaults[id][curveId].balanceOf[from];
        if (fromBalance < amount) {
            revert Errors.EthMultiVault_BurnInsufficientBalance();
        }

        unchecked {
            bondingCurveVaults[id][curveId].balanceOf[from] = fromBalance - amount;
        }
    }

    /// @dev set total assets and shares for a vault
    ///
    /// @param id vault ID to set totals for
    /// @param totalAssets new total assets for the vault
    /// @param totalShares new total shares for the vault
    function _setVaultTotals(uint256 id, uint256 totalAssets, uint256 totalShares) internal {
        // Share price can only change when vault totals change
        uint256 oldSharePrice = currentSharePrice(id);
        vaults[id].totalAssets = totalAssets;
        vaults[id].totalShares = totalShares;
        uint256 newSharePrice = currentSharePrice(id);
        emit SharePriceChanged(id, newSharePrice, oldSharePrice);
    }

    /// @dev increase the total assets and shares for a given bonding curve vault
    ///
    /// @param id the vault ID of the atom or triple
    /// @param curveId the vault ID of the curve
    /// @param assetsDelta the amount of assets to increase the total assets by
    /// @param sharesDelta the amount of shares to increase the total shares by
    /// @dev emits an event, as this affects the share price of the specified bonding curve vault
    function _increaseCurveVaultTotals(uint256 id, uint256 curveId, uint256 assetsDelta, uint256 sharesDelta)
        internal
    {
        // Share price can only change when vault totals change
        uint256 oldSharePrice = currentSharePriceCurve(id, curveId);
        bondingCurveVaults[id][curveId].totalAssets += assetsDelta;
        bondingCurveVaults[id][curveId].totalShares += sharesDelta;
        uint256 newSharePrice = currentSharePriceCurve(id, curveId);
        emit SharePriceChangedCurve(id, curveId, newSharePrice, oldSharePrice);
    }

    /// @dev decrease the total assets and shares for a given bonding curve vault
    ///
    /// @param id the vault ID of the atom or triple
    /// @param curveId the vault ID of the curve
    /// @param assetsDelta the amount of assets to decrease the total assets by
    /// @param sharesDelta the amount of shares to decrease the total shares by
    /// @dev emits an event, as this affects the share price of the specified bonding curve vault
    function _decreaseCurveVaultTotals(uint256 id, uint256 curveId, uint256 assetsDelta, uint256 sharesDelta)
        internal
    {

        // Share price can only change when vault totals change
        uint256 oldSharePrice = currentSharePriceCurve(id, curveId);
        bondingCurveVaults[id][curveId].totalAssets -= assetsDelta;
        bondingCurveVaults[id][curveId].totalShares -= sharesDelta;
        uint256 newSharePrice = currentSharePriceCurve(id, curveId);
        emit SharePriceChangedCurve(id, curveId, newSharePrice, oldSharePrice);
    }

    /// @dev internal method for vault creation
    function _createVault() internal returns (uint256) {
        uint256 id = ++count;
        return id;
    }

    /* =================================================== */
    /*                    VIEW FUNCTIONS                   */
    /* =================================================== */

    /* -------------------------- */
    /*         Fee Helpers        */
    /* -------------------------- */

    /// @notice returns the cost of creating an atom
    /// @return atomCost the cost of creating an atom
    function getAtomCost() public view returns (uint256) {
        uint256 atomCost = atomConfig.atomCreationProtocolFee // paid to protocol
            + atomConfig.atomWalletInitialDepositAmount // for purchasing shares for atom wallet
            + generalConfig.minShare; // for purchasing ghost shares
        return atomCost;
    }

    /// @notice returns the cost of creating a triple
    /// @return tripleCost the cost of creating a triple
    function getTripleCost() public view returns (uint256) {
        uint256 tripleCost = tripleConfig.tripleCreationProtocolFee // paid to protocol
            + tripleConfig.atomDepositFractionOnTripleCreation // goes towards increasing the amount of assets in the underlying atom vaults
            + generalConfig.minShare * 2; // for purchasing ghost shares for the positive and counter triple vaults
        return tripleCost;
    }

    /// @notice returns the total fees that would be charged for depositing 'assets' into a vault
    ///
    /// @param assets amount of `assets` to calculate fees on
    /// @param id vault id to get corresponding fees for
    ///
    /// @return totalFees total fees that would be charged for depositing 'assets' into a vault
    function getDepositFees(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 protocolFee = protocolFeeAmount(assets, id);
        uint256 userAssetsAfterprotocolFee = assets - protocolFee;

        uint256 atomDepositFraction = atomDepositFractionAmount(userAssetsAfterprotocolFee, id);
        uint256 userAssetsAfterprotocolFeeAndAtomDepositFraction = userAssetsAfterprotocolFee - atomDepositFraction;

        uint256 entryFee = entryFeeAmount(userAssetsAfterprotocolFeeAndAtomDepositFraction, id);
        uint256 totalFees = protocolFee + atomDepositFraction + entryFee;

        return totalFees;
    }

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
        public
        view
        returns (uint256, uint256, uint256, uint256)
    {
        uint256 atomDepositFraction = atomDepositFractionAmount(assets, id);
        uint256 userAssetsAfterAtomDepositFraction = assets - atomDepositFraction;

        // changes in vault's total assets
        // if the vault is an atom vault `atomDepositFraction` is 0
        uint256 totalAssetsDelta = assets - atomDepositFraction;

        uint256 entryFee;

        if (vaults[id].totalShares == generalConfig.minShare) {
            entryFee = 0;
        } else {
            entryFee = entryFeeAmount(userAssetsAfterAtomDepositFraction, id);
        }

        // amount of assets that goes towards minting shares for the receiver
        uint256 userAssetsAfterTotalFees = userAssetsAfterAtomDepositFraction - entryFee;

        // user receives amount of shares as calculated by `convertToShares`
        uint256 sharesForReceiver = convertToShares(userAssetsAfterTotalFees, id);

        return (totalAssetsDelta, sharesForReceiver, userAssetsAfterTotalFees, entryFee);
    }

    function getDepositSharesAndFeesCurve(uint256 assets, uint256 id, uint256 curveId)
        public
        view
        returns (uint256, uint256, uint256, uint256)
    {
        uint256 atomDepositFraction = atomDepositFractionAmount(assets, id);
        uint256 userAssetsAfterAtomDepositFraction = assets - atomDepositFraction;

        // changes in vault's total assets
        // if the vault is an atom vault `atomDepositFraction` is 0
        uint256 totalAssetsDelta = assets - atomDepositFraction;

        uint256 entryFee;

        if (bondingCurveVaults[id][curveId].totalShares == generalConfig.minShare) {
            entryFee = 0;
        } else {
            entryFee = entryFeeAmount(userAssetsAfterAtomDepositFraction, id);
        }

        // amount of assets that goes towards minting shares for the receiver
        uint256 userAssetsAfterTotalFees = userAssetsAfterAtomDepositFraction - entryFee;

        // user receives amount of shares as calculated by `convertToShares`
        uint256 sharesForReceiver = convertToSharesCurve(userAssetsAfterTotalFees, id, curveId);

        return (totalAssetsDelta, sharesForReceiver, userAssetsAfterTotalFees, entryFee);
    }

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
        public
        view
        returns (uint256, uint256, uint256, uint256)
    {
        uint256 remainingShares = vaults[id].totalShares - shares;

        uint256 assetsForReceiverBeforeFees = convertToAssets(shares, id);
        uint256 protocolFee;
        uint256 exitFee;

        /*
         * if the redeem amount results in a zero share balance for
         * the associated vault, no exit fee is charged to avoid
         * admin accumulating disproportionate fee revenue via ghost
         * shares. Also, in case of an emergency redemption (i.e. when the
         * contract is paused), no exit fees are charged either.
         */
        if (paused()) {
            exitFee = 0;
            protocolFee = 0;
        } else if (remainingShares == generalConfig.minShare) {
            exitFee = 0;
            protocolFee = protocolFeeAmount(assetsForReceiverBeforeFees, id);
        } else {
            protocolFee = protocolFeeAmount(assetsForReceiverBeforeFees, id);
            uint256 assetsForReceiverAfterprotocolFee = assetsForReceiverBeforeFees - protocolFee;
            exitFee = exitFeeAmount(assetsForReceiverAfterprotocolFee, id);
        }

        uint256 totalUserAssets = assetsForReceiverBeforeFees;
        uint256 assetsForReceiver = assetsForReceiverBeforeFees - exitFee - protocolFee;

        return (totalUserAssets, assetsForReceiver, protocolFee, exitFee);
    }

    function getRedeemAssetsAndFeesCurve(uint256 shares, uint256 id, uint256 curveId)
        public
        view
        returns (uint256, uint256, uint256, uint256)
    {
        uint256 remainingShares = bondingCurveVaults[id][curveId].totalShares - shares;

        uint256 assetsForReceiverBeforeFees = convertToAssetsCurve(shares, id, curveId);
        uint256 protocolFee;
        uint256 exitFee;

        /*
         * if the redeem amount results in a zero share balance for
         * the associated vault, no exit fee is charged to avoid
         * admin accumulating disproportionate fee revenue via ghost
         * shares. Also, in case of an emergency redemption (i.e. when the
         * contract is paused), no exit fees are charged either.
         */
        if (paused()) {
            exitFee = 0;
            protocolFee = 0;
        } else if (remainingShares == generalConfig.minShare) {
            exitFee = 0;
            protocolFee = protocolFeeAmount(assetsForReceiverBeforeFees, id);
        } else {
            protocolFee = protocolFeeAmount(assetsForReceiverBeforeFees, id);
            uint256 assetsForReceiverAfterprotocolFee = assetsForReceiverBeforeFees - protocolFee;
            exitFee = exitFeeAmount(assetsForReceiverAfterprotocolFee, id);
        }

        uint256 totalUserAssets = assetsForReceiverBeforeFees;
        uint256 assetsForReceiver = assetsForReceiverBeforeFees - exitFee - protocolFee;

        return (totalUserAssets, assetsForReceiver, protocolFee, exitFee);
    }

    /// @notice returns amount of assets that would be charged for the entry fee given an amount of 'assets' provided
    ///
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    ///
    /// @return feeAmount amount of assets that would be charged for the entry fee
    /// @dev if the vault being deposited on has a vault total shares of 0, the entry fee is not applied
    function entryFeeAmount(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 entryFee = vaultFees[id].entryFee;
        uint256 feeAmount = _feeOnRaw(assets, entryFee == 0 ? vaultFees[0].entryFee : entryFee);
        return feeAmount;
    }

    /// @notice returns amount of assets that would be charged for the exit fee given an amount of 'assets' provided
    ///
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    ///
    /// @return feeAmount amount of assets that would be charged for the exit fee
    /// @dev if the vault  being redeemed from given the shares to redeem results in a total shares after of 0,
    ///       the exit fee is not applied
    function exitFeeAmount(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 exitFee = vaultFees[id].exitFee;
        uint256 feeAmount = _feeOnRaw(assets, exitFee == 0 ? vaultFees[0].exitFee : exitFee);
        return feeAmount;
    }

    /// @notice returns amount of assets that would be charged by a vault on protocol fee given amount of 'assets'
    ///         provided
    ///
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    ///
    /// @return feeAmount amount of assets that would be charged by vault on protocol fee
    function protocolFeeAmount(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 protocolFee = vaultFees[id].protocolFee;
        uint256 feeAmount = _feeOnRaw(assets, protocolFee == 0 ? vaultFees[0].protocolFee : protocolFee);
        return feeAmount;
    }

    /// @notice returns atom deposit fraction given amount of 'assets' provided
    ///
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id
    ///
    /// @return feeAmount amount of assets that would be used as atom deposit fraction
    /// @dev only applies to triple vaults
    function atomDepositFractionAmount(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 feeAmount = isTripleId(id) ? _feeOnRaw(assets, tripleConfig.atomDepositFractionForTriple) : 0;
        return feeAmount;
    }

    /// @notice calculates fee on raw amount
    ///
    /// @param amount amount of assets to calculate fee on
    /// @param fee fee in %
    ///
    /// @return amount of assets that would be charged as fee
    function _feeOnRaw(uint256 amount, uint256 fee) internal view returns (uint256) {
        return amount.mulDivUp(fee, generalConfig.feeDenominator);
    }

    /* -------------------------- */
    /*     Accounting Helpers     */
    /* -------------------------- */

    /// @notice returns the current share price for the given vault id
    /// @param id vault id to get corresponding share price for
    /// @return price current share price for the given vault id, scaled by generalConfig.decimalPrecision
    function currentSharePrice(uint256 id) public view returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        // Changing this to match exactly how convertToShares is calculated
        // This was not previously used internally in production code
        uint256 price = supply == 0 ? 0 : vaults[id].totalAssets.mulDiv(generalConfig.decimalPrecision, supply);
        return price;
    }

    /// @notice returns the current share price for the given vault id and curve id
    /// @param id vault id to get corresponding share price for
    /// @param curveId curve id to get corresponding share price for
    /// @return price current share price for the given vault id and curve id, scaled by generalConfig.decimalPrecision
    function currentSharePriceCurve(uint256 id, uint256 curveId) public view returns (uint256) {
        uint256 supply = bondingCurveVaults[id][curveId].totalShares;
        uint256 totalAssets = bondingCurveVaults[id][curveId].totalAssets;
        uint256 basePrice = supply == 0 ? 0 : _registry().currentPrice(supply, curveId);
        uint256 price = basePrice;

        // Pool Ratio Adjustment
        if (totalAssets != 0 && supply != 0) {
            uint256 totalSharesInAssetSpace = _registry().convertToAssets(supply, supply, totalAssets, curveId);
            if (totalSharesInAssetSpace != 0) {
                price = price.mulDiv(totalAssets * generalConfig.decimalPrecision, totalSharesInAssetSpace);
            }
        }
        return price;
    }

    /// @notice returns max amount of eth that can be deposited into the vault
    /// @return maxDeposit max amount of eth that can be deposited into the vault
    function maxDeposit() public pure returns (uint256) {
        return type(uint256).max;
    }

    /// @notice returns max amount of assets that can be deposited into a bonding curve vault
    /// @param curveId the vault ID of the curve
    /// @return maxDepositCurve max amount of assets that can be deposited into the bonding curve vault
    /// @dev Tells the registry to ask the specified curve what its asset limits are.
    function maxDepositCurve(uint256 curveId) public view returns (uint256) {
        return _registry().getCurveMaxAssets(curveId);
    }

    /// @notice returns max amount of shares that can be redeemed from the 'sender' balance through a redeem call
    ///
    /// @param sender address of the account to get max redeemable shares for
    /// @param id vault id to get corresponding shares for
    ///
    /// @return shares amount of shares that can be redeemed from the 'sender' balance through a redeem call
    function maxRedeem(address sender, uint256 id) public view returns (uint256) {
        uint256 shares = vaults[id].balanceOf[sender];
        return shares;
    }

    /// @notice returns max amount of shares that can be redeemed from a bonding curve vault
    /// @param sender the address to redeem the shares from
    /// @param id the vault ID of the atom or triple
    /// @param curveId the vault ID of the curve
    /// @return shares the amount of shares that can be redeemed from the 'sender' balance through a redeem call
    function maxRedeemCurve(address sender, uint256 id, uint256 curveId) public view returns (uint256) {
        uint256 shares = bondingCurveVaults[id][curveId].balanceOf[sender];
        return shares;
    }

    /// @notice returns amount of shares that would be exchanged by vault given amount of 'assets' provided
    /// @param assets amount of assets to calculate shares on
    /// @param id vault id to get corresponding shares for
    /// @return shares amount of shares that would be exchanged by vault given amount of 'assets' provided
    /// @notice For regular vaults, shares maintain a linear relationship with assets:
    ///  $shares = assets \cdot \frac{S_{total}}{A_{total}}$
    /// ### Where:
    ///  $S_{total}$ = the total supply of shares
    ///  $A_{total}$ = the total assets in the vault
    /// @dev TLDR: Since assets and shares maintain a 1:1 relationship, we only need simple proportion math.
    ///  No domain conversion needed because 1 dollar worth of assets always equals 1 dollar worth of shares.
    function convertToShares(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        return assets.mulDiv(supply, vaults[id].totalAssets);
    }

    /// @notice returns amount of shares that would be exchanged by vault given amount of 'assets' provided
    /// @param assets amount of assets to calculate shares on
    /// @param id vault id to get corresponding shares for
    /// @param curveId vault id of the curve
    /// @return shares amount of shares that would be exchanged by vault given amount of 'assets' provided
    /// @notice The conversion happens in two steps:
    ///  1. First, we get the base shares from the bonding curve: 
    ///  $$s_{base} = f_{curve}(assets)$$
    ///  2. Then we apply a pool ratio adjustment to account for divergence between total assets and shares:
    ///  $$s_{final} = s_{base} \cdot \frac{S_{total}}{A_{total}^{(s)}}$$
    ///  ### Where:
    ///  1. $S_{total}$ is the total supply of shares
    ///  2. $A_{total}^{(s)} = f_{curve}^{-1}(A_{total})$ is the total assets converted to share domain
    ///        using the inverse of the bonding curve function
    /// @notice This adjustment is necessary because the actual ratio of assets:shares may drift from
    ///      the bonding curve's 'pure' conversion ratio due to:
    ///  - Protocol fees being taken in assets
    ///  - Share burns
    ///  - Direct asset transfers/airdrops
    /// @notice For example, if the pool has fewer assets than the curve expects for its share supply
    ///     (due to fees), new depositors will receive proportionally more shares to maintain fairness.
    /// @notice The crucial conversion of assets to share domain ($A_{total}^{(s)}$) ensures we're comparing
    ///      quantities in the same space, as the bonding curve defines a non-linear relationship
    ///      between assets and shares.
    /// @dev TLDR: You need to exchange apples for oranges and they each have their own wholesale discount tiers.
    ///     So you need to compute their value using a common denominator like dollars.
    function convertToSharesCurve(uint256 assets, uint256 id, uint256 curveId) public view returns (uint256) {
        uint256 supply = bondingCurveVaults[id][curveId].totalShares;
        uint256 totalAssets = bondingCurveVaults[id][curveId].totalAssets;

        uint256 shares = _registry().previewDeposit(assets, totalAssets, supply, curveId);

        // Pool Ratio Adjustment
        if (totalAssets != 0 && supply != 0) {
            uint256 totalAssetsInShareSpace = _registry().convertToShares(totalAssets, 0, 0, curveId);
            if (totalAssetsInShareSpace != 0) {
                shares = shares * totalAssetsInShareSpace / supply;
            }
        }
        return shares;
    }

    /// @notice returns amount of assets that would be exchanged by vault given amount of 'shares' provided
    /// @param shares amount of shares to calculate assets on
    /// @param id vault id to get corresponding assets for
    /// @return assets amount of assets that would be exchanged by vault given amount of 'shares' provided
    /// @notice For regular vaults, assets maintain a linear relationship with shares:
    ///  $assets = shares \cdot \frac{A_{total}}{S_{total}}$
    /// ### Where:
    ///  - $S_{total}$ is the total supply of shares
    ///  - $A_{total}$ is the total assets in the vault
    /// @dev TLDR: Since assets and shares maintain a 1:1 relationship, we only need simple proportion math.
    ///  No domain conversion needed because 1 dollar worth of shares always equals 1 dollar worth of assets.
    function convertToAssets(uint256 shares, uint256 id) public view returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        uint256 assets = supply == 0 ? shares : shares.mulDiv(vaults[id].totalAssets, supply);
        return assets;
    }

    /// @notice returns amount of assets that would be exchanged by vault given amount of 'shares' provided
    /// @param shares amount of shares to calculate assets on
    /// @param id vault id to get corresponding assets for
    /// @param curveId vault id of the curve
    /// @return assets amount of assets that would be exchanged by vault given amount of 'shares' provided
    /// @notice The conversion happens in two steps:
    ///  1. First, we get the base assets from the bonding curve: 
    ///  $$a_{base} = f_{curve}^{-1}(shares)$$
    ///  2. Then we apply a pool ratio adjustment to account for divergence between total assets and shares:
    ///  $$a_{final} = a_{base} \cdot \frac{A_{total}}{S_{total}^{(a)}}$$
    /// ### Where:
    ///  1. $A_{total}$ is the total assets in the vault
    ///  2. $S_{total}^{(a)} = f_{curve}(S_{total})$ is the total shares converted to asset domain
    ///    using the bonding curve function
    /// @notice This adjustment is necessary because the actual ratio of shares:assets may drift from
    /// the bonding curve's 'pure' conversion ratio due to:
    ///  - Protocol fees being taken in assets
    ///  - Share burns
    ///  - Direct asset transfers/airdrops
    /// @notice For example, if the pool has fewer assets than the curve expects for its share supply
    /// (due to fees), redeemers will receive proportionally fewer assets to maintain fairness.
    /// @notice The crucial conversion of shares to asset domain ($S_{total}^{(a)}$) ensures we're comparing
    ///  quantities in the same space, as the bonding curve defines a non-linear relationship
    ///  between shares and assets.
    /// @dev TLDR: You need to exchange oranges for apples and they each have their own wholesale discount tiers.
    ///  So you need to compute their value using a common denominator like dollars.
    function convertToAssetsCurve(uint256 shares, uint256 id, uint256 curveId) public view returns (uint256) {
        uint256 supply = bondingCurveVaults[id][curveId].totalShares;
        uint256 totalAssets = bondingCurveVaults[id][curveId].totalAssets;
        uint256 assets = _registry().previewRedeem(shares, supply, totalAssets, curveId);

        // // Pool Ratio Adjustment
        if (totalAssets != 0 && supply != 0) {
            uint256 totalSharesInAssetSpace = _registry().convertToAssets(supply, supply, totalAssets, curveId);
            if (totalSharesInAssetSpace != 0) {
                assets = assets * totalSharesInAssetSpace / totalAssets;
            }
        }
        return assets;
    }

    /// @notice simulates the effects of the deposited amount of 'assets' and returns the estimated
    ///         amount of shares that would be minted from the deposit of `assets`
    ///
    /// @param assets amount of assets to calculate shares on
    /// @param id vault id to get corresponding shares for
    ///
    /// @return shares amount of shares that would be minted from the deposit of `assets`
    /// @dev this function pessimistically estimates the amount of shares that would be minted from the
    ///       input amount of assets so if the vault is empty before the deposit the caller receives more
    ///       shares than returned by this function, reference internal _depositIntoVault logic for details
    function previewDeposit(
        uint256 assets, // should always be msg.value
        uint256 id
    ) public view returns (uint256) {
        (, uint256 sharesForReceiver,,) = getDepositSharesAndFees(assets, id);
        return sharesForReceiver;
    }

    function previewDepositCurve(
        uint256 assets, // should always be msg.value
        uint256 id,
        uint256 curveId
    ) public view returns (uint256) {
        (, uint256 sharesForReceiver,,) = getDepositSharesAndFeesCurve(assets, id, curveId);
        return sharesForReceiver;
    }

    /// @notice simulates the effects of the redemption of `shares` and returns the estimated
    ///         amount of assets estimated to be returned to the receiver of the redeem
    ///
    /// @param shares amount of shares to calculate assets on
    /// @param id vault id to get corresponding assets for
    ///
    /// @return assets amount of assets estimated to be returned to the receiver
    function previewRedeem(uint256 shares, uint256 id) public view returns (uint256) {
        (, uint256 assetsForReceiver,,) = getRedeemAssetsAndFees(shares, id);
        return assetsForReceiver;
    }

    function previewRedeemCurve(uint256 shares, uint256 id, uint256 curveId) public view returns (uint256) {
        (, uint256 assetsForReceiver,,) = getRedeemAssetsAndFeesCurve(shares, id, curveId);
        return assetsForReceiver;
    }

    /* -------------------------- */
    /*       Triple Helpers       */
    /* -------------------------- */

    /// @notice returns the corresponding hash for the given RDF triple, given the triple vault id
    /// @param id vault id of the triple
    /// @return hash the corresponding hash for the given RDF triple
    /// @dev only applies to triple vault IDs as input
    function tripleHash(uint256 id) public view returns (bytes32) {
        uint256[3] memory atomIds;
        (atomIds[0], atomIds[1], atomIds[2]) = getTripleAtoms(id);
        return keccak256(abi.encodePacked(atomIds[0], atomIds[1], atomIds[2]));
    }

    /// @notice returns whether the supplied vault id is a triple
    /// @param id vault id to check
    /// @return bool whether the supplied vault id is a triple
    function isTripleId(uint256 id) public view returns (bool) {
        bool isCounterTriple = id > type(uint256).max / 2;
        return isCounterTriple ? isTriple[type(uint256).max - id] : isTriple[id];
    }

    /// @notice returns the atoms that make up a triple/counter-triple
    /// @param id vault id of the triple/counter-triple
    /// @return tuple(atomIds) the atoms that make up the triple/counter-triple
    /// @dev only applies to triple vault IDs as input
    function getTripleAtoms(uint256 id) public view returns (uint256, uint256, uint256) {
        bool isCounterTriple = id > type(uint256).max / 2;
        uint256[3] memory atomIds = isCounterTriple ? triples[type(uint256).max - id] : triples[id];
        return (atomIds[0], atomIds[1], atomIds[2]);
    }

    /// @notice returns the corresponding hash for the given RDF triple, given the atoms that make up the triple
    ///
    /// @param subjectId the subject atom's vault id
    /// @param predicateId the predicate atom's vault id
    /// @param objectId the object atom's vault id
    ///
    /// @return hash the corresponding hash for the given RDF triple based on the atom vault ids
    function tripleHashFromAtoms(uint256 subjectId, uint256 predicateId, uint256 objectId)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(subjectId, predicateId, objectId));
    }

    /// @notice returns the counter id from the given triple id
    /// @param id vault id of the triple
    /// @return counterId the counter vault id from the given triple id
    /// @dev only applies to triple vault IDs as input
    function getCounterIdFromTriple(uint256 id) public pure returns (uint256) {
        return type(uint256).max - id;
    }

    /* -------------------------- */
    /*        Misc. Helpers       */
    /* -------------------------- */

    /// @notice returns the address of the atom warden
    function getAtomWarden() external view returns (address) {
        return walletConfig.atomWarden;
    }

    /// @notice returns the number of shares and assets (less fees) user has in the vault
    ///
    /// @param vaultId vault id of the vault
    /// @param receiver address of the receiver
    ///
    /// @return shares number of shares user has in the vault
    /// @return assets number of assets user has in the vault
    function getVaultStateForUser(uint256 vaultId, address receiver) external view returns (uint256, uint256) {
        uint256 shares = vaults[vaultId].balanceOf[receiver];
        (uint256 totalUserAssets,,,) = getRedeemAssetsAndFees(shares, vaultId);
        return (shares, totalUserAssets);
    }

    function getVaultStateForUserCurve(uint256 vaultId, uint256 curveId, address receiver)
        external
        view
        returns (uint256, uint256)
    {
        uint256 shares = bondingCurveVaults[vaultId][curveId].balanceOf[receiver];
        (uint256 totalUserAssets,,,) = getRedeemAssetsAndFeesCurve(shares, vaultId, curveId);
        return (shares, totalUserAssets);
    }

    /// @notice returns the Atom Wallet address for the given atom data
    /// @param id vault id of the atom associated to the atom wallet
    /// @return atomWallet the address of the atom wallet
    /// @dev the create2 salt is based off of the vault ID
    function computeAtomWalletAddr(uint256 id) public view returns (address) {
        // compute salt for create2
        bytes32 salt = bytes32(id);

        // get contract deployment data
        bytes memory data = _getDeploymentData();

        // compute the raw contract address
        bytes32 rawAddress = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(data)));

        return address(bytes20(rawAddress << 96));
    }

    /// @dev checks if an account holds shares in the vault counter to the id provided
    ///
    /// @param id the id of the vault to check
    /// @param receiver the account to check
    ///
    /// @return bool whether the account holds shares in the counter vault to the id provided or not
    function _hasCounterStake(uint256 id, address receiver) internal view returns (bool) {
        if (!isTripleId(id)) {
            revert Errors.EthMultiVault_VaultNotTriple();
        }

        return vaults[type(uint256).max - id].balanceOf[receiver] > 0;
    }

    function _hasCounterStakeCurve(uint256 id, uint256 curveId, address receiver) internal view returns (bool) {
        if (!isTripleId(id)) {
            revert Errors.EthMultiVault_VaultNotTriple();
        }

        return bondingCurveVaults[type(uint256).max - id][curveId].balanceOf[receiver] > 0;
    }

    /// @dev returns the deployment data for the AtomWallet contract
    /// @return bytes memory the deployment data for the AtomWallet contract (using BeaconProxy pattern)
    function _getDeploymentData() internal view returns (bytes memory) {
        // Address of the atomWalletBeacon contract
        address beaconAddress = walletConfig.atomWalletBeacon;

        // BeaconProxy creation code
        bytes memory code = type(BeaconProxy).creationCode;

        // encode the init function of the AtomWallet contract with constructor arguments
        bytes memory initData =
            abi.encodeWithSelector(AtomWallet.init.selector, IEntryPoint(walletConfig.entryPoint), address(this));

        // encode constructor arguments of the BeaconProxy contract (address beacon, bytes memory data)
        bytes memory encodedArgs = abi.encode(beaconAddress, initData);

        // concatenate the BeaconProxy creation code with the ABI-encoded constructor arguments
        return abi.encodePacked(code, encodedArgs);
    }

    /// @dev internal method to validate the timelock constraints
    /// @param operationHash hash of the operation
    function _validateTimelock(bytes32 operationHash) internal view {
        Timelock memory timelock = timelocks[operationHash];

        if (timelock.readyTime == 0) {
            revert Errors.EthMultiVault_OperationNotScheduled();
        }
        if (timelock.executed) {
            revert Errors.EthMultiVault_OperationAlreadyExecuted();
        }
        if (timelock.readyTime > block.timestamp) {
            revert Errors.EthMultiVault_TimelockNotExpired();
        }
    }

    function _registry() internal view returns (IBondingCurveRegistry) {
        return IBondingCurveRegistry(bondingCurveConfig.registry);
    }
}
