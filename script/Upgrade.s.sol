// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ProposeUpgradeResponse, Defender, Options} from "openzeppelin-foundry-upgrades/Defender.sol";

contract DefenderScript is Script {
    function setUp() public {}

    function run() public {
        address proxy = 0xf1C32Dc428C76A8f0ea77c9457f01d0e38f9Bce4;
        Options memory opts;
        ProposeUpgradeResponse memory response = Defender.proposeUpgrade(
            proxy,
            "EthMultiVaultV2.sol",
            opts
        );
        console.log("Proposal id", response.proposalId);
        console.log("Url", response.url);
    }
}