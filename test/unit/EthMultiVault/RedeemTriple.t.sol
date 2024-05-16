// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {EthMultiVaultBase} from "../../EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "../../helpers/EthMultiVaultHelpers.sol";
import {Errors} from "../../../src/libraries/Errors.sol";

contract RedeemTripleTest is EthMultiVaultBase, EthMultiVaultHelpers {
    function setUp() external {
        _setUp();
    }

    function testRedeemTripleAll() external {
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
        ethMultiVault.depositTriple{value: testDepositAmount}(alice, id);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        ethMultiVault.depositTriple{value: testDepositAmount}(bob, id);

        // snapshots before redeem
        uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;
        uint256 userSharesBeforeRedeem = getSharesInVault(id, bob);
        uint256 userBalanceBeforeRedeem = address(bob).balance;

        (, uint256 calculatedAssetsForReceiver, uint256 protocolFees, uint256 exitFees) = ethMultiVault.getRedeemAssetsAndFees(userSharesBeforeRedeem, id);
        uint256 assetsForReceiverBeforeFees = calculatedAssetsForReceiver + protocolFees + exitFees;

        // execute interaction - redeem all positive triple vault shares for bob
        uint256 assetsForReceiver = ethMultiVault.redeemTriple(userSharesBeforeRedeem, bob, id);

        checkProtocolVaultBalance(id, assetsForReceiverBeforeFees, protocolVaultBalanceBefore);

        // snapshots after redeem
        uint256 userSharesAfterRedeem = getSharesInVault(id, bob);
        uint256 userBalanceAfterRedeem = address(bob).balance;

        uint256 userBalanceDelta = userBalanceAfterRedeem - userBalanceBeforeRedeem;

        assertEq(userSharesAfterRedeem, 0);
        assertEq(userBalanceDelta, assetsForReceiver);

        vm.stopPrank();
    }

    function testRedeemTripleAllCounterVault() external {
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

        assertEq(getSharesInVault(id, address(0)), getMinShare());
        assertEq(getSharesInVault(counterId, address(0)), getMinShare());

        // execute interaction - deposit triple
        ethMultiVault.depositTriple{value: testDepositAmount}(alice, id);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit triple
        ethMultiVault.depositTriple{value: testDepositAmount}(bob, counterId);

        // snapshots before redeem
        uint256 userSharesBeforeRedeem = getSharesInVault(counterId, bob);
        uint256 userBalanceBeforeRedeem = address(bob).balance;

        // execute interaction - redeem all atom shares
        uint256 assetsForReceiver = ethMultiVault.redeemTriple(userSharesBeforeRedeem, bob, counterId);

        // snapshots after redeem
        uint256 userSharesAfterRedeem = getSharesInVault(counterId, bob);
        uint256 userBalanceAfterRedeem = address(bob).balance;

        uint256 userBalanceDelta = userBalanceAfterRedeem - userBalanceBeforeRedeem;

        assertEq(userSharesAfterRedeem, 0);
        assertEq(userBalanceDelta, assetsForReceiver);

        vm.stopPrank();
    }

    function testRedeemTripleZeroShares() external {
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
        ethMultiVault.depositTriple{value: testDepositAmount}(alice, id);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_DepositOrWithdrawZeroShares.selector));
        // execute interaction - redeem all atom shares
        ethMultiVault.redeemTriple(0, alice, id);

        vm.stopPrank();
    }

    function testRedeemTripleNotTriple() external {
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
        ethMultiVault.depositTriple{value: testDepositAmount}(alice, id);

        // snapshots after redeem
        uint256 userSharesAfterRedeem = getSharesInVault(id, alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_VaultNotTriple.selector));
        // execute interaction - redeem all atom shares
        ethMultiVault.redeemTriple(userSharesAfterRedeem, alice, subjectId);

        vm.stopPrank();
    }

    function testRedeemTripleInsufficientBalance() external {
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
        ethMultiVault.depositTriple{value: testDepositAmount}(alice, id);

        vm.stopPrank();

        // snapshots after redeem
        uint256 userSharesAfterRedeem = getSharesInVault(id, alice);

        vm.startPrank(bob, bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InsufficientSharesInVault.selector));
        // execute interaction - redeem all atom shares
        ethMultiVault.redeemTriple(userSharesAfterRedeem, bob, id);

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}
