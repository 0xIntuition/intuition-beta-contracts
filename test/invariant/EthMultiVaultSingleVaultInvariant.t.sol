// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {EthMultiVaultSingleVaultActor} from "./actors/EthMultiVaultSingleVaultActor.sol";
import {InvariantEthMultiVaultBase} from "./InvariantEthMultiVaultBase.sol";

contract EthMultiVaultSingleVaultInvariantTest is InvariantEthMultiVaultBase {
    // actor contracts
    EthMultiVaultSingleVaultActor public actor;

    // actor arrays
    uint256[] public actorPks;
    address[] public actors;

    function setUp() public override {
        super.setUp();

        // create single vault
        ethMultiVault.createAtom{value: 100 ether}("PEPE");

        // create 2 more atoms for the triple vault
        ethMultiVault.createAtom{value: 100 ether}("WIF");
        ethMultiVault.createAtom{value: 100 ether}("BASE");

        // create triple vault
        ethMultiVault.createTriple{value: 100 ether}(1, 2, 3);

        // deploy actor
        actor = new EthMultiVaultSingleVaultActor(ethMultiVault);

        // target actor
        targetContract(address(actor));

        // selectors for actor functions
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = actor.depositAtom.selector; // depositAtom
        selectors[1] = actor.redeemAtom.selector; // redeemAtom
        selectors[2] = actor.depositTriple.selector; // depositTriple
        selectors[3] = actor.redeemTriple.selector; // redeemTriple

        FuzzSelector memory fuzzSelector = FuzzSelector({addr: address(actor), selectors: selectors});

        // target the functions in the actor contract
        targetSelector(fuzzSelector);
    }

    function invariant_ethMultiVault_single() external {
        // assets less than or equal to eth balance
        invariant_ethMultiVault_asset_solvency();
        // shares less than or equal to assets
        invariant_ethMultiVault_share_solvency();

        emit log_named_uint("actor.numberOfCalls()---", actor.numberOfCalls());
        emit log_named_uint("actor.numberOfAtomDeposits()", actor.numberOfAtomDeposits());
        emit log_named_uint("actor.numberOfAtomRedeems()-", actor.numberOfAtomRedeems());
        emit log_named_uint("actor.numberOfTripleDeposits()", actor.numberOfTripleDeposits());
        emit log_named_uint("actor.numberOfTripleRedeems()", actor.numberOfTripleRedeems());
        emit log_named_uint("EthMultiVAULT ETH BALANCE---", address(ethMultiVault).balance);
    }
}
