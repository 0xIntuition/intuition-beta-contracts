// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";

contract RedeemAtomCurveTest is EthMultiVaultBase, EthMultiVaultHelpers {
    uint256 constant CURVE_ID = 2;

    function setUp() external {
        _setUp();
    }

    function testRedeemAtomCurveAll() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10;

        // create atom and deposit
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        // Get initial state
        uint256 aliceInitialBalance = address(alice).balance;
        (uint256 aliceShares,) = ethMultiVault.getVaultStateForUserCurve(id, CURVE_ID, alice);

        console.log("aliceShares", aliceShares);
        console.log("Attempting to redeem them.");
        uint256 test = ethMultiVault.convertToAssetsCurve(aliceShares, id, CURVE_ID);
        console.log("In assets that's ", test);
        uint256 assetsInVault = vaultTotalAssetsCurve(id, CURVE_ID);
        console.log("In vault assets ", assetsInVault);
        
        // Redeem all shares
        uint256 assetsReceived = ethMultiVault.redeemAtomCurve(aliceShares, alice, id, CURVE_ID);
        
        // Verify balance change
        assertEq(address(alice).balance - aliceInitialBalance, assetsReceived);
        
        // Verify shares are gone
        (uint256 sharesAfter,) = ethMultiVault.getVaultStateForUserCurve(id, CURVE_ID, alice);
        assertEq(sharesAfter, 0);

        vm.stopPrank();
    }

    function testRedeemAtomCurveNonExistentVault() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10; // Increase initial deposit

        // execute interaction - create atoms
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        // execute interaction - deposit atoms
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        // snapshots before redeem
        uint256 userSharesBeforeRedeem = getSharesInVaultCurve(id, CURVE_ID, alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultDoesNotExist.selector));
        // execute interaction - redeem all atom shares
        ethMultiVault.redeemAtomCurve(userSharesBeforeRedeem, alice, id + 1, CURVE_ID);

        vm.stopPrank();
    }

    function testRedeemAtomCurveZeroShares() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10; // Increase initial deposit

        // execute interaction - create atoms
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        // execute interaction - deposit atoms
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_DepositOrWithdrawZeroShares.selector));
        // execute interaction - redeem all atom shares
        ethMultiVault.redeemAtomCurve(0, alice, id, CURVE_ID);

        vm.stopPrank();
    }

    function testRedeemAtomCurveInsufficientBalance() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDeposit = getMinDeposit();
        uint256 testDepositAmount = testMinDeposit * 10; // Increase initial deposit

        // execute interaction - create atoms
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        // execute interaction - deposit atoms
        ethMultiVault.depositAtomCurve{value: testDepositAmount}(alice, id, CURVE_ID);

        vm.stopPrank();

        // snapshots before redeem
        uint256 userSharesBeforeRedeem = getSharesInVaultCurve(id, CURVE_ID, alice);

        vm.startPrank(bob, bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_InsufficientSharesInVault.selector));
        // execute interaction - redeem all atom shares
        ethMultiVault.redeemAtomCurve(userSharesBeforeRedeem, bob, id, CURVE_ID);

        vm.stopPrank();
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}