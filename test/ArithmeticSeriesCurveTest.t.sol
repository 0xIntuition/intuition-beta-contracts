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
    // Test users
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    uint256 public dealAmount = 1_000_000 ether;

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
    ArithmeticSeriesCurve public aggressiveArithmeticSeriesCurve;

    // Constants from Base
    IPermit2 permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3); // Permit2 on Base
    address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base

    // Curve parameters
    uint256 public priceIncrement = 0.00001 ether;
    uint256 public aggressivePriceIncrement = 0.0001 ether;

    // Test parameters
    uint256 public atomId;
    uint256 public bondingCurveId;
    uint256 public bondingCurveId2;

    function setUp() external {
        vm.deal(user, dealAmount);
        vm.deal(user2, dealAmount);
        vm.deal(user3, dealAmount);
        vm.deal(admin, dealAmount);

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

        // Use zero fees for this test
        IEthMultiVault.VaultFees memory vaultFees = IEthMultiVault.VaultFees({
            entryFee: 0, // Entry fee for vault 0
            exitFee: 0, // Exit fee for vault 0
            protocolFee: 0 // Protocol fee for vault 0
        });

        bondingCurveRegistry = new BondingCurveRegistry();
        bytes memory bondingCurveRegistryInitData =
            abi.encodeWithSelector(bondingCurveRegistry.initialize.selector, admin);
        bondingCurveRegistryProxy =
            new TransparentUpgradeableProxy(address(bondingCurveRegistry), admin, bondingCurveRegistryInitData);

        linearCurve = new LinearCurve("Linear Curve");
        arithmeticSeriesCurve = new ArithmeticSeriesCurve("Arithmetic Series Curve", priceIncrement);
        aggressiveArithmeticSeriesCurve =
            new ArithmeticSeriesCurve("Aggressive Arithmetic Series Curve", aggressivePriceIncrement);

        bondingCurveRegistry = BondingCurveRegistry(address(bondingCurveRegistryProxy));

        vm.startPrank(admin);

        bondingCurveRegistry.addBondingCurve(address(linearCurve));
        bondingCurveRegistry.addBondingCurve(address(arithmeticSeriesCurve));
        bondingCurveRegistry.addBondingCurve(address(aggressiveArithmeticSeriesCurve));

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
        atomId = ethMultiVault.createAtom{value: ethMultiVault.getAtomCost()}(testAtomUri);

        bondingCurveId = bondingCurveRegistry.curveIds(address(arithmeticSeriesCurve));
        bondingCurveId2 = bondingCurveRegistry.curveIds(address(aggressiveArithmeticSeriesCurve));
    }

    function testFuzz_arithmeticCurve_depositAndRedeemFlow(uint256 randomSharesToMint, uint256 randomSharesToRedeem)
        external
    {
        uint256 maxWholeSharesToMint = 100_000; // Reasonable upper bound for minting shares
        randomSharesToMint = bound(randomSharesToMint, 1, maxWholeSharesToMint);

        _depositAndRedeemFlow(randomSharesToMint, randomSharesToRedeem, bondingCurveId, address(arithmeticSeriesCurve));
    }

    function testFuzz_aggressiveArithmeticCurve_depositAndRedeemFlow(
        uint256 randomSharesToMint,
        uint256 randomSharesToRedeem
    ) external {
        uint256 maxWholeSharesToMint = 10_000; // Reasonable upper bound for minting shares
        randomSharesToMint = bound(randomSharesToMint, 1, maxWholeSharesToMint);

        _depositAndRedeemFlow(
            randomSharesToMint, randomSharesToRedeem, bondingCurveId2, address(aggressiveArithmeticSeriesCurve)
        );
    }

    function _depositAndRedeemFlow(
        uint256 randomSharesToMint,
        uint256 randomSharesToRedeem,
        uint256 curveId,
        address curveContract
    ) internal {
        // Reference to the chosen ArithmeticSeriesCurve contract
        ArithmeticSeriesCurve arithmeticSeriesCurveContract = ArithmeticSeriesCurve(curveContract);

        vm.startPrank(user);

        // Total shares in the vault are initially 0
        uint256 totalShares = 0;

        // Case 1: Deposit BASE_PRICE
        uint256 depositAmount = arithmeticSeriesCurveContract.BASE_PRICE();
        uint256 expectedShares = arithmeticSeriesCurveContract.convertToShares(depositAmount, 0, totalShares);
        uint256 actualShares = ethMultiVault.depositAtomCurve{value: depositAmount}(user, atomId, curveId);
        assertEq(actualShares, expectedShares);
        uint256 expectedUserShares = expectedShares;
        (uint256 userShares,) = ethMultiVault.getVaultStateForUserCurve(atomId, curveId, user);
        assertEq(userShares, expectedUserShares);

        // Case 2: Deposit enough to mint 1 additional share
        uint256 desiredNumberOfShares = 1;
        (, totalShares) = ethMultiVault.bondingCurveVaults(atomId, curveId);
        depositAmount = arithmeticSeriesCurveContract.calculateAssetsForDeposit(desiredNumberOfShares, totalShares);
        expectedShares = arithmeticSeriesCurveContract.convertToShares(depositAmount, 0, totalShares);
        actualShares = ethMultiVault.depositAtomCurve{value: depositAmount}(user, atomId, curveId);
        assertEq(actualShares, expectedShares);
        expectedUserShares += expectedShares;
        (userShares,) = ethMultiVault.getVaultStateForUserCurve(atomId, curveId, user);
        assertEq(userShares, expectedUserShares);

        // Case 3: Deposit enough to mint 5 additional shares
        desiredNumberOfShares = 5;
        (, totalShares) = ethMultiVault.bondingCurveVaults(atomId, curveId);
        depositAmount = arithmeticSeriesCurveContract.calculateAssetsForDeposit(desiredNumberOfShares, totalShares);
        expectedShares = arithmeticSeriesCurveContract.convertToShares(depositAmount, 0, totalShares);
        actualShares = ethMultiVault.depositAtomCurve{value: depositAmount}(user, atomId, curveId);
        assertEq(actualShares, expectedShares);
        expectedUserShares += expectedShares;
        (userShares,) = ethMultiVault.getVaultStateForUserCurve(atomId, curveId, user);
        assertEq(userShares, expectedUserShares);

        // Case 4: Deposit enough to mint randomSharesToMint additional shares
        desiredNumberOfShares = randomSharesToMint;
        (, totalShares) = ethMultiVault.bondingCurveVaults(atomId, curveId);
        depositAmount = arithmeticSeriesCurveContract.calculateAssetsForDeposit(desiredNumberOfShares, totalShares);
        expectedShares = arithmeticSeriesCurveContract.convertToShares(depositAmount, 0, totalShares);
        actualShares = ethMultiVault.depositAtomCurve{value: depositAmount}(user, atomId, curveId);
        assertEq(actualShares, expectedShares);
        expectedUserShares += expectedShares;
        (userShares,) = ethMultiVault.getVaultStateForUserCurve(atomId, curveId, user);
        assertEq(userShares, expectedUserShares);

        // Case 5: Redeem 1 share
        uint256 numberOfSharesToRedeem = 1 * arithmeticSeriesCurveContract.DECIMAL_PRECISION();
        (, totalShares) = ethMultiVault.bondingCurveVaults(atomId, curveId);
        uint256 expectedAssets = arithmeticSeriesCurveContract.convertToAssets(numberOfSharesToRedeem, totalShares, 0);
        uint256 actualAssets = ethMultiVault.redeemAtomCurve(numberOfSharesToRedeem, user, atomId, curveId);
        assertEq(actualAssets, expectedAssets);
        expectedUserShares -= numberOfSharesToRedeem;
        (userShares,) = ethMultiVault.getVaultStateForUserCurve(atomId, curveId, user);
        assertEq(userShares, expectedUserShares);

        // Case 6: Redeem 5 shares
        numberOfSharesToRedeem = 5 * arithmeticSeriesCurveContract.DECIMAL_PRECISION();
        (, totalShares) = ethMultiVault.bondingCurveVaults(atomId, curveId);
        expectedAssets = arithmeticSeriesCurveContract.convertToAssets(numberOfSharesToRedeem, totalShares, 0);
        actualAssets = ethMultiVault.redeemAtomCurve(numberOfSharesToRedeem, user, atomId, curveId);
        assertEq(actualAssets, expectedAssets);
        expectedUserShares -= numberOfSharesToRedeem;
        (userShares,) = ethMultiVault.getVaultStateForUserCurve(atomId, curveId, user);
        assertEq(userShares, expectedUserShares);

        // Case 7: Redeem randomSharesToRedeem shares
        uint256 maxRedeem = ethMultiVault.maxRedeemCurve(user, atomId, curveId);
        uint256 maxSharesToRedeem = maxRedeem / arithmeticSeriesCurveContract.DECIMAL_PRECISION();
        randomSharesToRedeem = bound(randomSharesToRedeem, 1, maxSharesToRedeem);

        numberOfSharesToRedeem = randomSharesToRedeem * arithmeticSeriesCurveContract.DECIMAL_PRECISION();
        (, totalShares) = ethMultiVault.bondingCurveVaults(atomId, curveId);
        expectedAssets = arithmeticSeriesCurveContract.convertToAssets(numberOfSharesToRedeem, totalShares, 0);
        actualAssets = ethMultiVault.redeemAtomCurve(numberOfSharesToRedeem, user, atomId, curveId);
        assertEq(actualAssets, expectedAssets);
        expectedUserShares -= numberOfSharesToRedeem;
        (userShares,) = ethMultiVault.getVaultStateForUserCurve(atomId, curveId, user);
        assertEq(userShares, expectedUserShares);

        vm.stopPrank();
    }
}
