// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {EthMultiVaultV2} from "../test/EthMultiVaultV2.sol";
import {Script, console} from "forge-std/Script.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";

/**
 * @title  Timelock Controller Parameters
 * @author 0xIntuition
 * @notice Generates the parameters that should be used to call TimelockController to schedule
 *         the upgrade of our contract on Safe Transaction Builder
 */
contract TimelockControllerParametersScript is Script {
    /// Just change here for your deployment addresses
    address _transparentUpgradeableProxy = 0xb243844355d80Ad82031f2e84C48B2e012c72D3b;
    address _atomWalletBeacon = 0x4c48b6654D5fdfcDFa84ba073563DCA03a0Cc5A2;
    address _proxyAdmin = 0xE17841F28a47250467f91D5D74a1D86768c182E9;
    address _timelockController = 0xFb05d31c3D2aa044b3e5Bd6A37807331A261Eed9;
    address _newImplementation = 0x1E75Db45bC9bd9E7f2866442F94404104c0898dF;

    IPermit2 _permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)); // Permit2 on Base
    address _entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base

    address _admin = 0xEcAc3Da134C2e5f492B702546c8aaeD2793965BB; // Intuition multisig
    address _protocolVault = _admin;
    address _atomWarden = _admin;

    function run() external view {
        IEthMultiVault.GeneralConfig memory generalConfig = IEthMultiVault.GeneralConfig({
            admin: _admin, // Admin address for the EthMultiVault contract
            protocolVault: _protocolVault, // Intuition protocol vault address (should be a multisig in production)
            feeDenominator: 1e4, // Common denominator for fee calculations
            minDeposit: 1e15, // Minimum deposit amount in wei
            minShare: 1e5, // Minimum share amount (e.g., for vault initialization)
            atomUriMaxLength: 250, // Maximum length of the atom URI data that can be passed when creating atom vaults
            decimalPrecision: 1e18, // decimal precision used for calculating share prices
            minDelay: 5 minutes // minimum delay for timelocked transactions
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
            permit2: IPermit2(address(_permit2)), // Permit2 on Base
            entryPoint: _entryPoint, // EntryPoint address on Base
            atomWarden: _atomWarden, // AtomWarden address (should be a multisig in production)
            atomWalletBeacon: _atomWalletBeacon // Address of the AtomWalletBeacon contract
        });

        IEthMultiVault.VaultConfig memory vaultConfig = IEthMultiVault.VaultConfig({
            entryFee: 500, // Entry fee for vault 0
            exitFee: 500, // Exit fee for vault 0
            protocolFee: 100 // Protocol fee for vault 0
        });

        /// Change values here as needed
        address to = _timelockController;
        address target = _proxyAdmin;
        uint256 value = 0;
        bytes32 predecessor = bytes32(0);
        bytes32 salt = bytes32(0);
        uint256 delay = 2 days;

        bytes memory initData = abi.encodeWithSelector(
            EthMultiVaultV2.init.selector, generalConfig, atomConfig, tripleConfig, walletConfig, vaultConfig
        );

        bytes memory timelockControllerData = abi.encodeWithSelector(
            ProxyAdmin.upgradeAndCall.selector,
            ITransparentUpgradeableProxy(_transparentUpgradeableProxy),
            _newImplementation,
            initData
        );

        // Print the parameters to Safe Transaction Builder
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
