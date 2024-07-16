// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {EthMultiVaultBase} from "../../EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "../../helpers/EthMultiVaultHelpers.sol";
import {Errors} from "../../../src/libraries/Errors.sol";

contract ApprovalsTest is EthMultiVaultBase, EthMultiVaultHelpers {
    function setUp() external {
        _setUp();
    }

    function testApproveSender() external {
        address sender = alice;
        address receiver = bob;

        vm.startPrank(receiver, receiver);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_CannotApproveSelf.selector));
        ethMultiVault.approveSender(receiver);

        ethMultiVault.approveSender(sender);
        assertTrue(getApproval(receiver, sender));

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_SenderAlreadyApproved.selector));
        ethMultiVault.approveSender(sender);

        vm.stopPrank();
    }

    function testRevokeSender() external {
        address sender = alice;
        address receiver = bob;

        vm.startPrank(receiver, receiver);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_CannotRevokeSelf.selector));
        ethMultiVault.revokeSender(receiver);

        ethMultiVault.approveSender(sender);
        assertTrue(getApproval(receiver, sender));

        ethMultiVault.revokeSender(sender);
        assertFalse(getApproval(receiver, sender));

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_SenderNotApproved.selector));
        ethMultiVault.revokeSender(sender);

        vm.stopPrank();
    }
}
