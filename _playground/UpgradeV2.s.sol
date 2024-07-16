// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {EthMultiVaultV2} from "test/EthMultiVaultV2.sol";

contract UpgradeV2Script is Script {
    function run() public {
        vm.startBroadcast();

        EthMultiVaultV2 ethMultiVaultV2 = new EthMultiVaultV2();
        console.log("deployed EthMultiVaultV2:", address(ethMultiVaultV2));

        vm.stopBroadcast();
    }
}
