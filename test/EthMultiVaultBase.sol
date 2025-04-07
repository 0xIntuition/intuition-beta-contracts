// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {AtomWallet} from "src/AtomWallet.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";

import {BondingCurveRegistry} from "src/BondingCurveRegistry.sol";
import {ProgressiveCurve} from "src/ProgressiveCurve.sol";
import {LinearCurve} from "src/LinearCurve.sol";
import {OffsetProgressiveCurve} from "src/OffsetProgressiveCurve.sol";
contract EthMultiVaultBase is Test {
    // msg.value - atomCreationProtocolFee - protocolFee

    /// @notice constants
    // initial eth amounts
    uint256 initialEth = 1000 ether;

    /// @notice dummy addresses for testing
    uint256 constant PK_BOB = 111; // priv key for REVM to consume
    uint256 constant PK_ALICE = 222;
    uint256 constant PK_RICH = 333;
    address immutable bob = vm.addr(PK_BOB);
    address immutable alice = vm.addr(PK_ALICE);
    address immutable rich = vm.addr(PK_RICH);

    /// @notice core contracts
    EthMultiVault ethMultiVaultImpl;
    EthMultiVault ethMultiVault;
    AtomWallet atomWallet;
    UpgradeableBeacon atomWalletBeacon;
    ProxyAdmin proxyAdmin;

    /// @notice set up test environment
    // usage in other test contracts that extend this one:
    // function setUp() external { _setUp(); [add in extra changes that extend the base environment here] }
    // _setUp() avoids using super.setUp() cuz I lazy and it's just as readable :)
    function _setUp() public {
        // deploy AtomWallet implementation contract
        atomWallet = new AtomWallet();

        // deploy AtomWalletBeacon pointing to the AtomWallet implementation contract
        atomWalletBeacon = new UpgradeableBeacon(address(atomWallet), msg.sender);

        // Define the configuration objects
        IEthMultiVault.GeneralConfig memory generalConfig = IEthMultiVault.GeneralConfig({
            admin: msg.sender,
            protocolMultisig: address(0xbeef),
            feeDenominator: 10000,
            minDeposit: 0.0003 ether,
            minShare: 1e5,
            atomUriMaxLength: 250,
            decimalPrecision: 1e18,
            minDelay: 1 days
        });

        IEthMultiVault.AtomConfig memory atomConfig = IEthMultiVault.AtomConfig({
            atomWalletInitialDepositAmount: 0.0001 ether,
            atomCreationProtocolFee: 0.0002 ether
        });

        IEthMultiVault.TripleConfig memory tripleConfig = IEthMultiVault.TripleConfig({
            tripleCreationProtocolFee: 0.0002 ether,
            totalAtomDepositsOnTripleCreation: 0.0003 ether,
            atomDepositFractionForTriple: 1500
        });

        IEthMultiVault.WalletConfig memory walletConfig = IEthMultiVault.WalletConfig({
            permit2: IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)),
            entryPoint: address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789),
            atomWarden: address(0xbeef),
            atomWalletBeacon: address(atomWalletBeacon)
        });

        IEthMultiVault.VaultFees memory vaultFees =
            IEthMultiVault.VaultFees({entryFee: 500, exitFee: 500, protocolFee: 100});

        address bondingCurveRegistry = address(new BondingCurveRegistry(address(this)));

        address linearCurve = address(new LinearCurve("Linear Curve"));
        BondingCurveRegistry(bondingCurveRegistry).addBondingCurve(linearCurve);
        address progressiveCurve = address(new ProgressiveCurve("Progressive Curve", 1e16));
        BondingCurveRegistry(bondingCurveRegistry).addBondingCurve(progressiveCurve);
        address offsetProgressiveCurve = address(new OffsetProgressiveCurve("Offset Progressive Curve", 1e16, 1e28));
        BondingCurveRegistry(bondingCurveRegistry).addBondingCurve(offsetProgressiveCurve);

        IEthMultiVault.BondingCurveConfig memory bondingCurveConfig =
            IEthMultiVault.BondingCurveConfig({registry: bondingCurveRegistry, defaultCurveId: 1});

        // Deploy implementation
        ethMultiVaultImpl = new EthMultiVault();

        // Deploy proxy admin
        proxyAdmin = new ProxyAdmin(msg.sender);

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            EthMultiVault.init.selector,
            generalConfig,
            atomConfig,
            tripleConfig,
            walletConfig,
            vaultFees,
            bondingCurveConfig
        );

        // Deploy proxy
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(ethMultiVaultImpl), address(proxyAdmin), initData);

        // Set up the proxy instance for testing
        ethMultiVault = EthMultiVault(payable(address(proxy)));

        // deal ether for use in tests that call with value
        vm.deal(address(this), initialEth);
        vm.deal(bob, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(rich, 20000 ether);
    }

    function getAtomCost() public view virtual returns (uint256 atomCost) {
        atomCost = ethMultiVault.getAtomCost();
    }

    function getTripleCost() public view virtual returns (uint256 tripleCost) {
        tripleCost = ethMultiVault.getTripleCost();
    }

    function vaultTotalAssets(uint256 id) public view returns (uint256 totalAssets) {
        (totalAssets,) = ethMultiVault.vaults(id);
    }

    function vaultTotalShares(uint256 id) public view returns (uint256 totalShares) {
        (, totalShares) = ethMultiVault.vaults(id);
    }

    function getCounterIdFromTriple(uint256 id) public view returns (uint256 counterId) {
        counterId = ethMultiVault.getCounterIdFromTriple(id);
    }

    function vaultBalanceOf(uint256 id, address account) public view returns (uint256 shares) {
        (shares,) = ethMultiVault.getVaultStateForUser(id, account);
    }

    function getVaultStateForUser(uint256 id, address account) public view returns (uint256 shares, uint256 assets) {
        (shares, assets) = ethMultiVault.getVaultStateForUser(id, account);
    }

    function entryFeeAmount(uint256 assets, uint256 id) public view returns (uint256 feeAmount) {
        return ethMultiVault.entryFeeAmount(assets, id);
    }

    function previewDeposit(uint256 assets, uint256 id) public view returns (uint256 feeAmount) {
        return ethMultiVault.previewDeposit(assets, id);
    }

    function previewRedeem(uint256 shares, uint256 id) public view returns (uint256) {
        return ethMultiVault.previewRedeem(shares, id);
    }

    function atomDepositsAmount(uint256 assets, uint256 id) public view returns (uint256) {
        return ethMultiVault.atomDepositsAmount(assets, id);
    }

    function getDepositSharesAndFees(uint256 assets, uint256 id)
        public
        view
        returns (uint256, uint256, uint256, uint256)
    {
        return ethMultiVault.getDepositSharesAndFees(assets, id);
    }

    function protocolFeeAmount(uint256 assets, uint256 id) public view returns (uint256) {
        return ethMultiVault.protocolFeeAmount(assets, id);
    }

    function getRedeemFees(uint256 shares, uint256 id) public view returns (uint256, uint256, uint256, uint256) {
        (uint256 totalUserAssets, uint256 assetsForReceiver, uint256 protocolFee, uint256 exitFee) =
            ethMultiVault.getRedeemAssetsAndFees(shares, id);
        return (totalUserAssets, assetsForReceiver, protocolFee, exitFee);
    }

    function currentSharePrice(uint256 id) public view returns (uint256) {
        return ethMultiVault.currentSharePrice(id);
    }

    function currentSharePriceCurve(uint256 id, uint256 curveId) public view returns (uint256) {
        return ethMultiVault.currentSharePriceCurve(id, curveId);
    }

    function getApproval(address receiver, address sender) public view returns (bool) {
        return ethMultiVault.approvals(receiver, sender) > 0;
    }

    //////// Generate Memes ////////

    function _generateMemes() internal {
        // create memes
        bytes[] memory batchCreateMemeNames = new bytes[](60);
        batchCreateMemeNames[0] = "abcd";
        batchCreateMemeNames[1] = "efgh";
        batchCreateMemeNames[2] = "ijkl";
        batchCreateMemeNames[3] = "mnop";
        batchCreateMemeNames[4] = "qrst";
        batchCreateMemeNames[5] = "uvwx";
        batchCreateMemeNames[6] = "yzab";
        batchCreateMemeNames[7] = "cdef";
        batchCreateMemeNames[8] = "ghij";
        batchCreateMemeNames[9] = "klmn";
        batchCreateMemeNames[10] = "opqr";
        batchCreateMemeNames[11] = "stuv";
        batchCreateMemeNames[12] = "wxyz";
        batchCreateMemeNames[13] = "abcde";
        batchCreateMemeNames[14] = "efghi";
        batchCreateMemeNames[15] = "ijkle";
        batchCreateMemeNames[16] = "mnope";
        batchCreateMemeNames[17] = "qrste";
        batchCreateMemeNames[18] = "uvwxy";
        batchCreateMemeNames[19] = "yzabe";
        batchCreateMemeNames[20] = "cdefa";
        batchCreateMemeNames[21] = "ghijt";
        batchCreateMemeNames[22] = "klmnw";
        batchCreateMemeNames[23] = "opqrq";
        batchCreateMemeNames[24] = "stuva";
        batchCreateMemeNames[25] = "wxyzz";
        batchCreateMemeNames[26] = "abcdf";
        batchCreateMemeNames[27] = "efghe";
        batchCreateMemeNames[28] = "ijkla";
        batchCreateMemeNames[29] = "mnopr";
        batchCreateMemeNames[30] = "abcdrfwr";
        batchCreateMemeNames[31] = "efghrwref";
        batchCreateMemeNames[32] = "ijklwefwe";
        batchCreateMemeNames[33] = "mnopfwe";
        batchCreateMemeNames[34] = "qrstfer";
        batchCreateMemeNames[35] = "uvwxwrf";
        batchCreateMemeNames[36] = "yzabwef";
        batchCreateMemeNames[37] = "cdefffr";
        batchCreateMemeNames[38] = "ghijetg";
        batchCreateMemeNames[39] = "klmnetgq";
        batchCreateMemeNames[40] = "opqrwed";
        batchCreateMemeNames[41] = "stuvwed";
        batchCreateMemeNames[42] = "wxyzwef";
        batchCreateMemeNames[43] = "abcdeerf";
        batchCreateMemeNames[44] = "efghia";
        batchCreateMemeNames[45] = "ijklea";
        batchCreateMemeNames[46] = "mnopewef";
        batchCreateMemeNames[47] = "qrstewf";
        batchCreateMemeNames[48] = "uvwxywef";
        batchCreateMemeNames[49] = "yzabewef";
        batchCreateMemeNames[50] = "cdefawef";
        batchCreateMemeNames[51] = "ghijtef";
        batchCreateMemeNames[52] = "klmnwrt";
        batchCreateMemeNames[53] = "opqrqrtg";
        batchCreateMemeNames[54] = "stuvatg";
        batchCreateMemeNames[55] = "wxyzzgt";
        batchCreateMemeNames[56] = "abcdfrtg";
        batchCreateMemeNames[57] = "efgheeg";
        batchCreateMemeNames[58] = "ijklaefr";
        batchCreateMemeNames[59] = "mnoprwf";

        // make string arrays
        bytes[] memory names = new bytes[](10);
        names[0] = "hellllledwe";
        names[1] = "worldddd";
        names[2] = "foob";
        names[3] = "bar";
        names[4] = "baz";
        names[5] = "qux";
        names[6] = "quux";
        names[7] = "corge";
        names[8] = "grault";
        names[9] = "garply";

        bytes[] memory oneDegree1 = new bytes[](1);
        oneDegree1[0] = "001";

        bytes[] memory oneDegree2 = new bytes[](1);
        oneDegree2[0] = "100";

        bytes[] memory oneDegree3 = new bytes[](1);
        oneDegree3[0] = "200";

        bytes[] memory multiDegree1 = new bytes[](60);
        multiDegree1[0] = "007";
        multiDegree1[1] = "008";
        multiDegree1[2] = "009";
        multiDegree1[3] = "010";
        multiDegree1[4] = "011";
        multiDegree1[5] = "012";
        multiDegree1[6] = "013";
        multiDegree1[7] = "014";
        multiDegree1[8] = "015";
        multiDegree1[9] = "016";
        multiDegree1[10] = "017";
        multiDegree1[11] = "018";
        multiDegree1[12] = "019";
        multiDegree1[13] = "020";
        multiDegree1[14] = "021";
        multiDegree1[15] = "022";
        multiDegree1[16] = "023";
        multiDegree1[17] = "024";
        multiDegree1[18] = "025";
        multiDegree1[19] = "026";
        multiDegree1[20] = "027";
        multiDegree1[21] = "028";
        multiDegree1[22] = "029";
        multiDegree1[23] = "030";
        multiDegree1[24] = "031";
        multiDegree1[25] = "032";
        multiDegree1[26] = "033";
        multiDegree1[27] = "034";
        multiDegree1[28] = "035";
        multiDegree1[29] = "036";
        multiDegree1[30] = "0071";
        multiDegree1[31] = "0081";
        multiDegree1[32] = "0091";
        multiDegree1[33] = "0101";
        multiDegree1[34] = "0111";
        multiDegree1[35] = "0121";
        multiDegree1[36] = "0131";
        multiDegree1[37] = "0141";
        multiDegree1[38] = "0151";
        multiDegree1[39] = "0161";
        multiDegree1[40] = "0171";
        multiDegree1[41] = "0181";
        multiDegree1[42] = "0191";
        multiDegree1[43] = "0201";
        multiDegree1[44] = "0211";
        multiDegree1[45] = "0221";
        multiDegree1[46] = "0231";
        multiDegree1[47] = "0241";
        multiDegree1[48] = "0251";
        multiDegree1[49] = "0261";
        multiDegree1[50] = "0271";
        multiDegree1[51] = "0281";
        multiDegree1[52] = "0291";
        multiDegree1[53] = "0301";
        multiDegree1[54] = "0311";
        multiDegree1[55] = "0321";
        multiDegree1[56] = "0331";
        multiDegree1[57] = "0341";
        multiDegree1[58] = "0351";
        multiDegree1[59] = "0361";

        bytes[] memory multiDegree2 = new bytes[](60);
        multiDegree2[0] = "037";
        multiDegree2[1] = "038";
        multiDegree2[2] = "039";
        multiDegree2[3] = "040";
        multiDegree2[4] = "041";
        multiDegree2[5] = "042";
        multiDegree2[6] = "043";
        multiDegree2[7] = "044";
        multiDegree2[8] = "045";
        multiDegree2[9] = "046";
        multiDegree2[10] = "047";
        multiDegree2[11] = "048";
        multiDegree2[12] = "049";
        multiDegree2[13] = "050";
        multiDegree2[14] = "051";
        multiDegree2[15] = "052";
        multiDegree2[16] = "053";
        multiDegree2[17] = "054";
        multiDegree2[18] = "055";
        multiDegree2[19] = "056";
        multiDegree2[20] = "057";
        multiDegree2[21] = "058";
        multiDegree2[22] = "059";
        multiDegree2[23] = "060";
        multiDegree2[24] = "061";
        multiDegree2[25] = "062";
        multiDegree2[26] = "063";
        multiDegree2[27] = "064";
        multiDegree2[28] = "065";
        multiDegree2[29] = "066";
        multiDegree2[30] = "0371";
        multiDegree2[31] = "0381";
        multiDegree2[32] = "0391";
        multiDegree2[33] = "0401";
        multiDegree2[34] = "0411";
        multiDegree2[35] = "0421";
        multiDegree2[36] = "0431";
        multiDegree2[37] = "0441";
        multiDegree2[38] = "0451";
        multiDegree2[39] = "0461";
        multiDegree2[40] = "0471";
        multiDegree2[41] = "0481";
        multiDegree2[42] = "0491";
        multiDegree2[43] = "0501";
        multiDegree2[44] = "0511";
        multiDegree2[45] = "0521";
        multiDegree2[46] = "0531";
        multiDegree2[47] = "0541";
        multiDegree2[48] = "0551";
        multiDegree2[49] = "0561";
        multiDegree2[50] = "0571";
        multiDegree2[51] = "0581";
        multiDegree2[52] = "0591";
        multiDegree2[53] = "0601";
        multiDegree2[54] = "0611";
        multiDegree2[55] = "0621";
        multiDegree2[56] = "0631";
        multiDegree2[57] = "0641";
        multiDegree2[58] = "0651";
        multiDegree2[59] = "0661";

        bytes[] memory multiDegree3 = new bytes[](60);
        multiDegree3[0] = "067";
        multiDegree3[1] = "068";
        multiDegree3[2] = "069";
        multiDegree3[3] = "070";
        multiDegree3[4] = "071";
        multiDegree3[5] = "072";
        multiDegree3[6] = "073";
        multiDegree3[7] = "074";
        multiDegree3[8] = "075";
        multiDegree3[9] = "076";
        multiDegree3[10] = "077";
        multiDegree3[11] = "078";
        multiDegree3[12] = "079";
        multiDegree3[13] = "080";
        multiDegree3[14] = "081";
        multiDegree3[15] = "082";
        multiDegree3[16] = "083";
        multiDegree3[17] = "084";
        multiDegree3[18] = "085";
        multiDegree3[19] = "086";
        multiDegree3[20] = "087";
        multiDegree3[21] = "088";
        multiDegree3[22] = "089";
        multiDegree3[23] = "090";
        multiDegree3[24] = "091";
        multiDegree3[25] = "092";
        multiDegree3[26] = "093";
        multiDegree3[27] = "094";
        multiDegree3[28] = "095";
        multiDegree3[29] = "096";
        multiDegree3[30] = "0671";
        multiDegree3[31] = "0681";
        multiDegree3[32] = "0691";
        multiDegree3[33] = "0701";
        multiDegree3[34] = "0711";
        multiDegree3[35] = "0721";
        multiDegree3[36] = "0731";
        multiDegree3[37] = "0741";
        multiDegree3[38] = "0751";
        multiDegree3[39] = "0761";
        multiDegree3[40] = "0771";
        multiDegree3[41] = "0781";
        multiDegree3[42] = "0791";
        multiDegree3[43] = "0801";
        multiDegree3[44] = "0811";
        multiDegree3[45] = "0821";
        multiDegree3[46] = "0831";
        multiDegree3[47] = "0841";
        multiDegree3[48] = "0851";
        multiDegree3[49] = "0861";
        multiDegree3[50] = "0871";
        multiDegree3[51] = "0881";
        multiDegree3[52] = "0891";
        multiDegree3[53] = "0901";
        multiDegree3[54] = "0911";
        multiDegree3[55] = "0921";
        multiDegree3[56] = "0931";
        multiDegree3[57] = "0941";
        multiDegree3[58] = "0951";
        multiDegree3[59] = "0961";

        // create 200 memes
        for (uint256 i = 0; i < names.length; i++) {
            ethMultiVault.createAtom{value: getAtomCost()}(names[i]);
        }
        ethMultiVault.createAtom{value: getAtomCost()}(oneDegree1[0]);
        ethMultiVault.createAtom{value: getAtomCost()}(oneDegree2[0]);
        ethMultiVault.createAtom{value: getAtomCost()}(oneDegree3[0]);
        for (uint256 i = 0; i < multiDegree1.length; i++) {
            ethMultiVault.createAtom{value: getAtomCost()}(multiDegree1[i]);
        }
        for (uint256 i = 0; i < multiDegree2.length; i++) {
            ethMultiVault.createAtom{value: getAtomCost()}(multiDegree2[i]);
        }
        for (uint256 i = 0; i < multiDegree3.length; i++) {
            ethMultiVault.createAtom{value: getAtomCost()}(multiDegree3[i]);
        }
        ethMultiVault.createAtom{value: getAtomCost()}(oneDegree1[0]);
        ethMultiVault.createAtom{value: getAtomCost()}(oneDegree1[0]);
        ethMultiVault.createAtom{value: getAtomCost()}(oneDegree1[0]);
        ethMultiVault.createAtom{value: getAtomCost()}(oneDegree1[0]);
        ethMultiVault.createAtom{value: getAtomCost()}(oneDegree1[0]);
        ethMultiVault.createAtom{value: getAtomCost()}(oneDegree1[0]);
        ethMultiVault.createAtom{value: getAtomCost()}(oneDegree1[0]);
    }
}
