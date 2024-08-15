// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {AtomWallet} from "src/AtomWallet.sol";
import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";

/**
 * @title  AtomWarden
 * @author 0xIntuition
 * @notice A utility contract of the Intuition protocol. It acts as an initial owner of all newly
 *            created atom wallets, and it also allows users to automatically claim ownership over
 *            the atom wallets for which they've proven ownership over.
 */
contract AtomWarden is Initializable, Ownable2StepUpgradeable {
    /// @notice The EthMultiVault contract address
    EthMultiVault public ethMultiVault;

    /// @notice Event emitted when the EthMultiVault contract address is set
    /// @param ethMultiVault EthMultiVault contract address
    event EthMultiVaultSet(EthMultiVault ethMultiVault);

    /// @notice Initializes the AtomWarden contract
    ///
    /// @param admin The address of the admin
    /// @param _ethMultiVault EthMultiVault contract
    function init(address admin, EthMultiVault _ethMultiVault) external initializer {
        __Ownable_init(admin);
        ethMultiVault = _ethMultiVault;
    }

    /// @notice Sets the EthMultiVault contract address
    /// @param _ethMultiVault EthMultiVault contract address
    function setEthMultiVault(EthMultiVault _ethMultiVault) external onlyOwner {
        if (address(_ethMultiVault) == address(0)) {
            revert Errors.AtomWarden_InvalidEthMultiVaultAddress();
        }

        ethMultiVault = _ethMultiVault;

        emit EthMultiVaultSet(_ethMultiVault);
    }

    /// @notice Allows the caller to claim ownership over an atom wallet address in case
    ///         atomUri is equal to the caller's address
    /// @param atomId The atom ID
    function claimOnwershipOverAddressAtom(uint256 atomId) external {
        if (atomId == 0 || atomId > ethMultiVault.count()) {
            revert Errors.AtomWarden_AtomIdOutOfBounds();
        }

        bytes memory atomUri = ethMultiVault.atoms(atomId);

        bytes32 atomUriHash = keccak256(atomUri);
        bytes32 msgSenderHash = keccak256(abi.encodePacked(msg.sender));

        if (atomUriHash == msgSenderHash) {
            address payable atomWalletAddress = payable(ethMultiVault.computeAtomWalletAddr(atomId));
            AtomWallet(atomWalletAddress).transferOwnership(msg.sender);
        } else {
            revert Errors.AtomWarden_ClaimOwnershipFailed();
        }
    }
}
