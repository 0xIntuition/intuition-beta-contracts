// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";
import {Multicall3} from "../vendor/multicall/Multicall3.sol";

/**
 * @title  CustomMulticall3
 * @author 0xIntuition
 * @notice A utility contract of the Intuition protocol. It allows for custom multicall operations.
 */
contract CustomMulticall3 is Initializable, Ownable2StepUpgradeable, Multicall3 {
    /// @notice EthMultiVault contract instance
    EthMultiVault public ethMultiVault;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Struct containing data for an atom
     * @param vaultId The ID of the vault
     * @param atomUri The URI of the atom
     * @param atomHash The hash of the atom
     * @param totalAssets The total assets in the atom
     * @param totalShares The total shares in the atom
     */
    struct AtomData {
        uint256 vaultId;
        bytes atomUri;
        bytes32 atomHash;
        uint256 totalAssets;
        uint256 totalShares;
    }

    /**
     * @notice Struct containing data for a triple
     * @param vaultId The ID of the vault
     * @param subjectId The ID of the subject
     * @param predicateId The ID of the predicate
     * @param objectId The ID of the object
     * @param tripleHash The hash of the triple
     * @param totalAssets The total assets in the triple
     * @param totalShares The total shares in the triple
     */
    struct TripleData {
        uint256 vaultId;
        uint256 subjectId;
        uint256 predicateId;
        uint256 objectId;
        bytes32 tripleHash;
        uint256 totalAssets;
        uint256 totalShares;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Event emitted when the EthMultiVault contract address is set
     *  @param ethMultiVault EthMultiVault contract address
     */
    event EthMultiVaultSet(address indexed ethMultiVault);

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                                 INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CustomMulticall3 contract
     * @param _ethMultiVault EthMultiVault contract
     * @param admin The address of the admin
     */
    function initialize(address _ethMultiVault, address admin) external initializer {
        __Ownable_init(admin);
        ethMultiVault = EthMultiVault(payable(_ethMultiVault));
    }

    /*//////////////////////////////////////////////////////////////
                                 CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a triple based on the provided atom URIs in a single transaction,
     *          in situations where none of the atoms comprising the triple exist yet
     * @param atomUris Array of atom URIs to create an atom for
     * @param values Array of values to create the atoms and the triple
     * @return tripleId The ID of the created triple
     */
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

    /**
     * @notice Creates a triple with a new atom based on the provided atom URI in a single transaction, in
     *          situations where two of the atoms comprising the triple are known, and the third atom is new
     *          Example use case: First two atoms are known, e.g. "I" and "follow", and the third atom is the user to follow
     * @param atomUri Atom URI to create an atom for
     * @param atomIds Array of atom IDs to create the triple with
     * @param values Array of values to create the atom and the triple
     * @return tripleId The ID of the created triple
     */
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

    /**
     * @notice Creates multiple triples with a fixed predicate and object in a single transaction. Example use case:
     *          Many things may have the "has tag" predicate, and the object is a known tag, e.g. "bullish".
     * @param subjectIds Array of subject IDs to create the triples with
     * @param predicateId The ID of the predicate
     * @param objectId The ID of the object
     * @return tripleIds Array of IDs of the created triples
     */
    function batchCreateTripleWithFixedPredicateAndObject(
        uint256[] calldata subjectIds,
        uint256 predicateId,
        uint256 objectId
    ) external payable returns (uint256[] memory) {
        uint256 length = subjectIds.length;

        if (length == 0) {
            revert Errors.CustomMulticall3_EmptyArray();
        }

        if (msg.value < ethMultiVault.getTripleCost() * length) {
            revert Errors.CustomMulticall3_InsufficientValue();
        }

        uint256[] memory tripleIds = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            tripleIds[i] = ethMultiVault.createTriple{value: msg.value / length}(subjectIds[i], predicateId, objectId);
        }

        return tripleIds;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the user's ETH balance in a particular vault
     * @param vaultId The ID of the vault
     * @param bondingCurveId The ID of the bonding curve
     * @param user The address of the user
     * @return The user's ETH balance in the vault
     */
    function getUserEthBalanceInVault(uint256 vaultId, uint256 bondingCurveId, address user)
        public
        view
        returns (uint256)
    {
        (uint256 shares,) = ethMultiVault.getVaultStateForUserCurve(vaultId, bondingCurveId, user);
        return ethMultiVault.convertToAssetsCurve(shares, vaultId, bondingCurveId);
    }

    /**
     * @notice Gets the user's ETH balances in multiple vaults
     * @param ids Array of atom and/or triple IDs
     * @param user The address of the user
     * @return Array of user's ETH balances in the vaults
     */
    function getBatchUserEthBalancesInVaults(uint256[] calldata ids, uint256[] calldata bondingCurveIds, address user)
        external
        view
        returns (uint256[] memory)
    {
        uint256 numIds = ids.length;
        uint256 numBondingCurveIds = bondingCurveIds.length;

        if (numIds == 0 || numBondingCurveIds == 0) {
            revert Errors.CustomMulticall3_EmptyArray();
        }

        if (numBondingCurveIds != numIds) {
            revert Errors.CustomMulticall3_ArraysNotSameLength();
        }

        uint256[] memory balances = new uint256[](numIds);

        for (uint256 i = 0; i < numIds; i++) {
            balances[i] = getUserEthBalanceInVault(ids[i], bondingCurveIds[i], user);
        }

        return balances;
    }

    /**
     * @notice Gets the data for multiple atoms
     * @param atomIds Array of atom IDs
     * @return Array of AtomData structs
     */
    function batchGetAtomData(uint256[] calldata atomIds) external view returns (AtomData[] memory) {
        uint256 length = atomIds.length;

        if (length == 0) {
            revert Errors.CustomMulticall3_EmptyArray();
        }

        AtomData[] memory atomData = new AtomData[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 atomId = atomIds[i];

            if (ethMultiVault.isTripleId(atomId)) {
                revert Errors.CustomMulticall3_VaultIsTriple(atomId);
            }

            bytes memory atomUri = ethMultiVault.atoms(atomId);
            bytes32 atomHash = keccak256(atomUri);
            (uint256 totalAssets, uint256 totalShares) = ethMultiVault.vaults(atomId);

            atomData[i] = AtomData({
                vaultId: atomId,
                atomUri: atomUri,
                atomHash: atomHash,
                totalAssets: totalAssets,
                totalShares: totalShares
            });
        }

        return atomData;
    }

    /**
     * @notice Gets the data for multiple triples
     * @param tripleIds Array of triple IDs
     * @return Array of TripleData structs
     */
    function batchGetTripleData(uint256[] calldata tripleIds) external view returns (TripleData[] memory) {
        uint256 length = tripleIds.length;

        if (length == 0) {
            revert Errors.CustomMulticall3_EmptyArray();
        }

        TripleData[] memory tripleData = new TripleData[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 tripleId = tripleIds[i];

            if (!ethMultiVault.isTripleId(tripleId)) {
                revert Errors.CustomMulticall3_VaultNotTriple(tripleId);
            }

            (uint256 subjectId, uint256 predicateId, uint256 objectId) = ethMultiVault.getTripleAtoms(tripleId);
            bytes32 tripleHash = ethMultiVault.tripleHashFromAtoms(subjectId, predicateId, objectId);
            (uint256 totalAssets, uint256 totalShares) = ethMultiVault.vaults(tripleId);

            tripleData[i] = TripleData({
                vaultId: tripleId,
                subjectId: subjectId,
                predicateId: predicateId,
                objectId: objectId,
                tripleHash: tripleHash,
                totalAssets: totalAssets,
                totalShares: totalShares
            });
        }

        return tripleData;
    }

    /**
     * @notice Gets the user's shares in multiple vaults
     * @param user The address of the user
     * @param ids Array of atom and/or triple IDs
     * @return Array of user's shares in the vaults
     */
    function batchGetUserShares(address user, uint256[] calldata ids) external view returns (uint256[] memory) {
        if (user == address(0)) {
            revert Errors.CustomMulticall3_AddressZero();
        }

        uint256 length = ids.length;

        if (length == 0) {
            revert Errors.CustomMulticall3_EmptyArray();
        }

        uint256[] memory userShares = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            (uint256 shares,) = ethMultiVault.getVaultStateForUser(ids[i], user);
            userShares[i] = shares;
        }

        return userShares;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the EthMultiVault contract address
     * @param _ethMultiVault EthMultiVault contract address
     */
    function setEthMultiVault(address _ethMultiVault) external onlyOwner {
        if (_ethMultiVault == address(0)) {
            revert Errors.CustomMulticall3_InvalidEthMultiVaultAddress();
        }

        ethMultiVault = EthMultiVault(payable(_ethMultiVault));

        emit EthMultiVaultSet(_ethMultiVault);
    }
}
