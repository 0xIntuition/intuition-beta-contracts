// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";

import {CatmullRomAssetShares} from "src/experiments/curves/CatmullRom.sol";
import {Exponential} from "src/experiments/curves/Exponential.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {TwoStepLinear} from "src/experiments/curves/TwoStepLinear.sol";

contract DeployExperimental is Script {
    // Addresses for key roles in the protocol
    address public admin = 0xaAE94A934c070F4a57303f436fb3599CBd5497C6; // Experimental admin
    address public protocolMultisig = 0xD8a8653ceD32364DeB582c900Cc3FcD16c34d6D5; // Experimental protocol multisig
    address public atomWarden = admin;
    address public atomWalletBeacon = 0x9688eAc5757735A4e0F23C05B528Ea1ADcfFeaf1; // AtomWalletBeacon on Base Sepolia

    // Constants from Base
    IPermit2 permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)); // Permit2 on Base
    address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base

    // Contracts to be deployed
    Exponential public exponential;
    CatmullRomAssetShares public catmullRom;
    TwoStepLinear public twoStepLinear;

    function run() external {
        // Begin sending tx's to network
        vm.startBroadcast();

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

        // Deploy Exponential curve
        exponential = new Exponential();
        console.logString("deployed Exponential curve.");

        // Initialize Exponential curve
        exponential.init(generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees);

        // Deploy CatmullRom curve
        // catmullRom = new CatmullRomAssetShares();
        // console.logString("deployed CatmullRom curve.");

        // Deploy TwoStepLinear curve
        // twoStepLinear = new TwoStepLinear();
        // console.logString("deployed TwoStepLinear curve.");

        // stop sending tx's
        vm.stopBroadcast();
    }
}
