// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {UserOperation} from "account-abstraction/contracts/core/BaseAccount.sol";

import {AtomWallet} from "src/AtomWallet.sol";
import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";

/// @dev Exposes the internal `extractValidUntilAndValidAfter` so it can be tested directly,
/// independent of the ECDSA/EntryPoint plumbing around it.
contract AtomWalletHarness is AtomWallet {
    function exposedExtractValidUntilAndValidAfter(bytes calldata callData)
        external
        pure
        returns (uint256 validUntil, uint256 validAfter, bytes memory actualCallData)
    {
        return extractValidUntilAndValidAfter(callData);
    }
}

contract AtomWalletTest is EthMultiVaultBase {
    address constant ENTRY_POINT = address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    function setUp() external {
        _setUp();
    }

    function _buildCallData(uint96 validUntil, uint96 validAfter, bytes memory innerCallData)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(validUntil, validAfter, innerCallData);
    }

    function test_ExtractValidUntilAndValidAfter_DecodesRealisticCallData() external {
        AtomWalletHarness harness = new AtomWalletHarness();

        uint96 validUntil = 1_800_000_000;
        uint96 validAfter = 1_700_000_000;
        bytes memory innerCallData = abi.encodeWithSelector(AtomWallet.getDeposit.selector);
        bytes memory callData = _buildCallData(validUntil, validAfter, innerCallData);

        (uint256 decodedValidUntil, uint256 decodedValidAfter, bytes memory decodedCallData) =
            harness.exposedExtractValidUntilAndValidAfter(callData);

        assertEq(decodedValidUntil, uint256(validUntil));
        assertEq(decodedValidAfter, uint256(validAfter));
        assertEq(decodedCallData, innerCallData);
    }

    function test_ExtractValidUntilAndValidAfter_RevertsOnCallDataTooShort() external {
        AtomWalletHarness harness = new AtomWalletHarness();

        vm.expectRevert(Errors.AtomWallet_InvalidCallDataLength.selector);
        harness.exposedExtractValidUntilAndValidAfter(hex"aabbccdd");
    }

    function test_ExtractValidUntilAndValidAfter_RevertsAtLength23() external {
        AtomWalletHarness harness = new AtomWalletHarness();

        vm.expectRevert(Errors.AtomWallet_InvalidCallDataLength.selector);
        harness.exposedExtractValidUntilAndValidAfter(new bytes(23));
    }

    function test_ExtractValidUntilAndValidAfter_SucceedsAtExactLength24() external {
        AtomWalletHarness harness = new AtomWalletHarness();

        uint96 validUntil = type(uint96).max;
        uint96 validAfter = type(uint96).max - 1;
        bytes memory callData = _buildCallData(validUntil, validAfter, "");

        (uint256 decodedValidUntil, uint256 decodedValidAfter, bytes memory decodedCallData) =
            harness.exposedExtractValidUntilAndValidAfter(callData);

        assertEq(decodedValidUntil, uint256(validUntil));
        assertEq(decodedValidAfter, uint256(validAfter));
        assertEq(decodedCallData.length, 0);
    }

    function testFuzz_ExtractValidUntilAndValidAfter(uint96 validUntil, uint96 validAfter, bytes calldata innerCallData)
        external
    {
        AtomWalletHarness harness = new AtomWalletHarness();
        bytes memory callData = _buildCallData(validUntil, validAfter, innerCallData);

        (uint256 decodedValidUntil, uint256 decodedValidAfter, bytes memory decodedCallData) =
            harness.exposedExtractValidUntilAndValidAfter(callData);

        assertEq(decodedValidUntil, uint256(validUntil));
        assertEq(decodedValidAfter, uint256(validAfter));
        assertEq(decodedCallData, innerCallData);
    }

    /// @dev Calls `validateUserOp` directly as the EntryPoint (rather than exercising a real
    /// `EntryPoint.handleOps` call), on a wallet deployed via the real EthMultiVault, proving both
    /// that decoding no longer reverts unconditionally AND that the deadline enforcement added in
    /// #87/#89 actually works.
    function test_ValidateUserOp_EnforcesValidUntilAndValidAfter() external {
        // Foundry's default block.timestamp is 1; warp forward so `validUntil - 1` etc. below
        // can't accidentally land on 0, which the contract treats as "no expiration".
        vm.warp(1_700_000_000);

        uint256 atomId = ethMultiVault.createAtom{value: getAtomCost()}("atom wallet time-bound test");
        address payable atomWalletAddr = payable(ethMultiVault.deployAtomWallet(atomId));
        AtomWallet wallet = AtomWallet(atomWalletAddr);

        // Claim ownership so we sign with a known private key instead of the atomWarden's.
        vm.prank(address(0xbeef));
        wallet.transferOwnership(bob);
        vm.prank(bob);
        wallet.acceptOwnership();

        bytes memory innerCallData = abi.encodeWithSelector(AtomWallet.getDeposit.selector);
        bytes32 userOpHash = keccak256("test user op");
        bytes memory signature = _signUserOpHash(PK_BOB, userOpHash);

        // Case 1: within the valid window, correct signature -> validation succeeds (0).
        uint256 validationData = _validate(
            wallet,
            _buildCallData(uint96(block.timestamp + 1 days), uint96(block.timestamp - 1), innerCallData),
            userOpHash,
            signature
        );
        assertEq(validationData, 0);

        // Case 2: validUntil already elapsed -> validation fails (1), even with a correct signature.
        validationData = _validate(
            wallet, _buildCallData(uint96(block.timestamp - 1), uint96(0), innerCallData), userOpHash, signature
        );
        assertEq(validationData, 1);

        // Case 3: validAfter still in the future -> validation fails (1), even with a correct signature.
        validationData = _validate(
            wallet,
            _buildCallData(uint96(block.timestamp + 1 days), uint96(block.timestamp + 1), innerCallData),
            userOpHash,
            signature
        );
        assertEq(validationData, 1);

        // Case 4: validUntil == 0 means "no expiration", so a correct signature still succeeds
        // even far in the future.
        validationData = _validate(
            wallet, _buildCallData(uint96(0), uint96(block.timestamp - 1), innerCallData), userOpHash, signature
        );
        assertEq(validationData, 0);

        // Case 5: block.timestamp == validAfter is still NOT valid (`<=` in the contract, so the
        // window opens strictly after validAfter).
        validationData = _validate(
            wallet,
            _buildCallData(uint96(block.timestamp + 1 days), uint96(block.timestamp), innerCallData),
            userOpHash,
            signature
        );
        assertEq(validationData, 1);

        // Case 6: block.timestamp == validUntil is already NOT valid (`>=` in the contract, so the
        // window closes exactly at validUntil).
        validationData =
            _validate(wallet, _buildCallData(uint96(block.timestamp), uint96(0), innerCallData), userOpHash, signature);
        assertEq(validationData, 1);
    }

    function _signUserOpHash(uint256 privateKey, bytes32 userOpHash) internal pure returns (bytes memory) {
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        return abi.encodePacked(r, s, v);
    }

    function _validate(AtomWallet wallet, bytes memory callData, bytes32 userOpHash, bytes memory signature)
        internal
        returns (uint256)
    {
        UserOperation memory userOp = UserOperation({
            sender: address(wallet),
            nonce: 0,
            initCode: "",
            callData: callData,
            callGasLimit: 100_000,
            verificationGasLimit: 100_000,
            preVerificationGas: 21_000,
            maxFeePerGas: 1 gwei,
            maxPriorityFeePerGas: 1 gwei,
            paymasterAndData: "",
            signature: signature
        });

        vm.prank(ENTRY_POINT);
        return wallet.validateUserOp(userOp, userOpHash, 0);
    }
}
