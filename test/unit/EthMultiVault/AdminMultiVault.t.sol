// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {EthMultiVaultBase} from "../../EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "../../helpers/EthMultiVaultHelpers.sol";
import {Errors} from "../../../src/libraries/Errors.sol";

contract AdminMultiVaultTest is EthMultiVaultBase, EthMultiVaultHelpers {
    function setUp() external {
        _setUp();
    }

    function testSetAdmin() external {
        address testValue = bob;

        // should revert if not admin
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_AdminOnly.selector));
        ethMultiVault.setAdmin(testValue);

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        ethMultiVault.setAdmin(testValue);
        assertEq(getAdmin(), testValue);
    }

    function testSetProtocolVault() external {
        address testValue = bob;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        ethMultiVault.setProtocolVault(testValue);
        assertEq(getProtocolVault(), testValue);
    }
    
    function testSetEntryFee() external {
        uint256 testVaultId = 0;
        uint256 testValue = 1000;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        ethMultiVault.setEntryFee(testVaultId, testValue);
        assertEq(getEntryFee(testVaultId), testValue);
    }

    function testSetExitFee() external {
        uint256 testVaultId = 0;
        uint256 testValue = 1000;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        ethMultiVault.setExitFee(testVaultId, testValue);
        assertEq(getExitFee(testVaultId), testValue);
    }

    function testSetExitFeeHigherThanAllowed() external {
        uint256 testVaultId = 0;
        uint256 testValue = 2000; // higher than 10%

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InvalidExitFee.selector));
        ethMultiVault.setExitFee(testVaultId, testValue);
    }

    function testSetProtocolFee() external {
        uint256 testVaultId = 0;
        uint256 testValue = 1000;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        ethMultiVault.setProtocolFee(testVaultId, testValue);
        assertEq(getProtocolFee(testVaultId), testValue);
    }

    function testSetAtomShareLockFee() external {
        uint256 testValue = 1000;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        ethMultiVault.setAtomShareLockFee(testValue);
        assertEq(getAtomShareLockFee(), testValue);
    }

    function testSetAtomCreationFee() external {
        uint256 testValue = 1000;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        ethMultiVault.setAtomCreationFee(testValue);
        assertEq(getAtomCreationFee(), testValue);
    }

    function testSetTripleCreateFee() external {
        uint256 testValue = 1000;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        ethMultiVault.setTripleCreationFee(testValue);
        assertEq(getTripleCreationFee(), testValue);
    }

    function testSetAtomEquityFee() external {
        uint256 testValue = 1000;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        ethMultiVault.setAtomEquityFee(testValue);
        assertEq(getAtomEquityFee(), testValue);
    }

    function testSetMinDeposit() external {
        uint256 testValue = 1000;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        ethMultiVault.setMinDeposit(testValue);
        assertEq(getMinDeposit(), testValue);
    }

    function testSetMinShare() external {
        uint256 testValue = 1000;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        ethMultiVault.setMinShare(testValue);
        assertEq(getMinShare(), testValue);
    }

    function testSetAtomUriMaxLength() external {
        uint256 testValue = 350;

        // msg.sender is the caller of EthMultiVaultBase
        vm.prank(msg.sender);
        ethMultiVault.setAtomUriMaxLength(testValue);
        assertEq(getAtomUriMaxLength(), testValue);
    }

    function getAtomCost()
        public
        view
        override
        returns (uint256)
    {
        return EthMultiVaultBase.getAtomCost();
    }
}
