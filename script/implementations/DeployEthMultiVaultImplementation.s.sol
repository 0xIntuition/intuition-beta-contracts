// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";

import {EthMultiVault} from "src/EthMultiVault.sol";

contract DeployEthMultiVaultImplementation is Script {
    error UnsupportedChainId();

    function run() external {
        vm.startBroadcast();

        // Check if the script is running on the correct network
        if (block.chainid != 8453) revert UnsupportedChainId();

        // Deploy the EthMultiVault implementation contract
        EthMultiVault ethMultiVault = new EthMultiVault();

        console.log("EthMultiVault implementation deployed at: %s", address(ethMultiVault));

        vm.stopBroadcast();
    }
}
