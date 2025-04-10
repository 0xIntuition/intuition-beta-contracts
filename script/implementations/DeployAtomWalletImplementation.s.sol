// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";

import {AtomWallet} from "src/AtomWallet.sol";

contract DeployAtomWalletImplementation is Script {
    error UnsupportedChainId();

    function run() external {
        vm.startBroadcast();

        // Check if the script is running on the correct network
        if (block.chainid != 8453) revert UnsupportedChainId();

        // Deploy the AtomWallet implementation contract
        AtomWallet atomWallet = new AtomWallet();

        console.log("AtomWallet implementation deployed at: %s", address(atomWallet));

        vm.stopBroadcast();
    }
}
