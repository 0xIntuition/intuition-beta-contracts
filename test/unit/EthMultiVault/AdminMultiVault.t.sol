// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";
import {IAdminControl} from "src/interfaces/IAdminControl.sol";

contract AdminMultiVaultTest is EthMultiVaultBase, EthMultiVaultHelpers {
    function setUp() external {
        _setUp();
    }

    function testScheduleOperation() external {
        bytes32 operationId = keccak256("setAdmin");
        address newAdmin = address(0x123);
        bytes memory data = abi.encodeWithSelector(IAdminControl.setAdmin.selector, newAdmin);
        uint256 minDelay = getMinDelay();

        // Expected operation hash
        bytes32 opHash = keccak256(abi.encodePacked(operationId, data, minDelay));

        // Schedule the operation
        vm.prank(msg.sender);
        adminControl.scheduleOperation(operationId, data);

        // Check if the operation was scheduled correctly
        (bytes memory scheduledData, uint256 readyTime, bool executed) = adminControl.timelocks(opHash);
        assertEq(scheduledData, data);
        assertEq(readyTime, block.timestamp + minDelay);
        assertFalse(executed);
    }

    function testCancelScheduledOperation() external {
        bytes32 operationId = keccak256("setExitFee");
        uint256 vaultId = 0;
        uint256 newExitFee = 100; // 100 basis points (1%)
        bytes memory data = abi.encodeWithSelector(IAdminControl.setExitFee.selector, vaultId, newExitFee);
        uint256 minDelay = getMinDelay();

        // Schedule the operation
        vm.prank(msg.sender);
        adminControl.scheduleOperation(operationId, data);

        // Cancel the scheduled operation
        vm.prank(msg.sender);
        adminControl.cancelOperation(operationId, data);

        // Verify the operation is canceled
        bytes32 opHash = keccak256(abi.encodePacked(operationId, data, minDelay));
        (, uint256 readyTime, bool executed) = adminControl.timelocks(opHash);
        assertTrue(readyTime == 0 && !executed);
    }

    function testSetAdmin() external {
        bytes32 operationId = keccak256("setAdmin");
        address newAdmin = address(0x456);
        bytes memory data = abi.encodeWithSelector(IAdminControl.setAdmin.selector, newAdmin);
        uint256 minDelay = getMinDelay();

        // Schedule the operation
        vm.prank(msg.sender);
        adminControl.scheduleOperation(operationId, data);

        // Forward time to surpass the delay
        vm.warp(block.timestamp + minDelay + 1);

        // should revert if not admin
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_AdminOnly.selector));
        adminControl.setAdmin(newAdmin);

        // Execute the scheduled operation
        vm.prank(msg.sender);
        adminControl.setAdmin(newAdmin);

        // Verify the operation's effects
        address currentAdmin = getAdmin();
        assertEq(currentAdmin, newAdmin);

        // Verify the operation is marked as executed
        bytes32 opHash = keccak256(abi.encodePacked(operationId, data, minDelay));
        (,, bool executed) = adminControl.timelocks(opHash);
        assertTrue(executed);
    }

    function testSetProtocolMultisig() external {
        address testValue = bob;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        adminControl.setProtocolMultisig(testValue);
        assertEq(getProtocolMultisig(), testValue);
    }

    function testSetEntryFee() external {
        uint256 testVaultId = 0;
        uint256 validEntryFee = getFeeDenominator() / 20; // Valid entry fee within allowed range
        uint256 invalidEntryFee = getFeeDenominator() / 5; // Invalid entry fee, exceeding allowed range

        // Attempt to set exit fee higher than allowed, should revert
        vm.prank(msg.sender);
        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_InvalidEntryFee.selector));
        adminControl.setEntryFee(testVaultId, invalidEntryFee);

        /// Sets a valid entry fee
        vm.prank(msg.sender);
        adminControl.setEntryFee(testVaultId, validEntryFee);
        assertEq(getEntryFee(testVaultId), validEntryFee);
    }

    function testSetExitFee() external {
        bytes32 operationId = keccak256("setExitFee");
        uint256 vaultId = 0; // Example vault ID
        uint256 validExitFee = getFeeDenominator() / 20; // Valid exit fee within allowed range
        uint256 invalidExitFee = getFeeDenominator() / 5; // Invalid exit fee, exceeding allowed range
        uint256 minDelay = getMinDelay();

        // Schedule operation with a valid exit fee
        bytes memory validData = abi.encodeWithSelector(IAdminControl.setExitFee.selector, vaultId, validExitFee);
        vm.prank(msg.sender);
        adminControl.scheduleOperation(operationId, validData);

        // Schedule operation with an invalid exit fee
        bytes memory invalidData = abi.encodeWithSelector(IAdminControl.setExitFee.selector, vaultId, invalidExitFee);
        vm.prank(msg.sender);
        adminControl.scheduleOperation(operationId, invalidData);

        // Forward time to surpass the delay
        vm.warp(block.timestamp + minDelay + 1);

        // Attempt to set exit fee higher than allowed, should revert
        vm.prank(msg.sender);
        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_InvalidExitFee.selector));
        adminControl.setExitFee(vaultId, invalidExitFee);

        // Set a valid exit fee
        vm.prank(msg.sender);
        adminControl.setExitFee(vaultId, validExitFee);

        // Verify the valid exit fee update
        uint256 currentExitFee = getExitFee(vaultId);
        assertEq(currentExitFee, validExitFee);

        // Verify the operation is marked as executed for the valid exit fee
        bytes32 opHashValid = keccak256(abi.encodePacked(operationId, validData, minDelay));
        (,, bool executedValid) = adminControl.timelocks(opHashValid);
        assertTrue(executedValid);
    }

    function testSetProtocolFee() external {
        uint256 testVaultId = 0;
        uint256 validProtocolFee = getFeeDenominator() / 20; // Valid protocol fee within allowed range
        uint256 invalidProtocolFee = getFeeDenominator() / 5; // Invalid protocol fee, exceeding allowed range

        // Attempt to set protocol fee higher than allowed, should revert
        vm.prank(msg.sender);
        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_InvalidProtocolFee.selector));
        adminControl.setProtocolFee(testVaultId, invalidProtocolFee);

        /// Sets a valid protocol fee
        vm.prank(msg.sender);
        adminControl.setProtocolFee(testVaultId, validProtocolFee);
        assertEq(getProtocolFee(testVaultId), validProtocolFee);
    }

    function testSetAtomWalletInitialDepositAmount() external {
        uint256 testValue = 1000;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        adminControl.setAtomWalletInitialDepositAmount(testValue);
        assertEq(getAtomWalletInitialDepositAmount(), testValue);
    }

    function testSetAtomCreationProtocolFee() external {
        uint256 testValue = 1000;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        adminControl.setAtomCreationProtocolFee(testValue);
        assertEq(getAtomCreationProtocolFee(), testValue);
    }

    function testSetTripleCreateFee() external {
        uint256 testValue = 1000;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        adminControl.setTripleCreationProtocolFee(testValue);
        assertEq(getTripleCreationProtocolFee(), testValue);
    }

    function testSetAtomDepositFractionOnTripleCreation() external {
        uint256 testValue = 0.0006 ether;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        adminControl.setAtomDepositFractionOnTripleCreation(testValue);
        assertEq(getAtomDepositFractionOnTripleCreation(), testValue);
    }

    function testSetAtomDepositFractionForTriple() external {
        uint256 validAtomDepositFractionForTriple = getFeeDenominator() / 10; // 10% of the deposit
        uint256 invalidAtomDepositFractionForTriple = getFeeDenominator(); // 100% of the deposit

        // Attempt to set atom deposit fraction higher than allowed, should revert
        vm.prank(msg.sender);
        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_InvalidAtomDepositFractionForTriple.selector));
        adminControl.setAtomDepositFractionForTriple(invalidAtomDepositFractionForTriple);

        // Set a valid atom deposit fraction for triple
        vm.prank(msg.sender);
        adminControl.setAtomDepositFractionForTriple(validAtomDepositFractionForTriple);
        assertEq(getAtomDepositFraction(), validAtomDepositFractionForTriple);
    }

    function testSetMinDeposit() external {
        uint256 testValue = 1000;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        adminControl.setMinDeposit(testValue);
        assertEq(getMinDeposit(), testValue);
    }

    function testSetMinShare() external {
        uint256 testValue = 1000;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        adminControl.setMinShare(testValue);
        assertEq(getMinShare(), testValue);
    }

    function testSetAtomUriMaxLength() external {
        uint256 testValue = 350;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        adminControl.setAtomUriMaxLength(testValue);
        assertEq(getAtomUriMaxLength(), testValue);
    }

    function testSetAtomWarden() external {
        address testValue = bob;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        adminControl.setAtomWarden(testValue);
        assertEq(ethMultiVault.getAtomWarden(), testValue);
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}
