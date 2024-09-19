// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVaultExperimental} from "src/experiments/EthMultiVaultExperimental.sol";

// Two step linear function:  X=Y until X=1, then X=2Y after that
contract TwoStepLinear is EthMultiVaultExperimental {
    function currentSharePrice(uint256 id) external view override returns (uint256) {}

    function convertToShares(uint256 assets, uint256 id) public view override returns (uint256) {}

    function convertToAssets(uint256 shares, uint256 id) public view override returns (uint256) {}
}
