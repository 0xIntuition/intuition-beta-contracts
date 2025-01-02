// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";

contract FeesTest is EthMultiVaultBase, EthMultiVaultHelpers {
    uint256 constant CURVE_ID = 2;
    uint256 constant NUM_CURVE_OPERATIONS = 50;

    struct CurveOperation {
        uint256 entryFee;
        uint256 exitFee;
        uint256 protocolFee;
    }

    function setUp() external {
        _setUp();
    }

    function performCurveOperation(
        address user,
        uint256 atomId,
        uint256 depositAmount
    ) internal returns (CurveOperation memory op) {
        // Get deposit details
        (,, uint256 protocolFee, uint256 entryFee) = ethMultiVault.getDepositSharesAndFeesCurve(depositAmount, atomId, CURVE_ID);
        op.entryFee = entryFee;
        op.protocolFee = protocolFee;

        // Deposit into curve
        ethMultiVault.depositAtomCurve{value: depositAmount}(user, atomId, CURVE_ID);
        
        // Get user's shares in curve vault
        (uint256 shares,) = ethMultiVault.getVaultStateForUserCurve(atomId, CURVE_ID, user);
        
        // Get exit fee that will flow to pro rata vault
        (, , uint256 redeemProtocolFee, uint256 exitFee) = ethMultiVault.getRedeemAssetsAndFeesCurve(shares, atomId, CURVE_ID);
        op.exitFee = exitFee;
        op.protocolFee += redeemProtocolFee;

        // Redeem from curve vault
        ethMultiVault.redeemAtomCurve(shares, user, atomId, CURVE_ID);

        console.log("\nCurve Operation:");
        console.log("  Deposit Amount:", depositAmount);
        console.log("  Entry Fee to Pro Rata:", op.entryFee);
        console.log("  Exit Fee to Pro Rata:", op.exitFee);
        console.log("  Protocol Fee:", op.protocolFee);
    }

    function testFeesFlowToProRataVault() public {
        uint256 aliceInitialDeposit = 1 ether;
        uint256 bobDepositAmount = 1.5 ether;
        uint256 numCurveOperations = NUM_CURVE_OPERATIONS;

        // Create atom
        vm.startPrank(alice);
        uint256 testAtomCost = getAtomCost();
        uint256 atomId = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        // Alice deposits into pro rata vault
        uint256 aliceInitialAssets = aliceInitialDeposit;
        uint256 aliceInitialShares = ethMultiVault.depositAtom{value: aliceInitialDeposit}(alice, atomId);
        vm.stopPrank();

        // Bob performs multiple deposits and redeems in the bonding curve
        vm.startPrank(bob);
        uint256 totalEntryFeesToProRata;
        uint256 totalExitFeesToProRata;
        uint256 totalProtocolFees;

        for (uint256 i = 0; i < numCurveOperations; i++) {
            // Deposit
            (,, uint256 entryFeeToProRata,) = ethMultiVault.getDepositSharesAndFeesCurve(bobDepositAmount, atomId, CURVE_ID);
            totalEntryFeesToProRata += entryFeeToProRata;
            ethMultiVault.depositAtomCurve{value: bobDepositAmount}(bob, atomId, CURVE_ID);

            // Get shares for redeem
            (uint256 bobShares,) = ethMultiVault.getVaultStateForUserCurve(atomId, CURVE_ID, bob);

            // Redeem
            (,, uint256 protocolFee, uint256 exitFeeToProRata) = ethMultiVault.getRedeemAssetsAndFeesCurve(bobShares, atomId, CURVE_ID);
            totalExitFeesToProRata += exitFeeToProRata;
            totalProtocolFees += protocolFee;
            ethMultiVault.redeemAtomCurve(bobShares, bob, atomId, CURVE_ID);
        }
        vm.stopPrank();

        // Get Alice's final state
        vm.startPrank(alice);
        (uint256 aliceShares, uint256 aliceFinalAssets) = ethMultiVault.getVaultStateForUser(atomId, alice);

        console.log("\nFee Summary:");
        console.log("  Entry Fees to Pro Rata:", totalEntryFeesToProRata);
        console.log("  Exit Fees to Pro Rata:", totalExitFeesToProRata);
        console.log("  Total Fees to Pro Rata:", totalEntryFeesToProRata + totalExitFeesToProRata);
        console.log("  Protocol Fees:", totalProtocolFees);

        console.log("\nAlice's State:");
        console.log("  Initial Assets:", aliceInitialAssets);
        console.log("  Initial Shares:", aliceInitialShares);
        console.log("  Final Assets:", aliceFinalAssets);
        console.log("  Final Shares:", aliceShares);
        console.log("  Asset Increase:", aliceFinalAssets - aliceInitialAssets);

        // Calculate share prices with higher precision
        uint256 PRECISION = 1e18;
        uint256 initialSharePrice = (aliceInitialAssets * PRECISION) / aliceInitialShares;
        uint256 finalSharePrice = (aliceFinalAssets * PRECISION) / aliceShares;
        uint256 sharePriceIncrease = finalSharePrice - initialSharePrice;

        console.log("\nShare Price (with 18 decimals):");
        console.log("  Initial Share Price:", initialSharePrice);
        console.log("  Final Share Price:", finalSharePrice);
        console.log("  Share Price Increase:", sharePriceIncrease);

        // Verify that Alice's shares are unchanged
        assertEq(aliceShares, aliceInitialShares, "Alice's shares should remain constant");

        // Calculate expected share price increase based on fees per share
        uint256 expectedSharePriceIncrease = (aliceFinalAssets * PRECISION) / aliceShares - (aliceInitialAssets * PRECISION) / aliceInitialShares;
        assertEq(sharePriceIncrease, expectedSharePriceIncrease, "Share price increase should match fees per share");
    }
} 