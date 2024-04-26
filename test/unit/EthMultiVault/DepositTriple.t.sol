// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {EthMultiVaultBase} from "../../EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "../../helpers/EthMultiVaultHelpers.sol";
import {Errors} from "../../../src/libraries/Errors.sol";

contract DepositTripleTest is EthMultiVaultBase, EthMultiVaultHelpers {
    function setUp() external {
        _setUp();
    }

    function testDepositTripleAtomDeposit() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testDepositAmountTriple = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: getAtomCost()}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: getAtomCost()}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: getAtomCost()}("object");

        // execute interaction - create a triple
        uint256 id = ethMultiVault.createTriple{value: getTripleCost()}(subjectId, predicateId, objectId);

        vm.stopPrank();

        // snapshots before interaction
        uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;

        uint256[3] memory totalAssetsBeforeAtomVaults =
            [vaultTotalAssets(subjectId), vaultTotalAssets(predicateId), vaultTotalAssets(objectId)];
        uint256[3] memory totalSharesBeforeAtomVaults =
            [vaultTotalShares(subjectId), vaultTotalShares(predicateId), vaultTotalShares(objectId)];

        vm.startPrank(bob, bob);

        // execute interaction - deposit triple
        ethMultiVault.depositTriple{value: testDepositAmountTriple}(address(1), id);

        uint256 userDepositAfterProtocolFees =
            testDepositAmountTriple - getProtocolFeeAmount(testDepositAmountTriple, id);

        checkProtocolVaultBalance(id, testDepositAmountTriple, protocolVaultBalanceBefore);

        uint256 amountToDistribute = atomDepositFractionAmount(userDepositAfterProtocolFees, id);
        uint256 distributeAmountPerAtomVault = amountToDistribute / 3;

        checkDepositIntoVault(
            distributeAmountPerAtomVault, subjectId, totalAssetsBeforeAtomVaults[0], totalSharesBeforeAtomVaults[0]
        );

        checkDepositIntoVault(
            distributeAmountPerAtomVault, predicateId, totalAssetsBeforeAtomVaults[1], totalSharesBeforeAtomVaults[1]
        );

        checkDepositIntoVault(
            distributeAmountPerAtomVault, objectId, totalAssetsBeforeAtomVaults[2], totalSharesBeforeAtomVaults[2]
        );

        vm.stopPrank();
    }

    function testDepositTripleZeroShares() external {
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

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_MinimumDeposit.selector));
        // execute interaction - deposit triple
        ethMultiVault.depositTriple{value: 0}(address(1), id);

        vm.stopPrank();
    }

    function testDepositTripleBelowMinimumDeposit() external {
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

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_MinimumDeposit.selector));
        // execute interaction - deposit triple
        ethMultiVault.depositTriple{value: testDepositAmount - 1}(address(1), id);

        vm.stopPrank();
    }

    function testDepositTripleIsNotTriple() external {
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

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_VaultNotTriple.selector));
        // execute interaction - deposit triple
        ethMultiVault.depositTriple{value: testDepositAmountTriple}(address(1), subjectId);

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}
