// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./Types.sol";

/// @title  Errors
/// @notice Library containing all custom errors detailing cases where the intuition core protocol may revert.
library Errors {
    /*//////////// MULTIVAULT ERRORS //////////////////////////////////////////////////////*/

    /// GENERAL ERRORS
    error MultiVault_AdminOnly();
    error MultiVault_DepositOrWithdrawZeroShares();
    error MultiVault_InsufficientDepositAmountToCoverFees();
    error MultiVault_InsufficientRemainingSharesInVault(uint256 remainingShares);
    error MultiVault_MinimumDeposit();
    error MultiVault_VaultDoesNotExist();
    error MultiVault_BurnFromZeroAddress();
    error MultiVault_BurnInsufficientBalance();
    error MultiVault_InsufficientBalance();
    error MultiVault_InsufficientSharesInVault();
    error MultiVault_ReceiveNotAllowed();
    /// RDF/INTUTION ERRORS
    error MultiVault_AtomUriTooLong();
    error MultiVault_AtomExists(bytes atomUri);
    error MultiVault_AtomDoesNotExist();
    error MultiVault_VaultNotAtom();
    error MultiVault_DeployAccountFailed();
    error MultiVault_NoAtomWalletRewards();
    error MultiVault_TripleExists(uint256 subjectId, uint256 predicateId, uint256 objectId);
    error MultiVault_ArraysNotSameLength();
    error MultiVault_VaultNotTriple();
    error MultiVault_VaultIsTriple();
    error MultiVault_HasCounterStake();
    error MultiVault_TransferFailed();
    error MultiVault_InvalidFeeSet();
    error MultiVault_InvalidExitFee();
    error MultiVault_OperationNotScheduled();
    error MultiVault_TimelockNotExpired();
    error MultiVault_OperationAlreadyExecuted();
    error MultiVault_OperationAlreadyScheduled();

    /*/////// TRUSTBONDING ERRORS /////////////////////////////////////////////////////////*/

    /// GENERAL ERRORS
    error TrustBonding_AdminOnly();
    error TrustBonding_NotMultiVault();
    error TrustBonding_BondZeroTrust();
    error TrustBonding_BondAddZeroTrust();
    error TrustBonding_BondAddZeroEpochs();
    error TrustBonding_BondAlreadyExists();
    error TrustBonding_BondDoesNotExist();
    error TrustBonding_BondExpired();
    error TrustBonding_BondNotExpiredYet();
    error TrustBonding_MinimumBondLength();
    error TrustBonding_MaximumBondLength();

    /*/////// ENERGY ERRORS ///////////////////////////////////////////////////////////////*/

    error Energy_OnlyMinter();

    /*/////// TRUST ERRORS ////////////////////////////////////////////////////////////////*/

    error Trust_OnlyMinter();
    error Trust_EpochNotOver();

    /*/////// PAYMASTER ERRORS ////////////////////////////////////////////////////////////*/

    /// GENERAL ERRORS
    error Paymaster_ApprovalDataInvalidLength();
    error Paymaster_PaymasterDataInvalidLength();
    error Paymaster_SenderNotWhitelisted();
    error Paymaster_TargetNotWhitelisted();
    error Paymaster_MethodNotWhitelisted();

    /*/////// ATOMWALLET ERRORS ///////////////////////////////////////////////////////////*/

    error AtomWallet_OnlyOwner();
    error AtomWallet_WrongArrayLengths();
    error AtomWallet_OnlyOwnerOrEntryPoint();
}
