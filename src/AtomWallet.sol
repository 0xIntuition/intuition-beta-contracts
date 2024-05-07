// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {BaseAccount, UserOperation} from "account-abstraction/contracts/core/BaseAccount.sol";
import {IEntryPoint} from "account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {Errors} from "./libraries/Errors.sol";

/**
 * @title  AtomWallet
 * @notice This contract is an abstract account associated with a corresponding atom.
 */
contract AtomWallet is Initializable, BaseAccount, OwnableUpgradeable {
    using ECDSA for bytes32;

    /// @notice The storage slot for the AtomWallet contract ownable storage
    ///         keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OwnableStorageLocation = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

    /// @notice The EthMultiVault contract address
    IEthMultiVault public ethMultiVault;

    /// @notice The flag to indicate if the wallet's ownership has been claimed by the user
    bool public isClaimed;

    /// @notice The entry point contract address
    IEntryPoint private _entryPoint;

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    /**
     * @notice Initialize the AtomWallet contract
     * @param anEntryPoint the entry point contract address
     * @param anOwner the owner of the contract (`walletConfig.atomWarden` is the initial owner of all atom wallets)
     * @param _ethMultiVault the EthMultiVault contract address
     */
    function init(IEntryPoint anEntryPoint, address anOwner, IEthMultiVault _ethMultiVault) external initializer {
        __Ownable_init(anOwner);
        _entryPoint = anEntryPoint;
        ethMultiVault = _ethMultiVault;
    }

    /// @notice Get the entry point contract address
    /// @return the entry point contract address
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    /**
     * @notice Execute a transaction (called directly from owner, or by entryPoint)
     * @param dest the target address
     * @param value the value to send
     * @param func the function call data
     */
    function execute(address dest, uint256 value, bytes calldata func) external onlyOwnerOrEntryPoint {
        _call(dest, value, func);
    }

    /**
     * @notice Execute a sequence (batch) of transactions
     * @param dest the target addresses array
     * @param func the function call data array
     */
    function executeBatch(address[] calldata dest, bytes[] calldata func) external onlyOwnerOrEntryPoint {
        if (dest.length != func.length) {
            revert Errors.AtomWallet_WrongArrayLengths();
        }

        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], 0, func[i]);
        }
    }

    /// implement template method of BaseAccount
    /**
     * @notice Validate the signature of the user operation
     * @param userOp the user operation
     * @param userOpHash the hash of the user operation
     * @return validationData the validation data (0 if successful)
     */
    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));

        (address recovered,,) = ECDSA.tryRecover(hash, userOp.signature);

        if (recovered != owner()) {
            return SIG_VALIDATION_FAILED;
        }

        return 0;
    }

    /**
     * @notice An internal method that calls a target address with value and data
     * @param target the target address
     * @param value the value to send
     * @param data the function call data
     */
    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /// @notice Returns the deposit of the account in the entry point contract
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /// @notice Add deposit to the account in the entry point contract
    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * @notice Withdraws value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(address payable withdrawAddress, uint256 amount) public {
        if (!(msg.sender == owner() || msg.sender == address(this))) {
            revert Errors.AtomWallet_OnlyOwner();
        }
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    /// @notice Transfer ownership of the wallet to a new owner. Ifn the wallet's ownership
    ///         is being transferred to the user, the wallet is considered claimed. Once claimed,
    ///         wallet is considered owned by the user and the action cannot be undone.
    /// @param newOwner the new owner of the wallet
    function transferOwnership(address newOwner) public override onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }

        if (!isClaimed && newOwner != ethMultiVault.getAtomWarden()) {
            isClaimed = true;
        }

        _transferOwnership(newOwner);
    }

    /// @notice Returns the owner of the wallet. If the wallet has been claimed, the owner
    ///         is the user. Otherwise, the owner is the atomWarden.
    function owner() public view override returns (address) {
        OwnableStorage storage $ = _getAtomWalletOwnableStorage();
        return isClaimed ? $._owner : ethMultiVault.getAtomWarden();
    }

    /// @dev Get the storage slot for the AtomWallet contract ownable storage
    function _getAtomWalletOwnableStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OwnableStorageLocation
        }
    }

    /// @dev Modifier to allow only the owner or entry point to call a function
    modifier onlyOwnerOrEntryPoint() {
        if (!(msg.sender == address(entryPoint()) || msg.sender == owner())) {
            revert Errors.AtomWallet_OnlyOwnerOrEntryPoint();
        }
        _;
    }
}
