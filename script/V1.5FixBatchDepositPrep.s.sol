// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";

/* To run this:
forge script script/V1.5FixBatchDepositPrep.s.sol:V1_5FixBatchDepositPrep \
--broadcast \
--verify \
--etherscan-api-key $ETHERSCAN_API_KEY
*/
contract V1_5FixBatchDepositPrep is Script {
    error UnsupportedChainId();

    EthMultiVault public ethMultiVault;

    function run() external {
        vm.createSelectFork(vm.envString("BASE_SEPOLIA_RPC_URL"));
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        if (block.chainid != 84_532) {
            revert UnsupportedChainId();
        }

        ethMultiVault = new EthMultiVault();
        console.log("EthMultiVault deployed at: ", address(ethMultiVault));

        vm.stopBroadcast();
    }
}
