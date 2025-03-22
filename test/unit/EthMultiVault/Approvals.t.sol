// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";

contract ApprovalsTest is EthMultiVaultBase, EthMultiVaultHelpers {
    function setUp() external {
        _setUp();
    }

    function testApproveSender() external {
        address sender = alice;
        address receiver = bob;

        vm.startPrank(receiver, receiver);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_CannotApproveOrRevokeSelf.selector));
        ethMultiVault.approve(receiver, IEthMultiVault.ApprovalTypes.DEPOSIT);

        ethMultiVault.approve(sender, IEthMultiVault.ApprovalTypes.DEPOSIT);
        assertTrue(getApproval(receiver, sender));

        vm.stopPrank();
    }

    function testRevokeSender() external {
        address sender = alice;
        address receiver = bob;

        vm.startPrank(receiver, receiver);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_CannotApproveOrRevokeSelf.selector));
        ethMultiVault.approve(receiver, IEthMultiVault.ApprovalTypes.NONE);

        ethMultiVault.approve(sender, IEthMultiVault.ApprovalTypes.DEPOSIT);
        assertTrue(getApproval(receiver, sender));

        ethMultiVault.approve(sender, IEthMultiVault.ApprovalTypes.NONE);
        assertFalse(getApproval(receiver, sender));

        vm.stopPrank();
    }
}
