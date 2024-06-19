// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {EthMultiVaultV2} from "./EthMultiVaultV2.sol";
import {Script, console} from "forge-std/Script.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";

/**
 * @title  Timelock Controller Parameters
 * @notice Generates the parameters that should be used to call TimelockController to schedule
 *         the upgrade of our contract on Safe Transaction Builder
 */
contract TimelockControllerParametersScript is Script {
    /// Just change here for your deployment addresses
    address _transparentUpgradeableProxy = address(0x0000000000000000000000000000000000000000);
    address _atomWalletBeacon = address(0x0000000000000000000000000000000000000000);
    address _proxyAdmin = address(0x0000000000000000000000000000000000000000);
    address _timelockController = address(0x0000000000000000000000000000000000000000);
    address _newImplementation = address(0x0000000000000000000000000000000000000000);

    /// Multisig addresses for key roles in the protocol
    address _admin = address(0x0000000000000000000000000000000000000000);
    address _protocolVault = address(0x0000000000000000000000000000000000000000);
    address _atomWarden = address(0x0000000000000000000000000000000000000000);

    IPermit2 _permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)); // Permit2 on Base
    address _entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base

    function run() external view {
        IEthMultiVault.GeneralConfig memory generalConfig = IEthMultiVault.GeneralConfig({
            admin: _admin, // Admin address for the EthMultiVault contract
            protocolVault: _protocolVault, // Protocol vault address (should be a multisig in production)
            feeDenominator: 10000, // Common denominator for fee calculations
            minDeposit: 0.0003 ether, // Minimum deposit amount in wei
            minShare: 1e5, // Minimum share amount (e.g., for vault initialization)
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
            atomDepositFractionOnTripleCreation: 0.0003 ether, // Static fee going towards increasing the amount of assets in the underlying atom vaults
            atomDepositFractionForTriple: 1500 // Fee for equity in atoms when creating a triple
        });

        IEthMultiVault.WalletConfig memory walletConfig = IEthMultiVault.WalletConfig({
            permit2: IPermit2(address(_permit2)), // Permit2 on Base
            entryPoint: _entryPoint, // EntryPoint address on Base
            atomWarden: _atomWarden, // AtomWarden address (should be a multisig in production)
            atomWalletBeacon: address(_atomWalletBeacon) // Address of the AtomWalletBeacon contract
        });

        IEthMultiVault.VaultFees memory vaultFees = IEthMultiVault.VaultFees({
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
        uint256 delay = 5 minutes;

        bytes memory initData = abi.encodeWithSelector(
            EthMultiVaultV2.initialize.selector, generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees
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
