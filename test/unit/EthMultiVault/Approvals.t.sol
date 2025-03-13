// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";

contract ApprovalsTest is EthMultiVaultBase, EthMultiVaultHelpers {
    IEthMultiVault.ApprovalTypes public noApproval = IEthMultiVault.ApprovalTypes.NONE;
    IEthMultiVault.ApprovalTypes public depositApproval = IEthMultiVault.ApprovalTypes.DEPOSIT;

    function setUp() external {
        _setUp();
    }

    function test_approve() external {
        address sender = alice;
        address receiver = bob;

        vm.startPrank(receiver, receiver);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_CannotApproveSelf.selector));
        ethMultiVault.approve(receiver, depositApproval);

        uint8 depositApprovalUint = uint8(depositApproval);

        ethMultiVault.approve(sender, depositApproval);
        assertEq(getApproval(receiver, sender), depositApprovalUint);

        vm.stopPrank();
    }

    function test_revokeApproval() external {
        address sender = alice;
        address receiver = bob;

        vm.startPrank(receiver, receiver);

        uint8 noApprovalUint = uint8(noApproval);
        uint8 depositApprovalUint = uint8(depositApproval);

        ethMultiVault.approve(sender, depositApproval);
        assertEq(getApproval(receiver, sender), depositApprovalUint);

        ethMultiVault.approve(sender, noApproval);
        assertEq(getApproval(receiver, sender), noApprovalUint);

        vm.stopPrank();
    }
}
