// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IAdminControl} from "src/interfaces/IAdminControl.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {IModel} from "src/interfaces/IModel.sol";
import {Errors} from "src/libraries/Errors.sol";

contract AdminControl is Initializable, IAdminControl, IModel {
    // Operation identifiers
    bytes32 public constant SET_ADMIN = keccak256("setAdmin");
    bytes32 public constant SET_EXIT_FEE = keccak256("setExitFee");

    /// @notice Configuration structs
    GeneralConfig public generalConfig;
    AtomConfig public atomConfig;
    TripleConfig public tripleConfig;
    WalletConfig public walletConfig;

    /// @notice Timelock mapping (operation hash -> timelock struct)
    mapping(bytes32 operationHash => Timelock timelock) public timelocks;

    /// @notice Mapping of vault ID to vault fees
    // Vault ID -> Vault Fees
    mapping(uint256 vaultId => VaultFees vaultFees) public vaultFees;

    /// @notice Mapping of receiver to sender to determine if a sender is allowed to deposit assets on behalf of a receiver
    // Receiver -> Sender -> Is Approved
    mapping(address receiver => mapping(address sender => bool isApproved)) public approvals;

    uint256[50] private __gap;

    /// @notice Initializes the AdminControl contract
    /// @param _generalConfig General configuration struct
    /// @param _atomConfig Atom configuration struct
    /// @param _tripleConfig Triple configuration struct
    /// @param _walletConfig Wallet configuration struct
    /// @param _defaultVaultFees Default vault fees struct
    function init(
        GeneralConfig memory _generalConfig,
        AtomConfig memory _atomConfig,
        TripleConfig memory _tripleConfig,
        WalletConfig memory _walletConfig,
        VaultFees memory _defaultVaultFees
    ) external initializer {
        generalConfig = _generalConfig;
        atomConfig = _atomConfig;
        tripleConfig = _tripleConfig;
        walletConfig = _walletConfig;
        vaultFees[0] = VaultFees({
            entryFee: _defaultVaultFees.entryFee,
            exitFee: _defaultVaultFees.exitFee,
            protocolFee: _defaultVaultFees.protocolFee
        });
    }

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
    /*                    ADMIN FUNCTIONS                  */
    /* =================================================== */

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
        bytes memory data = abi.encodeWithSelector(this.setAdmin.selector, admin);
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
        bytes memory data = abi.encodeWithSelector(this.setExitFee.selector, id, exitFee);
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

    /// @dev returns the general config
    /// @return generalConfig the general config
    function getGeneralConfig() external view returns (GeneralConfig memory) {
        return generalConfig;
    }

    /// @dev returns the atom config
    /// @return atomConfig the atom config
    function getAtomConfig() external view returns (AtomConfig memory) {
        return atomConfig;
    }

    /// @dev returns the triple config
    /// @return tripleConfig the triple config
    function getTripleConfig() external view returns (TripleConfig memory) {
        return tripleConfig;
    }

    /// @dev returns the vault fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default fees for all vaults, id = n changes fees for vault n specifically
    /// @param id vault id to get fees for
    /// @return vaultFees the vault fees
    function getVaultFees(uint256 id) external view returns (VaultFees memory) {
        return vaultFees[id];
    }

    /// @dev returns the wallet config
    /// @return walletConfig the wallet config
    function getWalletConfig() external view returns (WalletConfig memory) {
        return walletConfig;
    }

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

    /// @dev returns whether a sender is approved to deposit assets on behalf of a receiver
    /// @param receiver address of the receiver
    /// @param sender address of the sender
    /// @return whether the sender is approved to deposit assets on behalf of the receiver
    function isApproved(address receiver, address sender) external view returns (bool) {
        return approvals[receiver][sender];
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
}
