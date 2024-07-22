// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {Attestoor} from "src/utils/Attestoor.sol";
import {AttestoorFactory} from "src/utils/AttestoorFactory.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";

contract DeployAttestoor is Script {
    address deployer;

    address admin = 0xEcAc3Da134C2e5f492B702546c8aaeD2793965BB; // Testnet multisig Safe address
    address ethMultiVault = 0x78f576A734dEEFFd0C3550E6576fFf437933D9D5; // EthMultiVault proxy address on testnet

    TransparentUpgradeableProxy attestoorFactoryProxy;
    UpgradeableBeacon attestoorBeacon;

    AttestoorFactory attestoorFactory;
    Attestoor attestoor;

    function run() external {
        // Begin sending tx's to network
        vm.startBroadcast();

        // deploy Attestoor implementation contract
        attestoor = new Attestoor();
        console.logString("deployed Attestoor.");

        // deploy attestoorBeacon pointing to the Attestoor implementation contract
        attestoorBeacon = new UpgradeableBeacon(address(attestoor), admin);
        console.logString("deployed UpgradeableBeacon.");

        bytes memory initData = abi.encodeWithSelector(
            AttestoorFactory.init.selector, admin, IEthMultiVault(ethMultiVault), address(attestoorBeacon)
        );

        // deploy AttestoorFactory implementation contract
        attestoorFactory = new AttestoorFactory();
        console.logString("deployed AttestoorFactory.");

        // deploy TransparentUpgradeableProxy for AttestoorFactory
        attestoorFactoryProxy = new TransparentUpgradeableProxy(
            address(attestoorFactory), // logic contract address
            admin, // initial owner of the ProxyAdmin instance tied to the proxy
            initData // data to pass to the logic contract's initializer function
        );
        console.logString("deployed TransparentUpgradeableProxy for AttestoorFactory.");

        // stop sending tx's
        vm.stopBroadcast();

        console.log("All contracts deployed successfully:");
        console.log("Attestoor implementation address:", address(attestoor));
        console.log("attestoorBeacon address:", address(attestoorBeacon));
        console.log("AttestoorFactory implementation address:", address(attestoorFactory));
        console.log("AttestoorFactory proxy address:", address(attestoorFactoryProxy));
    }
}
