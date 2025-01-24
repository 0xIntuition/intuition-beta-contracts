// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;
import { console2 as console } from "forge-std/console2.sol";
import { Test, Vm } from "forge-std/Test.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { IEthMultiVault } from "src/interfaces/IEthMultiVault.sol";
import { IPermit2 } from "src/interfaces/IPermit2.sol";
import { AtomWallet } from "src/AtomWallet.sol";
import { BondingCurveRegistry } from "src/BondingCurveRegistry.sol";
import { EthMultiVault } from "src/EthMultiVault.sol";
import { LinearCurve } from "src/LinearCurve.sol";
import { ProgressiveCurve } from "src/ProgressiveCurve.sol";

struct BaseTestActors {
    address deployer;
    address alice;
    address bob;
    address charlie;
    address dan;
    address ethan;
}

struct BaseTestConfig {
    IEthMultiVault.GeneralConfig general;
    IEthMultiVault.AtomConfig atom;
    IEthMultiVault.TripleConfig triple;
    IEthMultiVault.WalletConfig wallet;
    IEthMultiVault.BondingCurveConfig bondingCurve;
    IEthMultiVault.VaultFees vaultFees;
}

struct BaseTestState {
    EthMultiVault vault;
    AtomWallet atomWallet;
    UpgradeableBeacon atomWalletBeacon;
}

contract BaseTest is Test {
    BaseTestActors internal actors;

    BaseTestConfig internal config;

    BaseTestState internal state;

    function _setUp() public {
        actors = _actors();
        config = _config();
        state.vault = new EthMultiVault();
        state.vault.init(
            config.general,
            config.atom,
            config.triple,
            config.wallet,
            config.vaultFees,
            config.bondingCurve
        );
        vm.stopPrank();
    }

    function defaultActors() internal returns (BaseTestActors memory) {
        return
            BaseTestActors({
                deployer: createActor("deployer"),
                alice: createActor("alice"),
                bob: createActor("bob"),
                charlie: createActor("charlie"),
                dan: createActor("dan"),
                ethan: createActor("ethan")
            });
    }

    function createActor(string memory _name) internal returns (address actor) {
        actor = makeAddr(_name);
        vm.deal(actor, 10_000 ether);
    }

    function defaultConfig() internal returns (BaseTestConfig memory) {
        vm.startPrank(actors.deployer);

        BaseTestConfig memory c = BaseTestConfig({
            general: IEthMultiVault.GeneralConfig({
                admin: actors.deployer,
                protocolMultisig: address(0xbeef),
                feeDenominator: 10000,
                minDeposit: 0.0003 ether,
                minShare: 1e5,
                atomUriMaxLength: 250,
                decimalPrecision: 1e18,
                minDelay: 1 days
            }),
            atom: IEthMultiVault.AtomConfig({
                atomWalletInitialDepositAmount: 0.0001 ether,
                atomCreationProtocolFee: 0.0002 ether
            }),
            triple: IEthMultiVault.TripleConfig({
                tripleCreationProtocolFee: 0.0002 ether,
                atomDepositFractionOnTripleCreation: 0.0003 ether,
                atomDepositFractionForTriple: 1500
            }),
            wallet: IEthMultiVault.WalletConfig({
                permit2: IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)),
                entryPoint: address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789),
                atomWarden: address(0xbeef),
                atomWalletBeacon: address(
                    new UpgradeableBeacon(address(new AtomWallet()), actors.deployer)
                )
            }),
            bondingCurve: IEthMultiVault.BondingCurveConfig({
                registry: address(new BondingCurveRegistry()),
                defaultCurveId: 1
            }),
            vaultFees: IEthMultiVault.VaultFees({ entryFee: 500, exitFee: 500, protocolFee: 100 })
        });

        BondingCurveRegistry(c.bondingCurve.registry).initialize(actors.deployer);
        address linearCurve = address(new LinearCurve("Linear Curve"));
        console.log("Admin: %s", BondingCurveRegistry(c.bondingCurve.registry).admin());
        BondingCurveRegistry(c.bondingCurve.registry).addBondingCurve(linearCurve);
        address progressiveCurve = address(
            new ProgressiveCurve("Progressive Curve", 0.00007054e18)
        ); // Because minDeposit is 0.0003 ether
        BondingCurveRegistry(c.bondingCurve.registry).addBondingCurve(progressiveCurve);
        vm.stopPrank();

        return c;
    }

    function _actors() internal virtual returns (BaseTestActors memory) {
        return defaultActors();
    }

    function _config() internal virtual returns (BaseTestConfig memory) {
        return defaultConfig();
    }
}
