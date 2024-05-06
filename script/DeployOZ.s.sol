// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Defender, ApprovalProcessResponse} from "openzeppelin-foundry-upgrades/Defender.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Defender.sol";

contract DeployEthMultiVaultScript is Script {
    // ======== Multisig addresses for key roles in the protocol ========
    address _protocolVault = address(0);
    address _admin = address(0);
    address _atomWarden = address(0);

    function run() external {
        vm.startBroadcast();

        address deployer = msg.sender;

        console.log("deployer:", deployer);
        console.log("protocolVault:", _protocolVault);
        console.log("admin:", _admin);
        console.log("atomWarden:", _atomWarden);

        IPermit2 permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)); // Permit2 on Base
        address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base

        // ======== OpenZeppelin Defender Approval Process ========

        // Check if we have a deploy processes defined
        ApprovalProcessResponse memory deployApprovalProcess = Defender.getDeployApprovalProcess();
        console.log("deploy approval:", deployApprovalProcess.via);
        if (deployApprovalProcess.via == address(0)) {
            revert(
                string.concat(
                    "Deploy approval process with id ",
                    deployApprovalProcess.approvalProcessId,
                    " has no assigned address"
                )
            );
        }

        Options memory opts;
        opts.defender.useDefenderDeploy = true;

        // ======== Deploy TimelockController ========

        uint256 minDelay = 2 days;
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);

        proposers[0] = _admin;
        executors[0] = _admin;

        TimelockController timelock = new TimelockController(
            minDelay, // minimum delay for timelock transactions
            proposers, // proposers (can schedule transactions)
            executors, // executors
            address(0) // no default _admin that can change things without going through the timelock process (self-_administered)
        );

        console.log("timelock:", address(timelock));

        // ======== Deploy AtomWalletBeacon ========

        /// Deploy AtomWalletBeacon pointing to the AtomWallet implementation contract
        address atomWalletBeacon = Upgrades.deployBeacon("AtomWallet.sol", address(timelock), opts);

        console.log("atomWalletBeacon:", address(atomWalletBeacon));

        // // ======== Deploy EthMultiVault ========

        IEthMultiVault.GeneralConfig memory generalConfig = IEthMultiVault.GeneralConfig({
            admin: _admin, // Admin address for the EthMultiVault contract
            protocolVault: _protocolVault, // Intuition protocol vault address (should be a multisig in production)
            feeDenominator: 10000, // Common denominator for fee calculations
            minDeposit: 0.0003 ether, // Minimum deposit amount in wei
            minShare: 1e5, // Minimum share amount (e.g., for vault initialization)
            atomUriMaxLength: 250, // Maximum length of the atom URI data that can be passed when creating atom vaults
            decimalPrecision: 1e18, // Decimal precision used for calculating share prices
            minDelay: 1 days // Minimum delay for timelocked transactions
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
            permit2: IPermit2(address(permit2)), // Permit2 on Base
            entryPoint: entryPoint, // EntryPoint address on Base
            atomWarden: _atomWarden, // AtomWarden address (should be a multisig in production)
            atomWalletBeacon: address(atomWalletBeacon) // Address of the AtomWalletBeacon contract
        });

        IEthMultiVault.VaultFees memory vaultFees = IEthMultiVault.VaultFees({
            entryFee: 500, // Entry fee for vault 0
            exitFee: 500, // Exit fee for vault 0
            protocolFee: 100 // Protocol fee for vault 0
        });

        address ethMultiVaultProxy = Upgrades.deployTransparentProxy(
            "EthMultiVault.sol",
            address(timelock),
            abi.encodeCall(EthMultiVault.init, (generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees)),
            opts
        );

        console.log("transparentUpgradableProxy:", ethMultiVaultProxy);

        vm.stopBroadcast();
    }
}
