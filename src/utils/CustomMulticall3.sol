// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {Errors} from "src/libraries/Errors.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {Multicall3} from "src/utils/Multicall3.sol";

/**
 * @title  AtomWallet
 * @author 0xIntuition
 * @notice Core contract of the Intuition protocol. This contract is an abstract account
 *         associated with a corresponding atom.
 */
contract CustomMulticall3 is Initializable, Multicall3 {
    /// @notice EthMultiVault contract
    IEthMultiVault public ethMultiVault;

    /// @notice Initializes the CustomMulticall3 contract
    /// @param _ethMultiVault EthMultiVault contract
    function init(IEthMultiVault _ethMultiVault) external initializer {
        ethMultiVault = _ethMultiVault;
    }

    /// @notice Creates a claim (triple) based on the provided atom URIs in a single transaction
    /// @param atomUris Array of atom URIs to create an atom for
    /// @param values Array of values to create the atoms and the triple
    /// @return tripleId The ID of the created triple
    function createClaim(bytes[] calldata atomUris, uint256[] calldata values) external payable returns (uint256) {
        if (atomUris.length != 3) {
            revert Errors.Multicall3_InvalidAtomUrisLength();
        }

        if (values.length != 4) {
            revert Errors.Multicall3_InvalidValuesLength();
        }

        uint256 atomCost = ethMultiVault.getAtomCost();
        uint256 length = atomUris.length;
        uint256 totalAtomCost = atomCost * length;
        uint256 tripleCost = ethMultiVault.getTripleCost();

        if ((totalAtomCost + tripleCost) > msg.value) {
            revert Errors.Multicall3_InsufficientValue();
        }

        if (values[0] < atomCost || values[1] < atomCost || values[2] < atomCost || values[3] < tripleCost) {
            revert Errors.Multicall3_InvalidValue();
        }

        uint256[] memory atomIds = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            atomIds[i] = ethMultiVault.createAtom{value: values[i]}(atomUris[i]);
        }

        uint256 tripleId = ethMultiVault.createTriple{value: values[3]}(atomIds[0], atomIds[1], atomIds[2]);

        return tripleId;
    }
}
