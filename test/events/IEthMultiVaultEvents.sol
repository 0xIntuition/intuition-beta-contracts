// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.21;

/// @title IVaultManager
/// @author 0xIntuition
/// @notice Interface for managing many ERC4626 style vaults in a single contract
interface IEthMultiVaultEvents {
    /*////////// EVENTS //////////////////////////////////////////////////////////////////*/

    /// @notice Emitted upon the minting of shares in the vault by depositing assets
    /// @param sender initializer of the deposit
    /// @param receiver beneficiary of the minted shares
    /// @param assets total assets transferred
    /// @param shares total shares transferred
    /// @param entryFee total fee amount collected for entering the vault
    /// @param id vault id
    event Deposit(
        address indexed sender, address indexed receiver, uint256 assets, uint256 shares, uint256 entryFee, uint256 id
    );

    /// @notice Emitted upon the withdrawal of assets from the vault by redeeming shares
    /// @param sender initializer of the withdrawal
    /// @param owner owner of the shares that were redeemed
    /// @param assets quantity of assets withdrawn
    /// @param shares quantity of shares redeemed
    /// @param exitFee total fee amount collected for exiting the vault
    /// @param id vault id
    event Withdraw(
        address indexed sender, address indexed owner, uint256 assets, uint256 shares, uint256 exitFee, uint256 id
    );

    /// @notice emitted upon creation of an atom
    /// @param creator address of the atom creator
    /// @param atomWallet address of the atom's associated abstract account
    /// @param atomString the atom's respective string
    /// @param vaultID the vault id of the atom
    event AtomCreated(address indexed creator, address indexed atomWallet, string atomString, uint256 vaultID);

    /// @notice emitted upon creation of a triple
    /// @param creator address of the triple creator
    /// @param hash the triple's respective hash keccak256(abi.encode(subject, predicate, object))
    /// @param subject the triple's respective subject atom
    /// @param predicate the triple's respective predicate atom
    /// @param object the triple's respective object atom
    /// @param vaultID the vault id of the triple
    event TripleCreated(
        address indexed creator, bytes32 hash, string subject, string predicate, string object, uint256 vaultID
    );
}
