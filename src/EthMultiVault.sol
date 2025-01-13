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
import {AdminControl} from "src/utils/AdminControl.sol";
import {AdminControl} from "src/utils/AdminControl.sol";
import {IModel} from "src/interfaces/IModel.sol";

/**
 * @title  EthMultiVault
 * @author 0xIntuition
 * @notice Core contract of the Intuition protocol. Manages the creation and management of vaults
 *         associated with atoms & triples.
 */
contract EthMultiVault is IEthMultiVault, IModel, Initializable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using FixedPointMathLib for uint256;
    using LibZip for bytes;

    /* =================================================== */
    /*                  STATE VARIABLES                    */
    /* =================================================== */

    // // Operation identifiers
    // bytes32 public constant SET_ADMIN = keccak256("setAdmin");
    // bytes32 public constant SET_EXIT_FEE = keccak256("setExitFee");

    // /// @notice Configuration structs
    // GeneralConfig public generalConfig;
    // AtomConfig public atomConfig;
    // TripleConfig public tripleConfig;
    // WalletConfig public walletConfig;

    /// @notice ID of the last vault to be created
    uint256 public count;

    /// @notice Mapping of vault ID to vault state
    // Vault ID -> Vault State
    mapping(uint256 vaultId => VaultState vaultState) public vaults;

    // /// @notice Mapping of vault ID to vault fees
    // // Vault ID -> Vault Fees
    // mapping(uint256 vaultId => VaultFees vaultFees) public vaultFees;

    // /// @notice Mapping of receiver to sender to determine if a sender is allowed to deposit assets on behalf of a receiver
    // // Receiver -> Sender -> Is Approved
    // mapping(address receiver => mapping(address sender => bool isApproved)) public approvals;

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

    // /// @notice Timelock mapping (operation hash -> timelock struct)
    // mapping(bytes32 operationHash => Timelock timelock) public timelocks;

    // /// @notice Bonding Curve Vaults (termId -> curveId -> vaultState)
    // mapping(uint256 vaultId => mapping(uint256 curveId => VaultState vaultState)) public bondingCurveVaults;

    // /// @notice Bonding Curve Configurations
    // BondingCurveConfig public bondingCurveConfig;

    /// @notice Admin control contract
    AdminControl public adminControl;

    /// @notice Address of the bonding curve contract
    address public bondingCurve;

    /// @dev Gap for upgrade safety
    uint256[47] private __gap;

    /* =================================================== */
    /*                    MODIFIERS                        */
    /* =================================================== */

    /// @notice Modifier to restrict a function to the admin
    modifier onlyAdmin() {
        if (msg.sender != adminControl.getGeneralConfig().admin) {
            revert Errors.EthMultiVault_AdminOnly();
        }
        _;
    }

    /// @notice Modifier to restrict a function to the bonding curve contract
    modifier onlyBondingCurve() {
        if (msg.sender != bondingCurve) {
            revert Errors.EthMultiVault_BondingCurveOnly();
        }
        _;
    }

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    /// @notice Initializes the EthMultiVault contract
    /// @param _adminControl address of the admin control contract
    /// NOTE: This function is called only once (during contract deployment)
    function init(address _adminControl) external initializer {
        __ReentrancyGuard_init();
        __Pausable_init();

        if (_adminControl == address(0)) {
            revert Errors.EthMultiVault_AdminControlNotSet();
        }

        adminControl = AdminControl(_adminControl);
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

    /// @dev sets the admin control contract
    /// @param _adminControl address of the admin control contract
    function setAdminControl(address _adminControl) external onlyAdmin {
        if (_adminControl == address(0)) {
            revert Errors.EthMultiVault_AdminControlNotSet();
        }

        adminControl = AdminControl(_adminControl);
    }

    /// @dev sets the bonding curve contract
    /// @param _bondingCurve address of the bonding curve contract
    function setBondingCurve(address _bondingCurve) external onlyAdmin {
        if (_bondingCurve == address(0)) {
            revert Errors.EthMultiVault_BondingCurveNotSet();
        }

        bondingCurve = _bondingCurve;
    }

    /* =================================================== */
    /*                MUTATIVE FUNCTIONS                   */
    /* =================================================== */

    /// @notice deploy a given atom wallet
    /// @param atomId vault id of atom
    /// @return atomWallet the address of the atom wallet
    /// NOTE: deploys an ERC4337 account (atom wallet) through a BeaconProxy. Reverts if the atom vault does not exist
    function deployAtomWallet(uint256 atomId) external returns (address) {
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
    /*         Create Atom        */
    /* -------------------------- */

    /// @notice Create an atom and return its vault id
    /// @param atomUri atom data to create atom with
    /// @return id vault id of the atom
    /// NOTE: This function will revert if called with less than `getAtomCost()` in `msg.value`
    function createAtom(bytes calldata atomUri) external payable nonReentrant whenNotPaused returns (uint256) {
        if (msg.value < getAtomCost()) {
            revert Errors.EthMultiVault_InsufficientBalance();
        }

        // create atom and get the protocol deposit fee
        (uint256 id, uint256 protocolDepositFee) = _createAtom(atomUri, msg.value);

        uint256 totalFeesForProtocol = adminControl.getAtomConfig().atomCreationProtocolFee + protocolDepositFee;
        transferFeesToProtocolMultisig(totalFeesForProtocol);

        return id;
    }

    /// @notice Batch create atoms and return their vault ids
    /// @param atomUris atom data array to create atoms with
    /// @return ids vault ids array of the atoms
    /// NOTE: This function will revert if called with less than `getAtomCost()` * `atomUris.length` in `msg.value`
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

        uint256 totalFeesForProtocol =
            adminControl.getAtomConfig().atomCreationProtocolFee * length + protocolDepositFeeTotal;
        transferFeesToProtocolMultisig(totalFeesForProtocol);

        return ids;
    }

    /// @notice Internal utility function to create an atom and handle vault creation
    ///
    /// @param atomUri The atom data to create an atom with
    /// @param value The value sent with the transaction
    ///
    /// @return id The new vault ID created for the atom
    function _createAtom(bytes calldata atomUri, uint256 value) internal returns (uint256, uint256) {
        if (atomUri.length > adminControl.getGeneralConfig().atomUriMaxLength) {
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
            adminControl.getAtomConfig().atomWalletInitialDepositAmount
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
    /// NOTE: This function will revert if called with less than `getTripleCost()` in `msg.value`.
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

        uint256 totalFeesForProtocol = adminControl.getTripleConfig().tripleCreationProtocolFee + protocolDepositFee;
        transferFeesToProtocolMultisig(totalFeesForProtocol);

        return id;
    }

    /// @notice batch create triples and return their vault ids
    ///
    /// @param subjectIds vault ids array of subject atoms
    /// @param predicateIds vault ids array of predicate atoms
    /// @param objectIds vault ids array of object atoms
    ///
    /// NOTE: This function will revert if called with less than `getTripleCost()` * `array.length` in `msg.value`.
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

        uint256 totalFeesForProtocol =
            adminControl.getTripleConfig().tripleCreationProtocolFee * length + protocolDepositFeeTotal;
        transferFeesToProtocolMultisig(totalFeesForProtocol);

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

        if (adminControl.getTripleConfig().atomDepositFractionOnTripleCreation > 0) {
            for (uint256 i = 0; i < 3; i++) {
                uint256 atomId = tripleAtomIds[i];
                // increase the total assets in each underlying atom vault
                _setVaultTotals(
                    atomId,
                    vaults[atomId].totalAssets
                        + (adminControl.getTripleConfig().atomDepositFractionOnTripleCreation / 3),
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
    /// NOTE: this function will revert if the minimum deposit amount of eth is not met and
    ///       if the vault ID does not exist/is not an atom.
    function depositAtom(address receiver, uint256 id) external payable nonReentrant whenNotPaused returns (uint256) {
        if (msg.sender != receiver && !adminControl.isApproved(receiver, msg.sender)) {
            revert Errors.EthMultiVault_SenderNotApproved();
        }

        if (id == 0 || id > count) {
            revert Errors.EthMultiVault_VaultDoesNotExist();
        }

        if (isTripleId(id)) {
            revert Errors.EthMultiVault_VaultNotAtom();
        }

        if (msg.value < adminControl.getGeneralConfig().minDeposit) {
            revert Errors.EthMultiVault_MinimumDeposit();
        }

        uint256 protocolFee = protocolFeeAmount(msg.value, id);
        uint256 userDepositAfterprotocolFee = msg.value - protocolFee;

        // deposit eth into vault and mint shares for the receiver
        uint256 shares = _deposit(receiver, id, userDepositAfterprotocolFee);

        transferFeesToProtocolMultisig(protocolFee);

        return shares;
    }

    /// @notice redeem shares from an atom vault for assets
    ///
    /// @param shares the amount of shares to redeem
    /// @param receiver the address to receiver the assets
    /// @param id the vault ID of the atom
    ///
    /// @return assets the amount of assets/eth withdrawn
    /// NOTE: Emergency redemptions without any fees being charged are always possible, even if the contract is paused
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

        transferFeesToProtocolMultisig(protocolFee);

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
    /// NOTE: this function will revert if the minimum deposit amount of eth is not met and
    ///       if the vault ID does not exist/is not a triple.
    function depositTriple(address receiver, uint256 id)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (msg.sender != receiver && !adminControl.isApproved(receiver, msg.sender)) {
            revert Errors.EthMultiVault_SenderNotApproved();
        }

        if (!isTripleId(id)) {
            revert Errors.EthMultiVault_VaultNotTriple();
        }

        if (_hasCounterStake(id, receiver)) {
            revert Errors.EthMultiVault_HasCounterStake();
        }

        if (msg.value < adminControl.getGeneralConfig().minDeposit) {
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

        transferFeesToProtocolMultisig(protocolFee);

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
    /// NOTE: Emergency redemptions without any fees being charged are always possible, even if the contract is paused
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

        transferFeesToProtocolMultisig(protocolFee);

        return assets;
    }

    /// @notice increment the total assets and shares of a vault
    /// @param id the vault ID of the atom or triple
    /// @param value the amount of assets or shares to increment
    function incrementVault(uint256 id, uint256 value) external onlyBondingCurve {
        _setVaultTotals(id, vaults[id].totalAssets + value, vaults[id].totalShares + value);
    }

    /* =================================================== */
    /*                 INTERNAL METHODS                    */
    /* =================================================== */

    /// @dev transfer fees to the protocol multisig
    /// @param value the amount of eth to transfer
    function transferFeesToProtocolMultisig(uint256 value) public {
        if (value == 0) return;

        (bool success,) = payable(adminControl.getGeneralConfig().protocolMultisig).call{value: value}("");
        if (!success) {
            revert Errors.EthMultiVault_TransferFailed();
        }

        emit FeesTransferred(msg.sender, adminControl.getGeneralConfig().protocolMultisig, value);
    }

    /// @dev divides amount across the three atoms composing the triple and issues shares to
    ///      the receiver. Doesn't charge additional protocol fees, but it does charge entry fees on each deposit
    ///      into an atom vault.
    ///
    /// @param id the vault ID of the triple
    /// @param receiver the address to receive the shares
    /// @param amount the amount of eth to deposit
    ///
    /// NOTE: assumes funds have already been transferred to this contract
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
        uint256 ghostShares = adminControl.getGeneralConfig().minShare;

        uint256 sharesForReceiver = assets;

        // changes in vault's total assets and total shares (because ratio is 1:1 on vault creation)
        uint256 totalDelta = isAtomWallet ? sharesForReceiver : sharesForReceiver + ghostShares;

        // set vault totals for the vault
        _setVaultTotals(id, vaults[id].totalAssets + totalDelta, vaults[id].totalShares + totalDelta);

        // mint `sharesOwed` shares to sender factoring in fees
        _mint(receiver, id, sharesForReceiver);

        // mint `ghostShares` shares to admin to initialize the vault
        if (!isAtomWallet) {
            _mint(adminControl.getGeneralConfig().admin, id, ghostShares);
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
            _mint(adminControl.getGeneralConfig().admin, counterVaultId, ghostShares);
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
        if (vaults[id].totalShares - shares < adminControl.getGeneralConfig().minShare) {
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

    /// @dev mint vault shares of vault ID `id` to address `to`
    ///
    /// @param to address to mint shares to
    /// @param id vault ID to mint shares for
    /// @param amount amount of shares to mint
    function _mint(address to, uint256 id, uint256 amount) internal {
        vaults[id].balanceOf[to] += amount;
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
        uint256 atomCost = adminControl.getAtomConfig().atomCreationProtocolFee // paid to protocol
            + adminControl.getAtomConfig().atomWalletInitialDepositAmount // for purchasing shares for atom wallet
            + adminControl.getGeneralConfig().minShare; // for purchasing ghost shares
        return atomCost;
    }

    /// @notice returns the cost of creating a triple
    /// @return tripleCost the cost of creating a triple
    function getTripleCost() public view returns (uint256) {
        uint256 tripleCost = adminControl.getTripleConfig().tripleCreationProtocolFee // paid to protocol
            + adminControl.getTripleConfig().atomDepositFractionOnTripleCreation // goes towards increasing the amount of assets in the underlying atom vaults
            + adminControl.getGeneralConfig().minShare * 2; // for purchasing ghost shares for the positive and counter triple vaults
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

        if (vaults[id].totalShares == adminControl.getGeneralConfig().minShare) {
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
        } else if (remainingShares == adminControl.getGeneralConfig().minShare) {
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
    /// NOTE: if the vault being deposited on has a vault total shares of 0, the entry fee is not applied
    function entryFeeAmount(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 entryFee = adminControl.getVaultFees(id).entryFee;
        uint256 feeAmount = _feeOnRaw(assets, entryFee == 0 ? adminControl.getVaultFees(0).entryFee : entryFee);
        return feeAmount;
    }

    /// @notice returns amount of assets that would be charged for the exit fee given an amount of 'assets' provided
    ///
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    ///
    /// @return feeAmount amount of assets that would be charged for the exit fee
    /// NOTE: if the vault  being redeemed from given the shares to redeem results in a total shares after of 0,
    ///       the exit fee is not applied
    function exitFeeAmount(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 exitFee = adminControl.getVaultFees(id).exitFee;
        uint256 feeAmount = _feeOnRaw(assets, exitFee == 0 ? adminControl.getVaultFees(0).exitFee : exitFee);
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
        uint256 protocolFee = adminControl.getVaultFees(id).protocolFee;
        uint256 feeAmount = _feeOnRaw(assets, protocolFee == 0 ? adminControl.getVaultFees(0).protocolFee : protocolFee);
        return feeAmount;
    }

    /// @notice returns atom deposit fraction given amount of 'assets' provided
    ///
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id
    ///
    /// @return feeAmount amount of assets that would be used as atom deposit fraction
    /// NOTE: only applies to triple vaults
    function atomDepositFractionAmount(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 feeAmount =
            isTripleId(id) ? _feeOnRaw(assets, adminControl.getTripleConfig().atomDepositFractionForTriple) : 0;
        return feeAmount;
    }

    /// @notice calculates fee on raw amount
    ///
    /// @param amount amount of assets to calculate fee on
    /// @param fee fee in %
    ///
    /// @return amount of assets that would be charged as fee
    function _feeOnRaw(uint256 amount, uint256 fee) internal view returns (uint256) {
        return amount.mulDivUp(fee, adminControl.getGeneralConfig().feeDenominator);
    }

    /* -------------------------- */
    /*     Accounting Helpers     */
    /* -------------------------- */

    /// @notice returns the current share price for the given vault id
    /// @param id vault id to get corresponding share price for
    /// @return price current share price for the given vault id, scaled by adminControl.generalConfig.decimalPrecision
    function currentSharePrice(uint256 id) public view returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        // Changing this to match exactly how convertToShares is calculated
        // This was not previously used internally in production code
        uint256 price =
            supply == 0 ? 0 : vaults[id].totalAssets.mulDiv(adminControl.getGeneralConfig().decimalPrecision, supply);
        return price;
    }

    /// @notice returns max amount of eth that can be deposited into the vault
    /// @return maxDeposit max amount of eth that can be deposited into the vault
    function maxDeposit() public pure returns (uint256) {
        return type(uint256).max;
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

    /// @notice returns amount of shares that would be exchanged by vault given amount of 'assets' provided
    ///
    /// @param assets amount of assets to calculate shares on
    /// @param id vault id to get corresponding shares for
    ///
    /// @return shares amount of shares that would be exchanged by vault given amount of 'assets' provided
    function convertToShares(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        uint256 shares = supply == 0 ? assets : assets.mulDiv(supply, vaults[id].totalAssets);
        return shares;
    }

    /// @notice returns amount of assets that would be exchanged by vault given amount of 'shares' provided
    ///
    /// @param shares amount of shares to calculate assets on
    /// @param id vault id to get corresponding assets for
    ///
    /// @return assets amount of assets that would be exchanged by vault given amount of 'shares' provided
    function convertToAssets(uint256 shares, uint256 id) public view returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        uint256 assets = supply == 0 ? shares : shares.mulDiv(vaults[id].totalAssets, supply);
        return assets;
    }

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
    function previewDeposit(
        uint256 assets, // should always be msg.value
        uint256 id
    ) public view returns (uint256) {
        (, uint256 sharesForReceiver,,) = getDepositSharesAndFees(assets, id);
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

    /* -------------------------- */
    /*       Triple Helpers       */
    /* -------------------------- */

    /// @notice returns the corresponding hash for the given RDF triple, given the triple vault id
    /// @param id vault id of the triple
    /// @return hash the corresponding hash for the given RDF triple
    /// NOTE: only applies to triple vault IDs as input
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
    /// NOTE: only applies to triple vault IDs as input
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
    /// NOTE: only applies to triple vault IDs as input
    function getCounterIdFromTriple(uint256 id) public pure returns (uint256) {
        return type(uint256).max - id;
    }

    /* -------------------------- */
    /*        Misc. Helpers       */
    /* -------------------------- */

    /// @notice returns the address of the atom warden
    function getAtomWarden() external view returns (address) {
        return adminControl.getWalletConfig().atomWarden;
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

    /// @notice returns the Atom Wallet address for the given atom data
    /// @param id vault id of the atom associated to the atom wallet
    /// @return atomWallet the address of the atom wallet
    /// NOTE: the create2 salt is based off of the vault ID
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

    /// @dev returns the deployment data for the AtomWallet contract
    /// @return bytes memory the deployment data for the AtomWallet contract (using BeaconProxy pattern)
    function _getDeploymentData() internal view returns (bytes memory) {
        // Address of the atomWalletBeacon contract
        address beaconAddress = adminControl.getWalletConfig().atomWalletBeacon;

        // BeaconProxy creation code
        bytes memory code = type(BeaconProxy).creationCode;

        // encode the init function of the AtomWallet contract with constructor arguments
        bytes memory initData = abi.encodeWithSelector(
            AtomWallet.init.selector, IEntryPoint(adminControl.getWalletConfig().entryPoint), address(this)
        );

        // encode constructor arguments of the BeaconProxy contract (address beacon, bytes memory data)
        bytes memory encodedArgs = abi.encode(beaconAddress, initData);

        // concatenate the BeaconProxy creation code with the ABI-encoded constructor arguments
        return abi.encodePacked(code, encodedArgs);
    }
}
