// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {BondingCurveRegistry} from "src/BondingCurveRegistry.sol";
import {OffsetProgressiveCurve} from "src/OffsetProgressiveCurve.sol";

// To run this:
/* forge script script/DeployCurve.s.sol \
   --rpc-url $BASE_SEPOLIA_RPC_URL \
   --private-key $PRIVATE_KEY \
   --sender $SENDER_ADDRESS \
   --broadcast \
   --verify \
   --etherscan-api-key $BASESCAN_API_KEY
*/

contract DeployCurve is Script {
    // Constants from previous deployment
    address public constant REGISTRY = 0x62d0670858ad598b5A65b3B5206A7C7937Ddabad;

    function run() external {
        // Begin sending tx's to network
        vm.startBroadcast();

        // Deploy OffsetProgressiveCurve
        OffsetProgressiveCurve offsetProgressiveCurve = new OffsetProgressiveCurve(
            "Offset Curve 2,5e35",
            2, // slope
            5e35 // offset
        );
        console.logString("deployed OffsetProgressiveCurve.");

        // Add curve to BondingCurveRegistry
        BondingCurveRegistry(REGISTRY).addBondingCurve(address(offsetProgressiveCurve));
        console.logString("added curve to registry.");

        // stop sending tx's
        vm.stopBroadcast();

        console.log("OffsetProgressiveCurve address:", address(offsetProgressiveCurve));
    }
}
