// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";

contract BatchDepositTest is EthMultiVaultBase, EthMultiVaultHelpers {
    uint256 constant CURVE_ID = 2;

    function setUp() external {
        _setUp();
    }

    function testBatchDeposit() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10;

        // Create atoms and triple
        uint256 atomId = ethMultiVault.createAtom{value: testAtomCost}("atom1");
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");
        uint256 tripleId = ethMultiVault.createTriple{value: getTripleCost()}(subjectId, predicateId, objectId);

        // Prepare arrays for batch deposit
        uint256[] memory termIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        termIds[0] = atomId;
        termIds[1] = tripleId;
        termIds[2] = subjectId;

        amounts[0] = testDepositAmount;
        amounts[1] = testDepositAmount;
        amounts[2] = testDepositAmount;

        // Initial deposit by alice
        uint256 aliceInitialBalance = address(alice).balance;
        uint256[] memory shares = ethMultiVault.batchDeposit{value: testDepositAmount * 3}(alice, termIds, amounts);

        // Check alice's balance change
        assertEq(aliceInitialBalance - address(alice).balance, testDepositAmount * 3);

        // Check alice's shares and assets for each vault
        for (uint256 i = 0; i < termIds.length; i++) {
            (uint256 aliceShares, uint256 aliceAssets) = ethMultiVault.getVaultStateForUser(termIds[i], alice);
            assertTrue(aliceShares > 0);
            assertTrue(aliceAssets > 0);
            assertEq(aliceShares, shares[i]);
        }

        vm.stopPrank();

        // Bob deposits
        vm.startPrank(bob, bob);
        uint256 bobInitialBalance = address(bob).balance;
        shares = ethMultiVault.batchDeposit{value: testDepositAmount * 3}(bob, termIds, amounts);

        // Check bob's balance change
        assertEq(bobInitialBalance - address(bob).balance, testDepositAmount * 3);

        // Check bob's shares and assets for each vault
        for (uint256 i = 0; i < termIds.length; i++) {
            (uint256 bobShares, uint256 bobAssets) = ethMultiVault.getVaultStateForUser(termIds[i], bob);
            assertTrue(bobShares > 0);
            assertTrue(bobAssets > 0);
            assertEq(bobShares, shares[i]);
        }

        vm.stopPrank();
    }

    function testBatchDepositCurve() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10;

        // Create atoms and triple
        uint256 atomId = ethMultiVault.createAtom{value: testAtomCost}("atom1");
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");
        uint256 tripleId = ethMultiVault.createTriple{value: getTripleCost()}(subjectId, predicateId, objectId);

        // Prepare arrays for batch deposit
        uint256[] memory termIds = new uint256[](3);
        uint256[] memory curveIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        termIds[0] = atomId;
        termIds[1] = tripleId;
        termIds[2] = subjectId;

        curveIds[0] = CURVE_ID;
        curveIds[1] = CURVE_ID;
        curveIds[2] = CURVE_ID;

        amounts[0] = testDepositAmount;
        amounts[1] = testDepositAmount;
        amounts[2] = testDepositAmount;

        // Initial deposit by alice
        uint256 aliceInitialBalance = address(alice).balance;
        uint256[] memory shares =
            ethMultiVault.batchDepositCurve{value: testDepositAmount * 3}(alice, termIds, curveIds, amounts);

        // Check alice's balance change
        assertEq(aliceInitialBalance - address(alice).balance, testDepositAmount * 3);

        // Check alice's shares and assets for each vault
        for (uint256 i = 0; i < termIds.length; i++) {
            (uint256 aliceShares, uint256 aliceAssets) =
                ethMultiVault.getVaultStateForUserCurve(termIds[i], curveIds[i], alice);
            assertTrue(aliceShares > 0);
            assertTrue(aliceAssets > 0);
            assertEq(aliceShares, shares[i]);
        }

        vm.stopPrank();

        // Bob deposits
        vm.startPrank(bob, bob);
        uint256 bobInitialBalance = address(bob).balance;
        shares = ethMultiVault.batchDepositCurve{value: testDepositAmount * 3}(bob, termIds, curveIds, amounts);

        // Check bob's balance change
        assertEq(bobInitialBalance - address(bob).balance, testDepositAmount * 3);

        // Check bob's shares and assets for each vault
        for (uint256 i = 0; i < termIds.length; i++) {
            (uint256 bobShares, uint256 bobAssets) =
                ethMultiVault.getVaultStateForUserCurve(termIds[i], curveIds[i], bob);
            assertTrue(bobShares > 0);
            assertTrue(bobAssets > 0);
            assertEq(bobShares, shares[i]);
        }

        vm.stopPrank();
    }

    function testBatchDepositBelowMinDeposit() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit / 2;

        // Create atoms
        uint256 atomId = ethMultiVault.createAtom{value: testAtomCost}("atom1");
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");

        // Prepare arrays for batch deposit
        uint256[] memory termIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        termIds[0] = atomId;
        termIds[1] = subjectId;

        amounts[0] = testDepositAmount;
        amounts[1] = testDepositAmount;

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_MinimumDeposit.selector));
        ethMultiVault.batchDeposit{value: testDepositAmount * 2}(alice, termIds, amounts);

        vm.stopPrank();
    }

    function testBatchDepositCurveBelowMinDeposit() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit / 2;

        // Create atoms
        uint256 atomId = ethMultiVault.createAtom{value: testAtomCost}("atom1");
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");

        // Prepare arrays for batch deposit
        uint256[] memory termIds = new uint256[](2);
        uint256[] memory curveIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        termIds[0] = atomId;
        termIds[1] = subjectId;

        curveIds[0] = CURVE_ID;
        curveIds[1] = CURVE_ID;

        amounts[0] = testDepositAmount;
        amounts[1] = testDepositAmount;

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_MinimumDeposit.selector));
        ethMultiVault.batchDepositCurve{value: testDepositAmount * 2}(alice, termIds, curveIds, amounts);

        vm.stopPrank();
    }

    function testBatchDepositNonExistentVault() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10;

        // Create atom
        uint256 atomId = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        // Prepare arrays for batch deposit
        uint256[] memory termIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        termIds[0] = atomId;
        termIds[1] = atomId + 1; // Non-existent vault

        amounts[0] = testDepositAmount;
        amounts[1] = testDepositAmount;

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultDoesNotExist.selector));
        ethMultiVault.batchDeposit{value: testDepositAmount * 2}(alice, termIds, amounts);

        vm.stopPrank();
    }

    function testBatchDepositCurveNonExistentVault() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10;

        // Create atom
        uint256 atomId = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        // Prepare arrays for batch deposit
        uint256[] memory termIds = new uint256[](2);
        uint256[] memory curveIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        termIds[0] = atomId;
        termIds[1] = atomId + 1; // Non-existent vault

        curveIds[0] = CURVE_ID;
        curveIds[1] = CURVE_ID;

        amounts[0] = testDepositAmount;
        amounts[1] = testDepositAmount;

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultDoesNotExist.selector));
        ethMultiVault.batchDepositCurve{value: testDepositAmount * 2}(alice, termIds, curveIds, amounts);

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}
