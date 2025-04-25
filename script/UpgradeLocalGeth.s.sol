// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;
import {Script, console} from "forge-std/Script.sol";
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

// To run this:
/* forge script script/UpgradeLocalGeth.s.sol \
--optimize --via-ir \
--rpc-url http://localhost:8545 \
--keystore ../intuition-rs/geth/keystore.json \
--password-file ../intuition-rs/geth/password.txt \
--broadcast 
*/

contract UpgradeLocalGeth is Script {
    address public admin = 0x07baA707F61c89F6eB33c8Cb948c483c9b387084;
    address public ethMultiVaultDeployedAddress = 0x60fF03e024dFdd7cee71CF541133FD88c7a59499;
    uint256 public defaultBondingCurveId = 1;
    uint256 public progressiveCurveId = 2;

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
    uint256 public oldCount;

    function run() external {
        // Begin sending tx's to network
        vm.startBroadcast();


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
        offsetProgressiveCurve = new OffsetProgressiveCurve("Offset Progressive Curve", 2,5e35);

        // Add the LinearCurve to the BondingCurveRegistry
        bondingCurveRegistry.addBondingCurve(address(linearCurve));

        // Add the ProgressiveCurve to the BondingCurveRegistry
        bondingCurveRegistry.addBondingCurve(address(progressiveCurve));

        // Add the OffsetProgressiveCurve to the BondingCurveRegistry
        bondingCurveRegistry.addBondingCurve(address(offsetProgressiveCurve));

        // Upgrade EthMultiVault to the latest version
        // To find the address of the ProxyAdmin contract for the EthMultiVault proxy, inspect the creation transaction of the EthMultiVault proxy contract on Basescan, in particular the AdminChanged event. Same applies to the CustomMulticall3 proxy contract.
        ProxyAdmin proxyAdmin = ProxyAdmin(0xadDCf9f1015bD2BD4f8591E8E8876Ef94E6aaf32);
        address newEthMultiVaultImplementation = address(new EthMultiVault());

        // Prepare the bonding curve configuration
        IEthMultiVault.BondingCurveConfig memory bondingCurveConfig = IEthMultiVault.BondingCurveConfig({
            registry: address(bondingCurveRegistry),
            defaultCurveId: 1
        });

        // Prepare initialization data for the upgrade
        bytes memory reinitData = abi.encodeWithSelector(
            EthMultiVault.reinitialize.selector,
            bondingCurveConfig
        );

        proxyAdmin.upgradeAndCall{value: 0}(
            ITransparentUpgradeableProxy(ethMultiVaultDeployedAddress), newEthMultiVaultImplementation, reinitData
        );
    }
}
