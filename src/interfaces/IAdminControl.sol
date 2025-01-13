// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

interface IAdminControl {
    /// @notice emitted upon scheduling an operation
    event OperationScheduled(bytes32 indexed operationId, bytes data, uint256 readyTime);

    /// @notice emitted upon cancelling an operation
    event OperationCancelled(bytes32 indexed operationId, bytes data);

    /// @notice emitted upon changing the admin
    event AdminSet(address indexed newAdmin, address indexed oldAdmin);

    /// @notice emitted upon changing the protocol multisig
    event protocolMultisigSet(address indexed newProtocolMultisig, address indexed oldProtocolMultisig);

    /// @notice emitted upon changing the minimum deposit amount
    event MinDepositSet(uint256 newMinDeposit, uint256 oldMinDeposit);

    /// @notice emitted upon changing the minimum share amount
    event MinShareSet(uint256 newMinShare, uint256 oldMinShare);

    /// @notice emitted upon changing the atom URI max length
    event AtomUriMaxLengthSet(uint256 newAtomUriMaxLength, uint256 oldAtomUriMaxLength);

    /// @notice emitted upon changing the atom share lock fee
    event AtomWalletInitialDepositAmountSet(
        uint256 newAtomWalletInitialDepositAmount, uint256 oldAtomWalletInitialDepositAmount
    );

    /// @notice emitted upon changing the atom creation fee
    event AtomCreationProtocolFeeSet(uint256 newAtomCreationProtocolFee, uint256 oldAtomCreationProtocolFee);

    /// @notice emitted upon changing the triple creation fee
    event TripleCreationProtocolFeeSet(uint256 newTripleCreationProtocolFee, uint256 oldTripleCreationProtocolFee);

    /// @notice emitted upon changing the atom deposit fraction on triple creation
    event AtomDepositFractionOnTripleCreationSet(
        uint256 newAtomDepositFractionOnTripleCreation, uint256 oldAtomDepositFractionOnTripleCreation
    );

    /// @notice emitted upon changing the atom deposit fraction for triples
    event AtomDepositFractionForTripleSet(
        uint256 newAtomDepositFractionForTriple, uint256 oldAtomDepositFractionForTriple
    );

    /// @notice emitted upon changing the entry fee
    event EntryFeeSet(uint256 id, uint256 newEntryFee, uint256 oldEntryFee);

    /// @notice emitted upon changing the exit fee
    event ExitFeeSet(uint256 id, uint256 newExitFee, uint256 oldExitFee);

    /// @notice emitted upon changing the protocol fee
    event ProtocolFeeSet(uint256 id, uint256 newProtocolFee, uint256 oldProtocolFee);

    /// @notice emitted upon changing the atomWarden
    event AtomWardenSet(address indexed newAtomWarden, address indexed oldAtomWarden);

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
}
