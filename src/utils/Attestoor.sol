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

    /// @dev See {IEthMultiVault-depositAtom}
    function depositAtom(address receiver, uint256 id) external payable onlyWhitelistedAttestor returns (uint256) {
        uint256 shares = ethMultiVault.depositAtom{value: msg.value}(receiver, id);
        return shares;
    }

    /// @dev See {IEthMultiVault-depositTriple}
    function depositTriple(address receiver, uint256 id) external payable onlyWhitelistedAttestor returns (uint256) {
        uint256 shares = ethMultiVault.depositTriple{value: msg.value}(receiver, id);
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

    /// @dev See {IEthMultiVault-redeemTriple}
    function redeemTriple(uint256 shares, address receiver, uint256 id)
        external
        onlyWhitelistedAttestor
        returns (uint256)
    {
        uint256 assets = ethMultiVault.redeemTriple(shares, receiver, id);
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
}
