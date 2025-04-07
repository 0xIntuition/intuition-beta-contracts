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
    address payable public constant ETH_MULTI_VAULT = payable(0x63B90A9c109fF8f137916026876171ffeEdEe714);

    bytes[] public ATOM_URIS = [
        bytes("intuition.systems"),
        bytes("is"),
        bytes("bullish"),
        bytes("cat"),
        bytes("internet")
    ];

    uint256[] public ATOM_IDS;

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
        console.log("Atom creation cost: %d wei", atomCost);
        uint256 tripleCost = ethMultiVault.getTripleCost();
        console.log("Triple creation cost: %d wei", tripleCost);

        // Create the atom with the raw URI "intuition.systems"
        for (uint256 i = 0; i < ATOM_URIS.length; i++) {
            uint256 atomId = ethMultiVault.createAtom{value: atomCost}(ATOM_URIS[i]);
            console.log("Created atom with ID: %s", atomId);
            ATOM_IDS.push(atomId);
        }

        // Stake in bonding curve 2
        for (uint256 i = 0; i < ATOM_IDS.length; i++) {
            console.log("Staking %d wei in %s bonding curve 2", STAKE_AMOUNT, string(ATOM_URIS[i]));
            uint256 shares2 = ethMultiVault.depositAtomCurve{value: STAKE_AMOUNT}(
                msg.sender, // receiver is the sender of this transaction
                ATOM_IDS[i],
                CURVE_ID_2
            );
            console.log("Received %d shares in bonding curve 2", shares2);

            // Stake in bonding curve 3
            console.log("Staking %d wei in %s bonding curve 3", STAKE_AMOUNT, string(ATOM_URIS[i]));
            uint256 shares3 = ethMultiVault.depositAtomCurve{value: STAKE_AMOUNT}(
                msg.sender, // receiver is the sender of this transaction
                ATOM_IDS[i],
                CURVE_ID_3
            );
            console.log("Received %d shares in bonding curve 3", shares3);
        }

        // Create a triple
        uint256 tripleId = ethMultiVault.createTriple{value: tripleCost}(ATOM_IDS[0], ATOM_IDS[1], ATOM_IDS[2]);
        console.log("Created triple with ID: %s", tripleId);

        // Stake in the triple
        console.log("Staking %d wei in triple", STAKE_AMOUNT);
        uint256 shares4 = ethMultiVault.depositTripleCurve{value: STAKE_AMOUNT}(
            msg.sender, // receiver is the sender of this transaction
            tripleId,
            CURVE_ID_3
        );
        console.log("Received %d shares in triple", shares4);

        // Create another triple
        uint256 tripleId2 = ethMultiVault.createTriple{value: tripleCost}(ATOM_IDS[3], ATOM_IDS[1], ATOM_IDS[4]);
        console.log("Created triple with ID: %s", tripleId2);

        // Stake in the second counter-triple
        console.log("Staking %s wei in second triple", STAKE_AMOUNT);
        uint256 counterTripleId = ethMultiVault.getCounterIdFromTriple(tripleId2);
        uint256 shares5 = ethMultiVault.depositTripleCurve{value: STAKE_AMOUNT}(
            msg.sender, // receiver is the sender of this transaction
            counterTripleId,
            CURVE_ID_3
        );
        console.log("Received %s shares in counter second triple", shares5);

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
