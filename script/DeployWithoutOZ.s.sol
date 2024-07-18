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

contract DeployEthMultiVault is Script {
    address deployer;

    // Multisig addresses for key roles in the protocol (should be replaced with the actual multisig addresses for each role in the production)
    address admin = 0xEcAc3Da134C2e5f492B702546c8aaeD2793965BB; // Testnet multisig Safe address
    address protocolMultisig = admin;
    address atomWarden = admin;

    // Constants from Base
    IPermit2 permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)); // Permit2 on Base
    address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base

    // Contracts to be deployed
    AtomWallet atomWallet;
    UpgradeableBeacon atomWalletBeacon;
    EthMultiVault ethMultiVault;
    TransparentUpgradeableProxy ethMultiVaultProxy;
    TimelockController timelock;

    function run() external {
        // Begin sending tx's to network
        vm.startBroadcast();

        // TimelockController parameters
        uint256 minDelay = 2 days;
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
            minDeposit: 0.00069 ether, // Minimum deposit amount in wei
            minShare: 1e6, // Minimum share amount (e.g., for vault initialization)
            atomUriMaxLength: 250, // Maximum length of the atom URI data that can be passed when creating atom vaults
            decimalPrecision: 1e18, // decimal precision used for calculating share prices
            minDelay: 1 days // minimum delay for timelocked transactions
        });

        IEthMultiVault.AtomConfig memory atomConfig = IEthMultiVault.AtomConfig({
            atomWalletInitialDepositAmount: 0.0001 ether, // Fee charged for purchasing vault shares for the atom wallet upon creation
            atomCreationProtocolFee: 0.0002 ether // Fee charged for creating an atom
        });

        IEthMultiVault.TripleConfig memory tripleConfig = IEthMultiVault.TripleConfig({
            tripleCreationProtocolFee: 0.0002 ether, // Fee for creating a triple
            atomDepositFractionOnTripleCreation: 0.00003 ether, // Static fee going towards increasing the amount of assets in the underlying atom vaults
            atomDepositFractionForTriple: 1500 // Fee for equity in atoms when creating a triple
        });

        IEthMultiVault.WalletConfig memory walletConfig = IEthMultiVault.WalletConfig({
            permit2: IPermit2(address(permit2)), // Permit2 on Base
            entryPoint: entryPoint, // EntryPoint address on Base
            atomWarden: atomWarden, // atomWarden address (same as admin)
            atomWalletBeacon: address(atomWalletBeacon) // Address of the AtomWalletBeacon contract
        });

        IEthMultiVault.VaultFees memory vaultFees = IEthMultiVault.VaultFees({
            entryFee: 500, // Entry fee for vault 0
            exitFee: 500, // Exit fee for vault 0
            protocolFee: 250 // Protocol fee for vault 0
        });

        // Prepare data for initializer function
        bytes memory initData = abi.encodeWithSelector(
            EthMultiVault.init.selector, generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees
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

        // ======== Deploy CustomMulticall3 ========

        // Prepare data for initializer function
        bytes memory multicallInitData =
            abi.encodeWithSelector(CustomMulticall3.init.selector, IEthMultiVault(address(ethMultiVaultProxy)), admin);

        // deploy CustomMulticall3 implementation contract
        CustomMulticall3 customMulticall3 = new CustomMulticall3();
        console.logString("deployed CustomMulticall3.");

        // deploy TransparentUpgradeableProxy for CustomMulticall3
        TransparentUpgradeableProxy customMulticall3Proxy = new TransparentUpgradeableProxy(
            address(customMulticall3), // logic contract address
            admin, // initial owner of the ProxyAdmin instance tied to the proxy
            multicallInitData // data to pass to the logic contract's initializer function
        );

        // stop sending tx's
        vm.stopBroadcast();

        console.log("All contracts deployed successfully:");
        console.log("TimelockController address:", address(timelock));
        console.log("AtomWallet implementation address:", address(atomWallet));
        console.log("UpgradeableBeacon address:", address(atomWalletBeacon));
        console.log("EthMultiVault implementation address:", address(ethMultiVault));
        console.log("EthMultiVault proxy address:", address(ethMultiVaultProxy));
        console.log(
            "To find the address of the ProxyAdmin contract for the EthMultiVault proxy, inspect the creation transaction of the EthMultiVault proxy contract on Basescan, in particular the AdminChanged event. Same applies to the CustomMulticall3 proxy contract."
        );
        console.log("customMulticall3 implementation:", address(customMulticall3));
        console.log("customMulticall3Proxy:", address(customMulticall3Proxy));
    }
}

// Add testnet deployment and add addresses to readme here and in the public repo
// Remove duplicate console logs for the custommulticall3
