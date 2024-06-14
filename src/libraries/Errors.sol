// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

/// @title  Errors Library
/// @notice Library containing all custom errors detailing cases in which the contracts should revert
library Errors {
    ////////////// MULTIVAULT ERRORS ////////////////////////////////////////////////////////

    error MultiVault_AdminOnly();
    error MultiVault_ArraysNotSameLength();
    error MultiVault_AtomDoesNotExist(uint256 atomId);
    error MultiVault_AtomExists(bytes atomUri);
    error MultiVault_AtomUriTooLong();
    error MultiVault_BurnFromZeroAddress();
    error MultiVault_BurnInsufficientBalance();
    error MultiVault_DeployAccountFailed();
    error MultiVault_DepositOrWithdrawZeroShares();
    error MultiVault_HasCounterStake();
    error MultiVault_InsufficientBalance();
    error MultiVault_InsufficientDepositAmountToCoverFees();
    error MultiVault_InsufficientRemainingSharesInVault(uint256 remainingShares);
    error MultiVault_InsufficientSharesInVault();
    error MultiVault_InvalidEntryFee();
    error MultiVault_InvalidExitFee();
    error MultiVault_InvalidProtocolFee();
    error MultiVault_MinimumDeposit();
    error MultiVault_OperationAlreadyExecuted();
    error MultiVault_OperationAlreadyScheduled();
    error MultiVault_OperationNotScheduled();
    error MultiVault_ReceiveNotAllowed();
    error MultiVault_TimelockNotExpired();
    error MultiVault_TransferFailed();
    error MultiVault_TripleExists(uint256 subjectId, uint256 predicateId, uint256 objectId);
    error MultiVault_VaultDoesNotExist();
    error MultiVault_VaultIsTriple(uint256 vaultId);
    error MultiVault_VaultNotAtom();
    error MultiVault_VaultNotTriple();

    ///////// ATOMWALLET ERRORS /////////////////////////////////////////////////////////////

    error AtomWallet_OnlyOwner();
    error AtomWallet_OnlyOwnerOrEntryPoint();
    error AtomWallet_WrongArrayLengths();

    ///////// CUSTOMMULTICALL3 ERRORS /////////////////////////////////////////////////////////////

    error CustomMulticall3_InsufficientValue();
    error CustomMulticall3_InvalidAtomIdsLength();
    error CustomMulticall3_InvalidAtomUrisLength();
    error CustomMulticall3_InvalidValue();
    error CustomMulticall3_InvalidValuesLength();
}
