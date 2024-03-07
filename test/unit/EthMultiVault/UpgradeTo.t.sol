// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";
import {EthMultiVaultV2} from "../../EthMultiVaultV2.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {IntuitionProxy} from "src/IntuitionProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeTo is Test {
    IPermit2 permit2;
    EntryPoint entryPoint;
    EthMultiVault ethMultiVault;
    EthMultiVaultV2 ethMultiVaultV2;
    EthMultiVaultV2 ethMultiVaultV2New;
    IntuitionProxy proxy;
    ProxyAdmin proxyAdmin;

    address user1 = address(1);

    function testUpgradeTo() external {
        permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));

        // deploy EntryPoint
        entryPoint = new EntryPoint();
        console.logString("deployed EntryPoint.");

        // Example configurations for EthMultiVault initialization (NOT meant to be used in production)
        IEthMultiVault.GeneralConfig memory generalConfig = IEthMultiVault.GeneralConfig({
            admin: msg.sender, // Deployer as admin for simplicity
            protocolVault: msg.sender, // Deployer as protocol vault for simplicity
            feeDenominator: 10000, // Common denominator for fee calculations
            minDeposit: 0.01 ether, // Minimum deposit amount in wei
            minShare: 1e18 // Minimum share amount (e.g., for vault initialization)
        });

        IEthMultiVault.AtomConfig memory atomConfig = IEthMultiVault.AtomConfig({
            atomCost: 0.01 ether, // Cost to create an atom
            atomCreationFee: 0.005 ether // Fee charged for creating an atom
        });

        IEthMultiVault.TripleConfig memory tripleConfig = IEthMultiVault.TripleConfig({
            tripleCreationFee: 0.02 ether, // Fee for creating a triple
            atomEquityFeeForTriple: 100 // Fee for equity in atoms when creating a triple
        });

        IEthMultiVault.WalletConfig memory walletConfig = IEthMultiVault.WalletConfig({
            permit2: IPermit2(address(permit2)), // Uniswap Protocol Permit2 contract on Optimism
            entryPoint: address(entryPoint), // Our deployed EntryPoint contract (in production, change this to the actual entry point contract address on Optimism)
            atomWarden: msg.sender // Deployer as atom warden for simplicity
        });

        bytes memory initData = abi.encodeWithSelector(
            EthMultiVault.init.selector,
            generalConfig,
            atomConfig,
            tripleConfig,
            walletConfig
        );

        // deploy EthMultiVault
        ethMultiVault = new EthMultiVault();
        console.logString("deployed EthMultiVault.");

        // deploy ProxyAdmin
        proxyAdmin = new ProxyAdmin();
        console.logString("deployed ProxyAdmin.");

        // deploy IntuitionProxy
        proxy = new IntuitionProxy(address(ethMultiVault), address(proxyAdmin), initData);
        console.logString("deployed IntuitionProxy.");

        // deploy EthMultiVaultV2
        ethMultiVaultV2 = new EthMultiVaultV2();
        console.logString("deployed EthMultiVaultV2.");

        // upgrade EthMultiVault
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(address(proxy)), address(ethMultiVaultV2));
        console.logString("upgraded EthMultiVault.");

        // verify VERSION variable in EthMultiVaultV2 is V2
        assertEq(ethMultiVaultV2.VERSION(), "V2");
        console.logString("verified VERSION variable in EthMultiVaultV2 is V2");

        // deploy EthMultiVaultV2New
        ethMultiVaultV2New = new EthMultiVaultV2();
        console.logString("deployed EthMultiVaultV2New.");

        // simulate a non-admin trying to upgrade EthMultiVault
        vm.prank(user1);

        // try to upgrade EthMultiVault as non-admin
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(address(proxy)), address(ethMultiVaultV2New));
    }
}
