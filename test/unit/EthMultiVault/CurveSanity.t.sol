// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";
import {StringUtils} from "./StringUtils.sol";
import {BondingCurveRegistry} from "src/BondingCurveRegistry.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";

contract CurveSanityTest is EthMultiVaultBase, EthMultiVaultHelpers {
    using StringUtils for uint256;
    using StringUtils for int256; // Add for signed integers (deviation)

    // Assuming curve IDs are 1, 2, and 3 based on common setup and CurveComparison.t.sol
    uint256 constant LINEAR_CURVE_ID = 1;
    uint256 constant PROGRESSIVE_CURVE_ID = 2;
    uint256 constant OFFSET_PROGRESSIVE_CURVE_ID = 3;

    uint256 internal testAtomId; // Store atom ID

    function setUp() external {
        _setUp();
        vm.deal(alice, 1 ether); // Give alice some ETH for atom creation
        // Create an atom for previewing deposits against
        vm.startPrank(alice, alice);
        try ethMultiVault.createAtom{value: getAtomCost()}("") returns (uint256 id) {
            testAtomId = id;
        } catch Error(string memory reason) {
            console2.log("Failed to create atom in setUp: ", reason);
            revert(reason);
        }
        vm.stopPrank();
    }

    function testPreviewDeposits() external view {
        console2.log("Previewing deposits in increments into each curve for Atom ID: %s", testAtomId.toString());

        (address registryAddr,) = ethMultiVault.bondingCurveConfig();
        BondingCurveRegistry registry = BondingCurveRegistry(registryAddr);

        uint256[] memory curveIds = new uint256[](3);
        curveIds[0] = LINEAR_CURVE_ID;
        curveIds[1] = PROGRESSIVE_CURVE_ID;
        curveIds[2] = OFFSET_PROGRESSIVE_CURVE_ID;

        uint256 increment = 0.1 ether;
        uint256 maxAmount = 1 ether;
        uint256 numSteps = (maxAmount - increment) / increment + 1;

        // --- Data Storage ---
        // Store deposit amounts used
        uint256[] memory depositAmounts = new uint256[](numSteps);
        // Store shares for each curve [curveIndex][stepIndex]
        uint256[][] memory allShares = new uint256[][](curveIds.length);
        for (uint256 i = 0; i < curveIds.length; i++) {
            allShares[i] = new uint256[](numSteps);
        }
        // Keep track if preview succeeded for a point
        bool[][] memory previewSucceeded = new bool[][](curveIds.length);
        for (uint256 i = 0; i < curveIds.length; i++) {
            previewSucceeded[i] = new bool[](numSteps);
        }

        // --- Data Collection Loop ---
        uint256 step = 0;
        for (uint256 depositAmount = increment; depositAmount <= maxAmount; depositAmount += increment) {
            depositAmounts[step] = depositAmount;
            console.log("\nPreviewing deposit of %s assets:", depositAmount.toString());

            for (uint256 i = 0; i < curveIds.length; i++) {
                uint256 curveId = curveIds[i];
                if (registry.curveAddresses(curveId) != address(0)) {
                    try ethMultiVault.previewDepositCurve(depositAmount, testAtomId, curveId) returns (
                        uint256 previewShares
                    ) {
                        console.log("  Curve ID %s: %s shares", curveId.toString(), previewShares.toString());
                        allShares[i][step] = previewShares;
                        previewSucceeded[i][step] = true;
                    } catch Error(string memory reason) {
                        console.log("  Curve ID %s: Failed preview - %s", curveId.toString(), reason);
                        previewSucceeded[i][step] = false;
                    } catch {
                        console.log("  Curve ID %s: Failed preview - Unknown reason", curveId.toString());
                        previewSucceeded[i][step] = false;
                    }
                } else {
                    console.log("  Curve ID %s: Not registered", curveId.toString());
                    // Mark as failed if not registered
                    for (uint256 s = 0; s < numSteps; s++) {
                        previewSucceeded[i][s] = false;
                    }
                }
            }
            step++;
        }

        // --- Linearity Calculation and Logging ---
        console.log("\n--- Linearity Analysis ---");

        for (uint256 i = 0; i < curveIds.length; i++) {
            uint256 curveId = curveIds[i];
            console.log("\nCurve ID: %s", curveId.toString());

            // Check if we have at least 2 successful points to define a line
            if (numSteps >= 2 && previewSucceeded[i][0] && previewSucceeded[i][1]) {
                uint256 shares0 = allShares[i][0];
                uint256 amount0 = depositAmounts[0]; // First point
                uint256 deltaAmount = amount0; // Distance from zero
                uint256 deltaShares = shares0; // Distance from zero

                // Handle case where shares are zero or negative
                if (shares0 == 0) {
                    console.log("  Warning: First point has zero shares. Cannot calculate baseline.");
                    continue;
                }

                console.log(
                    string(
                        abi.encodePacked(
                            "  Baseline: 0 ETH = 0 Shares -> ",
                            amount0.toString(),
                            " ETH = ",
                            shares0.toString(),
                            " Shares"
                        )
                    )
                );

                // Calculate slope components for precision: slope = deltaShares / deltaAmount

                for (uint256 j = 1; j < numSteps; j++) {
                    if (previewSucceeded[i][j]) {
                        uint256 currentAmount = depositAmounts[j];
                        uint256 actualShares = allShares[i][j];

                        // Calculate expected shares: expected = slope * currentAmount
                        // expected = (deltaShares / deltaAmount) * currentAmount
                        // To maintain precision: expected = (deltaShares * currentAmount) / deltaAmount
                        uint256 expectedShares = (deltaShares * currentAmount) / deltaAmount;

                        // Calculate deviation (can be negative)
                        uint256 deviation;
                        bool positiveDeviation = false;
                        if (actualShares >= expectedShares) {
                            deviation = actualShares - expectedShares;
                            positiveDeviation = true;
                        } else {
                            deviation = expectedShares - actualShares;
                            positiveDeviation = false;
                        }

                        console.log(
                            string(
                                abi.encodePacked(
                                    "  ",
                                    currentAmount.toString(),
                                    " ETH -> ",
                                    actualShares.toString(),
                                    " Shares (Linear: ",
                                    expectedShares.toString(),
                                    " Shares, ",
                                    positiveDeviation ? "+" : "-",
                                    deviation.toString(),
                                    " Shares)"
                                )
                            )
                        );
                    } else {
                        console.log(
                            string(abi.encodePacked("  ", depositAmounts[j].toString(), " ETH: Preview failed"))
                        );
                    }
                }
            } else {
                console.log("  Not enough successful preview points (need at least 2) to calculate linearity.");
            }
        }
    }
}
