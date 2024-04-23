// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

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
        uint256 testDepositAmountTriple = 1 ether;

        assertEq(getTripleCost(), 0.07 ether);

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testDepositAmount}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testDepositAmount}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testDepositAmount}("object");

        // snapshots before creating a triple
        // uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;
        // uint256 lastVaultIdBeforeCreatingTriple = ethMultiVault.count();

        // execute interaction - create triples
        uint256 id = ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        // should have created a new atom vault and triple-atom vault
        // assertEq(id, lastVaultIdBeforeCreatingTriple + 1);

        uint256 counterId = ethMultiVault.getCounterIdFromTriple(id);
        assertEq(vaultBalanceOf(counterId, address(0)), vaultBalanceOf(id, address(0)));
        assertEq(vaultTotalAssets(counterId), getMinShare());

        // snapshots after creating a triple
        uint256 protocolVaultBalanceAfter = address(getProtocolVault()).balance;
        // uint256 protocolDepositFee = protocolFeeAmount(testDepositAmountTriple - getTripleCost(), id);
        // uint256 protocolVaultBalanceAfterLessFees =
        //     protocolVaultBalanceAfter - protocolDepositFee - getTripleCreationFee();
        // assertEq(protocolVaultBalanceBefore, protocolVaultBalanceAfterLessFees);

        uint256 userDepositAfterFees = 1 ether - getTripleCost() - protocolFeeAmount(1 ether - getTripleCost(), id);

        uint256 atomDepositFractionValue = atomDepositFractionAmount(userDepositAfterFees, id);
        console.log("atomDepositFractionValue: %s", atomDepositFractionValue);
        assertEq(atomDepositFractionValue, 0.138105 ether);

        console.log("protocolVaultBalanceAfter: %s", protocolVaultBalanceAfter);
        assertEq(protocolVaultBalanceAfter, 0.0593 ether + (0.05 ether * 3)); // account for the atom creation fees

        uint256 zeroAddressSharesInPositiveVault = getSharesInVault(id, address(0));
        console.log("zeroAddressSharesInPositiveVault: %s", zeroAddressSharesInPositiveVault);
        assertEq(zeroAddressSharesInPositiveVault, getMinShare());

        uint256 zeroAddressSharesInCounterVault = getSharesInVault(counterId, address(0));
        console.log("zeroAddressSharesInCounterVault: %s", zeroAddressSharesInCounterVault);
        assertEq(zeroAddressSharesInCounterVault, getMinShare());

        uint256 userBalanceInSubjectVault = getSharesInVault(subjectId, alice);
        console.log("userBalanceInSubjectVault: %s", userBalanceInSubjectVault);
        assertEq(userBalanceInSubjectVault, 0.04373325 ether);

        uint256 subjectVaultTotalAssetsAfter = vaultTotalAssets(subjectId);
        console.log("subjectVaultTotalAssetsAfter: %s", subjectVaultTotalAssetsAfter);
        assertEq(subjectVaultTotalAssetsAfter, 0.046035 ether + 0.11 ether); // account for the previous atom assets

        uint256 entryFeeAmountPerTriple = entryFeeAmount(atomDepositFractionValue / 3, id);
        console.log("entryFeeAmountPerTriple: %s", entryFeeAmountPerTriple);
        assertEq(entryFeeAmountPerTriple, 0.00230175 ether);

        uint256 positiveVaultAssetsAfter = vaultTotalAssets(id);
        console.log("positiveVaultAssetsAfter: %s", positiveVaultAssetsAfter);
        assertEq(positiveVaultAssetsAfter, 0.792595 ether);

        uint256 sharePrice = positiveVaultAssetsAfter * 1e18 / vaultTotalShares(id);
        console.log("sharePrice: %s", sharePrice);
        assertEq(sharePrice, getCurrentSharePrice(id));

        // uint256 atomDepositFractionFor3Atoms = remainder * getAtomDepositFraction() / 10000;
        // uint256 entryFeeFor3Atoms = entryFeeAmount(atomDepositFractionFor3Atoms, id);

        // uint256 userBalanceInPositiveVault = getSharesInVault(id, alice);
        // console.log("userBalanceInPositiveVault: %s", userBalanceInPositiveVault);
        // assertEq(userBalanceInPositiveVault - entryFeeFor3Atoms, 0.782595 ether + (0.04373325 ether * 3));

        // uint256 totalAssets = vaultTotalAssets(id);
        // console.log("totalAssets: %s", totalAssets);
        // assertEq(totalAssets, remainder + getMinShare());

        // uint256 totalShares = vaultTotalShares(id);
        // console.log("totalShares: %s", totalShares);
        // assertEq(totalShares, remainder + getMinShare());

        // uint256 counterVaultTotalAssets = vaultTotalAssets(counterId);
        // console.log("counterVaultTotalAssets: %s", counterVaultTotalAssets);
        // assertEq(counterVaultTotalAssets, getMinShare());

        // uint256 counterVaultTotalShares = vaultTotalShares(counterId);
        // console.log("counterVaultTotalShares: %s", counterVaultTotalShares);
        // assertEq(counterVaultTotalShares, getMinShare());

        // potential changes: 
        // 1.) subtract atomDepositFractionAmount in the _depositOnVaultCreation function
        // 2.) call the _depositAtomFraction function in the _createTriple

        vm.stopPrank();
    }

    function testCreateTripleUniqueness() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testDepositAmountTriple = 1 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create triples
        ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.MultiVault_TripleExists.selector, subjectId, predicateId, objectId)
        );
        ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        vm.stopPrank();
    }

    function testCreateTripleNonExistentAtomVaultID() external {
        vm.startPrank(alice, alice);

        uint256 testDepositAmountTriple = 1 ether;

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
        uint256 testDepositAmountTriple = 1 ether;

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
