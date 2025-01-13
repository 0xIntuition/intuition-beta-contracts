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
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 100;

        // create atoms and triple
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");
        uint256 id = ethMultiVault.createTriple{value: getTripleCost()}(subjectId, predicateId, objectId);

        // Initial deposit
        bondingCurve.depositTripleCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        // Get initial state
        uint256 aliceInitialBalance = address(alice).balance;
        (uint256 aliceShares,) = bondingCurve.getVaultStateForUserCurve(id, CURVE_ID, alice);

        // Redeem all shares
        uint256 assetsReceived = bondingCurve.redeemTripleCurve(aliceShares, alice, id, CURVE_ID);

        // Verify balance change
        assertEq(address(alice).balance - aliceInitialBalance, assetsReceived);

        // Verify shares are gone
        (uint256 sharesAfter,) = bondingCurve.getVaultStateForUserCurve(id, CURVE_ID, alice);
        assertEq(sharesAfter, 0);

        vm.stopPrank();
    }

    function testRedeemTripleCurveAllCounterVault() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 100;

        // create atoms and triple
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");
        uint256 id = ethMultiVault.createTriple{value: getTripleCost()}(subjectId, predicateId, objectId);
        uint256 counterId = ethMultiVault.getCounterIdFromTriple(id);

        // Initial deposit into counter vault
        bondingCurve.depositTripleCurve{value: testDepositAmount}(alice, counterId, CURVE_ID);

        // Get initial state
        uint256 aliceInitialBalance = address(alice).balance;
        (uint256 aliceShares,) = bondingCurve.getVaultStateForUserCurve(counterId, CURVE_ID, alice);

        // Redeem all shares
        uint256 assetsReceived = bondingCurve.redeemTripleCurve(aliceShares, alice, counterId, CURVE_ID);

        // Verify balance change
        assertEq(address(alice).balance - aliceInitialBalance, assetsReceived);

        // Verify shares are gone
        (uint256 sharesAfter,) = bondingCurve.getVaultStateForUserCurve(counterId, CURVE_ID, alice);
        assertEq(sharesAfter, 0);

        vm.stopPrank();
    }

    function testRedeemTripleCurveInsufficientBalance() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 100; // Increase initial deposit significantly

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create a triple
        uint256 id = ethMultiVault.createTriple{value: getTripleCost()}(subjectId, predicateId, objectId);

        // execute interaction - deposit triple
        bondingCurve.depositTripleCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        vm.stopPrank();

        // snapshots before redeem
        uint256 userSharesBeforeRedeem = getSharesInVaultCurve(id, CURVE_ID, alice);

        vm.startPrank(bob, bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_InsufficientSharesInVault.selector));
        // execute interaction - redeem all triple shares
        bondingCurve.redeemTripleCurve(userSharesBeforeRedeem, bob, id, CURVE_ID);

        vm.stopPrank();
    }

    function testRedeemTripleCurveNotTriple() external {
        vm.startPrank(alice, alice);

        // Create an atom
        uint256 atomId = ethMultiVault.createAtom{value: getAtomCost()}("atom");

        // Deposit into the atom vault
        bondingCurve.depositAtomCurve{value: getMinDeposit() * 100}(alice, atomId, CURVE_ID);

        // Get shares
        (uint256 shares,) = bondingCurve.getVaultStateForUserCurve(atomId, CURVE_ID, alice);

        // Try to redeem from atom vault using redeemTripleCurve - should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultNotTriple.selector));
        bondingCurve.redeemTripleCurve(shares, alice, atomId, CURVE_ID);

        vm.stopPrank();
    }

    function testRedeemTripleCurveZeroShares() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 100; // Increase initial deposit significantly

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create a triple
        uint256 id = ethMultiVault.createTriple{value: getTripleCost()}(subjectId, predicateId, objectId);

        // execute interaction - deposit triple
        bondingCurve.depositTripleCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_DepositOrWithdrawZeroShares.selector));
        // execute interaction - redeem all triple shares
        bondingCurve.redeemTripleCurve(0, alice, id, CURVE_ID);

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}
