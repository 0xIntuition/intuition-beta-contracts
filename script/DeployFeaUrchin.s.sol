// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {FeaUrchinFactory} from "src/FeaUrchinFactory.sol";
import {FeaUrchin} from "src/FeaUrchin.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";

contract DeployFeaUrchin is Script {
    // The EthMultiVault address on the target network
    address constant VAULT_ADDRESS = 0x1A6950807E33d5bC9975067e6D6b5Ea4cD661665;

    // Fee configuration for the FeaUrchin instance
    uint256 constant FEE_NUMERATOR = 300; // 3% fee
    uint256 constant FEE_DENOMINATOR = 10000;

    function run() external {
        // Begin sending tx's to network
        vm.startBroadcast();

        // Deploy FeaUrchinFactory
        FeaUrchinFactory factory = new FeaUrchinFactory(IEthMultiVault(VAULT_ADDRESS));
        console.logString("Deployed FeaUrchinFactory");
        console.log("FeaUrchinFactory address:", address(factory));

        // Deploy a FeaUrchin instance through the factory
        FeaUrchin feaUrchin = factory.deployFeaUrchin(FEE_NUMERATOR, FEE_DENOMINATOR);
        console.logString("Deployed FeaUrchin instance");
        console.log("FeaUrchin address:", address(feaUrchin));

        // Stop sending tx's
        vm.stopBroadcast();
    }
} 