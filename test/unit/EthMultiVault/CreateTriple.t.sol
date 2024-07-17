// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";

contract CreateTripleTest is EthMultiVaultBase, EthMultiVaultHelpers {
    function setUp() external {
        _setUp();
    }

    function testCreateTripleProtocolValues() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testDepositAmountTriple = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: getAtomCost()}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: getAtomCost()}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: getAtomCost()}("object");

        // snapshots before creating a triple
        uint256 protocolMultisigBalanceBefore = address(getProtocolMultisig()).balance;
        uint256 lastVaultIdBeforeCreatingTriple = ethMultiVault.count();

        // execute interaction - create triples
        uint256 id = ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        // should have created a new atom vault and triple-atom vault
        assertEq(id, lastVaultIdBeforeCreatingTriple + 1);

        uint256 counterId = ethMultiVault.getCounterIdFromTriple(id);
        assertEq(vaultBalanceOf(counterId, getAdmin()), vaultBalanceOf(id, getAdmin()));
        assertEq(vaultTotalAssets(counterId), getMinShare());

        // snapshots after creating a triple
        uint256 protocolMultisigBalanceAfter = address(getProtocolMultisig()).balance;
        uint256 protocolMultisigBalanceAfterLessFees = protocolMultisigBalanceAfter
            - protocolFeeAmount(testDepositAmountTriple - getTripleCost(), id) - getTripleCreationProtocolFee();
        assertEq(protocolMultisigBalanceBefore, protocolMultisigBalanceAfterLessFees);

        // totalAssetsBefore and totalSharesBefore are 0 since triple is new
        checkDepositOnTripleVaultCreation(id, testDepositAmountTriple, 0, 0);

        vm.stopPrank();
    }

    function testCreateTripleAtomDepositOnTripleCreation() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testDepositAmountTriple = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: getAtomCost()}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: getAtomCost()}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: getAtomCost()}("object");

        uint256[3] memory totalAssetsBeforeAtomVaults =
            [vaultTotalAssets(subjectId), vaultTotalAssets(predicateId), vaultTotalAssets(objectId)];
        uint256[3] memory totalSharesBeforeAtomVaults =
            [vaultTotalShares(subjectId), vaultTotalShares(predicateId), vaultTotalShares(objectId)];

        // execute interaction - create triples
        uint256 id = ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        // totalAssetsBefore and totalSharesBefore are 0 since triple is new
        checkDepositOnTripleVaultCreation(id, testDepositAmountTriple, 0, 0);

        uint256 userDeposit = testDepositAmountTriple - getTripleCost();
        uint256 protocolDepositFee = protocolFeeAmount(userDeposit, id);
        uint256 userDepositAfterprotocolFee = userDeposit - protocolDepositFee;

        uint256 atomDepositFraction = atomDepositFractionAmount(userDepositAfterprotocolFee, id);
        uint256 distributeAmountPerAtomVault = atomDepositFraction / 3;

        uint256 atomDepositFractionOnTripleCreationPerAtom = getAtomDepositFractionOnTripleCreation() / 3;

        checkAtomDepositIntoVaultOnTripleVaultCreation(
            distributeAmountPerAtomVault,
            atomDepositFractionOnTripleCreationPerAtom,
            subjectId,
            totalAssetsBeforeAtomVaults[0],
            totalSharesBeforeAtomVaults[0]
        );

        checkAtomDepositIntoVaultOnTripleVaultCreation(
            distributeAmountPerAtomVault,
            atomDepositFractionOnTripleCreationPerAtom,
            predicateId,
            totalAssetsBeforeAtomVaults[1],
            totalSharesBeforeAtomVaults[1]
        );

        checkAtomDepositIntoVaultOnTripleVaultCreation(
            distributeAmountPerAtomVault,
            atomDepositFractionOnTripleCreationPerAtom,
            objectId,
            totalAssetsBeforeAtomVaults[2],
            totalSharesBeforeAtomVaults[2]
        );

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
            abi.encodeWithSelector(Errors.EthMultiVault_TripleExists.selector, subjectId, predicateId, objectId)
        );
        ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        vm.stopPrank();
    }

    function testCreateTripleNonExistentAtomVaultID() external {
        vm.startPrank(alice, alice);

        uint256 testDepositAmountTriple = 0.01 ether;

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_AtomDoesNotExist.selector, 0));
        ethMultiVault.createTriple{value: testDepositAmountTriple}(0, 0, 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_AtomDoesNotExist.selector, 7));
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

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultIsTriple.selector, positiveVaultId));
        ethMultiVault.createTriple{value: testDepositAmountTriple}(positiveVaultId, predicateId, objectId);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultIsTriple.selector, positiveVaultId));
        ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, positiveVaultId, objectId);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultIsTriple.selector, positiveVaultId));
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

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_InsufficientBalance.selector));
        ethMultiVault.createTriple(subjectId, predicateId, objectId);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_InsufficientBalance.selector));
        ethMultiVault.createAtom{value: testAtomCost - 1}("atom1");

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}
