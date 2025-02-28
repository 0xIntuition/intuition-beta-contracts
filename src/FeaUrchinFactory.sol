// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {FeaUrchin} from "./FeaUrchin.sol";
import {IEthMultiVault} from "./interfaces/IEthMultiVault.sol";

/**
 * @title  FeaUrchinFactory
 * @author 0xIntuition
 * @notice A factory contract for deploying FeaUrchin instances. Each FeaUrchin instance
 *         acts as a fee-taking wrapper around the EthMultiVault, allowing different
 *         fee configurations and administrators for different use cases.
 *
 * @notice The factory maintains a single reference to the EthMultiVault and ensures
 *         all deployed FeaUrchin instances interact with the same vault. This creates
 *         a standardized deployment process while allowing flexibility in fee structures.
 *
 * @dev    The factory pattern is used here to provide a clean, standardized way to deploy
 *         new FeaUrchin instances while ensuring they all reference the correct EthMultiVault.
 *         Each deployed instance can have its own fee configuration and administrator.
 */
contract FeaUrchinFactory {
    /// @notice The EthMultiVault instance that all deployed FeaUrchin contracts will interact with
    IEthMultiVault public immutable ethMultiVault;
    
    /// @notice Emitted when a new FeaUrchin instance is deployed
    /// @param admin The address that will be set as the admin of the new FeaUrchin
    /// @param feaUrchin The address of the newly deployed FeaUrchin contract
    event FeaUrchinDeployed(address indexed admin, address indexed feaUrchin);

    /// @notice Constructor that sets the EthMultiVault reference
    /// @param _ethMultiVault The address of the EthMultiVault contract
    constructor(IEthMultiVault _ethMultiVault) {
        ethMultiVault = _ethMultiVault;
    }

    /// @notice Deploys a new FeaUrchin instance with specified fee parameters
    /// @param feeNumerator The numerator of the fee fraction
    /// @param feeDenominator The denominator of the fee fraction
    /// @return The newly deployed FeaUrchin contract
    function deployFeaUrchin(uint256 feeNumerator, uint256 feeDenominator) external returns (FeaUrchin) {
        FeaUrchin feaUrchin = new FeaUrchin(
            ethMultiVault,
            msg.sender,
            feeNumerator,
            feeDenominator
        );
        
        emit FeaUrchinDeployed(msg.sender, address(feaUrchin));
        return feaUrchin;
    }
} 