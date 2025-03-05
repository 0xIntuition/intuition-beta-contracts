// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {BondingCurveRegistry} from "src/BondingCurveRegistry.sol";
import {OffsetProgressiveCurve} from "src/OffsetProgressiveCurve.sol";

contract DeployCurve is Script {
    // Constants from previous deployment
    address public constant REGISTRY = 0xB91c9B231cD726f84E5c5Caa6d320d26fF2424A2;

    function run() external {
        // Begin sending tx's to network
        vm.startBroadcast();

        // Deploy OffsetProgressiveCurve
        OffsetProgressiveCurve offsetProgressiveCurve = new OffsetProgressiveCurve(
            "Offset Progressive Curve",
            2, // slope
            1e17 // offset
        );
        console.logString("deployed OffsetProgressiveCurve.");

        // Add curve to BondingCurveRegistry
        BondingCurveRegistry(REGISTRY).addBondingCurve(address(offsetProgressiveCurve));
        console.logString("added curve to registry.");

        // stop sending tx's
        vm.stopBroadcast();

        console.log("OffsetProgressiveCurve address:", address(offsetProgressiveCurve));
    }
}