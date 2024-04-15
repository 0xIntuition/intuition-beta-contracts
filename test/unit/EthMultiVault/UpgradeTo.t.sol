// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// import "forge-std/Test.sol";
// import {EthMultiVault} from "src/EthMultiVault.sol";
// import {EthMultiVaultV2} from "../../EthMultiVaultV2.sol";
// import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
// import {AtomWallet} from "src/AtomWallet.sol";
// import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
// import {IPermit2} from "src/interfaces/IPermit2.sol";
// import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
// import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

// contract UpgradeTo is Test {
//     IPermit2 permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)); // Permit2 on Base
//     address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base

//     AtomWallet atomWallet;
//     UpgradeableBeacon atomWalletBeacon;
//     EthMultiVault ethMultiVault;
//     EthMultiVaultV2 ethMultiVaultV2;
//     EthMultiVaultV2 ethMultiVaultV2New;
//     TransparentUpgradeableProxy proxy;
//     ProxyAdmin proxyAdmin;

//     address user1 = address(1);

//     function testUpgradeTo() external {
//         // deploy AtomWallet implementation contract
//         atomWallet = new AtomWallet();
//         console.logString("deployed AtomWallet.");

//         // deploy AtomWalletBeacon pointing to the AtomWallet implementation contract
//         atomWalletBeacon = new UpgradeableBeacon(address(atomWallet), address(atomWallet));
//         console.logString("deployed AtomWalletBeacon.");

//         // Example configurations for EthMultiVault initialization (NOT meant to be used in production)
//         IEthMultiVault.GeneralConfig memory generalConfig = IEthMultiVault.GeneralConfig({
//             admin: msg.sender, // Deployer as admin for simplicity
//             protocolVault: msg.sender, // Deployer as protocol vault for simplicity
//             feeDenominator: 10000, // Common denominator for fee calculations
//             minDeposit: 0.01 ether, // Minimum deposit amount in wei
//             minShare: 1e18, // Minimum share amount (e.g., for vault initialization)
//             atomUriMaxLength: 250, // Maximum length of the atom URI data that can be passed when creating atom vaults
//             decimalPrecision: 1e18, // decimal precision used for calculating share prices
//             minDelay: 12 hours // minimum delay for timelocked transactions
//         });

//         IEthMultiVault.AtomConfig memory atomConfig = IEthMultiVault.AtomConfig({
//             atomShareLockFee: 1e15, // Fee charged for purchasing vault shares for the atom wallet upon creation
//             atomCreationFee: 5e14 // Fee charged for creating an atom
//         });

//         IEthMultiVault.TripleConfig memory tripleConfig = IEthMultiVault.TripleConfig({
//             tripleCreationFee: 2e15, // Fee for creating a triple
//             atomDepositFractionForTriple: 1e3 // Fee for equity in atoms when creating a triple
//         });

//         IEthMultiVault.WalletConfig memory walletConfig = IEthMultiVault.WalletConfig({
//             permit2: IPermit2(address(permit2)), // Permit2 on Base
//             entryPoint: entryPoint, // EntryPoint on Base
//             atomWarden: msg.sender, // Deployer as atom warden for simplicity
//             atomWalletBeacon: address(atomWalletBeacon) // AtomWalletBeacon address
//         });

//         IEthMultiVault.VaultConfig memory vaultConfig = IEthMultiVault.VaultConfig({
//             entryFee: 500, // Entry fee for vault 0
//             exitFee: 500, // Exit fee for vault 0
//             protocolFee: 100 // Protocol fee for vault 0
//         });

//         bytes memory initData = abi.encodeWithSelector(
//             EthMultiVault.init.selector,
//             generalConfig,
//             atomConfig,
//             tripleConfig,
//             walletConfig,
//             vaultConfig
//         );

//         // deploy EthMultiVault
//         ethMultiVault = new EthMultiVault();
//         console.logString("deployed EthMultiVault.");

//         // deploy ProxyAdmin
//         proxyAdmin = new ProxyAdmin(msg.sender);
//         console.logString("deployed ProxyAdmin.");

//         // deploy TransparentUpgradeableProxy with EthMultiVault logic contract
//         proxy = new TransparentUpgradeableProxy(
//             address(ethMultiVault),
//             address(proxyAdmin),
//             initData
//         );
//         console.logString("deployed TransparentUpgradeableProxy with EthMultiVault logic contract.");

//         // deploy EthMultiVaultV2
//         ethMultiVaultV2 = new EthMultiVaultV2();
//         console.logString("deployed EthMultiVaultV2.");

//         // upgrade EthMultiVault
//         proxyAdmin.upgrade(
//             ITransparentUpgradeableProxy(address(proxy)),
//             address(ethMultiVaultV2)
//         );
//         console.logString("upgraded EthMultiVault.");

//         // verify VERSION variable in EthMultiVaultV2 is V2
//         assertEq(ethMultiVaultV2.VERSION(), "V2");
//         console.logString("verified VERSION variable in EthMultiVaultV2 is V2");

//         // deploy EthMultiVaultV2New
//         ethMultiVaultV2New = new EthMultiVaultV2();
//         console.logString("deployed EthMultiVaultV2New.");

//         // simulate a non-admin trying to upgrade EthMultiVault
//         vm.prank(user1);

//         // try to upgrade EthMultiVault as non-admin
//         vm.expectRevert("Ownable: caller is not the owner");
//         proxyAdmin.upgrade(
//             ITransparentUpgradeableProxy(address(proxy)),
//             address(ethMultiVaultV2New)
//         );
//     }
// }
