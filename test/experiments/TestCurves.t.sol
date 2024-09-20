// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

// Import Foundry's Test library
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// Import interfaces and contracts
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";

// Curve contracts
// import {CatmullRomAssetShares} from "src/experiments/curves/CatmullRom.sol";
import {Cubic} from "src/experiments/curves/Cubic.sol";
import {Exponential} from "src/experiments/curves/Exponential.sol";
import {Logarithmic} from "src/experiments/curves/Logarithmic.sol";
import {LogarithmicStepCurve} from "src/experiments/curves/LogarithmicStepCurve.sol";
import {Polynomial} from "src/experiments/curves/Polynomial.sol";
import {PowerFunction} from "src/experiments/curves/PowerFunction.sol";
import {Quadratic} from "src/experiments/curves/Quadratic.sol";
import {Skewed} from "src/experiments/curves/Skewed.sol";
import {SQRT} from "src/experiments/curves/SQRT.sol";
import {SteppedCurve} from "src/experiments/curves/SteppedCurve.sol";
import {TwoStepLinear} from "src/experiments/curves/TwoStepLinear.sol";

// Helper libraries
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract TestCurves is Test {
    using Address for address payable;

    // Dummy user
    address payable public alice;

    // Contracts to be deployed
    // CatmullRomAssetShares public catmullRom;
    Cubic public cubic;
    Exponential public exponential;
    Logarithmic public logarithmic;
    LogarithmicStepCurve public logarithmicStepCurve;
    Polynomial public polynomial;
    PowerFunction public powerFunction;
    Quadratic public quadratic;
    Skewed public skewed;
    SQRT public sqrt;
    SteppedCurve public steppedCurve;
    TwoStepLinear public twoStepLinear;

    // Addresses for key roles in the protocol
    address public admin = address(0xaAE94A934c070F4a57303f436fb3599CBd5497C6); // Experimental admin
    address public protocolMultisig = address(0xD8a8653ceD32364DeB582c900Cc3FcD16c34d6D5); // Experimental protocol multisig
    address public atomWarden = address(0xaAE94A934c070F4a57303f436fb3599CBd5497C6);
    address public atomWalletBeacon = address(0x9688eAc5757735A4e0F23C05B528Ea1ADcfFeaf1); // AtomWalletBeacon on Base Sepolia

    // Constants from Base
    IPermit2 permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)); // Permit2 on Base
    address entryPoint = address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789); // EntryPoint on Base

    // Vault configuration structs
    IEthMultiVault.GeneralConfig public generalConfig;
    IEthMultiVault.AtomConfig public atomConfig;
    IEthMultiVault.TripleConfig public tripleConfig;
    IEthMultiVault.WalletConfig public walletConfig;
    IEthMultiVault.VaultFees public vaultFees;

    function setUp() public {
        // Create a dummy user called alice and fund her with 100 ether
        alice = payable(address(0xA11CE));
        vm.deal(alice, 100 ether);

        // Set up configuration structs
        generalConfig = IEthMultiVault.GeneralConfig({
            admin: admin, // Admin address for the EthMultiVault contract
            protocolMultisig: protocolMultisig, // Protocol multisig address
            feeDenominator: 10000, // Common denominator for fee calculations
            minDeposit: 0.00042 ether, // Minimum deposit amount in wei
            minShare: 1e6, // Minimum share amount (e.g., for vault initialization)
            atomUriMaxLength: 250, // Maximum length of the atom URI data that can be passed when creating atom vaults
            decimalPrecision: 1e18, // decimal precision used for calculating share prices
            minDelay: 1 days // minimum delay for timelocked transactions
        });

        atomConfig = IEthMultiVault.AtomConfig({
            atomWalletInitialDepositAmount: 0.00003 ether, // Fee charged for purchasing vault shares for the atom wallet upon creation
            atomCreationProtocolFee: 0.0003 ether // Fee charged for creating an atom
        });

        tripleConfig = IEthMultiVault.TripleConfig({
            tripleCreationProtocolFee: 0.0003 ether, // Fee for creating a triple
            atomDepositFractionOnTripleCreation: 0.00003 ether, // Static fee going towards increasing the amount of assets in the underlying atom vaults
            atomDepositFractionForTriple: 900 // Fee for equity in atoms when creating a triple
        });

        walletConfig = IEthMultiVault.WalletConfig({
            permit2: IPermit2(address(permit2)), // Permit2 on Base
            entryPoint: entryPoint, // EntryPoint address on Base
            atomWarden: atomWarden, // atomWarden address
            atomWalletBeacon: atomWalletBeacon // Address of the AtomWalletBeacon contract
        });

        vaultFees = IEthMultiVault.VaultFees({
            entryFee: 500, // Entry fee for vault 0
            exitFee: 500, // Exit fee for vault 0
            protocolFee: 250 // Protocol fee for vault 0
        });

        // Deploy and initialize curves
        // catmullRom = new CatmullRomAssetShares();
        // catmullRom.init(generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees);

        cubic = new Cubic();
        cubic.init(generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees);

        exponential = new Exponential();
        exponential.init(generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees);

        logarithmic = new Logarithmic();
        logarithmic.init(generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees);

        logarithmicStepCurve = new LogarithmicStepCurve();
        logarithmicStepCurve.init(generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees);

        polynomial = new Polynomial();
        polynomial.init(generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees);

        powerFunction = new PowerFunction();
        powerFunction.init(generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees);

        quadratic = new Quadratic();
        quadratic.init(generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees);

        skewed = new Skewed();
        skewed.init(generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees);

        sqrt = new SQRT();
        sqrt.init(generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees);

        steppedCurve = new SteppedCurve();
        steppedCurve.init(generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees);

        twoStepLinear = new TwoStepLinear();
        twoStepLinear.init(generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees);

        console.logString("All curves deployed and initialized.");
        console.log("Cubic: ", address(cubic));
        console.log("Exponential: ", address(exponential));
        console.log("Logarithmic: ", address(logarithmic));
        console.log("LogarithmicStepCurve: ", address(logarithmicStepCurve));
        console.log("Polynomial: ", address(polynomial));
        console.log("PowerFunction: ", address(powerFunction));
        console.log("Quadratic: ", address(quadratic));
        console.log("Skewed: ", address(skewed));
        console.log("SQRT: ", address(sqrt));
        console.log("SteppedCurve: ", address(steppedCurve));
        console.log("TwoStepLinear: ", address(twoStepLinear));
    }

    // Helper function to perform the test steps
    function performCurveTest(IEthMultiVault vault, string memory curveName) internal {
        // Get the atom cost
        uint256 atomCost = vault.getAtomCost();

        // alice creates an atom
        vm.prank(alice);
        uint256 atomId = vault.createAtom{value: atomCost}(bytes("atom1"));

        // alice deposits into the atom 5 times
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(alice);
            vault.depositAtom{value: 0.1 ether}(alice, atomId);
        }

        // Get alice's shares balance in the atom vault
        (uint256 shares,) = vault.getVaultStateForUser(atomId, alice);

        // alice redeems her shares
        vm.prank(alice);
        vault.redeemAtom(shares, alice, atomId);

        console.log(string(abi.encodePacked("Tested ", curveName, " curve successfully.")));
    }

    // Unit tests for each curve

    function testCubicCurve() public {
        performCurveTest(cubic, "Cubic");
    }

    function testExponentialCurve() public {
        performCurveTest(exponential, "Exponential");
    }

    function testLogarithmicCurve() public {
        performCurveTest(logarithmic, "Logarithmic");
    }

    function testLogarithmicStepCurve() public {
        performCurveTest(logarithmicStepCurve, "LogarithmicStepCurve");
    }

    function testPolynomialCurve() public {
        performCurveTest(polynomial, "Polynomial");
    }

    function testPowerFunctionCurve() public {
        performCurveTest(powerFunction, "PowerFunction");
    }

    function testQuadraticCurve() public {
        performCurveTest(quadratic, "Quadratic");
    }

    function testSkewedCurve() public {
        performCurveTest(skewed, "Skewed");
    }

    function testSQRTCurve() public {
        performCurveTest(sqrt, "SQRT");
    }

    function testSteppedCurve() public {
        performCurveTest(steppedCurve, "SteppedCurve");
    }

    function testTwoStepLinearCurve() public {
        performCurveTest(twoStepLinear, "TwoStepLinear");
    }
}
