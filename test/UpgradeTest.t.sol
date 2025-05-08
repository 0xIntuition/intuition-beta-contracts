// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Test} from "forge-std/Test.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {BondingCurveRegistry} from "src/BondingCurveRegistry.sol";
import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {LinearCurve} from "src/LinearCurve.sol";
import {ProgressiveCurve} from "src/ProgressiveCurve.sol";
import {OffsetProgressiveCurve} from "src/OffsetProgressiveCurve.sol";
import {AtomWallet} from "src/AtomWallet.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";

interface IOldEthMultiVault {
    function count() external view returns (uint256);
    function isTriple(uint256) external view returns (bool);
}

contract UpgradeTest is Test {
    /// @notice Constants
    uint256 public dealAmount = 1000 ether;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public admin = 0xa28d4AAcA48bE54824dA53a19b05121DE71Ef480;
    address public ethMultiVaultDeployedAddress = 0x430BbF52503Bd4801E51182f4cB9f8F534225DE5;
    uint256 public defaultBondingCurveId = 1;
    uint256 public progressiveCurveId = 2;
    bytes public exampleAtomData = bytes("exampleAtomData");

    IPermit2 permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)); // Permit2 on Base
    address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base
    address atomWarden = admin;

    /// @notice Deployed contracts
    EthMultiVault public ethMultiVault;
    BondingCurveRegistry public bondingCurveRegistry;
    LinearCurve public linearCurve;
    ProgressiveCurve public progressiveCurve;
    OffsetProgressiveCurve public offsetProgressiveCurve;
    AtomWallet atomWallet;
    UpgradeableBeacon atomWalletBeacon;

    /// @notice Variables for testing upgrade safety
    uint256 public oldCount;
    uint256 public exampleAtomId = 101;
    uint256 public exampleTripleId = 1000;

    function setUp() external {
        vm.createSelectFork("https://mainnet.base.org");

        // Deploy the BondingCurveRegistry contract
        bondingCurveRegistry = new BondingCurveRegistry(admin);

        // Get the deployed EthMultiVault contract
        ethMultiVault = EthMultiVault(payable(ethMultiVaultDeployedAddress));

        oldCount = IOldEthMultiVault(ethMultiVaultDeployedAddress).count();

        // Deploy the LinearCurve contract
        linearCurve = new LinearCurve("Linear Curve");

        // Deploy the ProgressiveCurve contract
        progressiveCurve = new ProgressiveCurve("Progressive Curve", 2);

        // Deploy the OffsetProgressiveCurve contract
        offsetProgressiveCurve = new OffsetProgressiveCurve("Offset Progressive Curve", 2, 5e35);

        // Add the LinearCurve to the BondingCurveRegistry
        vm.prank(admin);
        bondingCurveRegistry.addBondingCurve(address(linearCurve));

        // Add the ProgressiveCurve to the BondingCurveRegistry
        vm.prank(admin);
        bondingCurveRegistry.addBondingCurve(address(progressiveCurve));

        // Add the OffsetProgressiveCurve to the BondingCurveRegistry
        vm.prank(admin);
        bondingCurveRegistry.addBondingCurve(address(offsetProgressiveCurve));

        // Upgrade EthMultiVault to the latest version
        ProxyAdmin proxyAdmin = ProxyAdmin(0xc920E2F5eB6925faE85C69a98a2df6f56a7a245A);
        address newEthMultiVaultImplementation = address(new EthMultiVault());

        // Prepare the bonding curve configuration
        IEthMultiVault.BondingCurveConfig memory bondingCurveConfig =
            IEthMultiVault.BondingCurveConfig({registry: address(bondingCurveRegistry), defaultCurveId: 1});

        // Prepare initialization data for the upgrade
        bytes memory reinitData = abi.encodeWithSelector(EthMultiVault.reinitialize.selector, bondingCurveConfig);

        address proxyAdminOwner = proxyAdmin.owner();

        vm.prank(proxyAdminOwner);
        proxyAdmin.upgradeAndCall{value: 0}(
            ITransparentUpgradeableProxy(ethMultiVaultDeployedAddress), newEthMultiVaultImplementation, reinitData
        );

        // Deal some ether to test addresses
        vm.deal(alice, dealAmount);
        vm.deal(bob, dealAmount);
        vm.deal(admin, dealAmount);
    }

    function test_verifyStorageLayoutAfterUpgrade() external view {
        uint256 newCount = ethMultiVault.count();
        assertEq(oldCount, newCount);

        bool isTriple1 = ethMultiVault.isTriple(exampleAtomId);
        assertTrue(isTriple1 == false);

        bool isTriple2 = ethMultiVault.isTriple(exampleTripleId);
        assertTrue(isTriple2 == true);
    }

    function testFuzz_deposit_toExistingAtom(uint256 depositAmount) external {
        _assumeDepositAmountConstraints(depositAmount);

        vm.startPrank(alice);

        (uint256 sharesForReceiverBefore,) = ethMultiVault.getVaultStateForUser(exampleAtomId, alice);

        uint256 expectedSharesForReceiver = _getExpectedSharesForReceiver(depositAmount, exampleAtomId);

        uint256 protocolMultisigBalanceBefore = address(_getProtocolMultisig()).balance;

        uint256 mintedShares = ethMultiVault.depositAtom{value: depositAmount}(alice, exampleAtomId);

        (uint256 sharesForReceiverAfter,) = ethMultiVault.getVaultStateForUser(exampleAtomId, alice);

        uint256 protocolMultisigBalanceAfter = address(_getProtocolMultisig()).balance;

        assertEq(mintedShares, expectedSharesForReceiver);
        assertEq(sharesForReceiverAfter, sharesForReceiverBefore + expectedSharesForReceiver);
        assertEq(
            protocolMultisigBalanceAfter,
            protocolMultisigBalanceBefore + ethMultiVault.protocolFeeAmount(depositAmount, exampleAtomId)
        );

        vm.stopPrank();
    }

    function testFuzz_redeem_fromExistingAtom(uint256 redeemAmount) external {
        vm.startPrank(alice);

        ethMultiVault.depositAtom{value: 100 ether}(alice, exampleAtomId);

        (uint256 userSharesBeforeRedeem,) = ethMultiVault.getVaultStateForUser(exampleAtomId, alice);

        uint256 maxRedeem = ethMultiVault.maxRedeem(alice, exampleAtomId);

        vm.assume(redeemAmount > 0 && redeemAmount <= maxRedeem);

        uint256 assetsForReceiverBeforeFees = ethMultiVault.convertToAssets(redeemAmount, exampleAtomId);
        uint256 protocolFeeAmount = ethMultiVault.protocolFeeAmount(assetsForReceiverBeforeFees, exampleAtomId);

        uint256 protocolMultisigBalanceBefore = address(_getProtocolMultisig()).balance;

        uint256 userEthBalanceBeforeRedeem = address(alice).balance;

        uint256 assetsForReceiver = ethMultiVault.redeemAtom(redeemAmount, alice, exampleAtomId);

        uint256 protocolMultisigBalanceAfter = address(_getProtocolMultisig()).balance;

        uint256 userEthBalanceAfterRedeem = address(alice).balance;

        (uint256 userSharesAfterRedeem,) = ethMultiVault.getVaultStateForUser(exampleAtomId, alice);

        assertEq(userEthBalanceAfterRedeem, userEthBalanceBeforeRedeem + assetsForReceiver);
        assertEq(userSharesAfterRedeem, userSharesBeforeRedeem - redeemAmount);
        assertEq(protocolMultisigBalanceAfter, protocolMultisigBalanceBefore + protocolFeeAmount);

        vm.stopPrank();
    }

    function testFuzz_deposit_toExistingTriple(uint256 depositAmount) external {
        _assumeDepositAmountConstraints(depositAmount);

        vm.startPrank(alice);

        (uint256 sharesForReceiverBefore,) = ethMultiVault.getVaultStateForUser(exampleTripleId, alice);

        uint256 expectedSharesForReceiver = _getExpectedSharesForReceiver(depositAmount, exampleTripleId);

        uint256 protocolMultisigBalanceBefore = address(_getProtocolMultisig()).balance;

        uint256 mintedShares = ethMultiVault.depositTriple{value: depositAmount}(alice, exampleTripleId);

        uint256 protocolMultisigBalanceAfter = address(_getProtocolMultisig()).balance;

        (uint256 sharesForReceiverAfter,) = ethMultiVault.getVaultStateForUser(exampleTripleId, alice);

        assertEq(mintedShares, expectedSharesForReceiver);
        assertEq(sharesForReceiverAfter, sharesForReceiverBefore + expectedSharesForReceiver);
        assertEq(
            protocolMultisigBalanceAfter,
            protocolMultisigBalanceBefore + ethMultiVault.protocolFeeAmount(depositAmount, exampleTripleId)
        );

        vm.stopPrank();
    }

    function testFuzz_redeem_fromExistingTriple(uint256 redeemAmount) external {
        vm.startPrank(alice);

        ethMultiVault.depositTriple{value: 100 ether}(alice, exampleTripleId);

        (uint256 userSharesBeforeRedeem,) = ethMultiVault.getVaultStateForUser(exampleTripleId, alice);

        uint256 maxRedeem = ethMultiVault.maxRedeem(alice, exampleTripleId);

        vm.assume(redeemAmount > 0 && redeemAmount <= maxRedeem);

        uint256 userEthBalanceBeforeRedeem = address(alice).balance;

        uint256 assetsForReceiverBeforeFees = ethMultiVault.convertToAssets(redeemAmount, exampleTripleId);
        uint256 protocolFeeAmount = ethMultiVault.protocolFeeAmount(assetsForReceiverBeforeFees, exampleTripleId);

        uint256 protocolMultisigBalanceBefore = address(_getProtocolMultisig()).balance;

        uint256 assetsForReceiver = ethMultiVault.redeemTriple(redeemAmount, alice, exampleTripleId);

        uint256 protocolMultisigBalanceAfter = address(_getProtocolMultisig()).balance;

        uint256 userEthBalanceAfterRedeem = address(alice).balance;

        (uint256 userSharesAfterRedeem,) = ethMultiVault.getVaultStateForUser(exampleTripleId, alice);

        assertEq(userEthBalanceAfterRedeem, userEthBalanceBeforeRedeem + assetsForReceiver);
        assertEq(userSharesAfterRedeem, userSharesBeforeRedeem - redeemAmount);
        assertEq(protocolMultisigBalanceAfter, protocolMultisigBalanceBefore + protocolFeeAmount);

        vm.stopPrank();
    }

    function testFuzz_createAtom(uint256 depositAmount) external {
        vm.assume(depositAmount >= ethMultiVault.getAtomCost() && depositAmount <= dealAmount);

        vm.startPrank(alice);

        uint256 expectedNewAtomId = ethMultiVault.count() + 1;
        uint256 expectedGhostShares = _getGhostSharesAmount();
        uint256 expectedAtomWalletShares = _getAtomWalletInitialDepositAmount();
        address expectedAtomWalletAddress = ethMultiVault.computeAtomWalletAddr(expectedNewAtomId);

        uint256 atomCost = ethMultiVault.getAtomCost();
        uint256 userDepositAfterAtomCost = depositAmount - atomCost;
        uint256 expectedSharesForUser =
            userDepositAfterAtomCost - ethMultiVault.protocolFeeAmount(userDepositAfterAtomCost, expectedNewAtomId);

        uint256 protocolMultisigBalanceBefore = address(_getProtocolMultisig()).balance;

        uint256 atomId = ethMultiVault.createAtom{value: depositAmount}(exampleAtomData);

        uint256 protocolMultisigBalanceAfter = address(_getProtocolMultisig()).balance;

        (uint256 ghostShares,) = ethMultiVault.getVaultStateForUser(expectedNewAtomId, _getAdmin());
        (uint256 atomWalletShares,) = ethMultiVault.getVaultStateForUser(expectedNewAtomId, expectedAtomWalletAddress);
        (uint256 userShares,) = ethMultiVault.getVaultStateForUser(expectedNewAtomId, alice);

        assertEq(atomId, expectedNewAtomId);
        assertEq(ghostShares, expectedGhostShares);
        assertEq(atomWalletShares, expectedAtomWalletShares);
        assertEq(userShares, expectedSharesForUser);
        assertEq(
            protocolMultisigBalanceAfter,
            protocolMultisigBalanceBefore + _getAtomCreationProtocolFee()
                + ethMultiVault.protocolFeeAmount(userDepositAfterAtomCost, atomId)
        );

        address atomWalletAddress = ethMultiVault.deployAtomWallet(atomId);

        assertEq(atomWalletAddress, expectedAtomWalletAddress);

        vm.stopPrank();
    }

    function testFuzz_deposit_toNewAtom(uint256 depositAmount) external {
        vm.prank(bob);
        uint256 atomId = ethMultiVault.createAtom{value: ethMultiVault.getAtomCost()}(exampleAtomData);

        _assumeDepositAmountConstraints(depositAmount);

        vm.startPrank(alice);

        (uint256 sharesForReceiverBefore,) = ethMultiVault.getVaultStateForUser(atomId, alice);

        uint256 expectedSharesForReceiver = _getExpectedSharesForReceiver(depositAmount, atomId);

        uint256 protocolMultisigBalanceBefore = address(_getProtocolMultisig()).balance;

        uint256 mintedShares = ethMultiVault.depositAtom{value: depositAmount}(alice, atomId);

        uint256 protocolMultisigBalanceAfter = address(_getProtocolMultisig()).balance;

        (uint256 sharesForReceiverAfter,) = ethMultiVault.getVaultStateForUser(atomId, alice);

        assertEq(mintedShares, expectedSharesForReceiver);
        assertEq(sharesForReceiverAfter, sharesForReceiverBefore + expectedSharesForReceiver);
        assertEq(
            protocolMultisigBalanceAfter,
            protocolMultisigBalanceBefore + ethMultiVault.protocolFeeAmount(depositAmount, atomId)
        );

        vm.stopPrank();
    }

    function testFuzz_redeem_fromNewAtom(uint256 redeemAmount) external {
        vm.prank(bob);
        uint256 atomId = ethMultiVault.createAtom{value: ethMultiVault.getAtomCost()}(exampleAtomData);

        vm.startPrank(alice);

        ethMultiVault.depositAtom{value: 100 ether}(alice, atomId);

        (uint256 userSharesBeforeRedeem,) = ethMultiVault.getVaultStateForUser(atomId, alice);

        uint256 maxRedeem = ethMultiVault.maxRedeem(alice, atomId);

        vm.assume(redeemAmount > 0 && redeemAmount <= maxRedeem);

        uint256 userEthBalanceBeforeRedeem = address(alice).balance;

        uint256 assetsForReceiverBeforeFees = ethMultiVault.convertToAssets(redeemAmount, atomId);
        uint256 protocolFeeAmount = ethMultiVault.protocolFeeAmount(assetsForReceiverBeforeFees, atomId);

        uint256 protocolMultisigBalanceBefore = address(_getProtocolMultisig()).balance;

        uint256 assetsForReceiver = ethMultiVault.redeemAtom(redeemAmount, alice, atomId);

        uint256 protocolMultisigBalanceAfter = address(_getProtocolMultisig()).balance;

        uint256 userEthBalanceAfterRedeem = address(alice).balance;

        (uint256 userSharesAfterRedeem,) = ethMultiVault.getVaultStateForUser(atomId, alice);

        assertEq(userEthBalanceAfterRedeem, userEthBalanceBeforeRedeem + assetsForReceiver);
        assertEq(userSharesAfterRedeem, userSharesBeforeRedeem - redeemAmount);
        assertEq(protocolMultisigBalanceAfter, protocolMultisigBalanceBefore + protocolFeeAmount);

        vm.stopPrank();
    }

    function testFuzz_createTriple(uint256 depositAmount) external {
        vm.startPrank(bob);
        uint256 atomId = ethMultiVault.createAtom{value: ethMultiVault.getAtomCost()}(exampleAtomData);

        vm.assume(depositAmount >= ethMultiVault.getTripleCost() && depositAmount <= dealAmount);

        vm.startPrank(alice);

        uint256 expectedNewTripleId = atomId + 1;
        uint256 expectedGhostShares = _getGhostSharesAmount();

        uint256 tripleCost = ethMultiVault.getAtomCost();
        uint256 userDepositAfterTripleCost = depositAmount - tripleCost;
        uint256 userDepositAfterProtocolFees = userDepositAfterTripleCost
            - ethMultiVault.protocolFeeAmount(userDepositAfterTripleCost, expectedNewTripleId);
        uint256 expectedSharesForUser = userDepositAfterProtocolFees
            - ethMultiVault.atomDepositsAmount(userDepositAfterProtocolFees, exampleTripleId); // we use the existing triple ID because the new triple ID is not yet created

        uint256 protocolMultisigBalanceBefore = address(_getProtocolMultisig()).balance;

        uint256 tripleId = ethMultiVault.createTriple{value: depositAmount}(1, 2, atomId);

        uint256 protocolMultisigBalanceAfter = address(_getProtocolMultisig()).balance;

        (uint256 ghostSharesForPositiveVault,) = ethMultiVault.getVaultStateForUser(expectedNewTripleId, _getAdmin());
        (uint256 userShares,) = ethMultiVault.getVaultStateForUser(expectedNewTripleId, alice);

        uint256 counterTripleId = ethMultiVault.getCounterIdFromTriple(tripleId);

        (uint256 ghostSharesForCounterVault,) = ethMultiVault.getVaultStateForUser(counterTripleId, _getAdmin());

        assertEq(tripleId, expectedNewTripleId);
        assertEq(ghostSharesForPositiveVault, expectedGhostShares);
        assertEq(ghostSharesForCounterVault, expectedGhostShares);
        // due to rounding errors because of the calculations inside `createTriple`, there can be a small discrepancy between the expected and actual user shares,
        // but this should generally be within the ghost shares amount (0.000000000001 ETH)
        assertApproxEqAbs(userShares, expectedSharesForUser, _getGhostSharesAmount());
        assertApproxEqAbs(
            protocolMultisigBalanceAfter,
            protocolMultisigBalanceBefore + _getTripleCreationProtocolFee()
                + ethMultiVault.protocolFeeAmount(userDepositAfterTripleCost, tripleId),
            _getGhostSharesAmount()
        );

        vm.stopPrank();
    }

    function testFuzz_deposit_toNewTriple(uint256 depositAmount) external {
        vm.startPrank(bob);

        uint256 atomId = ethMultiVault.createAtom{value: ethMultiVault.getAtomCost()}(exampleAtomData);
        uint256 tripleId = ethMultiVault.createTriple{value: ethMultiVault.getTripleCost()}(1, 2, atomId);

        vm.stopPrank();

        _assumeDepositAmountConstraints(depositAmount);

        vm.startPrank(alice);

        (uint256 sharesForReceiverBefore,) = ethMultiVault.getVaultStateForUser(tripleId, alice);

        uint256 expectedSharesForReceiver = _getExpectedSharesForReceiver(depositAmount, tripleId);

        uint256 protocolMultisigBalanceBefore = address(_getProtocolMultisig()).balance;

        uint256 mintedShares = ethMultiVault.depositTriple{value: depositAmount}(alice, tripleId);

        uint256 protocolMultisigBalanceAfter = address(_getProtocolMultisig()).balance;

        (uint256 sharesForReceiverAfter,) = ethMultiVault.getVaultStateForUser(tripleId, alice);

        assertEq(mintedShares, expectedSharesForReceiver);
        assertEq(sharesForReceiverAfter, sharesForReceiverBefore + expectedSharesForReceiver);
        assertEq(
            protocolMultisigBalanceAfter,
            protocolMultisigBalanceBefore + ethMultiVault.protocolFeeAmount(depositAmount, tripleId)
        );

        vm.stopPrank();
    }

    function testFuzz_redeem_fromNewTriple(uint256 redeemAmount) external {
        vm.startPrank(bob);

        uint256 atomId = ethMultiVault.createAtom{value: ethMultiVault.getAtomCost()}(exampleAtomData);
        uint256 tripleId = ethMultiVault.createTriple{value: ethMultiVault.getTripleCost()}(1, 2, atomId);

        vm.stopPrank();

        vm.startPrank(alice);

        ethMultiVault.depositTriple{value: 100 ether}(alice, tripleId);

        (uint256 userSharesBeforeRedeem,) = ethMultiVault.getVaultStateForUser(tripleId, alice);

        uint256 maxRedeem = ethMultiVault.maxRedeem(alice, tripleId);

        vm.assume(redeemAmount > 0 && redeemAmount <= maxRedeem);

        uint256 userEthBalanceBeforeRedeem = address(alice).balance;

        uint256 assetsForReceiverBeforeFees = ethMultiVault.convertToAssets(redeemAmount, tripleId);
        uint256 protocolFeeAmount = ethMultiVault.protocolFeeAmount(assetsForReceiverBeforeFees, tripleId);

        uint256 protocolMultisigBalanceBefore = address(_getProtocolMultisig()).balance;

        uint256 assetsForReceiver = ethMultiVault.redeemTriple(redeemAmount, alice, tripleId);

        uint256 protocolMultisigBalanceAfter = address(_getProtocolMultisig()).balance;

        uint256 userEthBalanceAfterRedeem = address(alice).balance;

        (uint256 userSharesAfterRedeem,) = ethMultiVault.getVaultStateForUser(tripleId, alice);

        assertEq(userEthBalanceAfterRedeem, userEthBalanceBeforeRedeem + assetsForReceiver);
        assertEq(userSharesAfterRedeem, userSharesBeforeRedeem - redeemAmount);
        assertEq(protocolMultisigBalanceAfter, protocolMultisigBalanceBefore + protocolFeeAmount);

        vm.stopPrank();
    }

    function testFuzz_depositCurve_toNewAtom_progressiveCurve(uint256 depositAmount) external {
        vm.skip(true); // The slope parameter for ProgressiveCurve is based on the assumption that minDeposit is 0.0003 ETH,
        // but that was changed in the deployed contract that's live on Base mainnet. This creates a need to create a minDeposit
        // function in the BaseCurve contract, which will be addressed in a subsequent PR.
        vm.prank(bob);

        uint256 atomId = ethMultiVault.createAtom{value: ethMultiVault.getAtomCost()}(exampleAtomData);

        _assumeDepositAmountConstraints(depositAmount);

        vm.startPrank(alice);

        uint256 expectedGhostShares = _getGhostSharesAmount();
        uint256 depositAmountAfterGhostShares = depositAmount - expectedGhostShares;

        (uint256 sharesForReceiverBefore,) = ethMultiVault.getVaultStateForUserCurve(atomId, progressiveCurveId, alice);

        uint256 expectedSharesForReceiver =
            _getExpectedSharesForReceiverCurve(depositAmountAfterGhostShares, atomId, progressiveCurveId);

        uint256 protocolMultisigBalanceBefore = address(_getProtocolMultisig()).balance;

        uint256 mintedShares = ethMultiVault.depositAtomCurve{value: depositAmount}(alice, atomId, progressiveCurveId);

        uint256 protocolMultisigBalanceAfter = address(_getProtocolMultisig()).balance;

        (uint256 ghostShares,) = ethMultiVault.getVaultStateForUserCurve(atomId, progressiveCurveId, _getAdmin());
        (uint256 sharesForReceiverAfter,) = ethMultiVault.getVaultStateForUserCurve(atomId, progressiveCurveId, alice);

        assertEq(ghostShares, expectedGhostShares);
        assertEq(mintedShares, expectedSharesForReceiver);
        assertEq(sharesForReceiverAfter, sharesForReceiverBefore + expectedSharesForReceiver);
        assertEq(
            protocolMultisigBalanceAfter,
            protocolMultisigBalanceBefore + ethMultiVault.protocolFeeAmount(depositAmountAfterGhostShares, atomId)
        );

        vm.stopPrank();
    }

    function testFuzz_redeemCurve_fromNewAtom_progressiveCurve(uint256 redeemAmount) external {
        vm.prank(bob);
        uint256 atomId = ethMultiVault.createAtom{value: ethMultiVault.getAtomCost()}(exampleAtomData);

        vm.startPrank(alice);

        ethMultiVault.depositAtomCurve{value: 100 ether}(alice, atomId, progressiveCurveId);

        (uint256 userSharesBeforeRedeem,) = ethMultiVault.getVaultStateForUserCurve(atomId, progressiveCurveId, alice);

        uint256 maxRedeem = ethMultiVault.maxRedeemCurve(alice, atomId, progressiveCurveId);

        vm.assume(redeemAmount > 0 && redeemAmount <= maxRedeem);

        uint256 userEthBalanceBeforeRedeem = address(alice).balance;

        uint256 assetsForReceiverBeforeFees =
            ethMultiVault.convertToAssetsCurve(redeemAmount, atomId, progressiveCurveId);
        uint256 protocolFeeAmount = ethMultiVault.protocolFeeAmount(assetsForReceiverBeforeFees, atomId);

        uint256 protocolMultisigBalanceBefore = address(_getProtocolMultisig()).balance;

        uint256 assetsForReceiver = ethMultiVault.redeemAtomCurve(redeemAmount, alice, atomId, progressiveCurveId);

        uint256 protocolMultisigBalanceAfter = address(_getProtocolMultisig()).balance;

        uint256 userEthBalanceAfterRedeem = address(alice).balance;

        (uint256 userSharesAfterRedeem,) = ethMultiVault.getVaultStateForUserCurve(atomId, progressiveCurveId, alice);

        assertEq(userEthBalanceAfterRedeem, userEthBalanceBeforeRedeem + assetsForReceiver);
        assertEq(userSharesAfterRedeem, userSharesBeforeRedeem - redeemAmount);
        assertEq(protocolMultisigBalanceAfter, protocolMultisigBalanceBefore + protocolFeeAmount);

        vm.stopPrank();
    }

    function testFuzz_depositCurve_toNewTriple_progressiveCurve(uint256 depositAmount) external {
        vm.skip(true); // Skipped for the same reasons like the testFuzz_depositCurve_toNewAtom_progressiveCurve test
        vm.startPrank(bob);

        uint256 atomId = ethMultiVault.createAtom{value: ethMultiVault.getAtomCost()}(exampleAtomData);
        uint256 tripleId = ethMultiVault.createTriple{value: ethMultiVault.getTripleCost()}(1, 2, atomId);

        vm.stopPrank();

        _assumeDepositAmountConstraints(depositAmount);

        vm.startPrank(alice);

        uint256 expectedGhostShares = _getGhostSharesAmount();
        uint256 depositAmountAfterGhostShares = depositAmount - (expectedGhostShares * 2); // ghost shares are minted for both the positive and counter vaults

        (uint256 sharesForReceiverBefore,) =
            ethMultiVault.getVaultStateForUserCurve(tripleId, progressiveCurveId, alice);

        uint256 expectedSharesForReceiver =
            _getExpectedSharesForReceiverCurve(depositAmountAfterGhostShares, tripleId, progressiveCurveId);

        uint256 protocolMultisigBalanceBefore = address(_getProtocolMultisig()).balance;

        uint256 mintedShares =
            ethMultiVault.depositTripleCurve{value: depositAmount}(alice, tripleId, progressiveCurveId);

        uint256 protocolMultisigBalanceAfter = address(_getProtocolMultisig()).balance;

        (uint256 ghostSharesForPositiveVault,) =
            ethMultiVault.getVaultStateForUserCurve(tripleId, progressiveCurveId, _getAdmin());
        (uint256 ghostSharesForCounterVault,) = ethMultiVault.getVaultStateForUserCurve(
            ethMultiVault.getCounterIdFromTriple(tripleId), progressiveCurveId, _getAdmin()
        );
        (uint256 sharesForReceiverAfter,) = ethMultiVault.getVaultStateForUserCurve(tripleId, progressiveCurveId, alice);

        assertEq(ghostSharesForPositiveVault, expectedGhostShares);
        assertEq(ghostSharesForCounterVault, expectedGhostShares);
        assertEq(mintedShares, expectedSharesForReceiver);
        assertEq(sharesForReceiverAfter, sharesForReceiverBefore + expectedSharesForReceiver);
        assertEq(
            protocolMultisigBalanceAfter,
            protocolMultisigBalanceBefore + ethMultiVault.protocolFeeAmount(depositAmountAfterGhostShares, tripleId)
        );

        vm.stopPrank();
    }

    function testFuzz_redeemCurve_fromNewTriple_progressiveCurve(uint256 redeemAmount) external {
        vm.startPrank(bob);

        uint256 atomId = ethMultiVault.createAtom{value: ethMultiVault.getAtomCost()}(exampleAtomData);
        uint256 tripleId = ethMultiVault.createTriple{value: ethMultiVault.getTripleCost()}(1, 2, atomId);

        vm.stopPrank();

        vm.startPrank(alice);

        ethMultiVault.depositTripleCurve{value: 100 ether}(alice, tripleId, progressiveCurveId);

        (uint256 userSharesBeforeRedeem,) = ethMultiVault.getVaultStateForUserCurve(tripleId, progressiveCurveId, alice);

        uint256 maxRedeem = ethMultiVault.maxRedeemCurve(alice, tripleId, progressiveCurveId);

        vm.assume(redeemAmount > 0 && redeemAmount <= maxRedeem);

        uint256 userEthBalanceBeforeRedeem = address(alice).balance;

        uint256 assetsForReceiverBeforeFees =
            ethMultiVault.convertToAssetsCurve(redeemAmount, tripleId, progressiveCurveId);
        uint256 protocolFeeAmount = ethMultiVault.protocolFeeAmount(assetsForReceiverBeforeFees, tripleId);

        uint256 protocolMultisigBalanceBefore = address(_getProtocolMultisig()).balance;

        uint256 assetsForReceiver = ethMultiVault.redeemTripleCurve(redeemAmount, alice, tripleId, progressiveCurveId);

        uint256 protocolMultisigBalanceAfter = address(_getProtocolMultisig()).balance;

        uint256 userEthBalanceAfterRedeem = address(alice).balance;

        (uint256 userSharesAfterRedeem,) = ethMultiVault.getVaultStateForUserCurve(tripleId, progressiveCurveId, alice);

        assertEq(userEthBalanceAfterRedeem, userEthBalanceBeforeRedeem + assetsForReceiver);
        assertEq(userSharesAfterRedeem, userSharesBeforeRedeem - redeemAmount);
        assertEq(protocolMultisigBalanceAfter, protocolMultisigBalanceBefore + protocolFeeAmount);

        vm.stopPrank();
    }

    /// @notice Helper functions
    function _getExpectedSharesForReceiver(uint256 depositAmount, uint256 termId)
        internal
        view
        returns (uint256 expectedSharesForReceiver)
    {
        uint256 depositAmountAfterProtocolFees = depositAmount - ethMultiVault.protocolFeeAmount(depositAmount, termId);

        // Handle atom deposits for triple vaults
        uint256 atomDeposits = ethMultiVault.atomDepositsAmount(depositAmountAfterProtocolFees, termId);
        uint256 userAssetsAfterAtomDeposits = depositAmountAfterProtocolFees - atomDeposits;

        // Handle entry fees
        uint256 entryFee;
        (, uint256 totalShares) = ethMultiVault.vaults(termId);
        if (totalShares == _getGhostSharesAmount()) {
            entryFee = 0;
        } else {
            entryFee = ethMultiVault.entryFeeAmount(userAssetsAfterAtomDeposits, termId);
        }

        // Calculate final assets after all fees
        uint256 userAssetsAfterTotalFees = userAssetsAfterAtomDeposits - entryFee;

        // Convert to shares
        expectedSharesForReceiver = ethMultiVault.convertToShares(userAssetsAfterTotalFees, termId);
    }

    function _getAdmin() internal view returns (address adminAddress) {
        (adminAddress,,,,,,,) = ethMultiVault.generalConfig();
    }

    function _getProtocolMultisig() internal view returns (address protocolMultisig) {
        (, protocolMultisig,,,,,,) = ethMultiVault.generalConfig();
    }

    function _getMinDepositAmount() internal view returns (uint256 minDeposit) {
        (,,, minDeposit,,,,) = ethMultiVault.generalConfig();
    }

    function _getGhostSharesAmount() internal view returns (uint256 ghostSharesAmount) {
        (,,,, ghostSharesAmount,,,) = ethMultiVault.generalConfig();
    }

    function _getAtomWalletInitialDepositAmount() internal view returns (uint256 atomWalletInitialDepositAmount) {
        (atomWalletInitialDepositAmount,) = ethMultiVault.atomConfig();
    }

    function _getAtomCreationProtocolFee() internal view returns (uint256 atomCreationProtocolFee) {
        (, atomCreationProtocolFee) = ethMultiVault.atomConfig();
    }

    function _getTripleCreationProtocolFee() internal view returns (uint256 tripleCreationProtocolFee) {
        (tripleCreationProtocolFee,,) = ethMultiVault.tripleConfig();
    }

    function _assumeDepositAmountConstraints(uint256 depositAmount) internal view {
        vm.assume(depositAmount >= _getMinDepositAmount() && depositAmount <= dealAmount);
    }

    function _getExpectedSharesForReceiverCurve(uint256 depositAmount, uint256 termId, uint256 curveId)
        internal
        view
        returns (uint256 expectedSharesForReceiver)
    {
        uint256 depositAmountAfterProtocolFees = depositAmount - ethMultiVault.protocolFeeAmount(depositAmount, termId);

        (,, expectedSharesForReceiver,) =
            ethMultiVault.getDepositSharesAndFeesCurve(depositAmountAfterProtocolFees, termId, curveId);
    }
}
