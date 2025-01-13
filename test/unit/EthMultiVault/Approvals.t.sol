// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";

contract ApprovalsTest is EthMultiVaultBase, EthMultiVaultHelpers {
    function setUp() external {
        _setUp();
    }

    function testApproveSender() external {
        address sender = alice;
        address receiver = bob;

        vm.startPrank(receiver, receiver);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_CannotApproveSelf.selector));
        adminControl.approveSender(receiver);

        adminControl.approveSender(sender);
        assertTrue(getApproval(receiver, sender));

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_SenderAlreadyApproved.selector));
        adminControl.approveSender(sender);

        vm.stopPrank();
    }

    function testRevokeSender() external {
        address sender = alice;
        address receiver = bob;

        vm.startPrank(receiver, receiver);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_CannotRevokeSelf.selector));
        adminControl.revokeSender(receiver);

        adminControl.approveSender(sender);
        assertTrue(getApproval(receiver, sender));

        adminControl.revokeSender(sender);
        assertFalse(getApproval(receiver, sender));

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_SenderNotApproved.selector));
        adminControl.revokeSender(sender);

        vm.stopPrank();
    }
}
