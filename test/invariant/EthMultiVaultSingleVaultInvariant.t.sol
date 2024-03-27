// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

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

        // deploy actor
        actor = new EthMultiVaultSingleVaultActor(ethMultiVault);

        // target actor
        targetContract(address(actor));

        // selectors for actor functions
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = actor.depositAtom.selector; // depositAtom
        selectors[1] = actor.redeemAtom.selector; // redeemAtom

        FuzzSelector memory fuzzSelector = FuzzSelector({addr: address(actor), selectors: selectors});

        // target the functions in the actor contract
        targetSelector(fuzzSelector);
    }

    function invariant_ethMultiVault_single() external {
        // assets less than or equal to eth balance
        invariant_ethMultiVault_asset_solvency();
        emit log_named_uint("actor.numberOfCalls()---", actor.numberOfCalls());
        emit log_named_uint("actor.numberOfDeposits()", actor.numberOfDeposits());
        emit log_named_uint("actor.numberOfRedeems()-", actor.numberOfRedeems());
        emit log_named_uint("EthMultiVAULT ETH BALANCE---", address(ethMultiVault).balance);
    }
}
