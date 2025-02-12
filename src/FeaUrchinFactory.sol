// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {FeaUrchin} from "./FeaUrchin.sol";
import {IEthMultiVault} from "./interfaces/IEthMultiVault.sol";

contract FeaUrchinFactory {
    IEthMultiVault public immutable ethMultiVault;
    
    event FeaUrchinDeployed(address indexed admin, address indexed feaUrchin);

    constructor(IEthMultiVault _ethMultiVault) {
        ethMultiVault = _ethMultiVault;
    }

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