// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {Attestoor} from "src/utils/Attestoor.sol";
import {Errors} from "src/libraries/Errors.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";

/**
 * @title  AttestoorFactory
 * @author 0xIntuition
 * @notice A utility contract of the Intuition protocol. It allows for the deployment of Attestoor contracts using the BeaconProxy pattern.
 */
contract AttestoorFactory is Initializable, Ownable2StepUpgradeable {
    /// @notice The EthMultiVault contract address
    IEthMultiVault public ethMultiVault;

    /// @notice The address of the UpgradeableBeacon contract, which points to the implementation of the Attestoor contract
    address public attestoorBeacon;

    /// @notice The count of deployed Attestoor contracts
    uint256 public count;

    /// @notice Event emitted when an Attestoor contract is deployed
    ///
    /// @param attestoor The address of the deployed Attestoor contract
    /// @param admin The address of the admin
    event AttestoorDeployed(address indexed attestoor, address indexed admin);

    /// @notice Event emitted when the EthMultiVault contract address is set
    /// @param ethMultiVault EthMultiVault contract address
    event EthMultiVaultSet(IEthMultiVault ethMultiVault);

    /// @notice Initializes the AttestoorFactory contract
    ///
    /// @param admin The address of the admin
    /// @param _ethMultiVault EthMultiVault contract
    function init(address admin, IEthMultiVault _ethMultiVault, address _attestoorBeacon) external initializer {
        __Ownable_init(admin);
        ethMultiVault = _ethMultiVault;
        attestoorBeacon = _attestoorBeacon;
    }

    /// @notice Deploys a new Attestoor contract
    /// @param admin The address of the admin of the new Attestoor contract
    /// @return attestoorAddress The address of the deployed Attestoor contract
    function deployAttestoor(address admin) external returns (address) {
        // compute salt for create2
        bytes32 salt = bytes32(count);

        // get contract deployment data
        bytes memory data = _getDeploymentData(admin);

        address attestoorAddress;

        // deploy attestoor contract with create2:
        // value sent in wei,
        // memory offset of `code` (after first 32 bytes where the length is),
        // length of `code` (first 32 bytes of code),
        // salt for create2
        assembly {
            attestoorAddress := create2(0, add(data, 0x20), mload(data), salt)
        }

        if (attestoorAddress == address(0)) {
            revert Errors.Attestoor_DeployAttestoorFailed();
        }

        count++;

        emit AttestoorDeployed(attestoorAddress, admin);

        return attestoorAddress;
    }

    /// @notice Computes the address of the Attestoor contract that would be deployed using deployAttestoor function
    ///         with the given admin address and the `count` value
    ///
    /// @param _count The count value to be used in the computation as the salt for create2
    /// @param admin The address of the admin of the new Attestoor contract
    ///
    /// @return address The address of the Attestoor contract that would be deployed
    function computeAttestoorAddress(uint256 _count, address admin) public view returns (address) {
        // compute salt for create2
        bytes32 salt = bytes32(_count);

        // get contract deployment data
        bytes memory data = _getDeploymentData(admin);

        // compute the raw contract address
        bytes32 rawAddress = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(data)));

        return address(bytes20(rawAddress << 96));
    }

    /// @dev returns the deployment data for the Attestoor contract
    /// @param admin The address of the admin of the new Attestoor contract
    /// @return bytes memory the deployment data for the Attestoor contract (using BeaconProxy pattern)
    function _getDeploymentData(address admin) internal view returns (bytes memory) {
        // Address of the UpgradeableBeacon contract
        address beaconAddress = attestoorBeacon;

        // BeaconProxy creation code
        bytes memory code = type(BeaconProxy).creationCode;

        // encode the init function of the Attestoor contract with constructor arguments
        bytes memory initData = abi.encodeWithSelector(Attestoor.init.selector, admin, ethMultiVault);

        // encode constructor arguments of the BeaconProxy contract (address beacon, bytes memory data)
        bytes memory encodedArgs = abi.encode(beaconAddress, initData);

        // concatenate the BeaconProxy creation code with the ABI-encoded constructor arguments
        return abi.encodePacked(code, encodedArgs);
    }

    /// @notice Sets the EthMultiVault contract address
    /// @param _ethMultiVault EthMultiVault contract address
    function setEthMultiVault(IEthMultiVault _ethMultiVault) external onlyOwner {
        if (address(_ethMultiVault) == address(0)) {
            revert Errors.Attestoor_InvalidEthMultiVaultAddress();
        }

        ethMultiVault = _ethMultiVault;

        emit EthMultiVaultSet(_ethMultiVault);
    }
}
