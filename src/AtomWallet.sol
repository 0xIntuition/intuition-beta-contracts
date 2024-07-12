// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {BaseAccount, UserOperation} from "account-abstraction/contracts/core/BaseAccount.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {Errors} from "src/libraries/Errors.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";

/**
 * @title  AtomWallet
 * @author 0xIntuition
 * @notice Core contract of the Intuition protocol. This contract is an abstract account
 *         associated with a corresponding atom.
 */
contract AtomWallet is Initializable, BaseAccount, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
    using ECDSA for bytes32;

    /// @notice The EthMultiVault contract address
    IEthMultiVault public ethMultiVault;

    /// @notice The flag to indicate if the wallet's ownership has been claimed by the user
    bool public isClaimed;

    /// @notice The storage slot for the AtomWallet owner
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AtomWalletOwnerStorageLocation =
        0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

    /// @notice The storage slot for the AtomWallet pending owner
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable2Step")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AtomWalletPendingOwnerStorageLocation =
        0x237e158222e3e6968b72b9db0d8043aacf074ad9f650f0d1606b4d82ee432c00;

    /// @notice The entry point contract address
    IEntryPoint private _entryPoint;

    /// @dev Gap for upgrade safety
    uint256[50] private __gap;

    /// @dev Modifier to allow only the owner or entry point to call a function
    modifier onlyOwnerOrEntryPoint() {
        if (!(msg.sender == address(entryPoint()) || msg.sender == owner())) {
            revert Errors.AtomWallet_OnlyOwnerOrEntryPoint();
        }
        _;
    }

    /// @notice Initialize the AtomWallet contract
    ///
    /// @param anEntryPoint the entry point contract address
    /// @param _ethMultiVault the EthMultiVault contract address
    function init(IEntryPoint anEntryPoint, IEthMultiVault _ethMultiVault) external initializer {
        __Ownable_init(_ethMultiVault.getAtomWarden());
        __ReentrancyGuard_init();

        _entryPoint = anEntryPoint;
        ethMultiVault = _ethMultiVault;
    }

    receive() external payable {}

    //// @notice Execute a transaction (called directly from owner, or by entryPoint)
    ///
    /// @param dest the target address
    /// @param value the value to send
    /// @param func the function call data
    function execute(address dest, uint256 value, bytes calldata func)
        external
        payable
        onlyOwnerOrEntryPoint
        nonReentrant
    {
        _call(dest, value, func);
    }

    /// @notice Execute a sequence (batch) of transactions
    ///
    /// @param dest the target addresses array
    /// @param func the function call data array
    function executeBatch(address[] calldata dest, uint256[] calldata values, bytes[] calldata func)
        external
        payable
        onlyOwnerOrEntryPoint
        nonReentrant
    {
        if (dest.length != values.length || values.length != func.length) {
            revert Errors.AtomWallet_WrongArrayLengths();
        }

        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], values[i], func[i]);
        }
    }

    /// @notice Add deposit to the account in the entry point contract
    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /// @notice Withdraws value from the account's deposit
    ///
    /// @param withdrawAddress target to send to
    /// @param amount to withdraw
    function withdrawDepositTo(address payable withdrawAddress, uint256 amount) public {
        if (!(msg.sender == owner() || msg.sender == address(this))) {
            revert Errors.AtomWallet_OnlyOwner();
        }
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    /// @notice Initiates the ownership transfer over the wallet to a new owner.
    /// @param newOwner the new owner of the wallet (becomes the pending owner)
    /// NOTE: Overrides the transferOwnership function of Ownable2StepUpgradeable
    function transferOwnership(address newOwner) public override onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }

        Ownable2StepStorage storage $ = _getAtomWalletPendingOwnerStorage();
        $._pendingOwner = newOwner;

        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /// @notice The new owner accepts the ownership over the wallet. If the wallet's ownership
    ///         is being accepted by the user, the wallet is considered claimed. Once claimed,
    ///         wallet is considered owned by the user and this action cannot be undone.
    /// NOTE: Overrides the acceptOwnership function of Ownable2StepUpgradeable
    function acceptOwnership() public override {
        address sender = _msgSender();

        if (pendingOwner() != sender) {
            revert OwnableUnauthorizedAccount(sender);
        }

        if (!isClaimed) {
            isClaimed = true;
        }

        super._transferOwnership(sender);
    }

    /// @notice Returns the deposit of the account in the entry point contract
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /// @notice Get the entry point contract address
    /// @return the entry point contract address
    /// NOTE: Overrides the entryPoint function of BaseAccount
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    /// @notice Returns the owner of the wallet. If the wallet has been claimed, the owner
    ///         is the user. Otherwise, the owner is the atomWarden.
    /// @return the owner of the wallet
    /// NOTE: Overrides the owner function of OwnableUpgradeable
    function owner() public view override returns (address) {
        OwnableStorage storage $ = _getAtomWalletOwnerStorage();
        return isClaimed ? $._owner : ethMultiVault.getAtomWarden();
    }

    /// @notice Validate the signature of the user operation
    ///
    /// @param userOp the user operation
    /// @param userOpHash the hash of the user operation
    ///
    /// @return validationData the validation data (0 if successful)
    /// NOTE: Implements the template method of BaseAccount
    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        (uint256 validUntil, uint256 validAfter,) = extractValidUntilAndValidAfter(userOp.callData);

        if (block.timestamp < validAfter || block.timestamp > validUntil) {
            return SIG_VALIDATION_FAILED;
        }

        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));

        (address recovered, ECDSA.RecoverError recoverError, bytes32 errorArg) =
            ECDSA.tryRecover(hash, userOp.signature);

        if (recoverError == ECDSA.RecoverError.InvalidSignature) {
            revert Errors.AtomWallet_InvalidSignature();
        } else if (recoverError == ECDSA.RecoverError.InvalidSignatureLength) {
            revert Errors.AtomWallet_InvalidSignatureLength(uint256(errorArg));
        } else if (recoverError == ECDSA.RecoverError.InvalidSignatureS) {
            revert Errors.AtomWallet_InvalidSignatureS(errorArg);
        }

        if (recovered != owner()) {
            return SIG_VALIDATION_FAILED;
        }

        return 0;
    }

    /// @notice An internal method that calls a target address with value and data
    ///
    /// @param target the target address
    /// @param value the value to send
    /// @param data the function call data
    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /// @notice Extract the validUntil and validAfter from the call data
    /// @param callData the call data
    ///
    /// @return validUntil the valid until timestamp
    /// @return validAfter the valid after timestamp
    /// @return actualCallData the actual call data of the user operation
    function extractValidUntilAndValidAfter(bytes calldata callData)
        internal
        pure
        returns (uint256 validUntil, uint256 validAfter, bytes memory actualCallData)
    {
        if (callData.length < 24) {
            revert Errors.AtomWallet_InvalidCallDataLength();
        }

        validUntil = abi.decode(callData[:12], (uint256));
        validAfter = abi.decode(callData[12:24], (uint256));
        actualCallData = callData[24:];

        return (validUntil, validAfter, actualCallData);
    }

    /// @dev Get the storage slot for the AtomWallet contract owner
    /// @return $ the storage slot
    function _getAtomWalletOwnerStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := AtomWalletOwnerStorageLocation
        }
    }

    /// @dev Get the storage slot for the AtomWallet contract pending owner
    /// @return $ the storage slot
    function _getAtomWalletPendingOwnerStorage() private pure returns (Ownable2StepStorage storage $) {
        assembly {
            $.slot := AtomWalletPendingOwnerStorageLocation
        }
    }
}
