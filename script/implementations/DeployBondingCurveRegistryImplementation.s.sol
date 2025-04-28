// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";

import {BondingCurveRegistry} from "src/BondingCurveRegistry.sol";

contract DeployBondingCurveRegistryImplementation is Script {
    error UnsupportedChainId();

    function run() external {
        vm.startBroadcast();

        // Check if the script is running on the correct network
        if (block.chainid != 8453) revert UnsupportedChainId();

        // Deploy the BondingCurveRegistry implementation contract
        BondingCurveRegistry bondingCurveRegistry = new BondingCurveRegistry();

        console.log("BondingCurveRegistry implementation deployed at: %s", address(bondingCurveRegistry));

        vm.stopBroadcast();
    }
}
