// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ProposeUpgradeResponse, Defender, Options} from "openzeppelin-foundry-upgrades/Defender.sol";

contract UpgradeScript is Script {
    function setUp() public {}

    function run() public {
        address transparentUpgradeableProxy = 0xD655f1000B6a418e154A7e42eb88D9380649Aa92;
        Options memory opts;
        ProposeUpgradeResponse memory response = Defender.proposeUpgrade(
            transparentUpgradeableProxy,
            "EthMultiVaultV2.sol",
            opts
        );
        console.log("Transaction proposal:", response.proposalId);
        console.log("URL:", response.url);
    }
}