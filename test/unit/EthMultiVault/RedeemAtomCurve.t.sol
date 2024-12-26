// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";

contract RedeemAtomCurveTest is EthMultiVaultBase, EthMultiVaultHelpers {
    uint256 constant CURVE_ID = 2;

    function setUp() external {
        _setUp();
    }

    function testRedeemAtomCurveAll() external {
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
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(bob, id, CURVE_ID);

        // snapshots before redeem
        uint256 protocolMultisigBalanceBefore = address(getProtocolMultisig()).balance;
        uint256 userSharesBeforeRedeem = getSharesInVaultCurve(id, CURVE_ID, bob);
        uint256 userBalanceBeforeRedeem = address(bob).balance;

        (, uint256 calculatedAssetsForReceiver, uint256 protocolFee, uint256 exitFee) =
            ethMultiVault.getRedeemAssetsAndFeesCurve(userSharesBeforeRedeem, id, CURVE_ID);
        uint256 assetsForReceiverBeforeFees = calculatedAssetsForReceiver + protocolFee + exitFee;

        // execute interaction - redeem all atom shares for bob
        uint256 assetsForReceiver = ethMultiVault.redeemAtomCurve(userSharesBeforeRedeem, bob, id, CURVE_ID);

        checkProtocolMultisigBalance(id, assetsForReceiverBeforeFees, protocolMultisigBalanceBefore);

        // snapshots after redeem
        uint256 userSharesAfterRedeem = getSharesInVaultCurve(id, CURVE_ID, bob);
        uint256 userBalanceAfterRedeem = address(bob).balance;

        uint256 userBalanceDelta = userBalanceAfterRedeem - userBalanceBeforeRedeem;

        assertEq(userSharesAfterRedeem, 0);
        assertEq(userBalanceDelta, assetsForReceiver);

        vm.stopPrank();
    }

    function testRedeemAtomCurveNonExistentVault() external {
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
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        // snapshots before redeem
        uint256 userSharesBeforeRedeem = getSharesInVaultCurve(id, CURVE_ID, alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultDoesNotExist.selector));
        // execute interaction - redeem all atom shares
        ethMultiVault.redeemAtomCurve(userSharesBeforeRedeem, alice, id + 1, CURVE_ID);

        vm.stopPrank();
    }

    function testRedeemAtomCurveZeroShares() external {
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
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_DepositOrWithdrawZeroShares.selector));
        // execute interaction - redeem all atom shares
        ethMultiVault.redeemAtomCurve(0, alice, id, CURVE_ID);

        vm.stopPrank();
    }

    function testRedeemAtomCurveInsufficientBalance() external {
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
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        vm.stopPrank();

        // snapshots before redeem
        uint256 userSharesBeforeRedeem = getSharesInVaultCurve(id, CURVE_ID, alice);

        vm.startPrank(bob, bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_InsufficientSharesInVault.selector));
        // execute interaction - redeem all atom shares
        ethMultiVault.redeemAtomCurve(userSharesBeforeRedeem, bob, id, CURVE_ID);

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}