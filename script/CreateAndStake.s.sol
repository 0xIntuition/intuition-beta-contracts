// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";

// To run this:
// forge script script/CreateAndStake.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast

/**
 * @title CreateAndStake
 * @notice Script to create the "intuition.systems" atom and stake ETH in bonding curves 2 and 3
 */
contract CreateAndStake is Script {
    // Address of the EthMultiVault contract
    address payable public constant ETH_MULTI_VAULT = payable(0x71Ea9FEb2C8341897188B409c83bc9a64ECdDdFC);
    
    // Bonding curve IDs
    uint256 public constant CURVE_ID_2 = 2;
    uint256 public constant CURVE_ID_3 = 3;
    
    // Amount to stake in each curve (0.001 ETH)
    uint256 public constant STAKE_AMOUNT = 0.001 ether;

    function run() public {
        // Start broadcasting transactions
        vm.startBroadcast();
        
        // Get the EthMultiVault contract instance
        EthMultiVault ethMultiVault = EthMultiVault(ETH_MULTI_VAULT);
        
        // Get the atom cost
        uint256 atomCost = ethMultiVault.getAtomCost();
        console.log("Atom creation cost: %s wei", atomCost);
        
        // Create the atom with the raw URI "intuition.systems"
        bytes memory atomUri = bytes("intuition.systems");
        uint256 atomId = ethMultiVault.createAtom{value: atomCost}(atomUri);
        console.log("Created atom with ID: %s", atomId);
        
        // Stake in bonding curve 2
        console.log("Staking %s wei in bonding curve 2", STAKE_AMOUNT);
        uint256 shares2 = ethMultiVault.depositAtomCurve{value: STAKE_AMOUNT}(
            msg.sender, // receiver is the sender of this transaction
            atomId,
            CURVE_ID_2
        );
        console.log("Received %s shares in bonding curve 2", shares2);
        
        // Stake in bonding curve 3
        console.log("Staking %s wei in bonding curve 3", STAKE_AMOUNT);
        uint256 shares3 = ethMultiVault.depositAtomCurve{value: STAKE_AMOUNT}(
            msg.sender, // receiver is the sender of this transaction
            atomId,
            CURVE_ID_3
        );
        console.log("Received %s shares in bonding curve 3", shares3);
        
        // Stop broadcasting transactions
        vm.stopBroadcast();
        
        // Print summary
        console.log("Summary:");
        console.log("- Created atom 'intuition.systems' with ID: %s", atomId);
        console.log("- Staked %s wei in bonding curve 2, received %s shares", STAKE_AMOUNT, shares2);
        console.log("- Staked %s wei in bonding curve 3, received %s shares", STAKE_AMOUNT, shares3);
    }
}
