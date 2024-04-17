// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {EthMultiVaultV2} from "../test/EthMultiVaultV2.sol";
import {Script, console} from "forge-std/Script.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {Options} from "openzeppelin-foundry-upgrades/Defender.sol";

contract TimelockControllerParameters is Script {
    address _transparentUpgradeableProxy = 0xf1C32Dc428C76A8f0ea77c9457f01d0e38f9Bce4;
    address _atomWalletBeacon = 0xe95138f02636C32c26f0B89Ed4cE75d036d0C621;
    address _proxyAdmin = 0x3A886a83f39C74562278956606915B82AFab8baA;
    address _timelockController = 0xF37D55c8ADafc62E105348AC16a539ADD7ff364b;
    address _newImplementation = 0x5b669dfEf36753C2Ab5b69E2C7a8C5301cC6724C;

    IPermit2 _permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)); // Permit2 on Base
    address _entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base

    address _admin = 0xEcAc3Da134C2e5f492B702546c8aaeD2793965BB; // Intuition multisig
    address _protocolVault = _admin;
    address _atomWarden = _admin;

    function run() external view {
        Options memory opts;
        opts.defender.useDefenderDeploy = true;

        IEthMultiVault.GeneralConfig memory generalConfig = IEthMultiVault
            .GeneralConfig({
                admin: _admin, // Admin address for the EthMultiVault contract
                protocolVault: _protocolVault, // Intuition protocol vault address (should be a multisig in production)
                feeDenominator: 1e4, // Common denominator for fee calculations
                minDeposit: 1e15, // Minimum deposit amount in wei
                minShare: 1e5, // Minimum share amount (e.g., for vault initialization)
                atomUriMaxLength: 250, // Maximum length of the atom URI data that can be passed when creating atom vaults
                decimalPrecision: 1e18, // decimal precision used for calculating share prices
                minDelay: 5 minutes // minimum delay for timelocked transactions
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
                permit2: IPermit2(address(_permit2)), // Permit2 on Base
                entryPoint: _entryPoint, // EntryPoint address on Base
                atomWarden: _atomWarden, // AtomWarden address (should be a multisig in production)
                atomWalletBeacon: _atomWalletBeacon // Address of the AtomWalletBeacon contract
            });

        IEthMultiVault.VaultConfig memory vaultConfig = IEthMultiVault  
            .VaultConfig({
                entryFee: 500, // Entry fee for vault 0
                exitFee: 500, // Exit fee for vault 0
                protocolFee: 100 // Protocol fee for vault 0
            });


        address to = _timelockController;
        address target = _proxyAdmin;
        uint256 value = 0;
        bytes32 predecessor = bytes32(0);
        bytes32 salt = bytes32(0);
        uint256 delay = 2 days;

        bytes memory initData = abi.encodeWithSelector(
            EthMultiVaultV2.init.selector, 
            generalConfig, atomConfig, tripleConfig, walletConfig, vaultConfig
        );

        bytes memory timelockControllerData = abi.encodeWithSelector(
            ProxyAdmin.upgradeAndCall.selector,
            ITransparentUpgradeableProxy(_transparentUpgradeableProxy), _newImplementation, initData
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