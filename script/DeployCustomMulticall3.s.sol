// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {CustomMulticall3} from "src/utils/CustomMulticall3.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";

contract DeployCustomMulticall3 is Script {
    address deployer;

    address admin = 0xEcAc3Da134C2e5f492B702546c8aaeD2793965BB; // Testnet multisig Safe address
    address ethMultiVault = 0x78f576A734dEEFFd0C3550E6576fFf437933D9D5; // EthMultiVault proxy address on testnet

    CustomMulticall3 customMulticall3;
    TransparentUpgradeableProxy customMulticall3Proxy;

    function run() external {
        // Begin sending tx's to network
        vm.startBroadcast();

        // Prepare data for initializer function
        bytes memory initData = abi.encodeWithSelector(CustomMulticall3.init.selector, IEthMultiVault(ethMultiVault));

        // deploy CustomMulticall3 implementation contract
        customMulticall3 = new CustomMulticall3();
        console.logString("deployed CustomMulticall3.");

        // deploy TransparentUpgradeableProxy for CustomMulticall3
        customMulticall3Proxy = new TransparentUpgradeableProxy(
            address(customMulticall3), // logic contract address
            admin, // initial owner of the ProxyAdmin instance tied to the proxy
            initData // data to pass to the logic contract's initializer function
        );

        // stop sending tx's
        vm.stopBroadcast();

        console.log("All contracts deployed successfully:");
        console.log("CustomMulticall3 implementation address:", address(customMulticall3));
        console.log("CustomMulticall3 proxy address:", address(customMulticall3Proxy));
        console.log(
            "To find the address of the ProxyAdmin contract for the CustomMulticall3 proxy, inspect the creation transaction of the CustomMulticall3 proxy contract on Basescan, in particular the AdminChanged event."
        );
    }
}
