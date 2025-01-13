// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";

contract DepositTripleTest is EthMultiVaultBase, EthMultiVaultHelpers {
    function setUp() external {
        _setUp();
    }

    function testDepositTriple() external {
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
        uint256 totalAssetsBefore = vaultTotalAssets(id);
        uint256 totalSharesBefore = vaultTotalShares(id);
        uint256 protocolMultisigBalanceBefore = address(getProtocolMultisig()).balance;

        uint256[3] memory totalAssetsBeforeAtomVaults =
            [vaultTotalAssets(subjectId), vaultTotalAssets(predicateId), vaultTotalAssets(objectId)];
        uint256[3] memory totalSharesBeforeAtomVaults =
            [vaultTotalShares(subjectId), vaultTotalShares(predicateId), vaultTotalShares(objectId)];

        vm.startPrank(address(1), address(1));

        // execute interaction - approve sender
        adminControl.approveSender(bob);

        vm.stopPrank();

        vm.startPrank(address(2), address(2));

        // execute interaction - approve sender
        adminControl.approveSender(bob);

        vm.stopPrank();

        vm.startPrank(bob, bob);

        // execute interaction - deposit atoms
        ethMultiVault.depositTriple{value: testDepositAmount}(address(1), id);

        uint256 userDepositAfterprotocolFee = testDepositAmount - getProtocolFeeAmount(testDepositAmount, id);

        checkDepositIntoVault(userDepositAfterprotocolFee, id, totalAssetsBefore, totalSharesBefore);

        checkProtocolMultisigBalance(id, testDepositAmount, protocolMultisigBalanceBefore);

        // ------ Check Deposit Atom Fraction ------ //
        uint256 amountToDistribute = atomDepositFractionAmount(userDepositAfterprotocolFee, id);
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

        // execute interaction - deposit triple into counter vault
        uint256 counterId = ethMultiVault.getCounterIdFromTriple(id);

        ethMultiVault.depositTriple{value: testDepositAmount}(address(2), counterId);

        vm.stopPrank();
    }

    function testDepositTripleZeroShares() external {
        vm.startPrank(address(1), address(1));

        // execute interaction - approve sender
        adminControl.approveSender(alice);

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
        ethMultiVault.depositTriple{value: 0}(address(1), id);

        vm.stopPrank();
    }

    function testDepositTripleBelowMinimumDeposit() external {
        vm.startPrank(address(1), address(1));

        // execute interaction - approve sender
        adminControl.approveSender(alice);

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
        ethMultiVault.depositTriple{value: testDepositAmount - 1}(address(1), id);

        vm.stopPrank();
    }

    function testDepositTripleIsNotTriple() external {
        vm.startPrank(address(1), address(1));

        // execute interaction - approve sender
        adminControl.approveSender(alice);

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
        ethMultiVault.depositTriple{value: testDepositAmountTriple}(address(1), subjectId);

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}
