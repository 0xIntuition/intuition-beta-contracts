// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {CustomMulticall3} from "src/utils/CustomMulticall3.sol";

import {Errors} from "src/libraries/Errors.sol";

/**
 * @title  CustomMulticall3BatchRedeem
 * @author 0xIntuition
 * @notice A modified CustomMulticall3 contract that allows for redeeming assets from the multiple vaults
 *         in a single transaction. It is intended to be used by the single admin only, for example in the
 *         situations where the admin needs to redeem assets for multiple users and/or vaults at once.
 */
contract CustomMulticall3BatchRedeem is CustomMulticall3 {
    /**
     * @notice Redeems a specific amount of shares for a given owner and transfers the assets to the receiver
     * @dev `ids` need to represent either atom or triple vaults, and not a mix of both
     * @dev This contract needs to be an approved redeemer for each owner
     * @param owners The owners of the shares to redeem (receivers == owners in this case)
     * @param shares The amount of shares to redeem
     * @param ids The IDs of the atoms or triples to redeem
     * @param areTriples Boolean indicating whether the assets to redeem are from atom or triple vaults
     * @return assetsForReceivers The amount of assets received by the receivers
     */
    function batchRedeem(
        address[] calldata owners,
        uint256[] calldata shares,
        uint256[] calldata ids,
        bool areTriples
    ) external onlyOwner returns (uint256[] memory) {
        uint256 length = owners.length;

        if (length == 0) {
            revert Errors.CustomMulticall3_EmptyArray();
        }

        if (length != shares.length || length != ids.length) {
            revert Errors.CustomMulticall3_ArraysNotSameLength();
        }

        uint256[] memory assetsForReceivers = new uint256[](length);
        if (areTriples) {
            for (uint256 i = 0; i < length; i++) {
                assetsForReceivers[i] = ethMultiVault.redeemTriple(owners[i], shares[i], owners[i], ids[i]);
            }
        } else {
            for (uint256 i = 0; i < length; i++) {
                assetsForReceivers[i] = ethMultiVault.redeemAtom(owners[i], shares[i], owners[i], ids[i]);
            }
        }

        return assetsForReceivers;
    }

    // batchDeposit
}
