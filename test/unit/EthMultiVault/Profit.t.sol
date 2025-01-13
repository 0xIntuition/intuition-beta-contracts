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
    address internal charlie = makeAddr("charlie");

    function setUp() external {
        _setUp();
    }

    function testBondingCurveScenario(uint256 firstUserAmount, uint256 secondUserAmount) internal {
        // Alice creates an atom and deposits
        vm.startPrank(alice, alice);
        uint256 atomId = ethMultiVault.createAtom{value: getAtomCost()}("");
        bondingCurve.depositAtomCurve{value: firstUserAmount}(alice, atomId, CURVE_ID);
        (uint256 aliceShares,) = bondingCurve.getVaultStateForUserCurve(atomId, CURVE_ID, alice);
        vm.stopPrank();

        // Bob deposits
        vm.startPrank(bob, bob);
        bondingCurve.depositAtomCurve{value: secondUserAmount}(bob, atomId, CURVE_ID);
        (uint256 bobShares,) = bondingCurve.getVaultStateForUserCurve(atomId, CURVE_ID, bob);
        vm.stopPrank();

        // Alice redeems all shares
        vm.startPrank(alice, alice);
        uint256 balanceBefore = address(alice).balance;
        uint256 redeemAmount = bondingCurve.redeemAtomCurve(aliceShares, alice, atomId, CURVE_ID);
        uint256 profit = address(alice).balance - balanceBefore;
        console.log("Alice redeemed shares for %s", redeemAmount.toString());
        console.log("She purchased them with %s", firstUserAmount.toString());
        console.log("Profit: %s (%s)", profit.toString(), StringUtils.toPercentage(profit, firstUserAmount));
        vm.stopPrank();

        // Bob redeems all shares
        vm.startPrank(bob, bob);
        balanceBefore = address(bob).balance;
        redeemAmount = bondingCurve.redeemAtomCurve(bobShares, bob, atomId, CURVE_ID);
        int256 bobProfitOrLoss = int256(address(bob).balance) - int256(balanceBefore);
        console.log("Bob redeemed shares for %s", redeemAmount.toString());
        console.log("He purchased them with %s", secondUserAmount.toString());
        if (bobProfitOrLoss > 0) {
            console.log(
                "Profit: %s (%s)",
                uint256(bobProfitOrLoss).toString(),
                StringUtils.toPercentage(uint256(bobProfitOrLoss), secondUserAmount)
            );
        } else {
            console.log(
                "Loss: %s (%s)",
                uint256(-bobProfitOrLoss).toString(),
                StringUtils.toPercentage(uint256(-bobProfitOrLoss), secondUserAmount)
            );
        }
        vm.stopPrank();
    }

    function testBondingCurveThreeUserScenario(
        uint256 firstUserAmount,
        uint256 secondUserAmount,
        uint256 thirdUserAmount
    ) internal {
        // Fund charlie's account
        vm.deal(charlie, 100 ether);

        // Track total value in and out of system
        uint256 totalDeposited = firstUserAmount + secondUserAmount + thirdUserAmount;
        uint256 totalRedeemed;

        // Alice creates an atom and deposits
        vm.startPrank(alice, alice);
        uint256 atomId = ethMultiVault.createAtom{value: getAtomCost()}("");
        bondingCurve.depositAtomCurve{value: firstUserAmount}(alice, atomId, CURVE_ID);
        (uint256 aliceShares,) = bondingCurve.getVaultStateForUserCurve(atomId, CURVE_ID, alice);
        vm.stopPrank();

        // Bob deposits
        vm.startPrank(bob, bob);
        bondingCurve.depositAtomCurve{value: secondUserAmount}(bob, atomId, CURVE_ID);
        (uint256 bobShares,) = bondingCurve.getVaultStateForUserCurve(atomId, CURVE_ID, bob);
        vm.stopPrank();

        // Charlie deposits
        vm.startPrank(charlie, charlie);
        bondingCurve.depositAtomCurve{value: thirdUserAmount}(charlie, atomId, CURVE_ID);
        (uint256 charlieShares,) = bondingCurve.getVaultStateForUserCurve(atomId, CURVE_ID, charlie);
        vm.stopPrank();

        // Alice redeems all shares
        vm.startPrank(alice, alice);
        uint256 redeemAmount = bondingCurve.redeemAtomCurve(aliceShares, alice, atomId, CURVE_ID);
        totalRedeemed += redeemAmount;
        int256 aliceProfitOrLoss = int256(redeemAmount) - int256(firstUserAmount);
        console.log("Alice redeemed %s ETH from %s ETH deposit", redeemAmount.toString(), firstUserAmount.toString());
        if (aliceProfitOrLoss > 0) {
            console.log(
                "Profit: %s ETH (%s)",
                uint256(aliceProfitOrLoss).toString(),
                StringUtils.toPercentage(uint256(aliceProfitOrLoss), firstUserAmount)
            );
        } else {
            console.log(
                "Loss: %s ETH (%s)",
                uint256(-aliceProfitOrLoss).toString(),
                StringUtils.toPercentage(uint256(-aliceProfitOrLoss), firstUserAmount)
            );
        }
        vm.stopPrank();

        // Bob redeems all shares
        vm.startPrank(bob, bob);
        redeemAmount = bondingCurve.redeemAtomCurve(bobShares, bob, atomId, CURVE_ID);
        totalRedeemed += redeemAmount;
        int256 bobProfitOrLoss = int256(redeemAmount) - int256(secondUserAmount);
        console.log("Bob redeemed %s ETH from %s ETH deposit", redeemAmount.toString(), secondUserAmount.toString());
        if (bobProfitOrLoss > 0) {
            console.log(
                "Profit: %s ETH (%s)",
                uint256(bobProfitOrLoss).toString(),
                StringUtils.toPercentage(uint256(bobProfitOrLoss), secondUserAmount)
            );
        } else {
            console.log(
                "Loss: %s ETH (%s)",
                uint256(-bobProfitOrLoss).toString(),
                StringUtils.toPercentage(uint256(-bobProfitOrLoss), secondUserAmount)
            );
        }
        vm.stopPrank();

        // Charlie redeems all shares
        vm.startPrank(charlie, charlie);
        redeemAmount = bondingCurve.redeemAtomCurve(charlieShares, charlie, atomId, CURVE_ID);
        totalRedeemed += redeemAmount;
        int256 charlieProfitOrLoss = int256(redeemAmount) - int256(thirdUserAmount);
        console.log("Charlie redeemed %s ETH from %s ETH deposit", redeemAmount.toString(), thirdUserAmount.toString());
        if (charlieProfitOrLoss > 0) {
            console.log(
                "Profit: %s ETH (%s)",
                uint256(charlieProfitOrLoss).toString(),
                StringUtils.toPercentage(uint256(charlieProfitOrLoss), thirdUserAmount)
            );
        } else {
            console.log(
                "Loss: %s ETH (%s)",
                uint256(-charlieProfitOrLoss).toString(),
                StringUtils.toPercentage(uint256(-charlieProfitOrLoss), thirdUserAmount)
            );
        }
        vm.stopPrank();

        // Show total system profit/loss
        console.log("Total deposited: %s ETH", totalDeposited.toString());
        console.log("Total redeemed: %s ETH", totalRedeemed.toString());
        console.log("System loss (fees): %s ETH", (totalDeposited - totalRedeemed).toString());
    }

    function testBondingCurveProfit() external {
        testBondingCurveScenario(1 ether, 1 ether);
    }

    function testBondingCurveSmallVsLarge() external {
        // Test scenario where second user deposits 5x more than first
        // This is a common case where a larger player enters after a smaller one
        testBondingCurveScenario(1 ether, 5 ether);
    }

    function testBondingCurveTinyVsHuge() external {
        // Test extreme ratio (100x) to verify the math works at edges
        // 0.1 ETH vs 10 ETH represents a realistic range from small to whale deposits
        testBondingCurveScenario(0.1 ether, 10 ether);
    }

    function testBondingCurveRealisticAmounts() external {
        // Test with amounts that might be more common in practice
        // 2 ETH followed by 3 ETH represents typical user behavior
        // where users often deposit in round numbers
        testBondingCurveScenario(2 ether, 3 ether);
    }

    function testBondingCurveRealisticAmountsTwo() external {
        // Test with amounts that might be more common in practice
        // 2 ETH followed by 3 ETH represents typical user behavior
        // where users often deposit in round numbers
        testBondingCurveScenario(0.0003 ether, 4 ether);
    }

    function testBondingCurveSecondUserSmaller() external {
        // Test scenario where second user deposits less than first
        // This is important to verify the curve works in both directions
        testBondingCurveScenario(5 ether, 1 ether);
    }

    function testBondingCurveVeryLargeSecondDeposit() external {
        // Test scenario where second user deposits 100x more than first
        // This tests the extreme case of a whale entering after a small deposit
        testBondingCurveScenario(1 ether, 100 ether);
    }

    function testThreeUserEqualDeposits() external {
        // Test with all users depositing the same amount
        testBondingCurveThreeUserScenario(1 ether, 1 ether, 1 ether);
    }

    function testThreeUserIncreasing() external {
        // Test with each user depositing more than the last
        testBondingCurveThreeUserScenario(1 ether, 2 ether, 4 ether);
    }

    function testThreeUserWhaleInMiddle() external {
        // Test with a whale (Bob) in the middle
        testBondingCurveThreeUserScenario(1 ether, 10 ether, 1 ether);
    }

    function testThreeUserWhaleAtEnd() external {
        // Test with a whale (Charlie) at the end
        testBondingCurveThreeUserScenario(1 ether, 2 ether, 20 ether);
    }
}
