// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {IntuitionProxy} from "src/IntuitionProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployEthMultiVault is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    uint256 PRIVATE_KEY;
    string FOUNDRY_PROFILE;

    address deployer;

    IPermit2 permit2;
    EntryPoint entryPoint;
    EthMultiVault ethMultiVault;
    IntuitionProxy proxy;
    ProxyAdmin proxyAdmin;

    function run() external {
        permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));

        console.logString("reading environment...");
        PRIVATE_KEY = vm.envOr("PRIVATE_KEY", vm.deriveKey(mnemonic, 0));
        console.logString(" - PRIVATE_KEY");
        FOUNDRY_PROFILE = vm.envOr("FOUNDRY_PROFILE", string("local"));
        console.logString(" - FOUNDRY_PROFILE");

        console.logString("starting deploy...");

        // set up deployer wallet
        deployer = vm.addr(PRIVATE_KEY);

        // Begin sending tx's to network
        vm.startBroadcast(PRIVATE_KEY);

        // deploy EntryPoint
        entryPoint = new EntryPoint();
        console.logString("deployed EntryPoint.");

        // Example configurations for EthMultiVault initialization (NOT meant to be used in production)
        IEthMultiVault.GeneralConfig memory generalConfig = IEthMultiVault
            .GeneralConfig({
                admin: msg.sender, // Deployer as admin for simplicity
                protocolVault: msg.sender, // Deployer as protocol vault for simplicity
                feeDenominator: 10000, // Common denominator for fee calculations
                minDeposit: 0.01 ether, // Minimum deposit amount in wei
                minShare: 1e5, // Minimum share amount (e.g., for vault initialization)
                atomUriMaxLength: 250 // Maximum length of the atom URI data that can be passed when creating atom vaults
            });

        IEthMultiVault.AtomConfig memory atomConfig = IEthMultiVault
            .AtomConfig({
                atomShareLockFee: 0.01 ether, // Fee charged for purchasing vault shares for the atom wallet upon creation
                atomCreationFee: 0.005 ether // Fee charged for creating an atom
            });

        IEthMultiVault.TripleConfig memory tripleConfig = IEthMultiVault
            .TripleConfig({
                tripleCreationFee: 0.02 ether, // Fee for creating a triple
                atomEquityFeeForTriple: 100 // Fee for equity in atoms when creating a triple
            });

        IEthMultiVault.WalletConfig memory walletConfig = IEthMultiVault
            .WalletConfig({
                permit2: IPermit2(address(permit2)), // Uniswap Protocol Permit2 contract on Optimism
                entryPoint: address(entryPoint), // Our deployed EntryPoint contract (in production, change this to the actual entry point contract address on Optimism)
                atomWarden: msg.sender // Deployer as atom warden for simplicity
            });

        // Prepare data for initializer function
        bytes memory initData =
            abi.encodeWithSelector(EthMultiVault.init.selector, generalConfig, atomConfig, tripleConfig, walletConfig);

        // Deploy EthMultiVault contract
        console.log("Deploying EthMultiVault...");
        // log initData for contract verification on Etherscan
        console.logBytes(initData);
        ethMultiVault = new EthMultiVault();

        // // Deploy ProxyAdmin contract
        console.log("Deploying ProxyAdmin...");
        proxyAdmin = new ProxyAdmin();

        // // Deploy IntuitionProxy with EthMultiVault logic contract
        console.log("Deploying Proxy and initializing EthMultiVault...");
        proxy = new IntuitionProxy(
            address(ethMultiVault), // EthMultiVault logic contract address
            address(proxyAdmin), // ProxyAdmin address to manage proxy
            initData // Initialization data to call the `init` function in EthMultiVault
        );

        // // stop sending tx's
        vm.stopBroadcast();

        console.log("EthMultiVault deployed and initialized successfully through proxy.");
        console.log("EntryPoint address:", address(entryPoint));
        console.log("EthMultiVault Logic address:", address(ethMultiVault));
        console.log("Intuition ProxyAdmin address:", address(proxyAdmin));
        console.log("EthMultiVault Proxy address:", address(proxy));
    }
}
