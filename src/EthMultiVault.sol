// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {AtomWallet} from "src/AtomWallet.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {LibZip} from "solady/utils/LibZip.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {IEntryPoint} from "account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {Types} from "src/libraries/Types.sol";
import {Errors} from "src/libraries/Errors.sol";

/**
 * @title  EthMultiVault
 * @author 0xIntuition
 * @notice Core contract of the Intuition protocol. Manages the creation and management of vaults
 *         associated to Atom's & Triples
 */
contract EthMultiVault is
    IEthMultiVault,
    Initializable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using FixedPointMathLib for uint256;
    using LibZip for bytes;

    /* =================================================== */
    /*                  STATE VARIABLES                    */
    /* =================================================== */

    GeneralConfig public generalConfig;
    AtomConfig public atomConfig;
    TripleConfig public tripleConfig;
    WalletConfig public walletConfig;

    /// @notice ID of the last vault to be created
    uint256 public count;

    struct VaultState {
        uint256 totalAssets;
        uint256 totalShares;
        // address -> balanceOf, amount of shares an account has in a vault
        mapping(address => uint256) balanceOf;
    }

    struct VaultFees {
        // entry fee for vault 0 is considered the default entry fee
        uint256 entryFee;
        // exit fee for each vault, exit fee for vault 0 is considered the default exit fee
        uint256 exitFee;
        // protocol fee for each vault, protocol fee for vault 0 is considered the default protocol fee
        uint256 protocolFee;
    }

    mapping(uint256 => VaultState) public vaults;
    mapping(uint256 => VaultFees) public vaultFees;

    /// @notice RDF (Resource Description Framework)
    // mapping of vault ID to atom data
    // Vault ID -> Atom Data
    mapping(uint256 => bytes) public atoms;

    // mapping of atom hash to atom vault ID
    // Hash -> Atom ID
    mapping(bytes32 => uint256) public AtomsByHash;

    // mapping of triple vault ID to the underlying atom IDs that make up the triple
    // Triple ID -> VaultIDs of atoms that make up the triple
    mapping(uint256 => uint256[3]) public triples;

    // mapping of triple hash to triple vault ID
    // Hash -> Triple ID
    mapping(bytes32 => uint256) public TriplesByHash;

    // mapping of triple vault IDs to determine whether a vault is a triple or not
    // Vault ID -> (Is Triple)
    mapping(uint256 => bool) public isTriple;

    /// @notice Atom Equity Tracking
    /// used to enable atom shares earned from triple deposits to be redeemed proportionally
    /// to the triple shares that earned them upon redemption/withdraw
    /// Triple ID -> Atom ID -> Account Address -> Atom Share Balance
    mapping(uint256 => mapping(uint256 => mapping(address => uint256)))
        public tripleAtomShares;

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    /// @dev Initializes the MultiVault contract
    function init(
        GeneralConfig memory _generalConfig,
        AtomConfig memory _atomConfig,
        TripleConfig memory _tripleConfig,
        WalletConfig memory _walletConfig
    ) external initializer {
        __ReentrancyGuard_init();
        __Pausable_init();

        generalConfig = _generalConfig;
        atomConfig = _atomConfig;
        tripleConfig = _tripleConfig;
        walletConfig = _walletConfig;
    }

    /* =================================================== */
    /*                       VIEWS                         */
    /* =================================================== */

    /* -------------------------- */
    /*         Fee Helpers        */
    /* -------------------------- */

    function getAtomCost() public view returns (uint256 atomCost) {
        atomCost =
            atomConfig.atomCreationFee + // paid to protocol
            atomConfig.atomShareLockFee + // for purchasing shares for atom wallet
            generalConfig.minShare; // for purchasing ghost shares
    }

    function getTripleCost() public view returns (uint256 tripleCost) {
        tripleCost =
            tripleConfig.tripleCreationFee + // paid to protocol
            generalConfig.minShare *
            2; // for purchasing ghost shares for the positive and counter triple vaults
    }

    function getDepositFees(
        uint256 assets,
        uint256 id
    ) public view returns (uint256 totalFees) {
        uint256 protocolFees = protocolFeeAmount(assets, id);

        totalFees =
            entryFeeAmount(assets, id) +
            atomEquityFeeAmount(assets - protocolFees, id) +
            protocolFees;
    }

    /// @notice calculates fee on raw amount
    /// @param amount amount of assets to calculate fee on
    /// @param fee fee in %
    /// @return amount of assets that would be charged as fee
    function feeOnRaw(
        uint256 amount,
        uint256 fee
    ) internal view returns (uint256) {
        return amount.mulDivUp(fee, generalConfig.feeDenominator);
    }

    ///
    /// @notice returns amount of assets that would be charged for the entry fee given an amount of 'assets' provided
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    /// @return feeAmount amount of assets that would be charged for the entry fee
    /// NOTE: if the vault being deposited on has a vault total shares of 0, the entry fee is not applied
    function entryFeeAmount(
        uint256 assets,
        uint256 id
    ) public view returns (uint256 feeAmount) {
        feeAmount = feeOnRaw(
            assets,
            vaultFees[id].entryFee == 0
                ? vaultFees[0].entryFee
                : vaultFees[id].entryFee
        );
    }

    /// @notice returns amount of assets that would be charged for the exit fee given an amount of 'assets' provided
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    /// @return feeAmount amount of assets that would be charged for the exit fee
    /// NOTE: if the vault  being redeemed from given the shares to redeem results in a total shares after of 0,
    ///       the exit fee is not applied
    function exitFeeAmount(
        uint256 assets,
        uint256 id
    ) public view returns (uint256 feeAmount) {
        feeAmount = feeOnRaw(
            assets,
            vaultFees[id].exitFee == 0
                ? vaultFees[0].exitFee
                : vaultFees[id].exitFee
        );
    }

    /// @notice returns amount of assets that would be charged by a vault on protocol fee given amount of 'assets'
    ///         provided
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    /// @return feeAmount amount of assets that would be charged by vault on protocol fee
    /// NOTE: on deposit
    function protocolFeeAmount(
        uint256 assets,
        uint256 id
    ) public view returns (uint256 feeAmount) {
        feeAmount = feeOnRaw(
            assets,
            vaultFees[id].protocolFee == 0
                ? vaultFees[0].protocolFee
                : vaultFees[id].protocolFee
        );
    }

    /// @notice returns amount of assets that would be charged by vault for atom equity on entry given amount
    ///         of 'assets' provided
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id
    /// @return feeAmount amount of assets that would be charged by vault for atom equity on entry
    /// NOTE: only applies to triple vaults
    function atomEquityFeeAmount(
        uint256 assets,
        uint256 id
    ) public view returns (uint256 feeAmount) {
        feeAmount = assertTriple(id)
            ? feeOnRaw(assets, tripleConfig.atomEquityFeeForTriple)
            : 0;
    }

    /* -------------------------- */
    /*     Accounting Helpers     */
    /* -------------------------- */

    /// @notice returns amount of shares that would be exchanged by vault given amount of 'assets' provided
    /// @param assets amount of assets to calculate shares on
    /// @param id vault id to get corresponding shares for
    /// @return shares amount of shares that would be exchanged by vault given amount of 'assets' provided
    function convertToShares(
        uint256 assets,
        uint256 id
    ) public view returns (uint256 shares) {
        uint256 supply = vaults[id].totalShares;
        shares = supply == 0
            ? assets
            : assets.mulDiv(supply, vaults[id].totalAssets);
    }

    /// @notice returns amount of assets that would be exchanged by vault given amount of 'shares' provided
    /// @param shares amount of shares to calculate assets on
    /// @param id vault id to get corresponding assets for
    /// @return assets amount of assets that would be exchanged by vault given amount of 'shares' provided
    function convertToAssets(
        uint256 shares,
        uint256 id
    ) public view returns (uint256 assets) {
        uint256 supply = vaults[id].totalShares;
        assets = supply == 0
            ? shares
            : shares.mulDiv(vaults[id].totalAssets, supply);
    }

    function currentSharePrice(
        uint256 id
    ) external view returns (uint256 price) {
        price = vaults[id].totalShares == 0
            ? 0
            : (vaults[id].totalAssets * 1e18) / vaults[id].totalShares;
    }

    /// @notice simulates the effects of the deposited amount of 'assets' and returns the estimated
    ///         amount of shares that would be minted from the deposit of `assets`
    /// @param assets amount of assets to calculate shares on
    /// @param id vault id to get corresponding shares for
    /// @return shares amount of shares that would be minted from the deposit of `assets`
    /// NOTE: this function pessimistically estimates the amount of shares that would be minted from the
    ///       input amount of assets so if the vault is empty before the deposit the caller receives more
    ///       shares than returned by this function, reference internal _depositIntoVault logic for details
    function previewDeposit(
        uint256 assets, // should always be msg.value
        uint256 id
    ) public view returns (uint256 shares) {
        uint256 totalFees = getDepositFees(assets, id);

        if (assets < totalFees) {
            revert Errors.MultiVault_InsufficientDepositAmountToCoverFees();
        }

        uint256 totalAssetsDelta = assets - totalFees;
        shares = convertToShares(totalAssetsDelta, id);
    }

    /// @notice simulates the effects of the redemption of `shares` and returns the estimated
    ///         amount of assets estimated to be returned to the receiver of the redeem
    /// @param shares amount of shares to calculate assets on
    /// @param id vault id to get corresponding assets for
    /// @return assets amount of assets estimated to be returned to the receiver
    /// NOTE: this function pessimistically estimates the amount of assets that would be returned to the
    ///       receiver so in the case that the vault is empty after the redeem the receiver will receive
    ///       more assets than what is returned by this function, reference internal _redeem logic for details
    function previewRedeem(
        uint256 shares,
        uint256 id
    ) public view returns (uint256 assets, uint256 exitFees) {
        assets = convertToAssets(shares, id);
        exitFees = exitFeeAmount(assets, id);
        assets -= exitFees;
    }

    /// @notice returns max amount of shares that can be redeemed from the 'owner' balance through a redeem call
    /// @param owner address of the account to get max redeemable shares for
    /// @param id vault id to get corresponding shares for
    /// @return shares amount of shares that can be redeemed from the 'owner' balance through a redeem call
    function maxRedeem(
        address owner,
        uint256 id
    ) external view returns (uint256 shares) {
        return vaults[id].balanceOf[owner];
    }

    /* -------------------------- */
    /*       Triple Helpers       */
    /* -------------------------- */

    /// @notice returns the corresponding hash for the given RDF triple, given the atoms that make up the triple
    /// @param subjectId the subject atom's vault id
    /// @param predicateId the predicate atom's vault id
    /// @param objectId the object atom's vault id
    /// @return hash the corresponding hash for the given RDF triple based on the atom vault ids
    function tripleHashFromAtoms(
        uint256 subjectId,
        uint256 predicateId,
        uint256 objectId
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(subjectId, predicateId, objectId));
    }

    /// @notice returns the corresponding hash for the given RDF triple, given the triple vault id
    /// @param id vault id of the triple
    /// @return hash the corresponding hash for the given RDF triple
    /// NOTE: only applies to triple vault IDs as input
    function tripleHash(uint256 id) public view returns (bytes32) {
        uint256[3] memory atomIds;
        (atomIds[0], atomIds[1], atomIds[2]) = getTripleAtoms(id);
        return keccak256(abi.encodePacked(atomIds[0], atomIds[1], atomIds[2]));
    }

    /// @notice returns whether the supplied vault id is a triple
    /// @param id vault id to check
    /// @return bool whether the supplied vault id is a triple
    function assertTriple(uint256 id) public view returns (bool) {
        return
            id > type(uint256).max / 2
                ? isTriple[type(uint256).max - id]
                : isTriple[id];
    }

    /// @notice returns the atoms that make up a triple/counter-triple
    /// @param id vault id of the triple/counter-triple
    /// @return tuple(atomIds) the atoms that make up the triple/counter-triple
    /// NOTE: only applies to triple vault IDs as input
    function getTripleAtoms(
        uint256 id
    ) public view returns (uint256, uint256, uint256) {
        uint256[3] memory atomIds = id > type(uint256).max / 2
            ? triples[type(uint256).max - id]
            : triples[id];
        return (atomIds[0], atomIds[1], atomIds[2]);
    }

    /// @notice returns the counter id from the given triple id
    /// @param id vault id of the triple
    /// @return counterId the counter vault id from the given triple id
    /// NOTE: only applies to triple vault IDs as input
    function getCounterIdFromTriple(uint256 id) public pure returns (uint256) {
        return type(uint256).max - id;
    }

    /* -------------------------- */
    /*        Misc. Helpers       */
    /* -------------------------- */

    function getVaultBalance(
        uint256 vaultId,
        address user
    ) external view returns (uint256) {
        return vaults[vaultId].balanceOf[user];
    }

    /// @dev hasCounterStake - returns whether the account has any shares in the vault counter to the id provided
    function hasCounterStake(
        uint256 id,
        address account
    ) internal view returns (bool) {
        return vaults[type(uint256).max - id].balanceOf[account] > 0;
    }

    /// @notice returns the Atom Wallet address for the given atom data
    /// @param id vault id of the atom associated to the atom wallet
    /// @return atomWallet the address of the atom wallet
    /// NOTE: the create2 salt is based off of the vault ID
    function computeAtomWalletAddr(uint256 id) public view returns (address) {
        bytes memory code = type(AtomWallet).creationCode;
        bytes memory encodedArgs = abi.encode(
            IEntryPoint(walletConfig.entryPoint),
            walletConfig.atomWarden
        );
        bytes memory data = abi.encodePacked(code, encodedArgs);
        bytes32 salt = bytes32(id);
        bytes32 rawAddress = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(data))
        );
        return address(bytes20(rawAddress << 96));
    }

    /* =================================================== */
    /*                MUTATIVE FUNCTIONS                   */
    /* =================================================== */

    /* -------------------------- */
    /*         Atom Wallet        */
    /* -------------------------- */

    /// @notice deploy a given atom wallet
    /// @param atomId vault id of atom
    /// @return atomWallet the address of the atom wallet
    /// NOTE: deploys an ERC4337 account (atom wallet)
    function deployAtomWallet(
        uint256 atomId
    ) external whenNotPaused returns (address atomWallet) {
        // compute salt
        bytes32 salt = bytes32(atomId);
        // get creation code
        bytes memory code = type(AtomWallet).creationCode;
        // encode constructor arguments (IEntryPoint, address)
        bytes memory data = abi.encodePacked(
            code,
            abi.encode(
                IEntryPoint(walletConfig.entryPoint),
                walletConfig.atomWarden
            )
        );
        // deploy atom wallet with create2
        // value sent in wei,
        // memory offset of `code` (after first 32 bytes where length is),
        // length of `code` (first 32 bytes of code),
        // salt
        assembly {
            atomWallet := create2(0, add(data, 0x20), mload(data), salt)
        }
        if (atomWallet == address(0))
            revert Errors.MultiVault_DeployAccountFailed();
    }

    /* -------------------------- */
    /*         Create Atom        */
    /* -------------------------- */

    /// @notice Create an atom and return its vault id
    /// @param atomUri atom data to create atom with
    /// @return id vault id of the atom
    /// NOTE: This function will revert if called by an address with less than `getAtomCost()` eth balance.
    function createAtom(
        bytes calldata atomUri
    ) external payable nonReentrant whenNotPaused returns (uint256 id) {
        if (msg.value < getAtomCost())
            revert Errors.MultiVault_InsufficientBalance();

        uint256 protocolDepositFee;
        (id, protocolDepositFee) = _createAtom(atomUri, msg.value);

        (bool success, ) = payable(generalConfig.protocolVault).call{
            value: atomConfig.atomCreationFee + protocolDepositFee
        }("");
        if (!success) revert Errors.MultiVault_TransferFailed();
    }

    /// @notice Batch create atoms and return their vault ids
    /// @param atomUris atom data array to create atoms with
    /// @return ids vault ids array of the atoms
    /// NOTE: This function will revert if called by an address with less than `getAtomCost()` * atomUris.length eth balance
    ///       msg.value can be greater than `getAtomCost()` * atomUri.length.
    function batchCreateAtom(
        bytes[] calldata atomUris
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256[] memory ids)
    {
        uint256 length = atomUris.length;
        if (msg.value < getAtomCost() * length)
            revert Errors.MultiVault_InsufficientBalance();

        uint256 valuePerAtom = msg.value / length;
        uint256 protocolDepositFeeTotal;
        ids = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 protocolDepositFee;
            (ids[i], protocolDepositFee) = _createAtom(
                atomUris[i],
                valuePerAtom
            );

            // add protocol deposit fees to total
            protocolDepositFeeTotal += protocolDepositFee;
        }

        (bool success, ) = payable(generalConfig.protocolVault).call{
            value: protocolDepositFeeTotal + atomConfig.atomCreationFee * length
        }("");
        if (!success) revert Errors.MultiVault_TransferFailed();
    }

    /// @notice Internal utility function to create an atom and handle vault creation
    /// @param atomUri The atom data to create an atom with
    /// @param value The value sent with the transaction
    /// @return id The new vault ID created for the atom
    function _createAtom(
        bytes memory atomUri,
        uint256 value
    ) internal returns (uint256 id, uint256 protocolDepositFee) {
        uint256 atomCost = getAtomCost();
        bytes32 _hash = keccak256(atomUri);
        if (AtomsByHash[_hash] != 0)
            revert Errors.MultiVault_AtomExists(atomUri);

        uint256 userDeposit = value - atomCost;

        id = _createVault();

        protocolDepositFee = protocolFeeAmount(userDeposit, id);

        _depositOnVaultCreation(
            id,
            msg.sender, // receiver
            userDeposit - protocolDepositFee
        );

        address atomWallet = computeAtomWalletAddr(id);

        _depositOnVaultCreation(
            id,
            atomWallet, // receiver
            atomConfig.atomShareLockFee
        );

        // map the new vault ID to the atom data
        atoms[id] = atomUri;

        AtomsByHash[_hash] = id;

        emit AtomCreated(msg.sender, atomWallet, atomUri, id);
    }

    /* -------------------------- */
    /*        Create Triple       */
    /* -------------------------- */

    /// @notice create a triple and return its vault id
    /// @param subjectId vault id of the subject atom
    /// @param predicateId vault id of the predicate atom
    /// @param objectId vault id of the object atom
    /// @return id vault id of the triple
    /// NOTE: This function will revert if called by an address with less than `tripleCost` eth balance
    ///       msg.value can be greater than `tripleCost`. This function will revert if any of the atoms
    ///       do not exist or if any ids are triple vaults.
    function createTriple(
        uint256 subjectId,
        uint256 predicateId,
        uint256 objectId
    ) external payable nonReentrant whenNotPaused returns (uint256 id) {
        uint256 tripleCost = getTripleCost();

        if (msg.value < tripleCost)
            revert Errors.MultiVault_InsufficientBalance();

        uint256 protocolDepositFee;

        (id, protocolDepositFee) = _createTriple(
            subjectId,
            predicateId,
            objectId,
            msg.value
        );

        // transfer fees to protocol vault
        (bool success, ) = payable(generalConfig.protocolVault).call{
            value: tripleConfig.tripleCreationFee + protocolDepositFee
        }("");
        if (!success) revert Errors.MultiVault_TransferFailed();
    }

    /// @notice batch create triples and return their vault ids
    /// @param subjectIds vault ids array of subject atoms
    /// @param predicateIds vault ids array of predicate atoms
    /// @param objectIds vault ids array of object atoms
    /// NOTE: This function will revert if the input id arrays are not of the same length and if the caller has
    ///       less than (`tripleCost` * array.length) eth balance. msg.value can be greater than `tripleCost` * array.length.
    ///       This function will revert if any of the atoms do not exist or if any ids are triple vaults.
    function batchCreateTriple(
        uint256[] calldata subjectIds,
        uint256[] calldata predicateIds,
        uint256[] calldata objectIds
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256[] memory ids)
    {
        // assert arrays are of the same length
        if (
            subjectIds.length != predicateIds.length ||
            subjectIds.length != objectIds.length
        ) revert Errors.MultiVault_ArraysNotSameLength();

        uint256 length = subjectIds.length;
        uint256 tripleCost = getTripleCost();
        if (msg.value < tripleCost * length)
            revert Errors.MultiVault_InsufficientBalance();

        uint256 valuePerTriple = msg.value / length;
        uint256 protocolDepositFeeTotal;
        ids = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 protocolDepositFee;
            (ids[i], protocolDepositFee) = _createTriple(
                subjectIds[i],
                predicateIds[i],
                objectIds[i],
                valuePerTriple
            );

            // add protocol deposit fees to total
            protocolDepositFeeTotal += protocolDepositFee;
        }

        (bool success, ) = payable(generalConfig.protocolVault).call{
            value: protocolDepositFeeTotal +
                tripleConfig.tripleCreationFee *
                length
        }("");
        if (!success) revert Errors.MultiVault_TransferFailed();
    }

    /// @notice Internal utility function to create a triple
    /// @param subjectId vault id of the subject atom
    /// @param predicateId vault id of the predicate atom
    /// @param objectId vault id of the object atom
    /// @param value The amount of ETH the user has sent minus the base triple cost
    /// @return id The new vault ID of the created triple
    /// @return protocolDepositFee The calculated protocol fee for the deposit
    function _createTriple(
        uint256 subjectId,
        uint256 predicateId,
        uint256 objectId,
        uint256 value
    ) internal returns (uint256 id, uint256 protocolDepositFee) {
        uint256 tripleCost = getTripleCost();

        // assert atoms exist, if not, revert
        if (subjectId == 0 || subjectId > count)
            revert Errors.MultiVault_AtomDoesNotExist();
        if (predicateId == 0 || predicateId > count)
            revert Errors.MultiVault_AtomDoesNotExist();
        if (objectId == 0 || objectId > count)
            revert Errors.MultiVault_AtomDoesNotExist();

        // assert that each id is not a triple vault id
        if (assertTriple(subjectId)) revert Errors.MultiVault_VaultIsTriple();
        if (assertTriple(predicateId)) revert Errors.MultiVault_VaultIsTriple();
        if (assertTriple(objectId)) revert Errors.MultiVault_VaultIsTriple();

        // check if triple already exists
        bytes32 _hash = tripleHashFromAtoms(subjectId, predicateId, objectId);
        if (TriplesByHash[_hash] != 0)
            revert Errors.MultiVault_TripleExists(subjectId, predicateId, objectId);

        uint256 userDeposit = value - tripleCost;

        // create a new positive triple vault
        id = _createVault();

        protocolDepositFee = protocolFeeAmount(userDeposit, id);

        // map the resultant triple hash to the new vault ID of the triple
        TriplesByHash[_hash] = id;

        // map the triple's vault ID to the underlying atom vault IDs
        triples[id] = [subjectId, predicateId, objectId];

        // set this new triple's vault ID as true in the IsTriple mapping as well as its counter
        isTriple[id] = true;

        // give the user shares in the positive triple vault
        _depositOnVaultCreation(
            id,
            msg.sender, // receiver
            userDeposit - protocolDepositFee
        );

        emit TripleCreated(msg.sender, subjectId, predicateId, objectId, id);
    }

    /* -------------------------- */
    /*    Deposit/Redeem Atom     */
    /* -------------------------- */

    /// @notice deposit eth into an atom vault and grant ownership of 'shares' to 'reciever'
    /// *payable msg.value amount of eth to deposit
    /// @param receiver the address to receiver the shares
    /// @param id the vault ID of the atom
    /// @return shares the amount of shares minted
    /// NOTE: this function will revert if the minimum deposit amount of eth is not met and
    ///       if the vault ID does not exist/is not an atom.
    function depositAtom(
        address receiver,
        uint256 id
    ) external payable nonReentrant whenNotPaused returns (uint256 shares) {
        if (id == 0 || id > count) {
            revert Errors.MultiVault_VaultDoesNotExist();
        }

        if (assertTriple(id)) {
            revert Errors.MultiVault_VaultNotAtom();
        }

        uint256 protocolFees;
        (shares, protocolFees) = _deposit(receiver, id, msg.value);

        // transfer protocol fees to protocol vault
        (bool success, ) = payable(generalConfig.protocolVault).call{
            value: protocolFees
        }("");
        if (!success) revert Errors.MultiVault_TransferFailed();
    }

    /// @notice redeem assets from an atom vault
    /// @param shares the amount of shares to redeem
    /// @param receiver the address to receiver the assets
    /// @param id the vault ID of the atom
    /// @return assets the amount of assets/eth withdrawn
    function redeemAtom(
        uint256 shares,
        address receiver,
        uint256 id
    ) external nonReentrant returns (uint256 assets) {
        if (id == 0 || id > count) {
            revert Errors.MultiVault_VaultDoesNotExist();
        }

        /*
            withdraw shares from vault, returning the amount of
            assets to be transferred to the receiver
        */
        assets = _redeem(id, msg.sender, shares);

        // transfer eth to receiver factoring in fees/equity
        (bool success, ) = payable(receiver).call{value: assets}("");
        if (!success) revert Errors.MultiVault_TransferFailed();
    }

    /* -------------------------- */
    /*   Deposit/Redeem Triple    */
    /* -------------------------- */

    /// @notice deposits assets of underlying tokens into a triple vault and grants ownership of 'shares' to 'reciever'
    /// *payable msg.value amount of eth to deposit
    /// @param receiver the address to receiver the shares
    /// @param id the vault ID of the triple
    /// @return shares the amount of shares minted
    /// NOTE: this function will revert if the minimum deposit amount of eth is not met and
    ///       if the vault ID does not exist/is not a triple.
    function depositTriple(
        address receiver,
        uint256 id
    ) external payable nonReentrant whenNotPaused returns (uint256 shares) {
        if (!assertTriple(id)) {
            revert Errors.MultiVault_VaultNotTriple();
        }

        if (hasCounterStake(id, receiver)) {
            revert Errors.MultiVault_HasCounterStake();
        }

        uint256 protocolFees;
        (shares, protocolFees) = _deposit(receiver, id, msg.value);

        // transfer protocol amount to protocol vault
        (bool success, ) = payable(generalConfig.protocolVault).call{
            value: protocolFees
        }("");
        if (!success) revert Errors.MultiVault_TransferFailed();

        // transfer eth from sender to the MultiVault
        uint256 userDeposit = msg.value - protocolFees;

        // distribute atom equity for all 3 atoms that underlie the triple
        uint256 _atomEquityFeeAmount = atomEquityFeeAmount(userDeposit, id);
        _distributeAtomEquity(id, receiver, _atomEquityFeeAmount);
    }

    /// @notice redeems 'shares' number of shares from the triple vault and send 'assets' eth
    ///         from the multiVault to 'reciever' factoring in exit fees
    /// @param shares the amount of shares to redeem
    /// @param receiver the address to receiver the assets
    /// @param id the vault ID of the triple
    /// @return assets the amount of assets/eth withdrawn
    function redeemTriple(
        uint256 shares,
        address receiver,
        uint256 id
    ) external nonReentrant returns (uint256 assets) {
        if (!assertTriple(id)) {
            revert Errors.MultiVault_VaultNotTriple();
        }

        /*
            withdraw shares from vault, returning the amount of
            assets to be transferred to the receiver
        */
        assets = _redeem(id, msg.sender, shares);

        // transfer eth to receiver factoring in fees/equity
        (bool success, ) = payable(receiver).call{value: assets}("");
        if (!success) revert Errors.MultiVault_TransferFailed();
    }

    /* =================================================== */
    /*                 INTERNAL METHODS                    */
    /* =================================================== */

    /// @dev _distributeAtomEquity - divides amount across the three atoms composing the triple and issues the receiver shares
    /// NOTE: assumes funds have already been transferred to this contract.
    function _distributeAtomEquity(
        uint256 id,
        address receiver,
        uint256 amount
    ) internal {
        // load atom IDs
        uint256[3] memory atomsIds;
        (atomsIds[0], atomsIds[1], atomsIds[2]) = getTripleAtoms(id);

        // floor div, so perAtom is slightly less than 1/3 of total input amount
        uint256 perAtom = amount / 3;

        // distribute proportional equity to each atom
        for (uint8 i = 0; i < 3; i++) {
            uint256 shares = _depositIntoVault(atomsIds[i], receiver, perAtom);
            tripleAtomShares[id][atomsIds[i]][receiver] += shares;
        }
    }

    /// @dev deposit assets into a vault
    /// change the vault's total assets, total shares and balanceOf mappings to reflect the deposit
    /// @return sharesForReceiver the amount of shares minted for the receiver
    function _depositIntoVault(
        uint256 id,
        address receiver,
        uint256 assets // protocol fees already deducted
    ) internal returns (uint256 sharesForReceiver) {
        // changes in vault's total assets
        uint256 totalAssetsDelta = assets -
            entryFeeAmount(assets, id) -
            atomEquityFeeAmount(assets, id);

        if (totalAssetsDelta <= 0) {
            revert Errors.MultiVault_InsufficientDepositAmountToCoverFees();
        }

        if (vaults[id].totalShares == generalConfig.minShare) {
            sharesForReceiver = assets; // shares owed to receiver
        } else {
            sharesForReceiver = convertToShares(totalAssetsDelta, id); // shares owed to receiver
        }

        // changes in vault's total shares
        uint256 totalSharesDelta = sharesForReceiver;

        // set vault totals (assets and shares)
        _setVaultTotals(
            id,
            vaults[id].totalAssets + totalAssetsDelta,
            vaults[id].totalShares + totalSharesDelta
        );

        // mint `sharesOwed` shares to sender factoring in fees
        _mint(receiver, id, sharesForReceiver);

        emit Deposit(
            msg.sender,
            receiver,
            vaults[id].balanceOf[receiver],
            assets,
            sharesForReceiver,
            id
        );
    }

    /// @dev deposit assets into a vault upon creation
    /// change the vault's total assets, total shares and balanceOf mappings to reflect the deposit
    /// Additionally, initializes a counter vault with ghost shares.
    function _depositOnVaultCreation(
        uint256 id,
        address receiver,
        uint256 assets
    ) internal {
        bool isAtomWallet = receiver == computeAtomWalletAddr(id);

        // ghost shares minted to the zero address upon vault creation
        uint256 sharesForZeroAddress = generalConfig.minShare;

        uint256 assetsForZeroAddressInCounterVault = generalConfig.minShare;

        uint256 sharesForReceiver = assets;

        // changes in vault's total assets
        uint256 totalAssetsDelta = assets;

        // changes in vault's total shares
        uint256 totalSharesDelta = isAtomWallet
            ? sharesForReceiver
            : sharesForReceiver + sharesForZeroAddress;

        // set vault totals for the vault
        _setVaultTotals(
            id,
            vaults[id].totalAssets + totalAssetsDelta,
            vaults[id].totalShares + totalSharesDelta
        );

        // mint `sharesOwed` shares to sender factoring in fees
        _mint(receiver, id, sharesForReceiver);

        // mint `sharesForZeroAddress` shares to zero address to initialize the vault
        if (!isAtomWallet) {
            _mint(address(0), id, sharesForZeroAddress);
        }

        /*
         * Initialize the counter triple vault with ghost shares if id is a positive triple vault
         */
        if (assertTriple(id)) {
            uint256 counterVaultId = getCounterIdFromTriple(id);

            // set vault totals
            _setVaultTotals(
                counterVaultId,
                vaults[counterVaultId].totalAssets +
                    assetsForZeroAddressInCounterVault,
                vaults[counterVaultId].totalShares + sharesForZeroAddress
            );

            // mint `sharesForZeroAddress` shares to zero address to initialize the vault
            _mint(address(0), counterVaultId, sharesForZeroAddress);
        }

        emit Deposit(
            msg.sender,
            receiver,
            vaults[id].balanceOf[receiver],
            assets,
            totalSharesDelta,
            id
        );
    }

    /// @notice Internal function to encapsulate the common deposit logic for both atoms and triples
    /// @param receiver the address to receiver the shares
    /// @param id the vault ID of the atom or triple
    /// @param value the amount of eth to deposit
    /// @return shares the amount of shares minted
    /// @return protocolFees the amount of protocol fees deducted
    function _deposit(
        address receiver,
        uint256 id,
        uint256 value
    ) internal returns (uint256 shares, uint256 protocolFees) {
        if (previewDeposit(msg.value, id) == 0) {
            revert Errors.MultiVault_DepositOrWithdrawZeroShares();
        }

        if (value < generalConfig.minDeposit) {
            revert Errors.MultiVault_MinimumDeposit();
        }

        /*
            deposit eth into the vault, returning the amount of vault
            shares given to the receiver and protocol fees
        */
        protocolFees = protocolFeeAmount(msg.value, id);
        shares = _depositIntoVault(id, receiver, msg.value - protocolFees);
    }

    /// @dev redeem shares out of a given vault
    /// change the vault's total assets, total shares and balanceOf mappings to reflect the withdrawal
    /// @return assetsForReceiver the amount of assets/eth to be transferred to the receiver
    function _redeem(
        uint256 id,
        address owner,
        uint256 shares
    ) internal returns (uint256 assetsForReceiver) {
        if (shares == 0) {
            revert Errors.MultiVault_DepositOrWithdrawZeroShares();
        }

        if (vaults[id].balanceOf[msg.sender] < shares) {
            revert Errors.MultiVault_InsufficientSharesInVault();
        }

        uint256 remainingShares = vaults[id].totalShares - shares;
        if (remainingShares < generalConfig.minShare) {
            revert Errors.MultiVault_InsufficientRemainingSharesInVault(
                remainingShares
            );
        }
        uint256 exitFees;

        /*
         * if the withdraw amount results in a zero share balance for
         * the associated vault, no exit fee is charged to avoid
         * unaccounted for eth balances. Also, in case of an emergency
         * withdrawal (i.e. when the contract is paused), no exit fees
         * are charged either.
         */
        if (remainingShares == generalConfig.minShare || paused()) {
            exitFees = 0;
            assetsForReceiver = convertToAssets(shares, id);
        } else {
            (assetsForReceiver, exitFees) = previewRedeem(shares, id);
        }

        // changes in vault's total shares
        uint256 totalSharesDelta = shares;

        // changes in vault's total assets
        uint256 totalAssetsDelta = assetsForReceiver;

        // set vault totals (assets and shares)
        _setVaultTotals(
            id,
            vaults[id].totalAssets - totalAssetsDelta,
            vaults[id].totalShares - totalSharesDelta
        );

        // burn shares, then transfer assets to receiver
        _burn(owner, id, shares);

        emit Withdraw(
            msg.sender,
            owner,
            vaults[id].balanceOf[owner],
            assetsForReceiver,
            shares,
            exitFees,
            id
        );
    }

    /// @dev mint vault shares of vault ID `id` to address `to`
    function _mint(address to, uint256 id, uint256 amount) internal {
        vaults[id].balanceOf[to] += amount;
    }

    /// @dev burn vault shares of vault ID `id` from address `from`
    function _burn(address from, uint256 id, uint256 amount) internal {
        if (from == address(0)) revert Errors.MultiVault_BurnFromZeroAddress();

        uint256 fromBalance = vaults[id].balanceOf[from];
        if (fromBalance < amount) {
            revert Errors.MultiVault_BurnInsufficientBalance();
        }

        // TO-DO consider upgrading to solc v0.8.22 and remove unchecked
        unchecked {
            vaults[id].balanceOf[from] = fromBalance - amount;
        }
    }

    /// @dev set total assets and shares for a vault
    function _setVaultTotals(
        uint256 _id,
        uint256 _totalAssets,
        uint256 _totalShares
    ) internal {
        vaults[_id].totalAssets = _totalAssets;
        vaults[_id].totalShares = _totalShares;
    }

    /// @dev internal method for vault creation
    function _createVault() internal returns (uint256 id) {
        id = ++count;
    }

    /* =================================================== */
    /*               RESTRICTED FUNCTIONS                  */
    /* =================================================== */

    /// @dev set admin
    /// @param _admin address of the new admin
    function setAdmin(address _admin) external onlyAdmin {
        generalConfig.admin = _admin;
    }

    /// @dev pause the pausable contract methods
    function pause() external onlyAdmin {
        _pause();
    }

    /// @dev unpause the pausable contract methods
    function unpause() external onlyAdmin {
        _unpause();
    }

    /// @dev set protocol vault
    /// @param _protocolVault address of the new protocol vault
    function setProtocolVault(address _protocolVault) external onlyAdmin {
        generalConfig.protocolVault = _protocolVault;
    }

    /// @dev sets the denominator used for calculating percentages
    /// @param _feeDenominator new denominator used to calculate fees
    function setFeeDenominator(uint256 _feeDenominator) external onlyAdmin {
        generalConfig.feeDenominator = _feeDenominator;
    }

    /// @dev sets entry fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default entry fee, id = n changes fees for vault n specifically
    /// @param _id vault id to set entry fee for
    /// @param _entryFee entry fee to set
    function setEntryFee(uint256 _id, uint256 _entryFee) external onlyAdmin {
        if (_entryFee > 10 ** 4) revert Errors.MultiVault_InvalidFeeSet();
        vaultFees[_id].entryFee = _entryFee;
    }

    /// @dev sets exit fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default exit fee, id = n changes fees for vault n specifically
    /// @dev admin cannot set the exit fee to be greater than 10%, to avoid being able to prevent
    ///      users from withdrawing their assets
    /// @param _id vault id to set exit fee for
    /// @param _exitFee exit fee to set
    function setExitFee(uint256 _id, uint256 _exitFee) external onlyAdmin {
        if (_exitFee > 10 ** 3) revert Errors.MultiVault_InvalidExitFee();
        vaultFees[_id].exitFee = _exitFee;
    }

    /// @dev sets protocol fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default protocol fee, id = n changes fees for vault n specifically
    /// @param _id vault id to set protocol fee for
    /// @param _protocolFee protocol fee to set
    function setProtocolFee(
        uint256 _id,
        uint256 _protocolFee
    ) external onlyAdmin {
        if (_protocolFee > 10 ** 4) revert Errors.MultiVault_InvalidFeeSet();
        vaultFees[_id].protocolFee = _protocolFee;
    }

    /// @dev sets the atom share lock fee
    /// @param _atomShareLockFee new atom share lock fee
    function setAtomShareLockFee(uint256 _atomShareLockFee) external onlyAdmin {
        atomConfig.atomShareLockFee = _atomShareLockFee;
    }

    /// @dev sets the atom creation fee
    /// @param _atomCreationFee new atom creation fee
    function setAtomCreationFee(uint256 _atomCreationFee) external onlyAdmin {
        atomConfig.atomCreationFee = _atomCreationFee;
    }

    /// @dev sets fee charged in wei when creating a triple to protocol vault
    /// @param _tripleCreationFee new fee in wei
    function setTripleCreationFee(
        uint256 _tripleCreationFee
    ) external onlyAdmin {
        tripleConfig.tripleCreationFee = _tripleCreationFee;
    }

    /// @dev sets the atom equity fee percentage (number to be divided by `feeDenominator`)
    /// @param _atomEquityFeeForTriple new atom equity fee percentage
    function setAtomEquityFee(
        uint256 _atomEquityFeeForTriple
    ) external onlyAdmin {
        tripleConfig.atomEquityFeeForTriple = _atomEquityFeeForTriple;
    }

    /// @dev sets the minimum deposit amount for atoms and triples
    /// @param _minDeposit new minimum deposit amount
    function setMinDeposit(uint256 _minDeposit) external onlyAdmin {
        generalConfig.minDeposit = _minDeposit;
    }

    /// @dev sets the minimum share amount for atoms and triples
    /// @param _minShare new minimum share amount
    function setMinShare(uint256 _minShare) external onlyAdmin {
        generalConfig.minShare = _minShare;
    }

    /* =================================================== */
    /*                    MODIFIERS                        */
    /* =================================================== */

    modifier onlyAdmin() {
        if (msg.sender != generalConfig.admin)
            revert Errors.MultiVault_AdminOnly();

        _;
    }

    /* =================================================== */
    /*                     FALLBACK                        */
    /* =================================================== */

    fallback() external payable {
        LibZip.cdFallback();
    }
}
