// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {Errors} from "src/libraries/Errors.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {Multicall3} from "src/utils/Multicall3.sol";

/**
 * @title  CustomMulticall3 Library
 * @author 0xIntuition
 * @notice A utility contract of the Intuition protocol.
 *         It allows for the creation of claims (triples) based on atom URIs in a single transaction.
 */
contract CustomMulticall3 is Initializable, OwnableUpgradeable, Multicall3 {
    /// @notice EthMultiVault contract
    IEthMultiVault public ethMultiVault;

    /// @notice Initializes the CustomMulticall3 contract
    ///
    /// @param _ethMultiVault EthMultiVault contract
    /// @param admin The address of the admin
    function init(IEthMultiVault _ethMultiVault, address admin) external initializer {
        __Ownable_init(admin);
        ethMultiVault = _ethMultiVault;
    }

    /// @notice Creates a claim (triple) based on the provided atom URIs in a single transaction,
    ///         in situations where none of the atoms comprising the triple exist yet
    ///
    /// @param atomUris Array of atom URIs to create an atom for
    /// @param values Array of values to create the atoms and the triple
    ///
    /// @return tripleId The ID of the created triple
    function createTripleFromNewAtoms(bytes[] calldata atomUris, uint256[] calldata values)
        external
        payable
        returns (uint256)
    {
        if (atomUris.length != 3) {
            revert Errors.CustomMulticall3_InvalidAtomUrisLength();
        }

        if (values.length != 4) {
            revert Errors.CustomMulticall3_InvalidValuesLength();
        }

        uint256 atomCost = ethMultiVault.getAtomCost();
        uint256 length = atomUris.length;
        uint256 totalAtomCost = atomCost * length;
        uint256 tripleCost = ethMultiVault.getTripleCost();

        if ((totalAtomCost + tripleCost) > msg.value) {
            revert Errors.CustomMulticall3_InsufficientValue();
        }

        if (values[0] < atomCost || values[1] < atomCost || values[2] < atomCost || values[3] < tripleCost) {
            revert Errors.CustomMulticall3_InvalidValue();
        }

        uint256[] memory atomIds = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            atomIds[i] = ethMultiVault.createAtom{value: values[i]}(atomUris[i]);
        }

        uint256 tripleId = ethMultiVault.createTriple{value: values[3]}(atomIds[0], atomIds[1], atomIds[2]);

        return tripleId;
    }

    /// @notice Creates a triple with a new atom based on the provided atom URI in a single transaction, in
    ///         situations where two of the atoms comprising the triple are known, and the third atom is new
    ///         Example use case: First two atoms are known, e.g. "I" and "follow", and the third atom is the user to follow
    ///
    /// @param atomUri Atom URI to create an atom for
    /// @param atomIds Array of atom IDs to create the triple with
    /// @param values Array of values to create the atom and the triple
    ///
    /// @return tripleId The ID of the created triple
    function createTripleWithNewAtom(bytes calldata atomUri, uint256[] calldata atomIds, uint256[] calldata values)
        external
        payable
        returns (uint256)
    {
        if (atomIds.length != 2) {
            revert Errors.CustomMulticall3_InvalidAtomIdsLength();
        }

        if (values.length != 2) {
            revert Errors.CustomMulticall3_InvalidValuesLength();
        }

        uint256 atomCost = ethMultiVault.getAtomCost();
        uint256 tripleCost = ethMultiVault.getTripleCost();

        if ((atomCost + tripleCost) > msg.value) {
            revert Errors.CustomMulticall3_InsufficientValue();
        }

        if (values[0] < atomCost || values[1] < tripleCost) {
            revert Errors.CustomMulticall3_InvalidValue();
        }

        uint256 newAtomId = ethMultiVault.createAtom{value: values[0]}(atomUri);

        uint256 tripleId = ethMultiVault.createTriple{value: values[1]}(atomIds[0], atomIds[1], newAtomId);

        return tripleId;
    }

    /// @notice Sets the EthMultiVault contract address
    /// @param _ethMultiVault EthMultiVault contract address
    function setEthMultiVault(IEthMultiVault _ethMultiVault) external onlyOwner {
        ethMultiVault = _ethMultiVault;
    }
}
