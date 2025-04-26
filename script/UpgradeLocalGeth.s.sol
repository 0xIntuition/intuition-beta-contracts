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
/* 
export ETH_MULTI_VAULT_DEPLOYED_ADDRESS=0x04da5ecD66052469473B892fd86b12ACdb73799a
export ADMIN=0x07baA707F61c89F6eB33c8Cb948c483c9b387084
export PROXY_ADMIN_ADDRESS=0x0A50fe533b67E8a08f69E6bdf5722e6A1A62e494

forge script script/UpgradeLocalGeth.s.sol \
--optimize --via-ir \
--rpc-url http://localhost:8545 \
--keystore ../intuition-rs/geth/keystore.json \
--password-file ../intuition-rs/geth/password.txt \
--broadcast 
*/

contract UpgradeLocalGeth is Script {

    /// @notice Deployed contracts
    EthMultiVault public ethMultiVault;
    BondingCurveRegistry public bondingCurveRegistry;
    LinearCurve public linearCurve;
    ProgressiveCurve public progressiveCurve;
    OffsetProgressiveCurve public offsetProgressiveCurve;


    function run() external {
        // Begin sending tx's to network
        vm.startBroadcast();

        address admin = vm.envAddress("ADMIN");

        // Get the deployed EthMultiVault contract address from env variable
        address ethMultiVaultDeployedAddress = vm.envAddress("ETH_MULTI_VAULT_DEPLOYED_ADDRESS");

        // old proxy admin address
        // IEthMultiVault(ethMultiVaultDeployedAddress).generalConfig().admin ?????

       // To find the address of the ProxyAdmin contract for the EthMultiVault proxy, inspect the creation transaction of the EthMultiVault proxy contract on Basescan, in particular the AdminChanged event. 
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN_ADDRESS");
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);


        // Deploy the BondingCurveRegistry contract
        bondingCurveRegistry = new BondingCurveRegistry(admin);

        // Get the deployed EthMultiVault contract
        ethMultiVault = EthMultiVault(payable(ethMultiVaultDeployedAddress));

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
