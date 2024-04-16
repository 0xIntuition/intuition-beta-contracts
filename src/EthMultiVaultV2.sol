// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {AtomWallet} from "src/AtomWallet.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {LibZip} from "solady/utils/LibZip.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {IEntryPoint} from "account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {Errors} from "src/libraries/Errors.sol";

import {EthMultiVault} from "src/EthMultiVault.sol";

/// @custom:oz-upgrades-from EthMultiVault
contract EthMultiVaultV2 is EthMultiVault {
    bytes32 public VERSION = "V2";

    uint256 public counter;

    function addObject() external {
        counter += 1;
    }

    function version() external pure returns (uint256) {
        return 2;
    }
}