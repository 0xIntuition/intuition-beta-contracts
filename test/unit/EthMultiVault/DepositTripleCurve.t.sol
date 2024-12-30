// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";

contract DepositTripleCurveTest is EthMultiVaultBase, EthMultiVaultHelpers {
    uint256 constant CURVE_ID = 2;

    function setUp() external {
        _setUp();
    }

    function testDepositTripleCurve() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10;

        // create atoms and triple
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");
        uint256 id = ethMultiVault.createTriple{value: getTripleCost()}(subjectId, predicateId, objectId);

        // Initial deposit by alice
        uint256 aliceInitialBalance = address(alice).balance;
        ethMultiVault.depositTripleCurve{value: testDepositAmount}(alice, id, CURVE_ID);
        
        // Check alice's balance change
        assertEq(aliceInitialBalance - address(alice).balance, testDepositAmount);
        
        // Check alice's shares and assets
        (uint256 aliceShares, uint256 aliceAssets) = ethMultiVault.getVaultStateForUserCurve(id, CURVE_ID, alice);
        assertTrue(aliceShares > 0);
        assertTrue(aliceAssets > 0);

        vm.stopPrank();

        // Bob deposits
        vm.startPrank(bob, bob);
        uint256 bobInitialBalance = address(bob).balance;
        ethMultiVault.depositTripleCurve{value: testDepositAmount}(bob, id, CURVE_ID);
        
        // Check bob's balance change
        assertEq(bobInitialBalance - address(bob).balance, testDepositAmount);
        
        // Check bob's shares and assets
        (uint256 bobShares, uint256 bobAssets) = ethMultiVault.getVaultStateForUserCurve(id, CURVE_ID, bob);
        assertTrue(bobShares > 0);
        assertTrue(bobAssets > 0);

        vm.stopPrank();
    }

    function testDepositTripleCurveZeroShares() external {
        vm.startPrank(address(1), address(1));

        // execute interaction - approve sender
        ethMultiVault.approveSender(alice);

        vm.stopPrank();

        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10; // Increase initial deposit

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create a triple
        uint256 id = ethMultiVault.createTriple{value: getTripleCost()}(subjectId, predicateId, objectId);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_MinimumDeposit.selector));
        // execute interaction - deposit triple
        ethMultiVault.depositTripleCurve{value: 0}(address(1), id, CURVE_ID);

        vm.stopPrank();
    }

    function testDepositTripleCurveBelowMinimumDeposit() external {
        vm.startPrank(address(1), address(1));

        // execute interaction - approve sender
        ethMultiVault.approveSender(alice);

        vm.stopPrank();

        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10; // Increase initial deposit

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create a triple
        uint256 id = ethMultiVault.createTriple{value: getTripleCost()}(subjectId, predicateId, objectId);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_MinimumDeposit.selector));
        // execute interaction - deposit triple
        ethMultiVault.depositTripleCurve{value: testMinDeposit - 1}(address(1), id, CURVE_ID);

        vm.stopPrank();
    }

    function testDepositTripleCurveIsNotTriple() external {
        vm.startPrank(address(1), address(1));

        // execute interaction - approve sender
        ethMultiVault.approveSender(alice);

        vm.stopPrank();

        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10; // Increase initial deposit

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create a triple
        ethMultiVault.createTriple{value: getTripleCost()}(subjectId, predicateId, objectId);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultNotTriple.selector));
        // execute interaction - deposit triple
        ethMultiVault.depositTripleCurve{value: testDepositAmount}(address(1), subjectId, CURVE_ID);

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}