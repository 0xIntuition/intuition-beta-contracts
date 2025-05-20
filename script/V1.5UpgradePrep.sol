// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";

import {BondingCurveRegistry} from "src/BondingCurveRegistry.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {LinearCurve} from "src/LinearCurve.sol";
import {OffsetProgressiveCurve} from "src/OffsetProgressiveCurve.sol";

contract V1_5UpgradePrep is Script {
    address public DEVELOPER = 0x44A4b9E2A69d86BA382a511f845CbF2E31286770; // Developer Wallet

    // Contracts to be deployed
    EthMultiVault public ethMultiVault;
    BondingCurveRegistry public bondingCurveRegistry;
    LinearCurve public linearCurve;
    OffsetProgressiveCurve public offsetProgressiveCurve;

    function run() external {
        vm.startBroadcast();

        // Deploy the new EthMultiVault implementation contract (V1.5)
        ethMultiVault = new EthMultiVault();

        console.log("EthMultiVault deployed at: ", address(ethMultiVault));

        // Deploy BondingCurveRegistry and take temporary ownership to add the curves
        bondingCurveRegistry = new BondingCurveRegistry(msg.sender);
        console.log("BondingCurveRegistry deployed at: ", address(bondingCurveRegistry));

        // Deploy LinearCurve
        linearCurve = new LinearCurve("Linear Curve");
        console.log("LinearCurve deployed at: ", address(linearCurve));

        // Deploy OffsetProgressiveCurve
        offsetProgressiveCurve = new OffsetProgressiveCurve("Offset Progressive Curve", 2, 5e35);
        console.log("OffsetProgressiveCurve deployed at: ", address(offsetProgressiveCurve));

        // Add curves to the BondingCurveRegistry
        bondingCurveRegistry.addBondingCurve(address(linearCurve));
        bondingCurveRegistry.addBondingCurve(address(offsetProgressiveCurve));

        // Transfer ownership of BondingCurveRegistry to the developer wallet (for Base Sepolia)
        // NOTE: For Base Mainnet, the ownership will be transferred to the Safe
        bondingCurveRegistry.transferOwnership(address(DEVELOPER));

        // Build the bonding curve config
        IEthMultiVault.BondingCurveConfig memory bondingCurveConfig =
            IEthMultiVault.BondingCurveConfig({registry: address(bondingCurveRegistry), defaultCurveId: 1});

        // Print the data for the reinitialize call to the EthMultiVault
        bytes memory reinitializeData = abi.encodeWithSelector(EthMultiVault.reinitialize.selector, bondingCurveConfig);
        console.logString("Reinitialize data for EthMultiVault: ");
        console.logBytes(reinitializeData);

        vm.stopBroadcast();
    }
}
