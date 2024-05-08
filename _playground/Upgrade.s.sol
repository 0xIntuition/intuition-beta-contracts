// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ProposeUpgradeResponse, Defender, Options} from "openzeppelin-foundry-upgrades/Defender.sol";

contract UpgradeScript is Script {
    function setUp() public {}

    function run() public {
        address transparentUpgradeableProxy = address(0x0000000000000000000000000000000000000000);
        Options memory opts;
        ProposeUpgradeResponse memory response =
            Defender.proposeUpgrade(transparentUpgradeableProxy, "EthMultiVaultV2.sol", opts);
        console.log("Transaction proposal:", response.proposalId);
        console.log("URL:", response.url);
    }
}
