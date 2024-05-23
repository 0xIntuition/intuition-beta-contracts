// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {EthMultiVaultActor} from "./actors/EthMultiVaultActor.sol";
import {InvariantEthMultiVaultBase} from "./InvariantEthMultiVaultBase.sol";

contract EthMultiVaultBasicInvariantTest is InvariantEthMultiVaultBase {
    // actor contracts
    EthMultiVaultActor public actor;

    // actor arrays
    uint256[] public actorPks;
    address[] public actors;

    function setUp() public override {
        super.setUp();

        // deploy actor
        actor = new EthMultiVaultActor(ethMultiVault);

        // target actor
        targetContract(address(actor));

        // selectors for actor functions
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = actor.createAtom.selector; // createAtom
        selectors[1] = actor.depositAtom.selector; // depositAtom
        selectors[2] = actor.redeemAtom.selector; // redeemAtom
        selectors[3] = actor.createTriple.selector; // createTriple
        selectors[4] = actor.depositTriple.selector; // depositTriple
        selectors[5] = actor.redeemTriple.selector; // redeemTriple

        FuzzSelector memory fuzzSelector = FuzzSelector({addr: address(actor), selectors: selectors});

        // target the functions in the actor contract
        targetSelector(fuzzSelector);
    }

    function invariant_ethMultiVault_solvent() external {
        // assets less than or equal to eth balance
        invariant_ethMultiVault_asset_solvency();
        // shares less than or equal to assets
        invariant_ethMultiVault_share_solvency();

        emit log_named_uint("actor.numberOfCalls()---", actor.numberOfCalls());
        emit log_named_uint("actor.numberOfAtoms()---", actor.numberOfAtoms());
        emit log_named_uint("actor.numberOfAtomDeposits()", actor.numberOfAtomDeposits());
        emit log_named_uint("actor.numberOfAtomRedeems()-", actor.numberOfAtomRedeems());
        emit log_named_uint("actor.numberOfTriples()---", actor.numberOfTriples());
        emit log_named_uint("actor.numberOfTripleDeposits()", actor.numberOfTripleDeposits());
        emit log_named_uint("actor.numberOfTripleRedeems()", actor.numberOfTripleRedeems());
        emit log_named_uint("ETHMULTIVAULT ETH BALANCE---", address(ethMultiVault).balance);
    }
}
