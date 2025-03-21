// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";

contract BatchRedeemTest is EthMultiVaultBase, EthMultiVaultHelpers {
    uint256 constant CURVE_ID = 2;

    function setUp() external {
        _setUp();
    }

    function testBatchRedeem() external {
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

        // Get initial state
        uint256 aliceInitialBalance = address(alice).balance;

        // Redeem 100% of shares from all vaults
        uint256[] memory assets = ethMultiVault.batchRedeem(10000, alice, termIds);

        // Verify balance change
        uint256 totalAssetsReceived = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            totalAssetsReceived += assets[i];
        }
        assertEq(address(alice).balance - aliceInitialBalance, totalAssetsReceived);

        // Verify shares are gone from all vaults
        for (uint256 i = 0; i < termIds.length; i++) {
            (uint256 sharesAfter,) = ethMultiVault.getVaultStateForUser(termIds[i], alice);
            assertEq(sharesAfter, 0);
        }

        vm.stopPrank();
    }

    function testBatchRedeemCurve() external {
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

        // Get initial state
        uint256 aliceInitialBalance = address(alice).balance;

        // Redeem 100% of shares from all vaults
        uint256[] memory assets = ethMultiVault.batchRedeemCurve(10000, alice, termIds, curveIds);

        // Verify balance change
        uint256 totalAssetsReceived = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            totalAssetsReceived += assets[i];
        }
        assertEq(address(alice).balance - aliceInitialBalance, totalAssetsReceived);

        // Verify shares are gone from all vaults
        for (uint256 i = 0; i < termIds.length; i++) {
            (uint256 sharesAfter,) = ethMultiVault.getVaultStateForUserCurve(termIds[i], curveIds[i], alice);
            assertEq(sharesAfter, 0);
        }

        vm.stopPrank();
    }

    function testBatchRedeemZeroShares() external {
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
        ethMultiVault.batchDeposit{value: testDepositAmount * 3}(alice, termIds, amounts);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_DepositOrWithdrawZeroShares.selector));
        ethMultiVault.batchRedeem(0, alice, termIds);

        vm.stopPrank();
    }

    function testBatchRedeemCurveZeroShares() external {
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
        ethMultiVault.batchDepositCurve{value: testDepositAmount * 3}(alice, termIds, curveIds, amounts);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_DepositOrWithdrawZeroShares.selector));
        ethMultiVault.batchRedeemCurve(0, alice, termIds, curveIds);

        vm.stopPrank();
    }

    function testBatchRedeemInsufficientBalance() external {
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
        ethMultiVault.batchDeposit{value: testDepositAmount * 3}(alice, termIds, amounts);

        vm.stopPrank();

        // Bob tries to redeem alice's shares
        vm.startPrank(bob, bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_InsufficientSharesInVault.selector));
        ethMultiVault.batchRedeem(100, bob, termIds);

        vm.stopPrank();
    }

    function testBatchRedeemCurveInsufficientBalance() external {
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
        ethMultiVault.batchDepositCurve{value: testDepositAmount * 3}(alice, termIds, curveIds, amounts);

        vm.stopPrank();

        // Bob tries to redeem alice's shares
        vm.startPrank(bob, bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_InsufficientSharesInVault.selector));
        ethMultiVault.batchRedeemCurve(100, bob, termIds, curveIds);

        vm.stopPrank();
    }

    function testBatchRedeemNonExistentVault() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10;

        // Create atom
        uint256 atomId = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        // Deposit into first vault
        ethMultiVault.depositAtom{value: testDepositAmount}(alice, atomId);

        // Prepare arrays for batch deposit
        uint256[] memory termIds = new uint256[](2);

        termIds[0] = atomId;
        termIds[1] = atomId + 1; // Non-existent vault

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultDoesNotExist.selector));
        ethMultiVault.batchRedeem(100, alice, termIds);

        vm.stopPrank();
    }

    function testBatchRedeemCurveNonExistentVault() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10;

        // Create atom
        uint256 atomId = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        // Deposit into first vault's curve vault
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(alice, atomId, CURVE_ID);

        // Prepare arrays for batch deposit
        uint256[] memory termIds = new uint256[](2);
        uint256[] memory curveIds = new uint256[](2);

        termIds[0] = atomId;
        termIds[1] = atomId + 1; // Non-existent vault

        curveIds[0] = CURVE_ID;
        curveIds[1] = CURVE_ID;

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultDoesNotExist.selector));
        ethMultiVault.batchRedeemCurve(100, alice, termIds, curveIds);

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}
