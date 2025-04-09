// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";

contract DepositAtomCurveTest is EthMultiVaultBase, EthMultiVaultHelpers {
    uint256 constant CURVE_ID = 2;

    function setUp() external {
        _setUp();
    }

    function testDepositAtomCurve() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10;

        // create atom
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        // Initial deposit by alice
        uint256 aliceInitialBalance = address(alice).balance;
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(alice, id, CURVE_ID);

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
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(bob, id, CURVE_ID);

        // Check bob's balance change
        assertEq(bobInitialBalance - address(bob).balance, testDepositAmount);

        // Check bob's shares and assets
        (uint256 bobShares, uint256 bobAssets) = ethMultiVault.getVaultStateForUserCurve(id, CURVE_ID, bob);
        assertTrue(bobShares > 0);
        assertTrue(bobAssets > 0);

        vm.stopPrank();
    }

    function testDepositAtomCurveBelowMinDeposit() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit / 2;

        // execute interaction - create atom
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        vm.stopPrank();

        vm.startPrank(address(1), address(1));

        // execute interaction - approve sender
        ethMultiVault.approve(bob, IEthMultiVault.ApprovalTypes.DEPOSIT);

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
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10; // Increase initial deposit

        // execute interaction - create atoms
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        vm.stopPrank();

        vm.startPrank(address(1), address(1));

        // execute interaction - approve sender
        ethMultiVault.approve(bob, IEthMultiVault.ApprovalTypes.DEPOSIT);

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
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10; // Increase initial deposit
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
        ethMultiVault.approve(bob, IEthMultiVault.ApprovalTypes.DEPOSIT);

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
