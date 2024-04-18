// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {EthMultiVaultV2} from "../test/EthMultiVaultV2.sol";
import {Script, console} from "forge-std/Script.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {Options} from "openzeppelin-foundry-upgrades/Defender.sol";

contract TimelockControllerScript is Script {
    address _transparentUpgradeableProxy = 0xD655f1000B6a418e154A7e42eb88D9380649Aa92;
    address _atomWalletBeacon = 0x8914C65F19642Ca17Cf0e59a43847C5273B3322A;
    address _proxyAdmin = 0x1F2f0584591E4794Ae161EF57f60998631AFBA1b;
    address _timelockController = 0xce7c945a8e7fD930F7d3eB9dc9736f08B58ABa98;
    address _newImplementation = 0x4c201A6d11265b61296ab96dfB6D6285Fe49C898;

    IPermit2 _permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)); // Permit2 on Base
    address _entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base

    address _admin = 0xEcAc3Da134C2e5f492B702546c8aaeD2793965BB; // Intuition multisig
    address _protocolVault = _admin;
    address _atomWarden = _admin;

    function run() external view {
        Options memory opts;
        opts.defender.useDefenderDeploy = true;

        // IEthMultiVault.GeneralConfig memory generalConfig = IEthMultiVault
        //     .GeneralConfig({
        //         admin: _admin, // Admin address for the EthMultiVault contract
        //         protocolVault: _protocolVault, // Intuition protocol vault address (should be a multisig in production)
        //         feeDenominator: 1e4, // Common denominator for fee calculations
        //         minDeposit: 1e15, // Minimum deposit amount in wei
        //         minShare: 1e5, // Minimum share amount (e.g., for vault initialization)
        //         atomUriMaxLength: 250, // Maximum length of the atom URI data that can be passed when creating atom vaults
        //         decimalPrecision: 1e18, // decimal precision used for calculating share prices
        //         minDelay: 5 minutes // minimum delay for timelocked transactions
        //     });

        // IEthMultiVault.AtomConfig memory atomConfig = IEthMultiVault
        //     .AtomConfig({
        //         atomShareLockFee: 0.0021 ether, // Fee charged for purchasing vault shares for the atom wallet upon creation
        //         atomCreationFee: 0.0021 ether // Fee charged for creating an atom
        //     });

        // IEthMultiVault.TripleConfig memory tripleConfig = IEthMultiVault
        //     .TripleConfig({
        //         tripleCreationFee: 0.0021 ether, // Fee for creating a triple
        //         atomDepositFractionForTriple: 1500 // Fee for equity in atoms when creating a triple
        //     });

        // IEthMultiVault.WalletConfig memory walletConfig = IEthMultiVault
        //     .WalletConfig({
        //         permit2: IPermit2(address(_permit2)), // Permit2 on Base
        //         entryPoint: _entryPoint, // EntryPoint address on Base
        //         atomWarden: _atomWarden, // AtomWarden address (should be a multisig in production)
        //         atomWalletBeacon: _atomWalletBeacon // Address of the AtomWalletBeacon contract
        //     });

        // IEthMultiVault.VaultConfig memory vaultConfig = IEthMultiVault  
        //     .VaultConfig({
        //         entryFee: 500, // Entry fee for vault 0
        //         exitFee: 500, // Exit fee for vault 0
        //         protocolFee: 100 // Protocol fee for vault 0
        //     });

        address to = _timelockController;
        address target = _proxyAdmin;
        uint256 value = 0;
        bytes32 predecessor = bytes32(0);
        bytes32 salt = bytes32(0);
        uint256 delay = 2 days;

        // bytes memory initData = abi.encodeWithSelector(
        //     EthMultiVaultV2.init.selector, 
        //     generalConfig, atomConfig, tripleConfig, walletConfig, vaultConfig
        // );

        // bytes memory timelockControllerData = abi.encodeWithSelector(
        //     ProxyAdmin(_proxyAdmin).upgradeAndCall.selector,
        //     ITransparentUpgradeableProxy(_transparentUpgradeableProxy),
        //     _newImplementation,
        //     bytes("")
        // );

        bytes memory timelockControllerData = abi.encodeWithSelector(
            ProxyAdmin(_proxyAdmin).upgradeAndCall.selector,
            ITransparentUpgradeableProxy(_transparentUpgradeableProxy),
            _newImplementation,
            bytes("")
        );

        console.log("To Address:", to);
        console.log("Contract Method Selector: schedule");
        console.log("target (address):", target);
        console.log("Value (uint256):", value);
        console.log("data (bytes):");
        console.logBytes(timelockControllerData);
        console.log("predecessor (bytes32):");
        console.logBytes32(predecessor);
        console.log("salt (bytes32):");
        console.logBytes32(salt);
        console.log("delay (uint256):", delay);
    }
}