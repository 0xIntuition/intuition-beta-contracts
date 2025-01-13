// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {IPermit2} from "src/interfaces/IPermit2.sol";

/// @title IEthMultiVault
/// @author 0xIntuition
/// @notice Interface for managing many ERC4626 style vaults in a single contract
interface IEthMultiVault {
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

    /// @notice emitted upon changing the share price of an atom
    ///
    /// @param vaultId vault id of the atom
    /// @param newSharePrice new share price of the atom
    /// @param oldSharePrice old share price of the atom (not needed but staying in parallel with production code)
    event SharePriceChanged(uint256 indexed vaultId, uint256 newSharePrice, uint256 oldSharePrice);

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

    /// @notice returns the cost to create an atom
    /// @return cost the cost in wei to create an atom
    function getAtomCost() external view returns (uint256);

    /// @notice returns the cost to create a triple
    /// @return cost the cost in wei to create a triple
    function getTripleCost() external view returns (uint256);

    /// @notice creates a new atom with the given URI
    /// @param atomUri the URI data for the atom
    /// @return vaultId the vault ID of the created atom
    function createAtom(bytes calldata atomUri) external payable returns (uint256);

    /// @notice batch creates atoms with the given URIs
    /// @param atomUris array of URI data for the atoms
    /// @return ids array of vault IDs of the created atoms
    /// NOTE: This function will revert if called with less than `getAtomCost()` * `atomUris.length` in `msg.value`
    function batchCreateAtom(bytes[] calldata atomUris) external payable returns (uint256[] memory);

    /// @notice creates a new triple from three atom IDs
    /// @param subjectId the vault ID of the subject atom
    /// @param predicateId the vault ID of the predicate atom
    /// @param objectId the vault ID of the object atom
    /// @return vaultId the vault ID of the created triple
    function createTriple(uint256 subjectId, uint256 predicateId, uint256 objectId)
        external
        payable
        returns (uint256);

    /// @notice batch creates triples from arrays of atom IDs
    /// @param subjectIds array of vault IDs of subject atoms
    /// @param predicateIds array of vault IDs of predicate atoms
    /// @param objectIds array of vault IDs of object atoms
    /// @return ids array of vault IDs of the created triples
    /// NOTE: This function will revert if called with less than `getTripleCost()` * `array.length` in `msg.value`
    /// NOTE: This function will revert if arrays are not the same length
    function batchCreateTriple(
        uint256[] calldata subjectIds,
        uint256[] calldata predicateIds,
        uint256[] calldata objectIds
    ) external payable returns (uint256[] memory);

    /// @notice deposit eth into an atom vault and grant ownership of shares to receiver
    /// @param receiver the address to receive the shares
    /// @param id the vault ID of the atom
    /// @return shares the amount of shares minted
    /// NOTE: This function will revert if:
    /// - The minimum deposit amount of eth is not met
    /// - The vault ID does not exist/is not an atom
    /// - The sender is not approved by the receiver
    function depositAtom(address receiver, uint256 id) external payable returns (uint256);

    /// @notice deposits assets into a triple vault and grants ownership of shares to receiver
    /// @param receiver the address to receive the shares
    /// @param id the vault ID of the triple
    /// @return shares the amount of shares minted
    /// NOTE: This function will revert if:
    /// - The minimum deposit amount of eth is not met
    /// - The vault ID does not exist/is not a triple
    /// - The sender is not approved by the receiver
    /// - The receiver has counter stake in the vault
    function depositTriple(address receiver, uint256 id) external payable returns (uint256);

    /// @notice redeem shares from an atom vault for assets
    /// @param shares the amount of shares to redeem
    /// @param receiver the address to receive the assets
    /// @param id the vault ID of the atom
    /// @return assets the amount of assets/eth withdrawn
    /// NOTE: This function will revert if:
    /// - The shares amount is zero
    /// - The vault ID does not exist/is not an atom
    /// - The sender has insufficient shares
    /// - The remaining shares would be less than minShare
    /// NOTE: Emergency redemptions without any fees being charged are always possible, even if the contract is paused
    function redeemAtom(uint256 shares, address receiver, uint256 id) external returns (uint256);

    /// @notice redeem shares from a triple vault for assets
    /// @param shares the amount of shares to redeem
    /// @param receiver the address to receive the assets
    /// @param id the vault ID of the triple
    /// @return assets the amount of assets/eth withdrawn
    /// NOTE: This function will revert if:
    /// - The shares amount is zero
    /// - The vault ID does not exist/is not a triple
    /// - The sender has insufficient shares
    /// - The remaining shares would be less than minShare
    /// NOTE: Emergency redemptions without any fees being charged are always possible, even if the contract is paused
    function redeemTriple(uint256 shares, address receiver, uint256 id) external returns (uint256);

    /// @notice returns max amount of shares that can be redeemed from the sender's balance
    /// @param sender address of the account to get max redeemable shares for
    /// @param id vault id to get corresponding shares for
    /// @return shares amount of shares that can be redeemed from the sender's balance
    function maxRedeem(address sender, uint256 id) external view returns (uint256);

    /// @notice returns the current vault count (last created vault ID)
    /// @return count the current number of vaults that have been created
    function count() external view returns (uint256);

    /// @notice returns the current share price for a given vault
    /// @param vaultId the ID of the vault to query
    /// @return price the current price per share in wei
    function currentSharePrice(uint256 vaultId) external view returns (uint256);

    /// @notice returns amount of assets that would be charged by a vault on protocol fee
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    /// @return feeAmount amount of assets that would be charged by vault on protocol fee
    function protocolFeeAmount(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice transfers protocol fees to the protocol multisig address
    /// @param value the amount of eth to transfer
    /// @dev reverts if the transfer fails
    /// @dev emits a FeesTransferred event
    function transferFeesToProtocolMultisig(uint256 value) external;

    /// @notice returns atom deposit fraction given amount of assets provided
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id
    /// @return feeAmount amount of assets that would be used as atom deposit fraction
    /// NOTE: only applies to triple vaults
    function atomDepositFractionAmount(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice increments the total assets and shares of a vault
    /// @param id the vault ID of the atom or triple
    /// @param value the amount of assets and shares to increment by
    /// @dev only callable by the bonding curve contract
    function incrementVault(uint256 id, uint256 value) external;

    /// @notice returns amount of assets that would be charged for the entry fee
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    /// @return feeAmount amount of assets that would be charged for the entry fee
    /// NOTE: if the vault being deposited on has a vault total shares of 0, the entry fee is not applied
    function entryFeeAmount(uint256 assets, uint256 id) external view returns (uint256);

    /// @notice returns amount of assets that would be charged for the exit fee
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    /// @return feeAmount amount of assets that would be charged for the exit fee
    /// NOTE: if the vault being redeemed from has a vault total shares of minShare after redemption, the exit fee is not applied
    function exitFeeAmount(uint256 assets, uint256 id) external view returns (uint256);
}
