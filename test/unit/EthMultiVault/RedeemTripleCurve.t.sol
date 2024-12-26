// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";

contract RedeemTripleCurveTest is EthMultiVaultBase, EthMultiVaultHelpers {
    uint256 constant CURVE_ID = 2;

    function setUp() external {
        _setUp();
    }

    function testRedeemTripleCurveAll() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDepositAmount = testMinDesposit;
        uint256 testDepositAmountTriple = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create triples
        uint256 id = ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        // execute interaction - deposit atoms
        ethMultiVault.depositTripleCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        ethMultiVault.depositTripleCurve{value: testDepositAmount}(bob, id, CURVE_ID);

        // snapshots before redeem
        uint256 protocolMultisigBalanceBefore = address(getProtocolMultisig()).balance;
        uint256 userSharesBeforeRedeem = getSharesInVaultCurve(id, CURVE_ID, bob);
        uint256 userBalanceBeforeRedeem = address(bob).balance;

        (, uint256 calculatedAssetsForReceiver, uint256 protocolFee, uint256 exitFee) =
            ethMultiVault.getRedeemAssetsAndFeesCurve(userSharesBeforeRedeem, id, CURVE_ID);
        uint256 assetsForReceiverBeforeFees = calculatedAssetsForReceiver + protocolFee + exitFee;

        // execute interaction - redeem all positive triple vault shares for bob
        uint256 assetsForReceiver = ethMultiVault.redeemTripleCurve(userSharesBeforeRedeem, bob, id, CURVE_ID);

        checkProtocolMultisigBalance(id, assetsForReceiverBeforeFees, protocolMultisigBalanceBefore);

        // snapshots after redeem
        uint256 userSharesAfterRedeem = getSharesInVaultCurve(id, CURVE_ID, bob);
        uint256 userBalanceAfterRedeem = address(bob).balance;

        uint256 userBalanceDelta = userBalanceAfterRedeem - userBalanceBeforeRedeem;

        assertEq(userSharesAfterRedeem, 0);
        assertEq(userBalanceDelta, assetsForReceiver);

        vm.stopPrank();
    }

    function testRedeemTripleCurveAllCounterVault() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDepositAmount = testMinDesposit;
        uint256 testDepositAmountTriple = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create triple
        uint256 id = ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        uint256 counterId = ethMultiVault.getCounterIdFromTriple(id);

        assertEq(getSharesInVaultCurve(id, CURVE_ID, getAdmin()), getMinShare());
        assertEq(getSharesInVaultCurve(counterId, CURVE_ID, getAdmin()), getMinShare());

        // execute interaction - deposit triple
        ethMultiVault.depositTripleCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit triple
        ethMultiVault.depositTripleCurve{value: testDepositAmount}(bob, counterId, CURVE_ID);

        // snapshots before redeem
        uint256 userSharesBeforeRedeem = getSharesInVaultCurve(counterId, CURVE_ID, bob);
        uint256 userBalanceBeforeRedeem = address(bob).balance;

        // execute interaction - redeem all atom shares
        uint256 assetsForReceiver = ethMultiVault.redeemTripleCurve(userSharesBeforeRedeem, bob, counterId, CURVE_ID);

        // snapshots after redeem
        uint256 userSharesAfterRedeem = getSharesInVaultCurve(counterId, CURVE_ID, bob);
        uint256 userBalanceAfterRedeem = address(bob).balance;

        uint256 userBalanceDelta = userBalanceAfterRedeem - userBalanceBeforeRedeem;

        assertEq(userSharesAfterRedeem, 0);
        assertEq(userBalanceDelta, assetsForReceiver);

        vm.stopPrank();
    }

    function testRedeemTripleCurveZeroShares() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDepositAmount = testMinDesposit;
        uint256 testDepositAmountTriple = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create triples
        uint256 id = ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        // execute interaction - deposit atoms
        ethMultiVault.depositTripleCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_DepositOrWithdrawZeroShares.selector));
        // execute interaction - redeem all atom shares
        ethMultiVault.redeemTripleCurve(0, alice, id, CURVE_ID);

        vm.stopPrank();
    }

    function testRedeemTripleCurveNotTriple() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDepositAmount = testMinDesposit;
        uint256 testDepositAmountTriple = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create triples
        uint256 id = ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        // execute interaction - deposit atoms
        ethMultiVault.depositTripleCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        // snapshots after redeem
        uint256 userSharesAfterRedeem = getSharesInVaultCurve(id, CURVE_ID, alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultNotTriple.selector));
        // execute interaction - redeem all atom shares
        ethMultiVault.redeemTripleCurve(userSharesAfterRedeem, alice, subjectId, CURVE_ID);

        vm.stopPrank();
    }

    function testRedeemTripleCurveInsufficientBalance() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDepositAmount = testMinDesposit;
        uint256 testDepositAmountTriple = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create triples
        uint256 id = ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        // execute interaction - deposit atoms
        ethMultiVault.depositTripleCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        vm.stopPrank();

        // snapshots after redeem
        uint256 userSharesAfterRedeem = getSharesInVaultCurve(id, CURVE_ID, alice);

        vm.startPrank(bob, bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_InsufficientSharesInVault.selector));
        // execute interaction - redeem all atom shares
        ethMultiVault.redeemTripleCurve(userSharesAfterRedeem, bob, id, CURVE_ID);

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}