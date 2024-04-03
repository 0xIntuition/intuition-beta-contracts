// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {EthMultiVaultBase} from "../../EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "../../helpers/EthMultiVaultHelpers.sol";
import {Errors} from "../../../src/libraries/Errors.sol";

contract BatchCreateTripleTest is EthMultiVaultBase, EthMultiVaultHelpers {
    function setUp() external {
        _setUp();
    }

    function testBatchCreateTriple() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 triplesToCreate = 2;
        uint256 testAtomCost = getAtomCost();
        uint256 testDepositAmountTriple = 0.01 ether;

        uint256[] memory subjectIds = new uint256[](triplesToCreate);
        uint256[] memory predicateIds = new uint256[](triplesToCreate);
        uint256[] memory objectIds = new uint256[](triplesToCreate);

        subjectIds[0] = ethMultiVault.createAtom{value: testAtomCost}("subject1");
        predicateIds[0] = ethMultiVault.createAtom{value: testAtomCost}("predicate1");
        objectIds[0] = ethMultiVault.createAtom{value: testAtomCost}("object1");

        subjectIds[1] = ethMultiVault.createAtom{value: testAtomCost}("subject2");
        predicateIds[1] = ethMultiVault.createAtom{value: testAtomCost}("predicate2");
        objectIds[1] = ethMultiVault.createAtom{value: testAtomCost}("object2");

        // snapshots before creating a triple
        uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;

        uint256 lastVaultIdBeforeCreatingTriple = ethMultiVault.count();
        assertEq(lastVaultIdBeforeCreatingTriple, 3 * triplesToCreate);

        uint256[] memory totalAssetsBefore = new uint256[](triplesToCreate);
        uint256[] memory totalSharesBefore = new uint256[](triplesToCreate);

        for (uint256 i = 0; i < triplesToCreate; i++) {
            totalAssetsBefore[i] = vaultTotalAssets(lastVaultIdBeforeCreatingTriple + (i + 1) * 2);
            totalSharesBefore[i] = vaultTotalShares(lastVaultIdBeforeCreatingTriple + (i + 1) * 2);
        }

        // execute interaction - create triples
        uint256[] memory ids = ethMultiVault.batchCreateTriple{value: testDepositAmountTriple * triplesToCreate}(
            subjectIds, predicateIds, objectIds
        );

        // should have created a new atom vault and triple-atom vault
        // for each triple
        assertEq(ids.length, triplesToCreate);

        // snapshots after creating a triple
        uint256 protocolVaultBalanceAfter = address(getProtocolVault()).balance;

        // sum up all protocol deposit fees and creation fees
        uint256 protocolFeesTotal;
        for (uint256 i = 0; i < triplesToCreate; i++) {
            protocolFeesTotal += protocolFeeAmount(testDepositAmountTriple - getTripleCost(), ids[i]);
        }

        uint256 protocolVaultBalanceAfterLessFees = protocolVaultBalanceAfter - protocolFeesTotal - (getTripleCreationFee() * triplesToCreate);
        assertEq(protocolVaultBalanceBefore, protocolVaultBalanceAfterLessFees);

        vm.stopPrank();
    }

    function testBatchCreateTripleUniqueness() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 triplesToCreate = 2;
        uint256 testAtomCost = getAtomCost();
        uint256 testDepositAmountTriple = 0.01 ether;

        uint256[] memory subjectIds = new uint256[](triplesToCreate);
        uint256[] memory predicateIds = new uint256[](triplesToCreate);
        uint256[] memory objectIds = new uint256[](triplesToCreate);

        // execute interaction - create atoms
        for (uint256 i = 0; i < triplesToCreate; i++) {
            subjectIds[i] = ethMultiVault.createAtom{value: testAtomCost}(abi.encodePacked(bytes("subject"), i));
            predicateIds[i] = ethMultiVault.createAtom{value: testAtomCost}(abi.encodePacked(bytes("predicate"), i));
            objectIds[i] = ethMultiVault.createAtom{value: testAtomCost}(abi.encodePacked(bytes("object"), i));
        }

        // execute interaction - create triples
        ethMultiVault.batchCreateTriple{value: testDepositAmountTriple * triplesToCreate}(
            subjectIds, predicateIds, objectIds
        );

        vm.stopPrank();
    }

    function testBatchCreateTripleInsufficientBalance() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 triplesToCreate = 3;
        uint256 testAtomCost = getAtomCost();

        uint256[] memory subjectIds = new uint256[](triplesToCreate);
        uint256[] memory predicateIds = new uint256[](triplesToCreate);
        uint256[] memory objectIds = new uint256[](triplesToCreate);

        // execute interaction - create atoms
        for (uint256 i = 0; i < triplesToCreate; i++) {
            subjectIds[i] = ethMultiVault.createAtom{value: testAtomCost}(abi.encodePacked(bytes("subject"), i));
            predicateIds[i] = ethMultiVault.createAtom{value: testAtomCost}(abi.encodePacked(bytes("predicate"), i));
            objectIds[i] = ethMultiVault.createAtom{value: testAtomCost}(abi.encodePacked(bytes("object"), i));
        }
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InsufficientBalance.selector));
        ethMultiVault.batchCreateTriple{value: testAtomCost * (triplesToCreate - 1)}(
            subjectIds, predicateIds, objectIds
        );

        vm.stopPrank();
    }

    function testBatchCreateTripleArrayNotSameLength() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 triplesToCreate = 3;
        uint256 testAtomCost = getAtomCost();

        uint256[] memory subjectIds = new uint256[](triplesToCreate);
        uint256[] memory predicateIds = new uint256[](triplesToCreate);
        uint256[] memory objectIds = new uint256[](triplesToCreate);

        // atomData[i] = abi.encodePacked(bytes("atom"), i);
        // execute interaction - create atoms
        for (uint256 i = 0; i < triplesToCreate; i++) {
            subjectIds[i] = ethMultiVault.createAtom{value: testAtomCost}(abi.encodePacked(bytes("subject"), i));
            predicateIds[i] = ethMultiVault.createAtom{value: testAtomCost}(abi.encodePacked(bytes("predicate"), i));
            objectIds[i] = ethMultiVault.createAtom{value: testAtomCost}(abi.encodePacked(bytes("object"), i));
        }

        // remove last element from subjectIds
        uint256[] memory newSubjectIds = new uint256[](subjectIds.length - 1);
        for (uint256 i = 0; i < newSubjectIds.length; i++) {
            newSubjectIds[i] = subjectIds[i];
        }

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ArraysNotSameLength.selector));
        ethMultiVault.batchCreateTriple{value: testAtomCost * (triplesToCreate - 1)}(
            newSubjectIds, predicateIds, objectIds
        );

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}
