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
        uint256 testDepositAmount = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create a triple using test deposit amount for triple (0.01 ether)
        uint256 id = ethMultiVault.createTriple{value: getTripleCost()}(subjectId, predicateId, objectId);

        vm.stopPrank();

        // snapshots before interaction
        uint256 totalAssetsBefore = vaultTotalAssetsCurve(id, CURVE_ID);
        uint256 totalSharesBefore = vaultTotalSharesCurve(id, CURVE_ID);
        uint256 protocolMultisigBalanceBefore = address(getProtocolMultisig()).balance;

        uint256[3] memory totalAssetsBeforeAtomVaults = [
            vaultTotalAssetsCurve(subjectId, CURVE_ID),
            vaultTotalAssetsCurve(predicateId, CURVE_ID),
            vaultTotalAssetsCurve(objectId, CURVE_ID)
        ];
        uint256[3] memory totalSharesBeforeAtomVaults = [
            vaultTotalSharesCurve(subjectId, CURVE_ID),
            vaultTotalSharesCurve(predicateId, CURVE_ID),
            vaultTotalSharesCurve(objectId, CURVE_ID)
        ];

        vm.startPrank(address(1), address(1));

        // execute interaction - approve sender
        ethMultiVault.approveSender(bob);

        vm.stopPrank();

        vm.startPrank(address(2), address(2));

        // execute interaction - approve sender
        ethMultiVault.approveSender(bob);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        ethMultiVault.depositTripleCurve{value: testDepositAmount}(address(1), id, CURVE_ID);

        uint256 userDepositAfterprotocolFee = testDepositAmount - getProtocolFeeAmount(testDepositAmount, id);

        checkDepositIntoVaultCurve(userDepositAfterprotocolFee, id, CURVE_ID, totalAssetsBefore, totalSharesBefore);

        checkProtocolMultisigBalance(id, testDepositAmount, protocolMultisigBalanceBefore);

        // ------ Check Deposit Atom Fraction ------ //
        uint256 amountToDistribute = atomDepositFractionAmount(userDepositAfterprotocolFee, id);
        uint256 distributeAmountPerAtomVault = amountToDistribute / 3;

        checkDepositIntoVaultCurve(
            distributeAmountPerAtomVault,
            subjectId,
            CURVE_ID,
            totalAssetsBeforeAtomVaults[0],
            totalSharesBeforeAtomVaults[0]
        );

        checkDepositIntoVaultCurve(
            distributeAmountPerAtomVault,
            predicateId,
            CURVE_ID,
            totalAssetsBeforeAtomVaults[1],
            totalSharesBeforeAtomVaults[1]
        );

        checkDepositIntoVaultCurve(
            distributeAmountPerAtomVault,
            objectId,
            CURVE_ID,
            totalAssetsBeforeAtomVaults[2],
            totalSharesBeforeAtomVaults[2]
        );

        // execute interaction - deposit triple into counter vault
        uint256 counterId = ethMultiVault.getCounterIdFromTriple(id);

        ethMultiVault.depositTripleCurve{value: testDepositAmount}(address(2), counterId, CURVE_ID);

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
        uint256 testDepositAmountTriple = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create a triple
        uint256 id = ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

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
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDepositAmount = testMinDesposit;
        uint256 testDepositAmountTriple = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create a triple
        uint256 id = ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_MinimumDeposit.selector));
        // execute interaction - deposit triple
        ethMultiVault.depositTripleCurve{value: testDepositAmount - 1}(address(1), id, CURVE_ID);

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
        uint256 testDepositAmountTriple = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        // execute interaction - create a triple
        ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultNotTriple.selector));
        // execute interaction - deposit triple
        ethMultiVault.depositTripleCurve{value: testDepositAmountTriple}(address(1), subjectId, CURVE_ID);

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}