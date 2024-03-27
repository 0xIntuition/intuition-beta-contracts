// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {EthMultiVaultBase} from "../../EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "../../helpers/EthMultiVaultHelpers.sol";
import {Errors} from "../../../src/libraries/Errors.sol";

contract CreateTripleTest is EthMultiVaultBase, EthMultiVaultHelpers {
    function setUp() external {
        _setUp();
    }

    function testCreateTriple() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 testDepositAmount = getAtomCost();
        uint256 testDepositAmountTriple = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testDepositAmount}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testDepositAmount}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testDepositAmount}("object");

        // snapshots before creating a triple
        uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;
        uint256 lastVaultIdBeforeCreatingTriple = ethMultiVault.count();

        // execute interaction - create triples
        uint256 id = ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        // should have created a new atom vault and triple-atom vault
        assertEq(id, lastVaultIdBeforeCreatingTriple + 1);

        uint256 counterId = ethMultiVault.getCounterIdFromTriple(id);
        assertEq(vaultBalanceOf(counterId, address(0)), vaultBalanceOf(id, address(0)));
        assertEq(vaultTotalAssets(counterId), getMinShare());

        vm.stopPrank();
    }

    function testCreateTripleUniqueness() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testDepositAmountTriple = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create triples
        ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.MultiVault_TripleExists.selector, "subject", "predicate", "object")
        );
        ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        vm.stopPrank();
    }

    function testCreateTripleNonExistentAtomVaultID() external {
        vm.startPrank(alice, alice);

        uint256 testDepositAmountTriple = 0.01 ether;

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_AtomDoesNotExist.selector));
        ethMultiVault.createTriple{value: testDepositAmountTriple}(0, 0, 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_AtomDoesNotExist.selector));
        ethMultiVault.createTriple{value: testDepositAmountTriple}(7, 8, 9);

        vm.stopPrank();
    }

    function testCreateTripleVaultIDIsNotTriple() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testDepositAmountTriple = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");
        uint256 positiveVaultId =
            ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);
        assertEq(ethMultiVault.count(), 4);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_VaultIsTriple.selector));
        ethMultiVault.createTriple{value: testDepositAmountTriple}(positiveVaultId, predicateId, objectId);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_VaultIsTriple.selector));
        ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, positiveVaultId, objectId);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_VaultIsTriple.selector));
        ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, positiveVaultId);

        vm.stopPrank();
    }

    function testCreateTripleInsufficientBalance() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InsufficientBalance.selector));
        ethMultiVault.createTriple(subjectId, predicateId, objectId);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InsufficientBalance.selector));
        ethMultiVault.createAtom{value: testAtomCost - 1}("atom1");

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}
