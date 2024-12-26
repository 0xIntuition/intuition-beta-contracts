// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";

contract DepositAtomCurveTest is EthMultiVaultBase, EthMultiVaultHelpers {
    uint256 constant CURVE_ID = 2;

    function setUp() external {
        _setUp();
    }

    function testDepositAtomCurve() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDepositAmount = testMinDesposit;

        // execute interaction - create atoms
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        vm.stopPrank();

        // snapshots before interaction
        uint256 totalAssetsBefore = vaultTotalAssetsCurve(id, CURVE_ID);
        uint256 totalSharesBefore = vaultTotalSharesCurve(id, CURVE_ID);
        uint256 protocolMultisigBalanceBefore = address(getProtocolMultisig()).balance;

        vm.startPrank(bob, bob);

        uint256 protocolFee = getProtocolFeeAmount(testDepositAmount, id);
        uint256 valueToDeposit = testDepositAmount - protocolFee;

        uint256 sharesExpected = convertToSharesCurve(valueToDeposit - entryFeeAmount(valueToDeposit, id), id, CURVE_ID);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_SenderNotApproved.selector));
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(address(1), id, CURVE_ID);

        vm.stopPrank();

        vm.startPrank(address(1), address(1));

        // execute interaction - approve sender
        ethMultiVault.approveSender(bob);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atom
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(address(1), id, CURVE_ID);

        checkDepositIntoVaultCurve(valueToDeposit, id, CURVE_ID, totalAssetsBefore, totalSharesBefore);

        checkProtocolMultisigBalance(id, testDepositAmount, protocolMultisigBalanceBefore);

        (uint256 sharesGot, uint256 assetsGot) = getVaultStateForUserCurve(id, CURVE_ID, address(1));

        uint256 assetsExpected = convertToAssetsCurve(sharesGot, id, CURVE_ID);

        assertEq(assetsExpected, assetsGot);
        assertEq(sharesExpected, sharesGot);

        vm.stopPrank();
    }

    function testDepositAtomCurveBelowMinDeposit() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDepositAmount = testMinDesposit / 2;

        // execute interaction - create atom
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        vm.stopPrank();

        vm.startPrank(address(1), address(1));

        // execute interaction - approve sender
        ethMultiVault.approveSender(bob);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_MinimumDeposit.selector));
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(address(1), id, CURVE_ID);

        vm.stopPrank();
    }

    function testDepositAtomCurveNonExistentAtomVault() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDepositAmount = testMinDesposit;

        // execute interaction - create atoms
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        vm.stopPrank();

        vm.startPrank(address(1), address(1));

        // execute interaction - approve sender
        ethMultiVault.approveSender(bob);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultDoesNotExist.selector));
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(address(1), id + 1, CURVE_ID);

        vm.stopPrank();
    }

    function testDepositAtomCurveTripleVault() external {
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

        // execute interaction - create a triple
        uint256 positiveVaultId =
            ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        vm.stopPrank();

        vm.startPrank(address(1), address(1));

        // execute interaction - approve sender
        ethMultiVault.approveSender(bob);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultNotAtom.selector));
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(address(1), positiveVaultId, CURVE_ID);

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}