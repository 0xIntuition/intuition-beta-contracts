// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";
import {StringUtils} from "./StringUtils.sol";

contract ProfitTest is EthMultiVaultBase, EthMultiVaultHelpers {
    using StringUtils for uint256;

    uint256 constant CURVE_ID = 2;

    function setUp() external {
        _setUp();
    }

    function testBondingCurveProfit() external {
        // Alice creates an atom and deposits
        vm.startPrank(alice, alice);
        uint256 atomCost = getAtomCost();
        uint256 atomId = ethMultiVault.createAtom{value: atomCost}("profitAtom");
        
        uint256 aliceInitialBalance = address(alice).balance;
        uint256 aliceDepositAmount = 1 ether;
        ethMultiVault.depositAtomCurve{value: aliceDepositAmount}(alice, atomId, CURVE_ID);
        (uint256 aliceShares,) = ethMultiVault.getVaultStateForUserCurve(atomId, CURVE_ID, alice);
        vm.stopPrank();

        // Bob deposits
        vm.startPrank(bob, bob);
        uint256 bobInitialBalance = address(bob).balance;
        uint256 bobDepositAmount = 1 ether;
        ethMultiVault.depositAtomCurve{value: bobDepositAmount}(bob, atomId, CURVE_ID);
        (uint256 bobShares,) = ethMultiVault.getVaultStateForUserCurve(atomId, CURVE_ID, bob);
        vm.stopPrank();

        // Alice redeems all shares
        vm.startPrank(alice, alice);
        uint256 aliceBalanceBeforeRedeem = address(alice).balance;
        uint256 aliceRedeemAmount = ethMultiVault.redeemAtomCurve(aliceShares, alice, atomId, CURVE_ID);
        uint256 aliceProfit = address(alice).balance - aliceBalanceBeforeRedeem;
        console.log("Alice redeemed her shares for %s ETH", aliceRedeemAmount.toString());
        console.log("She purchased them with %s ETH", aliceDepositAmount.toString());
        console.log("Profit: %s ETH (%s)", aliceProfit.toString(), StringUtils.toPercentage(aliceProfit, aliceDepositAmount));
        vm.stopPrank();

        // Bob redeems all shares
        vm.startPrank(bob, bob);
        uint256 bobBalanceBeforeRedeem = address(bob).balance;
        uint256 bobRedeemAmount = ethMultiVault.redeemAtomCurve(bobShares, bob, atomId, CURVE_ID);
        uint256 bobLoss = bobDepositAmount - (address(bob).balance - bobBalanceBeforeRedeem);
        console.log("Bob sold all his shares for %s ETH", bobRedeemAmount.toString());
        console.log("He initially bought them for %s ETH", bobDepositAmount.toString());
        console.log("Loss: %s ETH (%s)", bobLoss.toString(), StringUtils.toPercentage(bobLoss, bobDepositAmount));
        vm.stopPrank();
    }
} 