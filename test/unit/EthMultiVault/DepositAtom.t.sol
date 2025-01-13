// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";

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
        uint256 testDepositAmount = testMinDesposit;

        // execute interaction - create atoms
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        vm.stopPrank();

        // snapshots before interaction
        uint256 totalAssetsBefore = vaultTotalAssets(id);
        uint256 totalSharesBefore = vaultTotalShares(id);
        console.log("totalAssetsBefore", totalAssetsBefore);
        console.log("totalSharesBefore", totalSharesBefore);
        uint256 protocolMultisigBalanceBefore = address(getProtocolMultisig()).balance;

        vm.startPrank(bob, bob);

        uint256 protocolFee = getProtocolFeeAmount(testDepositAmount, id);
        uint256 valueToDeposit = testDepositAmount - protocolFee;

        uint256 sharesExpected = convertToShares(valueToDeposit - entryFeeAmount(valueToDeposit, id), id);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_SenderNotApproved.selector));
        ethMultiVault.depositAtom{value: testDepositAmount}(address(1), id);

        vm.stopPrank();

        vm.startPrank(address(1), address(1));

        // execute interaction - approve sender
        adminControl.approveSender(bob);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atom
        ethMultiVault.depositAtom{value: testDepositAmount}(address(1), id);

        checkDepositIntoVault(valueToDeposit, id, totalAssetsBefore, totalSharesBefore);

        checkProtocolMultisigBalance(id, testDepositAmount, protocolMultisigBalanceBefore);

        (uint256 sharesGot, uint256 assetsGot) = getVaultStateForUser(id, address(1));

        uint256 assetsExpected = convertToAssets(sharesGot, id);

        assertEq(assetsExpected, assetsGot);
        assertEq(sharesExpected, sharesGot);

        vm.stopPrank();
    }

    function testDepositAtomBelowMinDeposit() external {
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
        adminControl.approveSender(bob);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_MinimumDeposit.selector));
        ethMultiVault.depositAtom{value: testDepositAmount}(address(1), id);

        vm.stopPrank();
    }

    function testDepositAtomNonExistentAtomVault() external {
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
        adminControl.approveSender(bob);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultDoesNotExist.selector));
        ethMultiVault.depositAtom{value: testDepositAmount}(address(1), id + 1);

        vm.stopPrank();
    }

    function testDepositAtomTripleVault() external {
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
        adminControl.approveSender(bob);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultNotAtom.selector));
        ethMultiVault.depositAtom{value: testDepositAmount}(address(1), positiveVaultId);

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}
