// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {AtomWallet} from "src/AtomWallet.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {LibZip} from "solady/utils/LibZip.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {IEntryPoint} from "account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {Types} from "src/libraries/Types.sol";
import {Errors} from "src/libraries/Errors.sol";

/**
 * @title  EthMultiVault
 * @author 0xIntuition
 * @notice Core contract of the Intuition protocol. Manages the creation and management of vaults
 *         associated to Atom's & Triples
 */
contract EthMultiVault is IEthMultiVault, Initializable, ReentrancyGuard {
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
    // mapping of atom data to vault ID
    // Atom Data -> Vault ID
    mapping(bytes => uint256) public atoms;

    // mapping of triple vault ID to the underlying atom IDs that make up the triple
    // Triple ID -> VaultIDs of atoms that make up the triple
    mapping(uint256 => uint256[3]) public triples;

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
        if (generalConfig.admin != address(0))
            revert Errors.MultiVault_AlreadyInitialized();
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
        feeAmount = isTriple[id]
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
        uint256 assets,
        uint256 id
    ) public view returns (uint256 shares) {
        uint256 totalFees = entryFeeAmount(assets, id) +
            atomEquityFeeAmount(assets, id) +
            protocolFeeAmount(assets, id);

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
    /// @param subjectId vault id of the subject atom
    /// @param predicateId vault id of the predicate atom
    /// @param objectId vault id of the object atom
    /// @return hash the corresponding hash for the given RDF triple
    function tripleHashFromAtoms(
        uint256 subjectId,
        uint256 predicateId,
        uint256 objectId
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(subjectId, predicateId, objectId));
    }

    /// @notice returns the corresponding hash for the given RDF triple, given the triple vault id
    /// @param id vault id of the triple
    /// @return hash the corresponding hash for the given RDF triple
    /// NOTE: only applies to triple vault IDs as input
    function tripleHash(uint256 id) external view returns (bytes32) {
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
    function getCounterIdFromTriple(
        uint256 id
    ) external pure returns (uint256) {
        return type(uint256).max - id;
    }

    /* -------------------------- */
    /*        Misc. Helpers       */
    /* -------------------------- */

    /// @notice returns vault total assets and shares for all vaults
    function getVaultStates()
        external
        view
        returns (Types.VaultState[] memory states)
    {
        states = new Types.VaultState[](count);
        for (uint256 i = 1; i <= count; i++) {
            states[i - 1] = Types.VaultState({
                id: i,
                assets: vaults[i].totalAssets,
                shares: vaults[i].totalShares
            });
        }
    }

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
        bytes32 salt = keccak256(abi.encode(address(this), id));
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
    ) external returns (address atomWallet) {
        // compute salt
        bytes32 salt = keccak256(abi.encode(address(this), atomId));
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

    /// @notice create an atom and return its vault id
    /// @param atomData atom data to create atom with
    /// @return id vault id of the atom
    /// NOTE: This function will revert if called by an address with less than `atomCost` eth balance.
    function createAtom(
        bytes calldata atomData
    ) external payable nonReentrant returns (uint256 id) {
        if (msg.value < atomConfig.atomCost)
            revert Errors.MultiVault_InsufficientBalance();

        // create a new vault ID
        id = _createVault();

        // compute atom wallet address
        address atomWallet = computeAtomWalletAddr(id);

        // give the atom wallet shares in the vault
        uint256 protocolDepositFee = _depositOnVaultCreation(
            id,
            atomWallet, // receiver
            msg.value - atomConfig.atomCreationFee
        );

        // transfer fees to protocol vault
        (bool success, ) = payable(generalConfig.protocolVault).call{
            value: atomConfig.atomCreationFee + protocolDepositFee
        }("");
        if (!success) revert Errors.MultiVault_TransferFailed();

        // map the atom data to the new vault ID
        atoms[atomData] = id;

        emit AtomCreated(msg.sender, atomWallet, atomData, id);
    }

    /// @notice create an atom and return its vault id
    /// @param atomData atom data to create atom with
    /// @return id vault id of the atom
    /// NOTE: This function will revert if called by an address with less than `atomCost` eth balance.
    ///       Atom data sent to this function is expected to be compressed using the run-length encoding
    ///       implementation in solady's LibZip to save on calldata costs
    function createAtomCompressed(
        bytes calldata atomData
    ) external payable nonReentrant returns (uint256 id) {
        if (msg.value < atomConfig.atomCost)
            revert Errors.MultiVault_InsufficientBalance();

        // decompress call data using LibZip
        bytes memory decompressedAtomData = atomData.cdDecompress();

        // create a new vault ID
        id = _createVault();

        // compute atom wallet address
        address atomWallet = computeAtomWalletAddr(id);

        // give the atom wallet shares in the vault
        uint256 protocolDepositFee = _depositOnVaultCreation(
            id,
            atomWallet, // receiver
            msg.value - atomConfig.atomCreationFee
        );

        // transfer fees to protocol vault
        (bool success, ) = payable(generalConfig.protocolVault).call{
            value: atomConfig.atomCreationFee + protocolDepositFee
        }("");
        if (!success) revert Errors.MultiVault_TransferFailed();

        // map the decompressed atom data to the new vault ID
        atoms[decompressedAtomData] = id;

        emit AtomCreated(msg.sender, atomWallet, atomData, id);
    }

    /// @notice batch create atoms and return their vault ids
    /// @param atomData atom data array to create atoms with
    /// @return ids vault ids array of the atoms
    /// NOTE: This function will revert if called by an address with less than `AtomCost` * atomData.length eth balance
    ///       msg.value can be greater than `AtomCost` * atomData.length.
    ///       Atom data sent to this function is expected to be compressed using the run-length encoding
    function batchCreateAtom(
        bytes[] calldata atomData
    ) external payable nonReentrant returns (uint256[] memory ids) {
        // cache
        uint256 length = atomData.length;
        uint256 valuePerAtom = msg.value / length;

        if (msg.value < atomConfig.atomCost * length)
            revert Errors.MultiVault_InsufficientBalance();

        uint256 protocolDepositFeesTotal;
        ids = new uint256[](length);

        // create atoms
        for (uint256 i = 0; i < length; i++) {
            // create a new vault ID
            ids[i] = _createVault();

            // compute atom wallet address
            address atomWallet = computeAtomWalletAddr(ids[i]);

            // give the atom wallet shares in the vault
            uint256 protocolDepositFees = _depositOnVaultCreation(
                ids[i],
                atomWallet, // receiver
                valuePerAtom - atomConfig.atomCreationFee
            );

            // add protocol deposit fees to total
            protocolDepositFeesTotal += protocolDepositFees;

            // map the atom data to the new vault ID
            atoms[atomData[i]] = ids[i];

            emit AtomCreated(msg.sender, atomWallet, atomData[i], ids[i]);
        }

        // transfer fees to protocol vault
        (bool success, ) = payable(generalConfig.protocolVault).call{
            value: protocolDepositFeesTotal +
                atomConfig.atomCreationFee *
                length
        }("");
        if (!success) revert Errors.MultiVault_TransferFailed();
    }

    /// @notice batch create atoms and return their vault ids
    /// @param atomData atom data array to create atoms with
    /// @return ids vault ids array of the atoms
    /// NOTE: This function will revert if called by an address with less than `AtomCost` * atomData.length eth balance
    ///       msg.value can be greater than `AtomCost` * atomData.length.
    ///       Atom data sent to this function is expected to be compressed using the run-length encoding
    ///       implementation in solady's LibZip to save on calldata costs
    function batchCreateAtomCompressed(
        bytes[] calldata atomData
    ) external payable nonReentrant returns (uint256[] memory ids) {
        // cache
        uint256 length = atomData.length;
        uint256 valuePerAtom = msg.value / length;

        if (msg.value < atomConfig.atomCost * length)
            revert Errors.MultiVault_InsufficientBalance();

        uint256 protocolDepositFeesTotal;
        ids = new uint256[](length);

        // create atoms
        for (uint256 i = 0; i < length; i++) {
            // decompress atom data using LibZip
            bytes memory decompressedAtomData = atomData[i].cdDecompress();

            // create a new vault ID
            ids[i] = _createVault();

            // compute atom wallet address
            address atomWallet = computeAtomWalletAddr(ids[i]);

            // give the atom wallet shares in the vault
            uint256 protocolDepositFees = _depositOnVaultCreation(
                ids[i],
                atomWallet, // receiver
                valuePerAtom - atomConfig.atomCreationFee
            );

            // add protocol deposit fees to total
            protocolDepositFeesTotal += protocolDepositFees;

            // map the decompressed atom data to the new vault ID
            atoms[decompressedAtomData] = ids[i];

            emit AtomCreated(msg.sender, atomWallet, atomData[i], ids[i]);
        }

        // transfer fees to protocol vault
        (bool success, ) = payable(generalConfig.protocolVault).call{
            value: protocolDepositFeesTotal +
                atomConfig.atomCreationFee *
                length
        }("");
        if (!success) revert Errors.MultiVault_TransferFailed();
    }

    /* -------------------------- */
    /*        Create Triple       */
    /* -------------------------- */

    /// @notice create a triple and return its vault id
    /// @param subjectId vault id of the subject atom
    /// @param predicateId vault id of the predicate atom
    /// @param objectId vault id of the object atom
    /// @return id vault id of the triple
    /// NOTE: This function will revert if called by an address with less than `atomCost` eth balance
    ///       msg.value can be greater than `atomCost`. This function will revert if any of the atoms
    ///       do not exist or if any ids are triple vaults.
    function createTriple(
        uint256 subjectId,
        uint256 predicateId,
        uint256 objectId
    ) external payable nonReentrant returns (uint256 id) {
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

        if (msg.value < atomConfig.atomCost)
            revert Errors.MultiVault_InsufficientBalance();

        // create a new triple atom vault id
        uint256 tripleAtomId = _createVault();

        // create a new triple vault id
        id = _createVault();

        // compute atom wallet address
        address atomWallet = computeAtomWalletAddr(tripleAtomId);

        // give the atom wallet shares in the triple atom vault
        /// @notice: assets are only deposited into the triple-atom vault
        uint256 protocolDepositFee = _depositOnVaultCreation(
            tripleAtomId,
            atomWallet, // receiver
            msg.value - tripleConfig.tripleCreationFee
        );

        // transfer fees to protocol vault
        (bool success, ) = payable(generalConfig.protocolVault).call{
            value: tripleConfig.tripleCreationFee + protocolDepositFee
        }("");
        if (!success) revert Errors.MultiVault_TransferFailed();

        // map the triple's vault ID to the underlying atom vault IDs
        triples[id] = [subjectId, predicateId, objectId];

        // set this new triple's vault ID as true in the IsTriple mapping as well as its counter
        isTriple[id] = true;

        emit TripleCreated(
            msg.sender,
            subjectId,
            predicateId,
            objectId,
            id,
            tripleAtomId
        );
    }

    /// @notice batch create triples and return their vault ids
    /// @param subjectIds vault ids array of subject atoms
    /// @param predicateIds vault ids array of predicate atoms
    /// @param objectIds vault ids array of object atoms
    /// NOTE: This function will revert if the input id arrays are not of the same length and if the caller has
    ///       less than (`AtomCost` * array.length) eth balance. msg.value can be greater than `AtomCost` * array.length.
    ///       This function will revert if any of the atoms do not exist or if any ids are triple vaults.
    function batchCreateTriple(
        uint256[] calldata subjectIds,
        uint256[] calldata predicateIds,
        uint256[] calldata objectIds
    ) external payable nonReentrant returns (uint256[] memory ids) {
        // assert arrays are of the same length
        if (
            subjectIds.length != predicateIds.length ||
            subjectIds.length != objectIds.length
        ) revert Errors.MultiVault_ArraysNotSameLength();

        // cache
        uint256 length = subjectIds.length;
        uint256 valuePerTriple = msg.value / length;

        if (msg.value < atomConfig.atomCost * length)
            revert Errors.MultiVault_InsufficientBalance();

        uint256 protocolDepositFeesTotal;
        ids = new uint256[](length);

        // create triples
        for (uint256 i = 0; i < length; i++) {
            // cache
            uint256 subjectId = subjectIds[i];
            uint256 predicateId = predicateIds[i];
            uint256 objectId = objectIds[i];

            // assert atoms exist, if not, revert
            if (subjectId == 0) revert Errors.MultiVault_AtomDoesNotExist();
            if (predicateId == 0) revert Errors.MultiVault_AtomDoesNotExist();
            if (objectId == 0) revert Errors.MultiVault_AtomDoesNotExist();

            // assert that each id is not a triple vault id
            if (assertTriple(subjectId))
                revert Errors.MultiVault_VaultIsTriple();
            if (assertTriple(predicateId))
                revert Errors.MultiVault_VaultIsTriple();
            if (assertTriple(objectId))
                revert Errors.MultiVault_VaultIsTriple();

            // create a new triple atom vault
            uint256 tripleAtomId = _createVault();

            // create a new triple vault
            uint256 id = _createVault();
            ids[i] = id;

            // compute atom wallet address
            address atomWallet = computeAtomWalletAddr(tripleAtomId);

            // give the atom wallet shares in the vault
            uint256 protocolDepositFees = _depositOnVaultCreation(
                tripleAtomId,
                atomWallet, // receiver
                valuePerTriple - tripleConfig.tripleCreationFee
            );

            // add protocol deposit fees to total
            protocolDepositFeesTotal += protocolDepositFees;

            // map the triple's vault ID to the underlying atom vault IDs
            triples[id] = [subjectId, predicateId, objectId];

            // set this new triple's vault ID as true in the IsTriple mapping as well as its counter
            isTriple[id] = true;

            emit TripleCreated(
                msg.sender,
                subjectId,
                predicateId,
                objectId,
                id,
                tripleAtomId
            );
        }

        // transfer fees to protocol vault
        (bool success, ) = payable(generalConfig.protocolVault).call{
            value: protocolDepositFeesTotal +
                tripleConfig.tripleCreationFee *
                length
        }("");
        if (!success) revert Errors.MultiVault_TransferFailed();
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
    ) external payable nonReentrant returns (uint256 shares) {
        if (msg.value < generalConfig.minDeposit) {
            revert Errors.MultiVault_MinimumDeposit();
        }

        if (previewDeposit(msg.value, id) == 0) {
            revert Errors.MultiVault_DepositOrWithdrawZeroShares();
        }

        if (id == 0 || id > count) {
            revert Errors.MultiVault_VaultDoesNotExist();
        }

        if (assertTriple(id)) {
            revert Errors.MultiVault_VaultNotAtom();
        }

        /*
            deposit eth into the vault, returning the amount of vault
            shares given to the receiver and protocol fees
        */
        uint256 protocolFees;
        (shares, protocolFees) = _depositIntoVault(id, receiver, msg.value);

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
        if (shares == 0) {
            revert Errors.MultiVault_DepositOrWithdrawZeroShares();
        }

        if (id == 0 || id > count) {
            revert Errors.MultiVault_VaultDoesNotExist();
        }

        if (vaults[id].balanceOf[msg.sender] < shares) {
            revert Errors.MultiVault_InsufficientBalance();
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
    ) external payable nonReentrant returns (uint256 shares) {
        if ((shares = previewDeposit(msg.value, id)) == 0) {
            revert Errors.MultiVault_DepositOrWithdrawZeroShares();
        }

        if (msg.value < generalConfig.minDeposit) {
            revert Errors.MultiVault_MinimumDeposit();
        }

        if (!assertTriple(id)) {
            revert Errors.MultiVault_VaultNotTriple();
        }

        if (hasCounterStake(id, receiver)) {
            revert Errors.MultiVault_HasCounterStake();
        }

        /*
            deposit eth into the vault, returning the amount of vault
            shares given to the receiver and protocol fees
        */
        uint256 protocolFees;
        (, protocolFees) = _depositIntoVault(id, receiver, msg.value);
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
        if (shares == 0) {
            revert Errors.MultiVault_DepositOrWithdrawZeroShares();
        }

        if (!assertTriple(id)) {
            revert Errors.MultiVault_VaultNotTriple();
        }

        if (vaults[id].balanceOf[msg.sender] < shares) {
            revert Errors.MultiVault_NotAtomCreator();
        }

        /*
            withdraw shares from vault, returning the amount of
            assets to be transferred to the receiver
        */
        assets += _redeem(id, msg.sender, shares);

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
        if (!assertTriple(id)) return;

        // load atom IDs
        uint256[3] memory atomsIds;
        (atomsIds[0], atomsIds[1], atomsIds[2]) = getTripleAtoms(id);

        // floor div, so perAtom is slightly less than 1/3 of total input amount
        uint256 perAtom = amount / 3;

        // distribute proportional equity to each atom
        for (uint8 i = 0; i < 3; i++) {
            (uint256 shares, ) = _depositIntoVault(
                atomsIds[i],
                receiver,
                perAtom
            );
            tripleAtomShares[id][atomsIds[i]][receiver] += shares;
        }
    }

    /// @dev _redeemAtomEquity - withdraws proportional amount of shares from each underlying atom
    /// @return assets the amount of assets/eth withdrawn from the underlying atom vaults
    /// NOTE: assumes id refers to a triple vault.
    function _redeemAtomEquity(
        uint256 id,
        uint256 shares,
        address owner
    ) internal returns (uint256 assets) {
        // load atom IDs
        uint256[3] memory atomIds;
        (atomIds[0], atomIds[1], atomIds[2]) = getTripleAtoms((id));
        // load receiver vault balance
        uint256 receiverVaultBalance = vaults[id].balanceOf[owner];
        // redeem `toRedeem` amount of shares from each atom vault representing the triple
        uint256 toRedeem;
        for (uint8 i = 0; i < 3; i++) {
            /// TripleAtomShares | Triple ID -> Atom ID -> Account Address -> Atom Share Balance (perAtom)
            toRedeem = shares.mulDiv(
                tripleAtomShares[id][atomIds[i]][owner],
                receiverVaultBalance
            );
            assets += _redeem(atomIds[i], owner, toRedeem);
            tripleAtomShares[id][atomIds[i]][owner] -= toRedeem;
        }
    }

    /// @dev deposit assets into a vault
    /// change the vault's total assets, total shares and balanceOf mappings to reflect the deposit
    /// @return sharesForReceiver the amount of shares minted for the receiver
    /// @return protocolFees the amount of fees charged on deposit by the protocol
    function _depositIntoVault(
        uint256 id,
        address receiver,
        uint256 assets
    ) internal returns (uint256 sharesForReceiver, uint256 protocolFees) {
        protocolFees = protocolFeeAmount(assets, id);

        if (vaults[id].totalShares == generalConfig.minShare) {
            sharesForReceiver = assets - protocolFees; // shares owed to receiver
        } else {
            sharesForReceiver = previewDeposit(assets, id); // shares owed to receiver
        }

        // changes in vault's total assets
        uint256 totalAssetsDelta = assets -
            atomEquityFeeAmount(assets, id) -
            protocolFees;

        if (totalAssetsDelta <= 0) {
            revert Errors.MultiVault_InsufficientDepositAmountToCoverFees();
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
    /// @return protocolFees the amount of protocol fees on the deposit
    function _depositOnVaultCreation(
        uint256 id,
        address receiver,
        uint256 assets
    ) internal returns (uint256 protocolFees) {
        protocolFees = protocolFeeAmount(assets, id);

        uint256 sharesForReceiver = assets - protocolFees;

        // changes in vault's total assets
        uint256 totalAssetsDelta = assets - protocolFees;

        if (sharesForReceiver <= 0 || totalAssetsDelta <= 0) {
            revert Errors.MultiVault_InsufficientDepositAmountToCoverFees();
        }

        // ghost shares minted to the zero address upon vault creation
        uint256 sharesForZeroAddress = generalConfig.minShare;

        // changes in vault's total shares
        uint256 totalSharesDelta = sharesForReceiver + sharesForZeroAddress;

        // set vault totals (assets and shares)
        _setVaultTotals(
            id,
            vaults[id].totalAssets + totalAssetsDelta,
            vaults[id].totalShares + totalSharesDelta
        );

        // mint `sharesOwed` shares to sender factoring in fees
        _mint(receiver, id, sharesForReceiver);

        // mint `sharesForZeroAddress` shares to zero address to initialize the vault
        _mint(address(0), id, sharesForZeroAddress);

        emit Deposit(
            msg.sender,
            receiver,
            vaults[id].balanceOf[msg.sender],
            assets,
            sharesForReceiver,
            id
        );
    }

    /// @dev redeem shares out of a given vault
    /// change the vault's total assets, total shares and balanceOf mappings to reflect the withdrawal
    /// @return assetsForReceiver the amount of assets/eth to be transferred to the receiver
    function _redeem(
        uint256 id,
        address owner,
        uint256 shares
    ) internal returns (uint256 assetsForReceiver) {
        uint256 remainingShares = vaults[id].totalShares - shares;
        if (remainingShares <= 0) {
            revert Errors.MultiVault_InsufficientRemainingSharesInVault();
        }
        uint256 exitFees;

        /*
         * if the withdraw amount results in a zero share balance for
         * the associated vault, no exit fee is charged to avoid
         * unaccounted for eth balances
         */
        if (remainingShares == generalConfig.minShare) {
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
    /// @param _id vault id to set exit fee for
    /// @param _exitFee exit fee to set
    function setExitFee(uint256 _id, uint256 _exitFee) external onlyAdmin {
        if (_exitFee > 10 ** 4) revert Errors.MultiVault_InvalidFeeSet();
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

    /// @dev sets the atom cost, amount of wei (eth) needed to create an atom
    /// @param _atomCost new atom cost
    function setAtomCost(uint256 _atomCost) external onlyAdmin {
        atomConfig.atomCost = _atomCost;
    }

    /// @dev sets fee charged in wei when creating an atom to protocol vault
    /// @param _atomCreationFee new fee in wei
    function setAtomCreationFee(uint256 _atomCreationFee) external onlyAdmin {
        atomConfig.atomCreationFee = _atomCreationFee;
    }

    /// @dev sets fee charged in wei when creating a triple to protocol vault
    /// @param _tripleCreationFee new fee in wei
    function setTripleCreationFee(uint256 _tripleCreationFee) external {
        if (msg.sender != generalConfig.admin)
            revert Errors.MultiVault_AdminOnly();
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

    receive() external payable {}
}
