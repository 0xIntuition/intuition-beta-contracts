// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {AtomWallet} from "src/AtomWallet.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "forge-std/Script.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";

contract DeployTimelockScript is Script {
    address private multisig = 0x9D5b33E8E4D8A68F4B773B831Ad34c8c1f925a6a; // the multi-sig claus set up

    // Constants from Base
    IPermit2 permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)); // Permit2 on Base
    address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base

    // Contracts to be deployed
    AtomWallet atomWallet;
    UpgradeableBeacon atomWalletBeacon;
    EthMultiVault ethMultiVault;
    TransparentUpgradeableProxy ethMultiVaultProxy;
    ProxyAdmin proxyAdmin;
    TimelockController timelock;

    function run() external {
        vm.startBroadcast();

        // deploy AtomWallet implementation contract
        atomWallet = new AtomWallet();
        console.log("deployed AtomWallet", address(atomWallet));

        // deploy AtomWalletBeacon pointing to the AtomWallet implementation contract
        atomWalletBeacon = new UpgradeableBeacon(address(atomWallet));
        console.log("deployed AtomWalletBeacon", address(atomWalletBeacon));

        IEthMultiVault.GeneralConfig memory generalConfig = IEthMultiVault.GeneralConfig({
            admin: multisig, // Admin address for the EthMultiVault contract
            protocolVault: multisig, // Intuition protocol vault address (should be a multisig in production)
            feeDenominator: 1e4, // Common denominator for fee calculations
            minDeposit: 1e15, // Minimum deposit amount in wei
            minShare: 1e5, // Minimum share amount (e.g., for vault initialization)
            atomUriMaxLength: 250, // Maximum length of the atom URI data that can be passed when creating atom vaults
            decimalPrecision: 1e18, // decimal precision used for calculating share prices
            minDelay: 12 hours // minimum delay for timelocked transactions
        });

        IEthMultiVault.AtomConfig memory atomConfig = IEthMultiVault.AtomConfig({
            atomShareLockFee: 0.0021 ether, // Fee charged for purchasing vault shares for the atom wallet upon creation
            atomCreationFee: 0.0021 ether // Fee charged for creating an atom
        });

        IEthMultiVault.TripleConfig memory tripleConfig = IEthMultiVault.TripleConfig({
            tripleCreationFee: 0.0021 ether, // Fee for creating a triple
            atomDepositFractionForTriple: 1500 // Fee for equity in atoms when creating a triple
        });

        IEthMultiVault.WalletConfig memory walletConfig = IEthMultiVault.WalletConfig({
            permit2: IPermit2(address(permit2)), // Permit2 on Base
            entryPoint: entryPoint, // EntryPoint address on Base
            atomWarden: multisig, // AtomWarden address (should be a multisig in production)
            atomWalletBeacon: address(atomWalletBeacon) // Address of the AtomWalletBeacon contract
        });

        IEthMultiVault.VaultConfig memory vaultConfig = IEthMultiVault.VaultConfig({
            entryFee: 500, // Entry fee for vault 0
            exitFee: 500, // Exit fee for vault 0
            protocolFee: 100 // Protocol fee for vault 0
        });

        // Prepare data for initializer function
        bytes memory initData = abi.encodeWithSelector(
            EthMultiVault.init.selector, generalConfig, atomConfig, tripleConfig, walletConfig, vaultConfig
        );

        // Deploy EthMultiVault contract
        console.log("Deploying EthMultiVault...");
        // log initData for contract verification on Etherscan
        console.logBytes(initData);
        ethMultiVault = new EthMultiVault();

        // Deploy ProxyAdmin contract
        console.log("Deploying ProxyAdmin...");
        proxyAdmin = new ProxyAdmin();

        // Deploy TransparentUpgradeableProxy with EthMultiVault logic contract
        console.log("Deploying Proxy and initializing EthMultiVault...");
        ethMultiVaultProxy = new TransparentUpgradeableProxy(
            address(ethMultiVault), // EthMultiVault logic contract address
            address(proxyAdmin), // ProxyAdmin address to manage the proxy contract
            initData // Initialization data to call the `init` function in EthMultiVault
        );

        // deploy TimelockController
        uint256 minDelay = 2 days;
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        address admin = multisig;

        proposers[0] = multisig;
        executors[0] = multisig;

        timelock = new TimelockController(minDelay, proposers, executors, admin);
        // Transfer ownership of ProxyAdmin to TimelockController to enforce timelock on upgrades for EthMultiVault
        console.log("Transferring ProxyAdmin ownership to TimelockController...");
        proxyAdmin.transferOwnership(address(timelock));

        // Transfer ownership of AtomWalletBeacon to TimelockController to enforce timelock on upgrades for AtomWallet
        console.log("Transferring UpgradeableBeacon ownership to TimelockController...");
        atomWalletBeacon.transferOwnership(address(timelock));

        vm.stopBroadcast();

        console.log("All contracts deployed successfully.");
        console.log("AtomWallet implementation address:", address(atomWallet));
        console.log("AtomWallet beacon address:", address(atomWalletBeacon));
        console.log("EthMultiVault implementation address:", address(ethMultiVault));
        console.log("EthMultiVault proxy address:", address(ethMultiVaultProxy));
        console.log("ProxyAdmin address:", address(proxyAdmin));
        console.log("TimelockController address:", address(timelock));
    }
}
