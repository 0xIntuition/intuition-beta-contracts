// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";
import {StringUtils} from "./StringUtils.sol";
import {BondingCurveRegistry} from "src/BondingCurveRegistry.sol";
import {ProgressiveCurve} from "src/ProgressiveCurve.sol";
import {OffsetProgressiveCurve} from "src/OffsetProgressiveCurve.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";

contract CurveComparisonTest is EthMultiVaultBase, EthMultiVaultHelpers {
    using StringUtils for uint256;

    uint256 constant PROGRESSIVE_CURVE_ID = 2;
    uint256 constant OFFSET_PROGRESSIVE_CURVE_ID = 3;
    address internal charlie = makeAddr("charlie");

    function setUp() external {
        _setUp();
        vm.deal(charlie, 100 ether);
    }

    function testCompareCurves(uint256 depositAmount) internal {
        // Log curve addresses and parameters
        (address registry,) = ethMultiVault.bondingCurveConfig();
        address progressiveCurve = BondingCurveRegistry(registry).curveAddresses(PROGRESSIVE_CURVE_ID);
        address offsetProgressiveCurve = BondingCurveRegistry(registry).curveAddresses(OFFSET_PROGRESSIVE_CURVE_ID);

        console2.log("Progressive Curve slope: ", ProgressiveCurve(progressiveCurve).SLOPE().unwrap().toString());
        console2.log(
            "Offset Progressive Curve slope: ",
            OffsetProgressiveCurve(offsetProgressiveCurve).SLOPE().unwrap().toString()
        );
        console2.log(
            "Offset Progressive Curve offset: ",
            OffsetProgressiveCurve(offsetProgressiveCurve).OFFSET().unwrap().toString()
        );

        // Alice creates an atom
        vm.startPrank(alice, alice);
        uint256 atomId;
        try ethMultiVault.createAtom{value: getAtomCost()}("") returns (uint256 id) {
            atomId = id;
        } catch Error(string memory reason) {
            console2.log("Failed to create atom: ", reason);
            revert(reason);
        }
        vm.stopPrank();

        uint256 progressiveShares;
        uint256 offsetProgressiveShares;

        // Deposit into Curve 2 (Progressive)
        vm.startPrank(bob, bob);
        try ethMultiVault.depositAtomCurve{value: depositAmount}(bob, atomId, PROGRESSIVE_CURVE_ID) {
            (progressiveShares,) = ethMultiVault.getVaultStateForUserCurve(atomId, PROGRESSIVE_CURVE_ID, bob);
            console2.log(
                "%s Assets into Progressive Curve yields %s shares",
                depositAmount.toString(),
                progressiveShares.toString()
            );
        } catch Error(string memory reason) {
            console2.log("Failed to deposit into progressive curve: ", reason);
            revert(reason);
        }
        vm.stopPrank();

        // Deposit into Curve 3 (Offset Progressive)
        vm.startPrank(charlie, charlie);
        try ethMultiVault.depositAtomCurve{value: depositAmount}(charlie, atomId, OFFSET_PROGRESSIVE_CURVE_ID) {
            (offsetProgressiveShares,) =
                ethMultiVault.getVaultStateForUserCurve(atomId, OFFSET_PROGRESSIVE_CURVE_ID, charlie);
            console2.log(
                "%s Assets into Offset Progressive Curve yields %s shares",
                depositAmount.toString(),
                offsetProgressiveShares.toString()
            );
        } catch Error(string memory reason) {
            console2.log("Failed to deposit into offset curve: ", reason);
            revert(reason);
        }
        vm.stopPrank();

        // Calculate and log differences
        uint256 shareDifference;
        if (progressiveShares > offsetProgressiveShares) {
            shareDifference = progressiveShares - offsetProgressiveShares;
            console2.log("Progressive curve produced more shares by: ", shareDifference);
            console2.log("Percentage difference: ", shareDifference.toPercentage(progressiveShares));
        } else {
            shareDifference = offsetProgressiveShares - progressiveShares;
            console2.log("Offset curve produced more shares by: ", shareDifference);
            console2.log("Percentage difference: ", shareDifference.toPercentage(offsetProgressiveShares));
        }
    }

    function testCompareCurvesSmallAmount() external {
        testCompareCurves(0.001 ether);
    }

    function testCompareCurvesMediumAmount() external {
        testCompareCurves(1 ether);
    }

    function testCompareCurvesLargeAmount() external {
        testCompareCurves(10 ether);
    }

    function testCompareCurvesVerySmallAmount() external {
        testCompareCurves(0.0003 ether);
    }

    function testCompareCurvesTinyAmount() external {
        testCompareCurves(0.003 ether);
    }

    function testCompareCurvesMicroAmount() external {
        testCompareCurves(0.03 ether);
    }
}
