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

    function testDepositTriple() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testDespositAmount = 1 ether;

        // execute interaction - create atoms
        uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
        uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
        uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

        console.log("tripleCost: %s", getTripleCost());

        // execute interaction - create a triple using test deposit amount for triple (0.01 ether)
        uint256 id = ethMultiVault.createTriple{value: getTripleCost()}(subjectId, predicateId, objectId);

        // uint256 atomDepositFractionValue = atomDepositFractionAmount(valueToDeposit, id);
        // console.log("atomDepositFractionValue: %s", atomDepositFractionValue);

        vm.stopPrank();

        // snapshots before interaction
        // uint256 totalAssetsBefore = vaultTotalAssets(id);
        // uint256 totalSharesBefore = vaultTotalShares(id);
        // uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;

        // uint256[3] memory totalAssetsBeforeAtomVaults =
        //     [vaultTotalAssets(subjectId), vaultTotalAssets(predicateId), vaultTotalAssets(objectId)];
        // uint256[3] memory totalSharesBeforeAtomVaults =
        //     [vaultTotalShares(subjectId), vaultTotalShares(predicateId), vaultTotalShares(objectId)];

        vm.startPrank(bob, bob);

        uint256 positiveVaultAssetsBefore = vaultTotalAssets(id);
        console.log("positiveVaultAssetsBefore: %s", positiveVaultAssetsBefore);
        assertEq(positiveVaultAssetsBefore, 0.01 ether);

        // execute interaction - deposit atoms
        ethMultiVault.depositTriple{value: testDespositAmount}(address(1), id);

        uint256 protocolVaultBalanceAfter = address(getProtocolVault()).balance;
        console.log("protocolVaultBalanceAfter: %s", protocolVaultBalanceAfter);
        assertEq(protocolVaultBalanceAfter, 0.21 ether); // account for the atom and triple creation fees

        uint256 valueToDeposit = testDespositAmount - getProtocolFeeAmount(testDespositAmount, id);
        console.log("valueToDeposit: %s", valueToDeposit);
        assertEq(valueToDeposit, 0.99 ether);

        uint256 atomDepositFractionValue = atomDepositFractionAmount(valueToDeposit, id);
        console.log("atomDepositFractionValue: %s", atomDepositFractionValue);
        assertEq(atomDepositFractionValue, 0.1485 ether);

        uint256 entryFeeAmountPerAtom = entryFeeAmount(atomDepositFractionValue / 3, id);
        console.log("entryFeeAmountPerAtom: %s", entryFeeAmountPerAtom);
        assertEq(entryFeeAmountPerAtom, 0.002475 ether);

        uint256 subjectVaultTotalAssetsAfter = vaultTotalAssets(subjectId);
        console.log("subjectVaultTotalAssetsAfter: %s", subjectVaultTotalAssetsAfter);
        assertEq(subjectVaultTotalAssetsAfter, 0.0495 ether + 0.11 ether); // account for the previous atom assets

        uint256 userBalanceInSubjectVault = getSharesInVault(subjectId, address(1));
        console.log("userBalanceInSubjectVault: %s", userBalanceInSubjectVault);
        assertEq(userBalanceInSubjectVault, 0.047025 ether);

        uint256 userSharesInPositiveVault = getSharesInVault(id, address(1));
        console.log("userSharesInPositiveVault: %s", userSharesInPositiveVault);
        // assertEq(userSharesInPositiveVault, 0.99 ether);

        uint256 vaultTotalSharesAfter = vaultTotalShares(id);
        console.log("vaultTotalSharesAfter: %s", vaultTotalSharesAfter);
        assertEq(vaultTotalSharesAfter, 0.99 ether);

        uint256 positiveVaultAssetsAfter = vaultTotalAssets(id);
        console.log("positiveVaultAssetsAfter: %s", positiveVaultAssetsAfter);
        assertEq(positiveVaultAssetsAfter, 0.8415 ether);

        uint256 calc = valueToDeposit - entryFeeAmount(valueToDeposit, id) - atomDepositFractionAmount(valueToDeposit, id);
        console.log("calc: %s", calc);

        // uint256 sharePrice = positiveVaultAssetsAfter * 1e18 / vaultTotalShares(id);
        // console.log("sharePrice: %s", sharePrice);
        // assertEq(sharePrice, getCurrentSharePrice(id));
  
        // checkDepositIntoVault(valueToDeposit, id, totalAssetsBefore, totalSharesBefore);

        // checkProtocolVaultBalance(id, testDespositAmount, protocolVaultBalanceBefore);

        // // ------ Check Distribute Atom Equity ------ //
        // uint256 amountToDistribute = atomDepositFractionAmount(valueToDeposit, id);
        // uint256 distributeAmountPerAtomVault = amountToDistribute / 3;

        // checkDepositIntoVault(
        //     distributeAmountPerAtomVault, subjectId, totalAssetsBeforeAtomVaults[0], totalSharesBeforeAtomVaults[0]
        // );

        // checkDepositIntoVault(
        //     distributeAmountPerAtomVault, predicateId, totalAssetsBeforeAtomVaults[1], totalSharesBeforeAtomVaults[1]
        // );

        // checkDepositIntoVault(
        //     distributeAmountPerAtomVault, objectId, totalAssetsBeforeAtomVaults[2], totalSharesBeforeAtomVaults[2]
        // );

        // execute interaction - deposit triple into counter vault
        // uint256 counterId = ethMultiVault.getCounterIdFromTriple(id);

        // ethMultiVault.depositTriple{value: testDespositAmount}(address(2), counterId);

        vm.stopPrank();
    }

    // function testDepositTripleZeroShares() external {
    //     vm.startPrank(alice, alice);

    //     // test values
    //     uint256 testAtomCost = getAtomCost();
    //     uint256 testDepositAmountTriple = getTripleCost();

    //     // execute interaction - create atoms
    //     uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
    //     uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
    //     uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

    //     // execute interaction - create a triple
    //     uint256 id = ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

    //     vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_DepositOrWithdrawZeroShares.selector));
    //     // execute interaction - deposit triple
    //     ethMultiVault.depositTriple{value: 0}(address(1), id);

    //     vm.stopPrank();
    // }

    // function testDepositTripleBelowMinimumDeposit() external {
    //     vm.startPrank(alice, alice);

    //     // test values
    //     uint256 testAtomCost = getAtomCost();
    //     uint256 testMinDesposit = getMinDeposit();
    //     uint256 testDespositAmount = testMinDesposit;
    //     uint256 testDepositAmountTriple = getTripleCost() - 1;

    //     // execute interaction - create atoms
    //     uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
    //     uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
    //     uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

    //     // execute interaction - create a triple
    //     uint256 id = ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

    //     vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_MinimumDeposit.selector));
    //     // execute interaction - deposit triple
    //     ethMultiVault.depositTriple{value: testDespositAmount - 1}(address(1), id);

    //     vm.stopPrank();
    // }

    // function testDepositTripleIsNotTriple() external {
    //     vm.startPrank(alice, alice);

    //     // test values
    //     uint256 testAtomCost = getAtomCost();
    //     uint256 testDepositAmountTriple = getTripleCost();

    //     // execute interaction - create atoms
    //     uint256 subjectId = ethMultiVault.createAtom{value: testAtomCost}("subject");
    //     uint256 predicateId = ethMultiVault.createAtom{value: testAtomCost}("predicate");
    //     uint256 objectId = ethMultiVault.createAtom{value: testAtomCost}("object");

    //     // execute interaction - create a triple
    //     ethMultiVault.createTriple{value: testDepositAmountTriple}(subjectId, predicateId, objectId);

    //     vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_VaultNotTriple.selector));
    //     // execute interaction - deposit triple
    //     ethMultiVault.depositTriple{value: testDepositAmountTriple}(address(1), subjectId);

    //     vm.stopPrank();
    // }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}
