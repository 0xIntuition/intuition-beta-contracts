// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {AtomWallet} from "src/AtomWallet.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployEthMultiVault is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    uint256 PRIVATE_KEY;
    string FOUNDRY_PROFILE;

    address deployer;

    // Multisig addresses for key roles in the protocol (`msg.sender` for should be replaced with the actual multisig addresses for each role in production)
    address admin = msg.sender;
    address protocolVault = msg.sender;
    address atomWarden = msg.sender;

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

        // deploy AtomWallet implementation contract
        atomWallet = new AtomWallet();
        console.logString("deployed AtomWallet.");

        // deploy AtomWalletBeacon pointing to the AtomWallet implementation contract
        atomWalletBeacon = new UpgradeableBeacon(address(atomWallet));
        console.logString("deployed AtomWalletBeacon.");

        // Example configurations for EthMultiVault initialization (NOT meant to be used in production)
        IEthMultiVault.GeneralConfig memory generalConfig = IEthMultiVault
            .GeneralConfig({
                admin: admin, // Admin address for the EthMultiVault contract
                protocolVault: protocolVault, // Intuition protocol vault address (should be a multisig in production)
                feeDenominator: 1e4, // Common denominator for fee calculations
                minDeposit: 1e15, // Minimum deposit amount in wei
                minShare: 1e5, // Minimum share amount (e.g., for vault initialization)
                atomUriMaxLength: 250, // Maximum length of the atom URI data that can be passed when creating atom vaults
                decimalPrecision: 1e18, // decimal precision used for calculating share prices
                minDelay: 12 hours // minimum delay for timelocked transactions
            });

        IEthMultiVault.AtomConfig memory atomConfig = IEthMultiVault
            .AtomConfig({
                atomShareLockFee: 0.0021 ether, // Fee charged for purchasing vault shares for the atom wallet upon creation
                atomCreationFee: 0.0021 ether // Fee charged for creating an atom
            });

        IEthMultiVault.TripleConfig memory tripleConfig = IEthMultiVault
            .TripleConfig({
                tripleCreationFee: 0.0021 ether, // Fee for creating a triple
                atomDepositFractionForTriple: 1500 // Fee for equity in atoms when creating a triple
            });

        IEthMultiVault.WalletConfig memory walletConfig = IEthMultiVault
            .WalletConfig({
                permit2: IPermit2(address(permit2)), // Permit2 on Base
                entryPoint: entryPoint, // EntryPoint address on Base
                atomWarden: atomWarden, // AtomWarden address (should be a multisig in production)
                atomWalletBeacon: address(atomWalletBeacon) // Address of the AtomWalletBeacon contract
            });

        IEthMultiVault.VaultConfig memory vaultConfig = IEthMultiVault  
            .VaultConfig({
                entryFee: 500, // Entry fee for vault 0
                exitFee: 500, // Exit fee for vault 0
                protocolFee: 100 // Protocol fee for vault 0
            });

        // Prepare data for initializer function
        bytes memory initData =
            abi.encodeWithSelector(EthMultiVault.init.selector, generalConfig, atomConfig, tripleConfig, walletConfig, vaultConfig);

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

        // stop sending tx's
        vm.stopBroadcast();

        console.log("All contracts deployed successfully.");
        console.log("AtomWallet implementation address:", address(atomWallet));
        console.log("UpgradeableBeacon address:", address(atomWalletBeacon));
        console.log("EthMultiVault implementation address:", address(ethMultiVault));
        console.log("EthMultiVault proxy address:", address(ethMultiVaultProxy));
        console.log("ProxyAdmin address:", address(proxyAdmin));
        console.log("TimelockController address:", address(timelock));
    }
}
