// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {AtomWallet} from "src/AtomWallet.sol";
import {CustomMulticall3} from "src/utils/CustomMulticall3.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";

import {BondingCurveRegistry} from "src/BondingCurveRegistry.sol";
import {ProgressiveCurve} from "src/ProgressiveCurve.sol";
import {LinearCurve} from "src/LinearCurve.sol";

contract DeployEthMultiVault is Script {
    address deployer;

    // Multisig addresses for key roles in the protocol
    address admin = 0xa28d4AAcA48bE54824dA53a19b05121DE71Ef480;
    address protocolMultisig = 0xC03F0dE5b34339e1B968e4f317Cd7e7FBd421FD1;
    address atomWarden = 0xC35DFCFE50da58d957fc47C7063f56135aFF61B8;

    // Constants from Base
    IPermit2 permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)); // Permit2 on Base
    address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base

    // Contracts to be deployed
    AtomWallet atomWallet;
    UpgradeableBeacon atomWalletBeacon;
    EthMultiVault ethMultiVault;
    TransparentUpgradeableProxy ethMultiVaultProxy;
    TimelockController timelock;

    // Bonding Curves
    BondingCurveRegistry bondingCurveRegistry;
    LinearCurve linearCurve; // <-- Not used in this edition of EthMultiVault
    ProgressiveCurve progressiveCurve;

    function run() external {
        // Begin sending tx's to network
        vm.startBroadcast();

        // TimelockController parameters
        uint256 minDelay = 3 days;
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);

        proposers[0] = admin;
        executors[0] = admin;

        // deploy TimelockController
        timelock = new TimelockController(
            minDelay, // minimum delay for timelock transactions
            proposers, // proposers (can schedule transactions)
            executors, // executors
            address(0) // no default admin that can change things without going through the timelock process (self-administered)
        );
        console.logString("deployed TimelockController.");

        // deploy AtomWallet implementation contract
        atomWallet = new AtomWallet();
        console.logString("deployed AtomWallet.");

        // deploy AtomWalletBeacon pointing to the AtomWallet implementation contract
        atomWalletBeacon = new UpgradeableBeacon(address(atomWallet), address(timelock));
        console.logString("deployed UpgradeableBeacon.");

        IEthMultiVault.GeneralConfig memory generalConfig = IEthMultiVault.GeneralConfig({
            admin: admin, // Admin address for the EthMultiVault contract
            protocolMultisig: protocolMultisig, // Protocol multisig address
            feeDenominator: 10000, // Common denominator for fee calculations
            minDeposit: 0.00042 ether, // Minimum deposit amount in wei
            minShare: 1e6, // Minimum share amount (e.g., for vault initialization)
            atomUriMaxLength: 250, // Maximum length of the atom URI data that can be passed when creating atom vaults
            decimalPrecision: 1e18, // decimal precision used for calculating share prices
            minDelay: 1 days // minimum delay for timelocked transactions
        });

        IEthMultiVault.AtomConfig memory atomConfig = IEthMultiVault.AtomConfig({
            atomWalletInitialDepositAmount: 0.00003 ether, // Fee charged for purchasing vault shares for the atom wallet upon creation
            atomCreationProtocolFee: 0.0003 ether // Fee charged for creating an atom
        });

        IEthMultiVault.TripleConfig memory tripleConfig = IEthMultiVault.TripleConfig({
            tripleCreationProtocolFee: 0.0003 ether, // Fee for creating a triple
            atomDepositFractionOnTripleCreation: 0.00003 ether, // Static fee going towards increasing the amount of assets in the underlying atom vaults
            atomDepositFractionForTriple: 900 // Fee for equity in atoms when creating a triple
        });

        IEthMultiVault.WalletConfig memory walletConfig = IEthMultiVault.WalletConfig({
            permit2: IPermit2(address(permit2)), // Permit2 on Base
            entryPoint: entryPoint, // EntryPoint address on Base
            atomWarden: atomWarden, // atomWarden address
            atomWalletBeacon: address(atomWalletBeacon) // Address of the AtomWalletBeacon contract
        });

        IEthMultiVault.VaultFees memory vaultFees = IEthMultiVault.VaultFees({
            entryFee: 500, // Entry fee for vault 0
            exitFee: 500, // Exit fee for vault 0
            protocolFee: 250 // Protocol fee for vault 0
        });

        // ------------------------------- Bonding Curves----------------------------------------

        // Deploy BondingCurveRegistry and take temporary ownership to add the curves
        bondingCurveRegistry = new BondingCurveRegistry();
        console.logString("deployed BondingCurveRegistry.");
        bondingCurveRegistry.initialize(address(this));

        // Deploy LinearCurve
        linearCurve = new LinearCurve("Linear Curve");
        console.logString("deployed LinearCurve.");

        // Deploy ProgressiveCurve
        progressiveCurve = new ProgressiveCurve("Progressive Curve", 0.00007054e18);
        console.logString("deployed ProgressiveCurve.");

        // Add curves to BondingCurveRegistry
        bondingCurveRegistry.addBondingCurve(address(linearCurve));
        bondingCurveRegistry.addBondingCurve(address(progressiveCurve));

        // Transfer ownership of BondingCurveRegistry to admin
        bondingCurveRegistry.setAdmin(admin);

        IEthMultiVault.BondingCurveConfig memory bondingCurveConfig = IEthMultiVault.BondingCurveConfig({
            registry: address(bondingCurveRegistry),
            defaultCurveId: 1 // Unused in this edition of EthMultiVault
        });

        // -------------------------------------------------------------------------------------

        // Prepare data for initializer function
        bytes memory initData = abi.encodeWithSelector(
            EthMultiVault.init.selector, generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees, bondingCurveConfig
        );

        // Deploy EthMultiVault implementation contract
        ethMultiVault = new EthMultiVault();
        console.logString("deployed EthMultiVault.");

        // Deploy TransparentUpgradeableProxy with EthMultiVault logic contract
        ethMultiVaultProxy = new TransparentUpgradeableProxy(
            address(ethMultiVault), // EthMultiVault logic contract address
            address(timelock), // Timelock controller address, which will be the owner of the ProxyAdmin contract for the proxy
            initData // Initialization data to call the `init` function in EthMultiVault
        );
        console.logString("deployed TransparentUpgradeableProxy.");

        // stop sending tx's
        vm.stopBroadcast();

        console.log("All contracts deployed successfully:");
        console.log("TimelockController address:", address(timelock));
        console.log("AtomWallet implementation address:", address(atomWallet));
        console.log("UpgradeableBeacon address:", address(atomWalletBeacon));
        console.log("EthMultiVault implementation address:", address(ethMultiVault));
        console.log("EthMultiVault proxy address:", address(ethMultiVaultProxy));
        console.log("BondingCurveRegistry address:", address(bondingCurveRegistry));
        console.log(
            "To find the address of the ProxyAdmin contract for the EthMultiVault proxy, inspect the creation transaction of the EthMultiVault proxy contract on Basescan, in particular the AdminChanged event. Same applies to the CustomMulticall3 proxy contract."
        );
    }
}
