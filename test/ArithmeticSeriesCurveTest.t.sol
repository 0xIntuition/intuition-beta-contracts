// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {AtomWallet} from "src/AtomWallet.sol";
import {BondingCurveRegistry} from "src/BondingCurveRegistry.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";
import {LinearCurve} from "src/LinearCurve.sol";
import {ArithmeticSeriesCurve} from "src/ArithmeticSeriesCurve.sol";

contract ArithmeticSeriesCurveTest is Test {
    // Test user2
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");

    // Multisig addresses for key roles in the protocol
    address public admin = makeAddr("admin");
    address public protocolMultisig = makeAddr("protocolMultisig");
    address public atomWarden = makeAddr("atomWarden");

    // Contracts to be deployed
    AtomWallet public atomWallet;
    UpgradeableBeacon public atomWalletBeacon;
    EthMultiVault public ethMultiVault;
    TransparentUpgradeableProxy public ethMultiVaultProxy;

    // Bonding Curves
    BondingCurveRegistry public bondingCurveRegistry;
    TransparentUpgradeableProxy public bondingCurveRegistryProxy;
    LinearCurve public linearCurve;
    ArithmeticSeriesCurve public arithmeticSeriesCurve;

    // Constants from Base
    IPermit2 permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3); // Permit2 on Base
    address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base

    // Curve parameters
    uint256 public priceIncrement = 0.00001 ether;

    function setUp() external {
        vm.deal(user, 1000 ether);
        vm.deal(user2, 1000 ether);
        vm.deal(user3, 1000 ether);
        vm.deal(admin, 1000 ether);

        atomWallet = new AtomWallet();
        atomWalletBeacon = new UpgradeableBeacon(address(atomWallet), admin);

        IEthMultiVault.GeneralConfig memory generalConfig = IEthMultiVault.GeneralConfig({
            admin: admin, // Admin address for the EthMultiVault contract
            protocolMultisig: protocolMultisig, // Protocol multisig address
            feeDenominator: 10000, // Common denominator for fee calculations
            minDeposit: 0.0001 ether, // Minimum deposit amount in wei
            minShare: 1e6, // Minimum share amount (e.g., for vault initialization)
            atomUriMaxLength: 250, // Maximum length of the atom URI data that can be passed when creating atom vaults
            decimalPrecision: 1e18, // decimal precision used for calculating share prices
            minDelay: 3 days // minimum delay for timelocked transactions
        });

        IEthMultiVault.AtomConfig memory atomConfig = IEthMultiVault.AtomConfig({
            atomWalletInitialDepositAmount: 0 ether, // Fee charged for purchasing vault shares for the atom wallet upon creation
            atomCreationProtocolFee: 0.0003 ether // Fee charged for creating an atom
        });

        IEthMultiVault.TripleConfig memory tripleConfig = IEthMultiVault.TripleConfig({
            tripleCreationProtocolFee: 0.0003 ether, // Fee for creating a triple
            atomDepositFractionOnTripleCreation: 0 ether, // Static fee going towards increasing the amount of assets in the underlying atom vaults
            atomDepositFractionForTriple: 0 // Fee for equity in atoms when creating a triple
        });

        IEthMultiVault.WalletConfig memory walletConfig = IEthMultiVault.WalletConfig({
            permit2: IPermit2(permit2), // Permit2 on Base
            entryPoint: entryPoint, // EntryPoint address on Base
            atomWarden: atomWarden, // atomWarden address
            atomWalletBeacon: address(atomWalletBeacon) // Address of the AtomWalletBeacon contract
        });

        IEthMultiVault.VaultFees memory vaultFees = IEthMultiVault.VaultFees({
            entryFee: 500, // Entry fee for vault 0
            exitFee: 500, // Exit fee for vault 0
            protocolFee: 100 // Protocol fee for vault 0
        });

        bondingCurveRegistry = new BondingCurveRegistry();
        bytes memory bondingCurveRegistryInitData =
            abi.encodeWithSelector(bondingCurveRegistry.initialize.selector, admin);
        bondingCurveRegistryProxy =
            new TransparentUpgradeableProxy(address(bondingCurveRegistry), admin, bondingCurveRegistryInitData);

        linearCurve = new LinearCurve("Linear Curve");
        arithmeticSeriesCurve = new ArithmeticSeriesCurve("Arithmetic Series Curve", priceIncrement);

        bondingCurveRegistry = BondingCurveRegistry(address(bondingCurveRegistryProxy));

        vm.startPrank(admin);

        bondingCurveRegistry.addBondingCurve(address(linearCurve));
        bondingCurveRegistry.addBondingCurve(address(arithmeticSeriesCurve));

        vm.stopPrank();

        IEthMultiVault.BondingCurveConfig memory bondingCurveConfig = IEthMultiVault.BondingCurveConfig({
            registry: address(bondingCurveRegistry),
            defaultCurveId: 1 // Unused in this edition of EthMultiVault
        });

        ethMultiVault = new EthMultiVault();

        bytes memory ethMultiVaultInitData = abi.encodeWithSelector(
            ethMultiVault.init.selector,
            generalConfig,
            atomConfig,
            tripleConfig,
            walletConfig,
            vaultFees,
            bondingCurveConfig
        );

        ethMultiVaultProxy = new TransparentUpgradeableProxy(address(ethMultiVault), admin, ethMultiVaultInitData);

        ethMultiVault = EthMultiVault(payable(address(ethMultiVaultProxy)));

        bytes memory testAtomUri = bytes("test");
        ethMultiVault.createAtom{value: ethMultiVault.getAtomCost()}(testAtomUri);
    }

    function test_convertToShares() external {
        uint256 totalAssets = 0; // used as a placeholder

        vm.startPrank(user);

        // deposit basePrice => 1 share
        uint256 basePrice = 0.0001 ether;
        uint256 totalShares = 0; // beginning state

        uint256 shares1 = arithmeticSeriesCurve.convertToShares(basePrice, totalAssets, totalShares);
        // assertEq(shares1, 1e18);
        console.log("Shares for basePrice (should be ~1e18):", shares1);

        vm.stopPrank();
    }
}
