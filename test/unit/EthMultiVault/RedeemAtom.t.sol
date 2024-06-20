// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {EthMultiVaultBase} from "../../EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "../../helpers/EthMultiVaultHelpers.sol";
import {Errors} from "../../../src/libraries/Errors.sol";

contract RedeemAtomTest is EthMultiVaultBase, EthMultiVaultHelpers {
    function setUp() external {
        _setUp();
    }

    function testRedeemAtomAll() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDepositAmount = testMinDesposit;

        // execute interaction - create atoms
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        // execute interaction - deposit atoms
        ethMultiVault.depositAtom{value: testDepositAmount}(alice, id);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        ethMultiVault.depositAtom{value: testDepositAmount}(bob, id);

        // snapshots before redeem
        uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;
        uint256 userSharesBeforeRedeem = getSharesInVault(id, bob);
        uint256 userBalanceBeforeRedeem = address(bob).balance;

        (, uint256 calculatedAssetsForReceiver, uint256 protocolFee, uint256 exitFee) =
            ethMultiVault.getRedeemAssetsAndFees(userSharesBeforeRedeem, id);
        uint256 assetsForReceiverBeforeFees = calculatedAssetsForReceiver + protocolFee + exitFee;

        // execute interaction - redeem all atom shares for bob
        uint256 assetsForReceiver = ethMultiVault.redeemAtom(userSharesBeforeRedeem, bob, id);

        checkProtocolVaultBalance(id, assetsForReceiverBeforeFees, protocolVaultBalanceBefore);

        // snapshots after redeem
        uint256 userSharesAfterRedeem = getSharesInVault(id, bob);
        uint256 userBalanceAfterRedeem = address(bob).balance;

        uint256 userBalanceDelta = userBalanceAfterRedeem - userBalanceBeforeRedeem;

        assertEq(userSharesAfterRedeem, 0);
        assertEq(userBalanceDelta, assetsForReceiver);

        vm.stopPrank();
    }

    function testRedeemAtomNonExistentVault() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDepositAmount = testMinDesposit;

        // execute interaction - create atoms
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        // execute interaction - deposit atoms
        ethMultiVault.depositAtom{value: testDepositAmount}(alice, id);

        // snapshots before redeem
        uint256 userSharesBeforeRedeem = getSharesInVault(id, alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_VaultDoesNotExist.selector));
        // execute interaction - redeem all atom shares
        ethMultiVault.redeemAtom(userSharesBeforeRedeem, alice, id + 1);

        vm.stopPrank();
    }

    function testRedeemAtomZeroShares() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDepositAmount = testMinDesposit;

        // execute interaction - create atoms
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        // execute interaction - deposit atoms
        ethMultiVault.depositAtom{value: testDepositAmount}(alice, id);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_DepositOrWithdrawZeroShares.selector));
        // execute interaction - redeem all atom shares
        ethMultiVault.redeemAtom(0, alice, id);

        vm.stopPrank();
    }

    function testRedeemAtomInsufficientBalance() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDepositAmount = testMinDesposit;

        // execute interaction - create atoms
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        // execute interaction - deposit atoms
        ethMultiVault.depositAtom{value: testDepositAmount}(alice, id);

        vm.stopPrank();

        // snapshots before redeem
        uint256 userSharesBeforeRedeem = getSharesInVault(id, alice);

        vm.startPrank(bob, bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InsufficientSharesInVault.selector));
        // execute interaction - redeem all atom shares
        ethMultiVault.redeemAtom(userSharesBeforeRedeem, bob, id);

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}
