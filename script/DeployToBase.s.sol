// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import { Script, console } from "forge-std/Script.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { TransparentUpgradeableProxy, ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { AtomWallet } from "src/AtomWallet.sol";
import { EthMultiVault } from "src/EthMultiVault.sol";
import { IEthMultiVault } from "src/interfaces/IEthMultiVault.sol";
import { IPermit2 } from "src/interfaces/IPermit2.sol";

import { BondingCurveRegistry } from "src/BondingCurveRegistry.sol";
import { ProgressiveCurve } from "src/ProgressiveCurve.sol";
import { LinearCurve } from "src/LinearCurve.sol";

contract DeployToBase is Script {
    // Multisig addresses for key roles in the protocol
    address public admin = 0xa28d4AAcA48bE54824dA53a19b05121DE71Ef480;
    address public protocolMultisig = 0xC03F0dE5b34339e1B968e4f317Cd7e7FBd421FD1;
    address public atomWarden = 0xC35DFCFE50da58d957fc47C7063f56135aFF61B8;

    // Constants from Base
    IPermit2 public permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)); // Permit2 on Base
    address public entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base

    // Contracts to be deployed
    AtomWallet public atomWallet;
    UpgradeableBeacon public atomWalletBeacon;
    EthMultiVault public ethMultiVault;
    TransparentUpgradeableProxy public ethMultiVaultProxy;
    TimelockController public timelock;

    // Bonding Curves
    BondingCurveRegistry public bondingCurveRegistry;
    TransparentUpgradeableProxy public bondingCurveRegistryProxy;
    LinearCurve public linearCurve; // <-- Not used in this edition of EthMultiVault
    ProgressiveCurve public progressiveCurve;

    error UnsupportedChainId();

    function run() external {
        // Begin sending tx's to network
        vm.startBroadcast();

        // Check if the script is running on the correct network
        uint256 chainId = block.chainid;
        if (chainId != 8453) revert UnsupportedChainId();

        // TimelockController parameters
        uint256 minDelay = 3 days;
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);

        proposers[0] = admin;
        executors[0] = address(0);

        // deploy TimelockController
        timelock = new TimelockController(
            minDelay, // minimum delay for timelock transactions
            proposers, // proposers (can schedule and cancel transactions)
            executors, // executors (can execute transactions; address(0) means it's an open role, i.e. anyone can execute the scheduled transactions)
            address(0) // no optional admin that can change things without going through the timelock process
        );
        console.logString("deployed TimelockController.");
        console.logString("encoded constructor args: ");
        console.logBytes(abi.encode(minDelay, proposers, executors, address(0)));

        // deploy AtomWallet implementation contract
        atomWallet = new AtomWallet();
        console.logString("deployed AtomWallet.");

        // deploy AtomWalletBeacon pointing to the AtomWallet implementation contract
        atomWalletBeacon = new UpgradeableBeacon(address(atomWallet), address(timelock));
        console.logString("deployed UpgradeableBeacon.");
        console.logString("encoded constructor args: ");
        console.logBytes(abi.encode(address(atomWallet), address(timelock)));

        IEthMultiVault.GeneralConfig memory generalConfig = IEthMultiVault.GeneralConfig({
            admin: admin, // Admin address for the EthMultiVault contract
            protocolMultisig: protocolMultisig, // Protocol multisig address
            feeDenominator: 10000, // Common denominator for fee calculations
            minDeposit: 0.000025 ether, // Minimum deposit amount in wei
            minShare: 1e6, // Minimum share amount (e.g., for vault initialization)
            atomUriMaxLength: 250, // Maximum length of the atom URI data that can be passed when creating atom vaults
            decimalPrecision: 1e18, // decimal precision used for calculating share prices
            minDelay: 1 days // minimum delay for timelocked transactions
        });

        IEthMultiVault.AtomConfig memory atomConfig = IEthMultiVault.AtomConfig({
            atomWalletInitialDepositAmount: 0.000003 ether, // Fee charged for purchasing vault shares for the atom wallet upon creation
            atomCreationProtocolFee: 0.000003 ether // Fee charged for creating an atom
        });

        IEthMultiVault.TripleConfig memory tripleConfig = IEthMultiVault.TripleConfig({
            tripleCreationProtocolFee: 0.000003 ether, // Fee for creating a triple
            atomDepositFractionOnTripleCreation: 0.000003 ether, // Static fee going towards increasing the amount of assets in the underlying atom vaults
            atomDepositFractionForTriple: 300 // Fee for equity in atoms when creating a triple
        });

        IEthMultiVault.WalletConfig memory walletConfig = IEthMultiVault.WalletConfig({
            permit2: IPermit2(address(permit2)), // Permit2 on Linea
            entryPoint: entryPoint, // EntryPoint address on Linea
            atomWarden: atomWarden, // atomWarden address
            atomWalletBeacon: address(atomWalletBeacon) // Address of the AtomWalletBeacon contract
        });

        IEthMultiVault.VaultFees memory vaultFees = IEthMultiVault.VaultFees({
            entryFee: 500, // Entry fee for vault 0
            exitFee: 500, // Exit fee for vault 0
            protocolFee: 100 // Protocol fee for vault 0
        });

        IEthMultiVault.BondingCurveConfig memory bondingCurveConfig = IEthMultiVault
            .BondingCurveConfig({
                registry: address(bondingCurveRegistry),
                defaultCurveId: 1 // Unused in this edition of EthMultiVault
            });

        // ------------------------------- Bonding Curves----------------------------------------

        // Deploy BondingCurveRegistry and take temporary ownership to add the curves
        bondingCurveRegistry = new BondingCurveRegistry();
        console.logString("deployed BondingCurveRegistry implementation.");

        address bondingCurveRegistryImplementation = address(bondingCurveRegistry);

        bytes memory bondingCurveRegistryInitData = abi.encodeWithSelector(
            BondingCurveRegistry.initialize.selector,
            msg.sender
        );

        // Deploy BondingCurveRegistry proxy
        bondingCurveRegistryProxy = new TransparentUpgradeableProxy(
            address(bondingCurveRegistry), // BondingCurveRegistry logic contract address
            address(timelock), // Timelock controller address, which will be the owner of the ProxyAdmin contract for the proxy
            bondingCurveRegistryInitData // Initialization data to call the `initialize` function in BondingCurveRegistry
        );
        console.logString("deployed BondingCurveRegistry proxy.");
        console.logString("encoded constructor args: ");
        console.logBytes(
            abi.encode(
                address(bondingCurveRegistry),
                address(timelock),
                bondingCurveRegistryInitData
            )
        );

        // Deploy LinearCurve
        linearCurve = new LinearCurve("Linear Curve");
        console.logString("deployed LinearCurve.");
        console.logString("encoded constructor args: ");
        console.logBytes(abi.encode("Linear Curve"));

        // Deploy ProgressiveCurve
        progressiveCurve = new ProgressiveCurve("Progressive Curve", 0.00007054e18);
        console.log("deployed ProgressiveCurve.");
        console.logString("encoded constructor args: ");
        console.logBytes(abi.encode("Progressive Curve", 0.00007054e18));

        // Reference to the BondingCurveRegistry proxy contract
        bondingCurveRegistry = BondingCurveRegistry(address(bondingCurveRegistryProxy));

        // Add curves to BondingCurveRegistry
        bondingCurveRegistry.addBondingCurve(address(linearCurve));
        bondingCurveRegistry.addBondingCurve(address(progressiveCurve));

        // Transfer ownership of BondingCurveRegistry to multisig
        bondingCurveRegistry.setAdmin(admin);

        // -------------------------------------------------------------------------------------

        // Prepare data for initializer function
        bytes memory initData = abi.encodeWithSelector(
            EthMultiVault.init.selector,
            generalConfig,
            atomConfig,
            tripleConfig,
            walletConfig,
            vaultFees,
            bondingCurveConfig
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
        console.logString("encoded constructor args: ");
        console.logBytes(abi.encode(address(ethMultiVault), address(timelock), initData));

        console.log("encoded constructor args for the ProxyAdmin: ");
        console.logBytes(abi.encode(address(timelock)));

        // stop sending tx's
        vm.stopBroadcast();

        console.log("All contracts deployed successfully!");
        console.log("TimelockController address:", address(timelock));
        console.log("AtomWallet implementation address:", address(atomWallet));
        console.log("UpgradeableBeacon address:", address(atomWalletBeacon));
        console.log("EthMultiVault implementation address:", address(ethMultiVault));
        console.log("EthMultiVault proxy address:", address(ethMultiVaultProxy));
        console.log(
            "BondingCurveRegistry implementation address:",
            bondingCurveRegistryImplementation
        );
        console.log("BondingCurveRegistry proxy address:", address(bondingCurveRegistryProxy));
        console.log("LinearCurve address:", address(linearCurve));
        console.log("ProgressiveCurve address:", address(progressiveCurve));
        console.log(
            "To find the address of the ProxyAdmin contract for the EthMultiVault proxy, inspect the creation transaction of the EthMultiVault proxy contract on Basescan, in particular the AdminChanged event. Same applies to the BondingCurveRegistry proxy contract."
        );
    }
}
