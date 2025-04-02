// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {console2 as console} from "forge-std/console2.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {AtomWallet} from "src/AtomWallet.sol";
import {BondingCurveRegistry} from "src/BondingCurveRegistry.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";
import {LinearCurve} from "src/LinearCurve.sol";
import {ProgressiveCurve} from "src/ProgressiveCurve.sol";
import {OffsetProgressiveCurve} from "src/OffsetProgressiveCurve.sol";

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
    using FixedPointMathLib for uint256;

    BaseTestActors internal actors;

    BaseTestConfig internal config;

    BaseTestState internal state;

    function setUp() public {
        actors = _actors();
        config = _config();

        // Deploy implementation
        EthMultiVault implementation = new EthMultiVault();

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                EthMultiVault.init.selector,
                config.general,
                config.atom,
                config.triple,
                config.wallet,
                config.vaultFees,
                config.bondingCurve
            )
        );

        // Cast proxy to EthMultiVault interface
        state.vault = EthMultiVault(payable(address(proxy)));

        vm.stopPrank();
    }

    function defaultActors() internal returns (BaseTestActors memory) {
        return BaseTestActors({
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
                totalAtomDepositsOnTripleCreation: 0.0003 ether,
                totalAtomDepositsForTriple: 1500
            }),
            wallet: IEthMultiVault.WalletConfig({
                permit2: IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)),
                entryPoint: address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789),
                atomWarden: address(0xbeef),
                atomWalletBeacon: address(new UpgradeableBeacon(address(new AtomWallet()), actors.deployer))
            }),
            bondingCurve: IEthMultiVault.BondingCurveConfig({
                registry: address(new BondingCurveRegistry(actors.deployer)),
                defaultCurveId: 1
            }),
            vaultFees: IEthMultiVault.VaultFees({entryFee: 500, exitFee: 500, protocolFee: 100})
        });

        address linearCurve = address(new LinearCurve("Linear Curve"));
        BondingCurveRegistry(c.bondingCurve.registry).addBondingCurve(linearCurve);

        // Testing for offset curve:
        // - 7e13 - 0 - 36%
        // - 7e13 - 10 - 36% initial dropoff

        // address progressiveCurve = address(
        //     new ProgressiveCurve("Progressive Curve", 0.00007054e18);
        // - default
        //   Slope: 0.00007054e18
        //   Alice Shares: 2.645751311e9
        //   Bob Shares: 3.17043765565655076e17
        //   Charlie Shares: 2.82335376863657827e17
        //
        // - 1/10
        //   Slope: 0.000007054e18
        //   Alice Shares: 8.888194417e9
        //   Bob Shares: 4.04623800546193655e17
        //   Charlie Shares: 3.08261900500235198e17
        //
        // - 1/100
        //   Slope: 0.0000007054e18
        //   Alice Shares: 2.826658805e10
        //   Bob Shares: 4.13268430959427379e17
        //   Charlie Shares: 3.16888290166311742e17
        //
        // - 1/10000
        //   Slope: 0.000000007054e18
        //   Alice Shares: 8.9437128755e10
        //   Bob Shares: 4.14132267880182129e17
        //   Charlie Shares: 3.17781355457602312e17

        address progressiveCurve = address(new ProgressiveCurve("Progressive Curve", 2));
        BondingCurveRegistry(c.bondingCurve.registry).addBondingCurve(progressiveCurve);

        address offsetCurve = address(new OffsetProgressiveCurve("Offset Curve", 2, 5e35));
        BondingCurveRegistry(c.bondingCurve.registry).addBondingCurve(offsetCurve);
        vm.stopPrank();

        return c;
    }

    function _actors() internal virtual returns (BaseTestActors memory) {
        return defaultActors();
    }

    function _config() internal virtual returns (BaseTestConfig memory) {
        return defaultConfig();
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                            Atoms & Triples                            │
    // ╰───────────────────────────────────────────────────────────────────────╯

    // ────────────────────────────── Creation ───────────────────────────

    function createTriple(address _who, uint256 _subjectId, uint256 _predicateId, uint256 _objectId)
        internal
        returns (uint256 tripleId)
    {
        require(state.vault.currentSharePrice(_subjectId) != 0, "subject already exists");
        require(state.vault.currentSharePrice(_predicateId) != 0, "prediacte already exists");
        require(state.vault.currentSharePrice(_objectId) != 0, "object already exists");

        vm.startPrank(_who);
        tripleId = state.vault.createTriple{value: state.vault.getTripleCost()}(_subjectId, _predicateId, _objectId);
        vm.stopPrank();
    }

    function createAtom(address _who, string memory _label) internal returns (uint256 atomId) {
        uint256 atomCost = state.vault.getAtomCost();

        vm.startPrank(_who);
        atomId = state.vault.createAtom{value: atomCost}(bytes(_label));
        vm.stopPrank();
    }

    // ────────────────────────────── Deposits ───────────────────────────

    function depositAtom(address _who, uint256 _atomId, uint256 _curveId, uint256 _amount)
        internal
        returns (uint256 shares)
    {
        vm.startPrank(_who);
        shares = state.vault.depositAtomCurve{value: _amount}(_who, _atomId, _curveId);
        vm.stopPrank();
    }

    function depositAtom(address _who, uint256 _atomId) internal returns (uint256 shares) {
        uint256 atomCost = state.vault.getAtomCost();
        uint256 curveId = 2;
        shares = depositAtom(_who, _atomId, curveId, atomCost);
    }

    // ───────────────────────────── Redemptions ─────────────────────────────

    function redeemAtom(address _who, uint256 _atomId, uint256 _curveId, uint256 _amount)
        internal
        returns (uint256 assets)
    {
        vm.startPrank(_who);
        assets = state.vault.redeemAtomCurve(_amount, _who, _atomId, _curveId);
        vm.stopPrank();
    }

    function redeemAtom(address _who, uint256 _atomId) internal returns (uint256 assets) {
        vm.startPrank(_who);
        uint256 curveId = 2;
        (uint256 shareBalance,) = state.vault.getVaultStateForUserCurve(_atomId, curveId, _who);
        assets = state.vault.redeemAtomCurve(shareBalance, _who, _atomId, curveId);
        vm.stopPrank();
    }

    // ────────────────────────────── Balances ───────────────────────────

    function vaultBalance(address _who, uint256 _vaultId, uint256 _curveId)
        internal
        view
        returns (uint256 shares, uint256 assets)
    {
        (shares, assets) = state.vault.getVaultStateForUserCurve(_vaultId, _curveId, _who);
    }

    function vaultBalance(address _who, uint256 _vaultId) internal view returns (uint256 shares, uint256 assets) {
        uint256 curveId = 2;
        (shares, assets) = vaultBalance(_who, _vaultId, curveId);
    }

    // ─────────────────────────────── Testing ───────────────────────────────

    function test_deposit_redeem_curve_single_actor() external {
        string memory atomString = "atom1";
        uint256 atomId = createAtom(actors.alice, atomString);

        uint256 aliceShares = depositAtom(actors.alice, atomId);

        assertGt(aliceShares, 0);

        uint256 aliceReturns = redeemAtom(actors.alice, atomId);

        assertGt(aliceReturns, 0);
    }

    function test_deposit_redeem_multiple_actors() external {
        // Have alice create the atom.
        string memory atomString = "atom1";
        uint256 atomId = createAtom(actors.deployer, atomString);

        uint256 aliceShares = depositAtom(actors.alice, atomId);
        uint256 aliceBalance = actors.alice.balance;
        uint256 bobShares = depositAtom(actors.bob, atomId);
        uint256 bobBalance = actors.bob.balance;
        uint256 charlieShares = depositAtom(actors.charlie, atomId);
        uint256 charlieBalance = actors.charlie.balance;

        console.log("Alice Shares: %e", aliceShares);
        console.log("Bob Shares: %e", (bobShares * 1e18).divWad(aliceShares * 1e18));
        console.log("Charlie Shares: %e", (charlieShares * 1e18).divWad(aliceShares * 1e18));

        console.log("Alice Shares Quantity: %e", aliceShares);
        console.log("Bob Shares Quantity: %e", bobShares);
        console.log("Charlie Shares Quantity: %e", charlieShares);

        if (aliceBalance > actors.alice.balance) {
            console.log("Alice Balance: %e", aliceBalance - actors.alice.balance);
        }
        if (bobBalance > actors.bob.balance) {
            console.log("Bob Balance Diff: %e", bobBalance - actors.bob.balance);
        }
        if (charlieBalance > actors.alice.balance) {
            console.log("Charlie Balance Diff: %e", actors.charlie.balance);
        }

        // Redeem all shares
        vm.prank(actors.alice);
        state.vault.redeemAtomCurve(aliceShares, actors.alice, atomId, 2); // assets for alice
        vm.prank(actors.bob);
        state.vault.redeemAtomCurve(bobShares, actors.bob, atomId, 2); // assets for bob
        vm.prank(actors.charlie);
        state.vault.redeemAtomCurve(charlieShares, actors.charlie, atomId, 2); // assets for charlie
    }
}
