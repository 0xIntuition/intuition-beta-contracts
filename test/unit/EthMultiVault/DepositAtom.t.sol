// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {EthMultiVaultBase} from "../../EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "../../helpers/EthMultiVaultHelpers.sol";
import {Errors} from "../../../src/libraries/Errors.sol";

contract DepositAtomTest is EthMultiVaultBase, EthMultiVaultHelpers {
    function setUp() external {
        _setUp();
    }

    function testDepositAtom() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDespositAmount = testMinDesposit;

        // execute interaction - create atoms
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        vm.stopPrank();

        // snapshots before interaction
        uint256 totalAssetsBefore = vaultTotalAssets(id);
        uint256 totalSharesBefore = vaultTotalShares(id);
        uint256 protocolVaultBalanceBefore = address(getProtocolVault())
            .balance;

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        ethMultiVault.depositAtom{value: testDespositAmount}(address(1), id);

        uint256 protocolFee = getProtocolFeeAmount(testDespositAmount, id);
        uint256 valueToDeposit = testDespositAmount - protocolFee;

        checkDepositIntoVault(
            valueToDeposit,
            id,
            totalAssetsBefore,
            totalSharesBefore
        );

        checkProtocolVaultBalance(
            id,
            testDespositAmount,
            protocolVaultBalanceBefore
        );

        vm.stopPrank();
    }

    function testDepositAtomBelowMinDeposit() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDespositAmount = testMinDesposit / 2;

        // execute interaction - create atoms
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        vm.expectRevert(
            abi.encodeWithSelector(Errors.MultiVault_MinimumDeposit.selector)
        );
        ethMultiVault.depositAtom{value: testDespositAmount}(address(1), id);

        vm.stopPrank();
    }

    function testDepositAtomNonExistentAtomVault() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDespositAmount = testMinDesposit;

        // execute interaction - create atoms
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        vm.expectRevert(
            abi.encodeWithSelector(Errors.MultiVault_VaultDoesNotExist.selector)
        );
        ethMultiVault.depositAtom{value: testDespositAmount}(
            address(1),
            id + 1
        );

        vm.stopPrank();
    }

    function testDepositAtomTripleVault() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDespositAmount = testMinDesposit;
        uint256 testDepositAmountTriple = 0.01 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}(
            "subject"
        );
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}(
            "predicate"
        );
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}(
            "object"
        );

        // execute interaction - create a triple
        uint256 positiveVaultId = ethMultiVault.createTriple{
            value: testDepositAmountTriple
        }(subjectId, predicateId, objectId);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        vm.expectRevert(
            abi.encodeWithSelector(Errors.MultiVault_VaultNotAtom.selector)
        );
        ethMultiVault.depositAtom{value: testDespositAmount}(
            address(1),
            positiveVaultId
        );

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}
