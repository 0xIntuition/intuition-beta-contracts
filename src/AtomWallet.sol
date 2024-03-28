// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {BaseAccount, UserOperation} from "account-abstraction/contracts/core/BaseAccount.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEntryPoint} from "account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {Errors} from "./libraries/Errors.sol";

/**
 * @title  AtomWallet
 * @author 0xIntuition
 * @notice Core contract of the Intuition protocol. This contract is the abstract account
 *         associated to a corresponding atom.
 */
contract AtomWallet is BaseAccount, Ownable {
    using ECDSA for bytes32;

    IEntryPoint private immutable _entryPoint;

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    constructor(IEntryPoint anEntryPoint, address anOwner) {
        _entryPoint = anEntryPoint;
        transferOwnership(anOwner);
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external onlyOwnerOrEntryPoint {
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     */
    function executeBatch(
        address[] calldata dest,
        bytes[] calldata func
    ) external onlyOwnerOrEntryPoint {
        if (dest.length != func.length) 
            revert Errors.AtomWallet_WrongArrayLengths();
            
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], 0, func[i]);
        }
    }

    /// implement template method of BaseAccount
    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owner() != hash.recover(userOp.signature))
            return SIG_VALIDATION_FAILED;
        }
        return 0;
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * check current account deposit in the entryPoint
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * deposit more funds for this account in the entryPoint
     */
    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * withdraw value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) public {
        if (!(msg.sender == owner() || msg.sender == address(this))) {
            revert Errors.AtomWallet_OnlyOwner();
        }
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    modifier onlyOwnerOrEntryPoint() {
        if (!(msg.sender == address(entryPoint()) || msg.sender == owner()))
            revert Errors.AtomWallet_OnlyOwnerOrEntryPoint();
        _;
    }
}
