// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {Errors} from "src/libraries/Errors.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";

/**
 * @title  Attestoor
 * @author 0xIntuition
 * @notice A utility contract of the Intuition protocol. It allows for the whitelisted accounts to attest
 *         on behalf of the Intuiton itself, effectively acting as an official attestoor account.
 */
contract Attestoor is Initializable, Ownable2StepUpgradeable {
    /// @notice The EthMultiVault contract address
    IEthMultiVault public ethMultiVault;

    /// @notice Mapping of whitelisted attestors
    mapping(address => bool) public whitelistedAttestors;

    /// @notice Event emitted when the EthMultiVault contract address is set
    /// @param ethMultiVault EthMultiVault contract address
    event EthMultiVaultSet(IEthMultiVault ethMultiVault);

    /// @notice Event emitted when an attestor is whitelisted or blacklisted
    ///
    /// @param attestor The address of the attestor
    /// @param whitelisted Whether the attestor is whitelisted or not
    event WhitelistedAttestorSet(address attestor, bool whitelisted);

    /// @notice Modifier to allow only whitelisted attestors to call a function
    modifier onlyWhitelistedAttestor() {
        if (!whitelistedAttestors[msg.sender]) {
            revert Errors.Attestoor_NotAWhitelistedAttestor();
        }
        _;
    }

    /// @notice Initializes the Attestoor contract
    ///
    /// @param admin The address of the admin
    /// @param _ethMultiVault EthMultiVault contract
    function init(address admin, IEthMultiVault _ethMultiVault) external initializer {
        __Ownable_init(admin);
        ethMultiVault = _ethMultiVault;
        whitelistedAttestors[admin] = true;
    }

    /// @dev See {IEthMultiVault-createAtom}
    function createAtom(bytes calldata atomUri) external payable onlyWhitelistedAttestor returns (uint256) {
        uint256 id = ethMultiVault.createAtom{value: msg.value}(atomUri);
        return id;
    }

    /// @dev See {IEthMultiVault-batchCreateAtom}
    function batchCreateAtom(bytes[] calldata atomUris)
        external
        payable
        onlyWhitelistedAttestor
        returns (uint256[] memory)
    {
        uint256[] memory ids = ethMultiVault.batchCreateAtom{value: msg.value}(atomUris);
        return ids;
    }

    /// @notice Creates multiple atom vaults with different values in a single transaction
    ///
    /// @param atomUris Array of atom URIs
    /// @param values Array of asset values to create the vaults
    ///
    /// @return ids Array of atom vault IDs
    function batchCreateAtomDifferentValues(bytes[] calldata atomUris, uint256[] calldata values)
        external
        payable
        onlyWhitelistedAttestor
        returns (uint256[] memory)
    {
        if (atomUris.length != values.length) {
            revert Errors.Attestoor_WrongArrayLengths();
        }

        uint256 sum = _getSum(values);

        if (msg.value < sum) {
            revert Errors.Attestoor_InsufficientValue();
        }

        uint256[] memory ids = new uint256[](atomUris.length);

        for (uint256 i = 0; i < atomUris.length; i++) {
            ids[i] = ethMultiVault.createAtom{value: values[i]}(atomUris[i]);
        }

        return ids;
    }

    /// @dev See {IEthMultiVault-createTriple}
    function createTriple(uint256 subjectId, uint256 predicateId, uint256 objectId)
        external
        payable
        onlyWhitelistedAttestor
        returns (uint256)
    {
        uint256 id = ethMultiVault.createTriple{value: msg.value}(subjectId, predicateId, objectId);
        return id;
    }

    /// @dev See {IEthMultiVault-batchCreateTriple}
    function batchCreateTriple(
        uint256[] calldata subjectIds,
        uint256[] calldata predicateIds,
        uint256[] calldata objectIds
    ) external payable onlyWhitelistedAttestor returns (uint256[] memory) {
        uint256[] memory ids = ethMultiVault.batchCreateTriple{value: msg.value}(subjectIds, predicateIds, objectIds);
        return ids;
    }

    /// @notice Creates multiple triple vaults with different values in a single transaction
    ///
    /// @param subjectIds Array of subject IDs
    /// @param predicateIds Array of predicate IDs
    /// @param objectIds Array of object IDs
    /// @param values Array of asset values to create the vaults
    ///
    /// @return ids Array of triple vault IDs
    function batchCreateTripleDifferentValues(
        uint256[] calldata subjectIds,
        uint256[] calldata predicateIds,
        uint256[] calldata objectIds,
        uint256[] calldata values
    ) external payable onlyWhitelistedAttestor returns (uint256[] memory) {
        if (subjectIds.length != predicateIds.length || predicateIds.length != objectIds.length) {
            revert Errors.Attestoor_WrongArrayLengths();
        }

        uint256 length = subjectIds.length;

        if (length != values.length) {
            revert Errors.Attestoor_WrongArrayLengths();
        }

        uint256 sum = _getSum(values);

        if (msg.value < sum) {
            revert Errors.Attestoor_InsufficientValue();
        }

        uint256[] memory ids = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            ids[i] = ethMultiVault.createTriple{value: values[i]}(subjectIds[i], predicateIds[i], objectIds[i]);
        }

        return ids;
    }

    /// @dev See {IEthMultiVault-depositAtom}
    function depositAtom(address receiver, uint256 id) external payable onlyWhitelistedAttestor returns (uint256) {
        uint256 shares = ethMultiVault.depositAtom{value: msg.value}(receiver, id);
        return shares;
    }

    /// @notice Deposits assets into multiple atom vaults in a single transaction
    ///
    /// @param receiver The address of the receiver
    /// @param ids Array of atom vault IDs
    /// @param values Array of asset values to deposit
    ///
    /// @return shares Array of shares received
    function batchDepositAtom(address receiver, uint256[] calldata ids, uint256[] calldata values)
        external
        payable
        onlyWhitelistedAttestor
        returns (uint256[] memory)
    {
        if (ids.length != values.length) {
            revert Errors.Attestoor_WrongArrayLengths();
        }

        uint256 sum = _getSum(values);

        if (msg.value < sum) {
            revert Errors.Attestoor_InsufficientValue();
        }

        uint256[] memory shares = new uint256[](ids.length);

        for (uint256 i = 0; i < ids.length; i++) {
            shares[i] = ethMultiVault.depositAtom{value: values[i]}(receiver, ids[i]);
        }

        return shares;
    }

    /// @dev See {IEthMultiVault-depositTriple}
    function depositTriple(address receiver, uint256 id) external payable onlyWhitelistedAttestor returns (uint256) {
        uint256 shares = ethMultiVault.depositTriple{value: msg.value}(receiver, id);
        return shares;
    }

    /// @notice Deposits assets into multiple triple vaults in a single transaction
    ///
    /// @param receiver The address of the receiver
    /// @param ids Array of triple vault IDs
    /// @param values Array of asset values to deposit
    ///
    /// @return shares Array of shares received
    function batchDepositTriple(address receiver, uint256[] calldata ids, uint256[] calldata values)
        external
        payable
        onlyWhitelistedAttestor
        returns (uint256[] memory)
    {
        if (ids.length != values.length) {
            revert Errors.Attestoor_WrongArrayLengths();
        }

        uint256 sum = _getSum(values);

        if (msg.value < sum) {
            revert Errors.Attestoor_InsufficientValue();
        }

        uint256[] memory shares = new uint256[](ids.length);

        for (uint256 i = 0; i < ids.length; i++) {
            shares[i] = ethMultiVault.depositTriple{value: values[i]}(receiver, ids[i]);
        }

        return shares;
    }

    /// @dev See {IEthMultiVault-redeemAtom}
    function redeemAtom(uint256 shares, address receiver, uint256 id)
        external
        onlyWhitelistedAttestor
        returns (uint256)
    {
        uint256 assets = ethMultiVault.redeemAtom(shares, receiver, id);
        return assets;
    }

    /// @notice Redeems shares from multiple atom vaults for assets in a single transaction
    ///
    /// @param shares Array of shares to redeem
    /// @param receiver The address of the receiver
    /// @param ids Array of atom vault IDs
    ///
    /// @return assets Array of assets received
    function batchRedeemAtom(uint256[] calldata shares, address receiver, uint256[] calldata ids)
        external
        onlyWhitelistedAttestor
        returns (uint256[] memory)
    {
        if (shares.length != ids.length) {
            revert Errors.Attestoor_WrongArrayLengths();
        }

        if (!_checkRedeemability(shares, ids)) {
            revert Errors.Attestoor_SharesCannotBeRedeeemed();
        }

        uint256[] memory assets = new uint256[](ids.length);

        for (uint256 i = 0; i < ids.length; i++) {
            assets[i] = ethMultiVault.redeemAtom(shares[i], receiver, ids[i]);
        }

        return assets;
    }

    /// @dev See {IEthMultiVault-redeemTriple}
    function redeemTriple(uint256 shares, address receiver, uint256 id)
        external
        onlyWhitelistedAttestor
        returns (uint256)
    {
        uint256 assets = ethMultiVault.redeemTriple(shares, receiver, id);
        return assets;
    }

    /// @notice Redeems shares from multiple triple vaults for assets in a single transaction
    ///
    /// @param shares Array of shares to redeem
    /// @param receiver The address of the receiver
    /// @param ids Array of triple vault IDs
    ///
    /// @return assets Array of assets received
    function batchRedeemTriple(uint256[] calldata shares, address receiver, uint256[] calldata ids)
        external
        onlyWhitelistedAttestor
        returns (uint256[] memory)
    {
        if (shares.length != ids.length) {
            revert Errors.Attestoor_WrongArrayLengths();
        }

        if (!_checkRedeemability(shares, ids)) {
            revert Errors.Attestoor_SharesCannotBeRedeeemed();
        }

        uint256[] memory assets = new uint256[](ids.length);

        for (uint256 i = 0; i < ids.length; i++) {
            assets[i] = ethMultiVault.redeemTriple(shares[i], receiver, ids[i]);
        }

        return assets;
    }

    /// @notice Sets the EthMultiVault contract address
    /// @param _ethMultiVault EthMultiVault contract address
    function setEthMultiVault(IEthMultiVault _ethMultiVault) external onlyOwner {
        if (address(_ethMultiVault) == address(0)) {
            revert Errors.Attestoor_InvalidEthMultiVaultAddress();
        }

        ethMultiVault = _ethMultiVault;

        emit EthMultiVaultSet(_ethMultiVault);
    }

    /// @notice Whitelists or blacklists an attestor
    ///
    /// @param attestor The address of the attestor
    /// @param whitelisted Whether the attestor is whitelisted or not
    function whitelistAttestor(address attestor, bool whitelisted) external onlyOwner {
        whitelistedAttestors[attestor] = whitelisted;

        emit WhitelistedAttestorSet(attestor, whitelisted);
    }

    /// @notice Whitelists or blacklists multiple attestors
    ///
    /// @param attestors Array of attestor addresses
    /// @param whitelisted Whether the attestors are whitelisted or not
    function batchWhitelistAttestors(address[] calldata attestors, bool whitelisted) external onlyOwner {
        uint256 length = attestors.length;

        if (length == 0) {
            revert Errors.Attestoor_EmptyAttestorsArray();
        }

        for (uint256 i = 0; i < length; i++) {
            whitelistedAttestors[attestors[i]] = whitelisted;

            emit WhitelistedAttestorSet(attestors[i], whitelisted);
        }
    }

    /// @dev Checks if all amounts of shares can be redeemed for assets from multiple vaults
    ///
    /// @param shares Array of shares to redeem
    /// @param ids Array of vault IDs
    ///
    /// @return bool Whether all shares can be redeemed or not
    function _checkRedeemability(uint256[] calldata shares, uint256[] calldata ids) internal view returns (bool) {
        if (shares.length != ids.length) {
            revert Errors.Attestoor_WrongArrayLengths();
        }

        for (uint256 i = 0; i < ids.length; i++) {
            if (ethMultiVault.maxRedeem(msg.sender, ids[i]) < shares[i]) {
                return false;
            }
        }

        return true;
    }

    /// @dev Computes the sum of an array of values
    /// @param values Array of uint256 values
    /// @return sum The sum of the values
    function _getSum(uint256[] calldata values) internal pure returns (uint256) {
        uint256 sum;

        for (uint256 i = 0; i < values.length; i++) {
            sum += values[i];
        }

        return sum;
    }
}
