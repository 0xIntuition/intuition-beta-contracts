// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";
import {EthMultiVaultV2} from "../../EthMultiVaultV2.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {AtomWallet} from "src/AtomWallet.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract UpgradeTo is Test {
    address user1 = address(1);

    IPermit2 permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)); // Permit2 on Base
    address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base

    // Multisig addresses for key roles in the protocol
    address admin = msg.sender;
    address protocolVault = admin;
    address atomWarden = admin;

    uint256 minDelay = 5 minutes; // 2 days for prod

    AtomWallet atomWallet;
    UpgradeableBeacon atomWalletBeacon;
    EthMultiVault ethMultiVault;
    TransparentUpgradeableProxy ethMultiVaultProxy;

    EthMultiVaultV2 ethMultiVaultV2;
    ProxyAdmin proxyAdmin;

    address atomWalletBeaconOwner;
    address proxyAdminOwner;

    function testUpgradeTo() external {
        address[] memory proposers = new address[](1);

        console.log("admin:", admin);

        // ======== Deploy TimelockController ========

        proposers[0] = admin;

        TimelockController timelock = new TimelockController(
            minDelay, // minimum delay for timelock transactions
            proposers, // proposers (can schedule transactions)
            proposers, // executors
            address(0) // no default admin that can change things without going through the timelock process (self-administered)
        );

        console.log("timelock:", address(timelock));

        // ======== Deploy AtomWalletBeacon ========

        // Deploy AtomWallet pointing to the Atom implementation contract
        atomWallet = new AtomWallet();
        console.log("atomWallet:", address(atomWallet));

        /// Deploy AtomWalletBeacon pointing to the AtomWallet implementation contract
        atomWalletBeacon = new UpgradeableBeacon(address(atomWallet), address(timelock));
        console.log("atomWalletBeacon:", address(atomWalletBeacon));

        atomWalletBeaconOwner = atomWalletBeacon.owner();
        console.log("atomWalletBeaconOwner:", atomWalletBeaconOwner);

        assertEq(atomWalletBeaconOwner, address(timelock));

        // ======== Deploy EthMultiVault ========

        // Example configurations for EthMultiVault initialization (NOT meant to be used in production)
        IEthMultiVault.GeneralConfig memory generalConfig = IEthMultiVault.GeneralConfig({
            admin: admin, // Admin address for the EthMultiVault contract
            protocolVault: protocolVault, // Intuition protocol vault address (should be a multisig in production)
            feeDenominator: 1e4, // Common denominator for fee calculations
            minDeposit: 0.0003 ether, // Minimum deposit amount in wei
            minShare: 1e5, // Minimum share amount (e.g., for vault initialization)
            atomUriMaxLength: 250, // Maximum length of the atom URI data that can be passed when creating atom vaults
            decimalPrecision: 1e18, // decimal precision used for calculating share prices
            minDelay: 5 minutes // 1 days for prod // minimum delay for timelocked transactions
        });

        IEthMultiVault.AtomConfig memory atomConfig = IEthMultiVault.AtomConfig({
            atomShareLockFee: 0.0001 ether, // Fee charged for purchasing vault shares for the atom wallet upon creation
            atomCreationFee: 0.0002 ether // Fee charged for creating an atom
        });

        IEthMultiVault.TripleConfig memory tripleConfig = IEthMultiVault.TripleConfig({
            tripleCreationFee: 0.0003 ether, // Fee for creating a triple
            atomDepositFractionForTriple: 1500 // Fee for equity in atoms when creating a triple
        });

        IEthMultiVault.WalletConfig memory walletConfig = IEthMultiVault.WalletConfig({
            permit2: IPermit2(address(permit2)), // Permit2 on Base
            entryPoint: entryPoint, // EntryPoint address on Base
            atomWarden: atomWarden, // AtomWarden address (should be a multisig in production)
            atomWalletBeacon: address(atomWalletBeacon) // Address of the AtomWalletBeacon contract
        });

        IEthMultiVault.VaultConfig memory vaultConfig = IEthMultiVault.VaultConfig({
            entryFee: 500, // Entry fee for vault 0
            exitFee: 500, // Exit fee for vault 0
            protocolFee: 100 // Protocol fee for vault 0
        });

        ethMultiVault = new EthMultiVault();
        console.log("deployed EthMultiVault", address(ethMultiVault));

        // // Prepare data for initializer function
        bytes memory initData = abi.encodeWithSelector(
            EthMultiVault.init.selector, generalConfig, atomConfig, tripleConfig, walletConfig, vaultConfig
        );

        // // Deploy EthMultiVaultProxy
        // ethMultiVaultProxy = new TransparentUpgradeableProxy(address(ethMultiVault), address(timelock), initData);
        // console.log("ethMultiVaultProxy:", address(ethMultiVaultProxy));

        // // deploy EthMultiVaultV2
        // ethMultiVaultV2 = new EthMultiVaultV2();
        // console.logString("deployed EthMultiVaultV2.");

        // // hardcode the proxyAdmin here or just change the var to public on TransparentUpgradeableProxy
        // proxyAdmin = ProxyAdmin(0x0000000000000000000000000000000000000000);
        // // proxyAdmin = ProxyAdmin(ethMultiVaultProxy._admin());
        // console.log("proxyAdmin:", address(proxyAdmin));

        // proxyAdminOwner = proxyAdmin.owner();
        // console.log("proxyAdminOwner:", proxyAdminOwner);

        // assertEq(proxyAdminOwner, address(timelock));

        // vm.startPrank(admin, admin);

        // bytes memory initDataV2 = abi.encodeWithSelector(
        //     EthMultiVaultV2.init.selector, generalConfig, atomConfig, tripleConfig, walletConfig, vaultConfig
        // );

        // // prepare data for upgradeAndCall transaction
        // bytes memory data = abi.encodeWithSelector(
        //     proxyAdmin.upgradeAndCall.selector,
        //     ITransparentUpgradeableProxy(address(ethMultiVaultProxy)),
        //     address(ethMultiVaultV2),
        //     initDataV2
        // );

        // // schedule an upgradeAndCall transaction in the timelock
        // timelock.schedule(address(proxyAdmin), 0, data, bytes32(0), bytes32(0), timelock.getMinDelay() + 1000);

        // console.logString("scheduled upgradeAndCall transaction in the timelock.");

        // // go 3 days into the future
        // // Forward time to surpass the delay
        // vm.warp(block.timestamp + timelock.getMinDelay() + 1001);

        // // execute the upgradeAndCall transaction
        // timelock.execute(address(proxyAdmin), 0, data, bytes32(0), bytes32(0));

        // console.logString("executed upgradeAndCall transaction in the timelock.");
        // vm.stopPrank();
    }
}
