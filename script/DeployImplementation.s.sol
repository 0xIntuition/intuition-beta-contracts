// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";

import {EthMultiVault} from "src/EthMultiVault.sol";

contract DeployImplementation is Script {
    error UnsupportedChainId();

    function run() external {
        vm.startBroadcast();

        uint256 chainId = block.chainid;

        if (chainId != 8453) {
            revert UnsupportedChainId();
        }

        EthMultiVault ethMultiVaultImplementation = new EthMultiVault(); // Replace with other implementation contracts as needed

        console.log("EthMultiVault implementation deployed at: %s", address(ethMultiVaultImplementation));

        vm.stopBroadcast();
    }
}
