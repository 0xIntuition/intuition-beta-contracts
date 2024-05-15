// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Minimal Permit2 interface, derived from:
// https://github.com/Uniswap/permit2/blob/main/src/interfaces/ISignatureTransfer.sol
interface IPermit2 {
    /// @notice Token and amount in a permit message
    struct TokenPermissions {
        /// @dev Token to transfer
        IERC20 token;
        /// @dev Amount to transfer
        uint256 amount;
    }

    /// @notice The permit2 message
    struct PermitTransferFrom {
        /// @dev Permitted token and amount
        TokenPermissions permitted;
        /// @dev Unique identifier for this permit
        uint256 nonce;
        /// @dev Expiration for this permit
        uint256 deadline;
    }

    /// @notice Transfer details for permitTransferFrom()
    struct SignatureTransferDetails {
        /// @dev Recipient of tokens
        address to;
        /// @dev Amount to transfer
        uint256 requestedAmount;
    }

    /// @notice Consume a permit2 message and transfer tokens
    ///
    /// @param permit The permit message
    /// @param transferDetails Details for the transfer
    /// @param owner The owner of the tokens
    /// @param signature The signature for the permit message
    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}
