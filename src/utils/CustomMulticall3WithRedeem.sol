// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {CustomMulticall3} from "src/utils/CustomMulticall3.sol";

import {Errors} from "src/libraries/Errors.sol";

/**
 * @title  CustomMulticall3WithRedeem
 * @author 0xIntuition
 * @notice A modified CustomMulticall3 contract that allows for redeeming assets from the multiple vaults
 *            in a single transaction. It is intended to be used by the single admin only.
 */
contract CustomMulticall3WithRedeem is CustomMulticall3 {
    /**
     * @notice Redeems a specific amount of shares for a given owner and transfers the assets to the receiver
     * @dev `ids` need to represent either atom or triple vaults, and not a mix of both
     * @dev This contract needs to be an approved redeemer for each owner
     * @param owners The owners of the shares to redeem
     * @param shares The amount of shares to redeem
     * @param receivers The receivers of the assets
     * @param ids The IDs of the atoms or triples to redeem
     * @param isTriple Boolean indicating whether the assets to redeem are from atom or triple vaults
     * @return assetsForReceivers The amount of assets received by the receivers
     */
    function batchRedeem(
        address[] calldata owners,
        uint256[] calldata shares,
        address[] calldata receivers,
        uint256[] calldata ids,
        bool isTriple
    ) external onlyOwner returns (uint256[] memory) {
        uint256 length = owners.length;

        if (length == 0) {
            revert Errors.CustomMulticall3_ZeroLengthArray();
        }

        if (length != shares.length || length != receivers.length || length != ids.length) {
            revert Errors.CustomMulticall3_ArraysNotSameLength();
        }

        uint256[] memory assetsForReceivers = new uint256[](length);
        if (isTriple) {
            for (uint256 i = 0; i < length; i++) {
                assetsForReceivers[i] = ethMultiVault.redeemTriple(owners[i], shares[i], receivers[i], ids[i]);
            }
        } else {
            for (uint256 i = 0; i < length; i++) {
                assetsForReceivers[i] = ethMultiVault.redeemAtom(owners[i], shares[i], receivers[i], ids[i]);
            }
        }

        return assetsForReceivers;
    }
}
