// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {Errors} from "src/libraries/Errors.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {Multicall3} from "src/utils/MultiCall3.sol";

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
    /// @return tripleId The ID of the created triple
    function createClaim(bytes[] calldata atomUris) external payable returns (uint256) {
        if (atomUris.length != 3) {
            revert Errors.Multicall3_InvalidAtomUrisLength();
        }

        uint256 totalAtomCost = ethMultiVault.getAtomCost() * atomUris.length;
        uint256 tripleCost = ethMultiVault.getTripleCost();

        if ((totalAtomCost + tripleCost) != msg.value) {
            revert Errors.Multicall3_InvalidValue();
        }

        uint256[] memory atomIds = new uint256[](atomUris.length);
        atomIds = ethMultiVault.batchCreateAtom{value: totalAtomCost}(atomUris);

        uint256 tripleId = ethMultiVault.createTriple{value: tripleCost}(atomIds[0], atomIds[1], atomIds[2]);

        return tripleId;
    }
}
