// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {AtomWallet} from "src/AtomWallet.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {LibZip} from "solady/utils/LibZip.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {IEntryPoint} from "account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {Errors} from "src/libraries/Errors.sol";

/**
 * @title  EthMultiVault
 * @notice Manages the creation and management of vaults associated with atoms & triples.
 */
contract EthMultiVault is IEthMultiVault, Initializable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using FixedPointMathLib for uint256;
    using LibZip for bytes;

    /* =================================================== */
    /*                  STATE VARIABLES                    */
    /* =================================================== */

    /// @notice Configuration structs
    GeneralConfig public generalConfig;
    AtomConfig public atomConfig;
    TripleConfig public tripleConfig;
    WalletConfig public walletConfig;

    /// @notice ID of the last vault to be created
    uint256 public count;

    // Operation identifiers
    bytes32 public constant SET_ADMIN = keccak256("setAdmin");
    bytes32 public constant SET_EXIT_FEE = keccak256("setExitFee");

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

    /// @notice Timelock struct
    struct Timelock {
        bytes data;
        uint256 readyTime;
        bool executed;
    }

    /// @notice Mapping of vault ID to vault state
    // Vault ID -> Vault State
    mapping(uint256 => VaultState) public vaults;

    /// @notice Mapping of vault ID to vault fees
    // Vault ID -> Vault Fees
    mapping(uint256 => VaultFees) public vaultFees;

    /// @notice RDF (Resource Description Framework)
    // mapping of vault ID to atom data
    // Vault ID -> Atom Data
    mapping(uint256 => bytes) public atoms;

    // mapping of atom hash to atom vault ID
    // Hash -> Atom ID
    mapping(bytes32 => uint256) public atomsByHash;

    // mapping of triple vault ID to the underlying atom IDs that make up the triple
    // Triple ID -> VaultIDs of atoms that make up the triple
    mapping(uint256 => uint256[3]) public triples;

    // mapping of triple hash to triple vault ID
    // Hash -> Triple ID
    mapping(bytes32 => uint256) public triplesByHash;

    // mapping of triple vault IDs to determine whether a vault is a triple or not
    // Vault ID -> (Is Triple)
    mapping(uint256 => bool) public isTriple;

    /// @notice Atom Shares Tracking
    /// used to enable atom shares earned from triple deposits to be redeemed proportionally
    /// to the triple shares that earned them upon redemption/withdraw
    /// Triple ID -> Atom ID -> Account Address -> Atom Share Balance
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public tripleAtomShares;

    /// @notice Timelock mapping (operation hash -> timelock struct)
    mapping(bytes32 => Timelock) public timelocks;

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    /// @notice Initializes the MultiVault contract
    /// @param _generalConfig General configuration struct
    /// @param _atomConfig Atom configuration struct
    /// @param _tripleConfig Triple configuration struct
    /// @param _walletConfig Wallet configuration struct
    /// @param _vaultConfig Vault configuration struct
    /// @dev This function is called only once (during contract deployment)
    function init(
        GeneralConfig memory _generalConfig,
        AtomConfig memory _atomConfig,
        TripleConfig memory _tripleConfig,
        WalletConfig memory _walletConfig,
        VaultConfig memory _vaultConfig
    ) external initializer {
        __ReentrancyGuard_init();
        __Pausable_init();

        generalConfig = _generalConfig;
        atomConfig = _atomConfig;
        tripleConfig = _tripleConfig;
        walletConfig = _walletConfig;

        vaultFees[0] = VaultFees({
            entryFee: _vaultConfig.entryFee,
            exitFee: _vaultConfig.exitFee,
            protocolFee: _vaultConfig.protocolFee
        });
    }

    /* =================================================== */
    /*                       VIEWS                         */
    /* =================================================== */

    /* -------------------------- */
    /*         Fee Helpers        */
    /* -------------------------- */

    /// @notice returns the cost of creating an atom
    /// @return atomCost the cost of creating an atom
    function getAtomCost() public view returns (uint256) {
        uint256 atomCost = atomConfig.atomCreationProtocolFee // paid to protocol
            + atomConfig.atomWalletInitialDepositAmount // for purchasing shares for atom wallet
            + generalConfig.minShare; // for purchasing ghost shares
        return atomCost;
    }

    /// @notice returns the cost of creating a triple
    /// @return tripleCost the cost of creating a triple
    function getTripleCost() public view returns (uint256) {
        uint256 tripleCost = tripleConfig.tripleCreationProtocolFee // paid to protocol
            + generalConfig.minShare * 2; // for purchasing ghost shares for the positive and counter triple vaults
        return tripleCost;
    }

    /// @notice returns the total fees that would be charged for depositing 'assets' into a vault
    /// @param assets amount of `assets` to calculate fees on
    /// @param id vault id to get corresponding fees for
    /// @return totalFees total fees that would be charged for depositing 'assets' into a vault
    function getDepositFees(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 protocolFees = protocolFeeAmount(assets, id);
        uint256 assetsAfterProtocolFees = assets - protocolFees;

        uint256 entryFee = entryFeeAmount(assets, id);
        uint256 atomDepositFraction = atomDepositFractionAmount(assetsAfterProtocolFees, id);

        uint256 totalFees = entryFee + atomDepositFraction + protocolFees;
        return totalFees;
    }

    /// @notice returns the assets that would be returned to the receiver of the redeem and protocol fees
    /// @param shares amount of `shares` to calculate fees on
    /// @param id vault id to get corresponding fees for
    /// @return assetsForReceiver amount of assets that would be returned to the receiver
    /// @return protocolFees amount of assets that would be sent to the protocol vault
    /// @return exitFees amount of assets that would be charged for the exit fee
    function getRedeemValues(uint256 shares, uint256 id) public view returns (uint256, uint256, uint256) {
        uint256 remainingShares = vaults[id].totalShares - shares;

        uint256 assetsForReceiver = convertToAssets(shares, id);
        uint256 protocolFees;
        uint256 exitFees;

        /*
         * if the redeem amount results in a zero share balance for
         * the associated vault, no exit fee is charged to avoid
         * zero address accumulating disproportionate fee revenue via ghost 
         * shares. Also, in case of an emergency redemption (i.e. when the 
         * contract is paused), no exit fees are charged either.
         */
        if (paused()) {
            exitFees = 0;
            protocolFees = 0;
        } else if (remainingShares == generalConfig.minShare) {
            exitFees = 0;
            protocolFees = protocolFeeAmount(assetsForReceiver, id);
        } else {
            protocolFees = protocolFeeAmount(assetsForReceiver, id);
            uint256 assetsForReceiverAfterProtocolFees = assetsForReceiver - protocolFees;
            exitFees = exitFeeAmount(assetsForReceiverAfterProtocolFees, id);
        }

        assetsForReceiver = assetsForReceiver - exitFees - protocolFees;

        return (assetsForReceiver, protocolFees, exitFees);
    }

    /// @notice calculates fee on raw amount
    /// @param amount amount of assets to calculate fee on
    /// @param fee fee in %
    /// @return amount of assets that would be charged as fee
    function _feeOnRaw(uint256 amount, uint256 fee) internal view returns (uint256) {
        return amount.mulDivUp(fee, generalConfig.feeDenominator);
    }

    /// @notice returns amount of assets that would be charged for the entry fee given an amount of 'assets' provided
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    /// @return feeAmount amount of assets that would be charged for the entry fee
    /// NOTE: if the vault being deposited on has a vault total shares of 0, the entry fee is not applied
    function entryFeeAmount(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 entryFees = vaultFees[id].entryFee;
        uint256 feeAmount = _feeOnRaw(assets, entryFees == 0 ? vaultFees[0].entryFee : entryFees);
        return feeAmount;
    }

    /// @notice returns amount of assets that would be charged for the exit fee given an amount of 'assets' provided
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    /// @return feeAmount amount of assets that would be charged for the exit fee
    /// NOTE: if the vault  being redeemed from given the shares to redeem results in a total shares after of 0,
    ///       the exit fee is not applied
    function exitFeeAmount(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 exitFees = vaultFees[id].exitFee;
        uint256 feeAmount = _feeOnRaw(assets, exitFees == 0 ? vaultFees[0].exitFee : exitFees);
        return feeAmount;
    }

    /// @notice returns amount of assets that would be charged by a vault on protocol fee given amount of 'assets'
    ///         provided
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id to get corresponding fees for
    /// @return feeAmount amount of assets that would be charged by vault on protocol fee
    function protocolFeeAmount(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 protocolFees = vaultFees[id].protocolFee;
        uint256 feeAmount = _feeOnRaw(assets, protocolFees == 0 ? vaultFees[0].protocolFee : protocolFees);
        return feeAmount;
    }

    /// @notice returns atom deposit fraction given amount of 'assets' provided
    /// @param assets amount of assets to calculate fee on
    /// @param id vault id
    /// @return feeAmount amount of assets that would be used as atom deposit fraction
    /// NOTE: only applies to triple vaults
    function atomDepositFractionAmount(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 feeAmount = isTripleId(id) ? _feeOnRaw(assets, tripleConfig.atomDepositFractionForTriple) : 0;
        return feeAmount;
    }

    /* -------------------------- */
    /*     Accounting Helpers     */
    /* -------------------------- */

    /// @notice returns amount of shares that would be exchanged by vault given amount of 'assets' provided
    /// @param assets amount of assets to calculate shares on
    /// @param id vault id to get corresponding shares for
    /// @return shares amount of shares that would be exchanged by vault given amount of 'assets' provided
    function convertToShares(uint256 assets, uint256 id) public view returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        uint256 shares = supply == 0 ? assets : assets.mulDiv(supply, vaults[id].totalAssets);
        return shares;
    }

    /// @notice returns amount of assets that would be exchanged by vault given amount of 'shares' provided
    /// @param shares amount of shares to calculate assets on
    /// @param id vault id to get corresponding assets for
    /// @return assets amount of assets that would be exchanged by vault given amount of 'shares' provided
    function convertToAssets(uint256 shares, uint256 id) public view returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        uint256 assets = supply == 0 ? shares : shares.mulDiv(vaults[id].totalAssets, supply);
        return assets;
    }

    /// @notice returns the current share price for the given vault id
    /// @param id vault id to get corresponding share price for
    /// @return price current share price for the given vault id
    function currentSharePrice(uint256 id) external view returns (uint256) {
        uint256 supply = vaults[id].totalShares;
        uint256 price = supply == 0 ? 0 : (vaults[id].totalAssets * generalConfig.decimalPrecision) / supply;
        return price;
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
    ) public view returns (uint256) {
        uint256 totalFees = getDepositFees(assets, id);

        if (assets < totalFees) {
            revert Errors.MultiVault_InsufficientDepositAmountToCoverFees();
        }

        uint256 totalAssetsDelta = assets - totalFees;
        uint256 shares = convertToShares(totalAssetsDelta, id);
        return shares;
    }

    /// @notice simulates the effects of the redemption of `shares` and returns the estimated
    ///         amount of assets estimated to be returned to the receiver of the redeem
    /// @param shares amount of shares to calculate assets on
    /// @param id vault id to get corresponding assets for
    /// @return assets amount of assets estimated to be returned to the receiver
    function previewRedeem(uint256 shares, uint256 id) public view returns (uint256) {
        (uint256 assetsForReceiver,,) = getRedeemValues(shares, id);
        return assetsForReceiver;
    }

    /// @notice returns max amount of shares that can be redeemed from the 'owner' balance through a redeem call
    /// @param owner address of the account to get max redeemable shares for
    /// @param id vault id to get corresponding shares for
    /// @return shares amount of shares that can be redeemed from the 'owner' balance through a redeem call
    function maxRedeem(address owner, uint256 id) external view returns (uint256) {
        uint256 shares = vaults[id].balanceOf[owner];
        return shares;
    }

    /* -------------------------- */
    /*       Triple Helpers       */
    /* -------------------------- */

    /// @notice returns the corresponding hash for the given RDF triple, given the atoms that make up the triple
    /// @param subjectId the subject atom's vault id
    /// @param predicateId the predicate atom's vault id
    /// @param objectId the object atom's vault id
    /// @return hash the corresponding hash for the given RDF triple based on the atom vault ids
    function tripleHashFromAtoms(uint256 subjectId, uint256 predicateId, uint256 objectId)
        public
        pure
        returns (bytes32)
    {
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
    function isTripleId(uint256 id) public view returns (bool) {
        bool isCounterTriple = id > type(uint256).max / 2;
        return isCounterTriple ? isTriple[type(uint256).max - id] : isTriple[id];
    }

    /// @notice returns the atoms that make up a triple/counter-triple
    /// @param id vault id of the triple/counter-triple
    /// @return tuple(atomIds) the atoms that make up the triple/counter-triple
    /// NOTE: only applies to triple vault IDs as input
    function getTripleAtoms(uint256 id) public view returns (uint256, uint256, uint256) {
        bool isCounterTriple = id > type(uint256).max / 2;
        uint256[3] memory atomIds = isCounterTriple ? triples[type(uint256).max - id] : triples[id];
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

    /// @notice returns the number of shares user has in the vault
    /// @param vaultId vault id of the vault
    /// @param receiver address of the receiver
    /// @return balance number of shares user has in the vault
    function getVaultBalance(uint256 vaultId, address receiver) external view returns (uint256) {
        return vaults[vaultId].balanceOf[receiver];
    }

    /// @notice returns the number of shares and assets (less fees) user has in the vault
    /// @param vaultId vault id of the vault
    /// @param receiver address of the receiver
    /// @return shares number of shares user has in the vault
    /// @return assets number of assets user has in the vault
    function getVaultStateForUser(uint256 vaultId, address receiver) external view returns (uint256, uint256) {
        uint256 shares = vaults[vaultId].balanceOf[receiver];
        (uint256 assets,,) = getRedeemValues(shares, vaultId);
        return (shares, assets);
    }

    /// @dev checks if an account holds shares in the vault counter to the id provided
    /// @param id the id of the vault to check
    /// @param receiver the account to check
    /// @return bool whether the account holds shares in the counter vault to the id provided or not
    function _hasCounterStake(uint256 id, address receiver) internal view returns (bool) {
        if (!isTripleId(id)) {
            revert Errors.MultiVault_VaultNotTriple();
        }

        return vaults[type(uint256).max - id].balanceOf[receiver] > 0;
    }

    /// @dev getDeploymentData - returns the deployment data for the AtomWallet contract
    /// @return bytes memory the deployment data for the AtomWallet contract (using BeaconProxy pattern)
    function _getDeploymentData() internal view returns (bytes memory) {
        // Address of the atomWalletBeacon contract
        address beaconAddress = walletConfig.atomWalletBeacon;

        // BeaconProxy creation code
        bytes memory code = type(BeaconProxy).creationCode;

        // encode the init function of the AtomWallet contract with the entryPoint and atomWarden as constructor arguments
        bytes memory initData = abi.encodeWithSelector(
            AtomWallet.init.selector, IEntryPoint(walletConfig.entryPoint), walletConfig.atomWarden
        );

        // encode constructor arguments of the BeaconProxy contract (address beacon, bytes memory data)
        bytes memory encodedArgs = abi.encode(beaconAddress, initData);

        // concatenate the BeaconProxy creation code with the ABI-encoded constructor arguments
        return abi.encodePacked(code, encodedArgs);
    }

    /// @notice returns the Atom Wallet address for the given atom data
    /// @param id vault id of the atom associated to the atom wallet
    /// @return atomWallet the address of the atom wallet
    /// NOTE: the create2 salt is based off of the vault ID
    function computeAtomWalletAddr(uint256 id) public view returns (address) {
        // compute salt for create2
        bytes32 salt = bytes32(id);

        // get contract deployment data
        bytes memory data = _getDeploymentData();

        // compute the raw contract address
        bytes32 rawAddress = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(data)));

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
    /// NOTE: deploys an ERC4337 account (atom wallet) through a BeaconProxy. Reverts if the atom vault does not exist
    function deployAtomWallet(uint256 atomId) external whenNotPaused returns (address) {
        if (atomId == 0 || atomId > count) {
            revert Errors.MultiVault_VaultDoesNotExist();
        }

        // compute salt for create2
        bytes32 salt = bytes32(atomId);

        // get contract deployment data
        bytes memory data = _getDeploymentData();

        address atomWallet;

        // deploy atom wallet with create2:
        // value sent in wei,
        // memory offset of `code` (after first 32 bytes where the length is),
        // length of `code` (first 32 bytes of code),
        // salt for create2
        assembly {
            atomWallet := create2(0, add(data, 0x20), mload(data), salt)
        }

        if (atomWallet == address(0)) {
            revert Errors.MultiVault_DeployAccountFailed();
        }

        return atomWallet;
    }

    /* -------------------------- */
    /*         Create Atom        */
    /* -------------------------- */

    /// @notice Create an atom and return its vault id
    /// @param atomUri atom data to create atom with
    /// @return id vault id of the atom
    /// NOTE: This function will revert if called with less than `getAtomCost()` in `msg.value`
    function createAtom(bytes calldata atomUri) external payable nonReentrant whenNotPaused returns (uint256) {
        if (msg.value < getAtomCost()) {
            revert Errors.MultiVault_InsufficientBalance();
        }

        // create atom and get the protocol deposit fee
        (uint256 id, uint256 protocolDepositFee) = _createAtom(atomUri, msg.value);

        uint256 totalFeesForProtocol = atomConfig.atomCreationProtocolFee + protocolDepositFee;
        _transferFeesToProtocolVault(totalFeesForProtocol);

        return id;
    }

    /// @notice Batch create atoms and return their vault ids
    /// @param atomUris atom data array to create atoms with
    /// @return ids vault ids array of the atoms
    /// NOTE: This function will revert if called with less than `getAtomCost()` * `atomUris.length` in `msg.value`
    function batchCreateAtom(bytes[] calldata atomUris)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256[] memory)
    {
        uint256 length = atomUris.length;
        if (msg.value < getAtomCost() * length) {
            revert Errors.MultiVault_InsufficientBalance();
        }

        uint256 valuePerAtom = msg.value / length;
        uint256 protocolDepositFeeTotal;
        uint256[] memory ids = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 protocolDepositFee;
            (ids[i], protocolDepositFee) = _createAtom(atomUris[i], valuePerAtom);

            // add protocol deposit fees to total
            protocolDepositFeeTotal += protocolDepositFee;
        }

        uint256 totalFeesForProtocol = atomConfig.atomCreationProtocolFee * length + protocolDepositFeeTotal;
        _transferFeesToProtocolVault(totalFeesForProtocol);

        return ids;
    }

    /// @notice Internal utility function to create an atom and handle vault creation
    /// @param atomUri The atom data to create an atom with
    /// @param value The value sent with the transaction
    /// @return id The new vault ID created for the atom
    function _createAtom(bytes calldata atomUri, uint256 value) internal returns (uint256, uint256) {
        if (atomUri.length > generalConfig.atomUriMaxLength) {
            revert Errors.MultiVault_AtomUriTooLong();
        }

        uint256 atomCost = getAtomCost();

        // check if atom already exists based on hash
        bytes32 hash = keccak256(atomUri);
        if (atomsByHash[hash] != 0) {
            revert Errors.MultiVault_AtomExists(atomUri);
        }

        // calculate user deposit amount
        uint256 userDeposit = value - atomCost;

        // create a new atom vault
        uint256 id = _createVault();

        // calculate protocol deposit fee
        uint256 protocolDepositFee = protocolFeeAmount(userDeposit, id);

        // calculate user deposit after protocol fees
        uint256 userDepositAfterProtocolFees = userDeposit - protocolDepositFee;

        // deposit user funds into vault and mint shares for the user and shares for the zero address
        _depositOnVaultCreation(
            id,
            msg.sender, // receiver
            userDepositAfterProtocolFees
        );

        // get atom wallet address for the corresponding atom
        address atomWallet = computeAtomWalletAddr(id);

        // deposit atomWalletInitialDepositAmount amount of assets and mint the shares for the atom wallet
        _depositOnVaultCreation(
            id,
            atomWallet, // receiver
            atomConfig.atomWalletInitialDepositAmount
        );

        // map the new vault ID to the atom data
        atoms[id] = atomUri;

        // map the resultant atom hash to the new vault ID
        atomsByHash[hash] = id;

        emit AtomCreated(msg.sender, atomWallet, atomUri, id);

        return (id, protocolDepositFee);
    }

    /* -------------------------- */
    /*        Create Triple       */
    /* -------------------------- */

    /// @notice create a triple and return its vault id
    /// @param subjectId vault id of the subject atom
    /// @param predicateId vault id of the predicate atom
    /// @param objectId vault id of the object atom
    /// @return id vault id of the triple
    /// NOTE: This function will revert if called with less than `getTripleCost()` in `msg.value`.
    ///       This function will revert if any of the atoms do not exist or if any ids are triple vaults.
    function createTriple(uint256 subjectId, uint256 predicateId, uint256 objectId)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (msg.value < getTripleCost()) {
            revert Errors.MultiVault_InsufficientBalance();
        }

        // create triple and get the protocol deposit fee
        (uint256 id, uint256 protocolDepositFee) = _createTriple(subjectId, predicateId, objectId, msg.value);

        uint256 totalFeesForProtocol = tripleConfig.tripleCreationProtocolFee + protocolDepositFee;
        _transferFeesToProtocolVault(totalFeesForProtocol);

        return id;
    }

    /// @notice batch create triples and return their vault ids
    /// @param subjectIds vault ids array of subject atoms
    /// @param predicateIds vault ids array of predicate atoms
    /// @param objectIds vault ids array of object atoms
    /// NOTE: This function will revert if called with less than `getTripleCost()` * `array.length` in `msg.value`.
    ///       This function will revert if any of the atoms do not exist or if any ids are triple vaults.
    function batchCreateTriple(
        uint256[] calldata subjectIds,
        uint256[] calldata predicateIds,
        uint256[] calldata objectIds
    ) external payable nonReentrant whenNotPaused returns (uint256[] memory) {
        if (subjectIds.length != predicateIds.length || subjectIds.length != objectIds.length) {
            revert Errors.MultiVault_ArraysNotSameLength();
        }

        uint256 length = subjectIds.length;
        uint256 tripleCost = getTripleCost();
        if (msg.value < tripleCost * length) {
            revert Errors.MultiVault_InsufficientBalance();
        }

        uint256 valuePerTriple = msg.value / length;
        uint256 protocolDepositFeeTotal;
        uint256[] memory ids = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 protocolDepositFee;
            (ids[i], protocolDepositFee) = _createTriple(subjectIds[i], predicateIds[i], objectIds[i], valuePerTriple);

            // add protocol deposit fees to total
            protocolDepositFeeTotal += protocolDepositFee;
        }

        uint256 totalFeesForProtocol = tripleConfig.tripleCreationProtocolFee * length + protocolDepositFeeTotal;
        _transferFeesToProtocolVault(totalFeesForProtocol);

        return ids;
    }

    /// @notice Internal utility function to create a triple
    /// @param subjectId vault id of the subject atom
    /// @param predicateId vault id of the predicate atom
    /// @param objectId vault id of the object atom
    /// @param value The amount of ETH the user has sent minus the base triple cost
    /// @return id The new vault ID of the created triple
    /// @return protocolDepositFee The calculated protocol fee for the deposit
    function _createTriple(uint256 subjectId, uint256 predicateId, uint256 objectId, uint256 value)
        internal
        returns (uint256, uint256)
    {
        uint256[3] memory tripleAtomIds = [subjectId, predicateId, objectId];

        for (uint256 i = 0; i < 3; i++) {
            // make sure atoms exist, if not, revert
            if (tripleAtomIds[i] == 0 || tripleAtomIds[i] > count) {
                revert Errors.MultiVault_AtomDoesNotExist(tripleAtomIds[i]);
            }

            // make sure that each id is not a triple vault id
            if (isTripleId(tripleAtomIds[i])) {
                revert Errors.MultiVault_VaultIsTriple(tripleAtomIds[i]);
            }
        }

        // check if triple already exists
        bytes32 hash = tripleHashFromAtoms(subjectId, predicateId, objectId);

        if (triplesByHash[hash] != 0) {
            revert Errors.MultiVault_TripleExists(subjectId, predicateId, objectId);
        }

        // calculate user deposit amount
        uint256 userDeposit = value - getTripleCost();

        // create a new positive triple vault
        uint256 id = _createVault();

        // calculate protocol deposit fee
        uint256 protocolDepositFee = protocolFeeAmount(userDeposit, id);

        // calculate user deposit after protocol fees
        uint256 userDepositAfterProtocolFees = userDeposit - protocolDepositFee;

        // map the resultant triple hash to the new vault ID of the triple
        triplesByHash[hash] = id;

        // map the triple's vault ID to the underlying atom vault IDs
        triples[id] = [subjectId, predicateId, objectId];

        // set this new triple's vault ID as true in the IsTriple mapping as well as its counter
        isTriple[id] = true;

        // give the user shares in the positive triple vault
        _depositOnVaultCreation(
            id,
            msg.sender, // receiver
            userDepositAfterProtocolFees
        );

        emit TripleCreated(msg.sender, subjectId, predicateId, objectId, id);

        return (id, protocolDepositFee);
    }

    /* -------------------------- */
    /*    Deposit/Redeem Atom     */
    /* -------------------------- */

    /// @notice deposit eth into an atom vault and grant ownership of 'shares' to 'reciever'
    /// *payable msg.value amount of eth to deposit
    /// @dev assets parameter is omitted in favor of msg.value, unlike in ERC4626
    /// @param receiver the address to receive the shares
    /// @param id the vault ID of the atom
    /// @return shares the amount of shares minted
    /// NOTE: this function will revert if the minimum deposit amount of eth is not met and
    ///       if the vault ID does not exist/is not an atom.
    function depositAtom(address receiver, uint256 id) external payable nonReentrant whenNotPaused returns (uint256) {
        if (id == 0 || id > count) {
            revert Errors.MultiVault_VaultDoesNotExist();
        }

        if (isTripleId(id)) {
            revert Errors.MultiVault_VaultNotAtom();
        }

        // deposit eth into vault and mint shares for the receiver
        (uint256 shares, uint256 protocolFees) = _deposit(receiver, id, msg.value);

        _transferFeesToProtocolVault(protocolFees);

        return shares;
    }

    /// @notice redeem assets from an atom vault
    /// @param shares the amount of shares to redeem
    /// @param receiver the address to receiver the assets
    /// @param id the vault ID of the atom
    /// @return assets the amount of assets/eth withdrawn
    function redeemAtom(uint256 shares, address receiver, uint256 id) external nonReentrant returns (uint256) {
        if (id == 0 || id > count) {
            revert Errors.MultiVault_VaultDoesNotExist();
        }

        /*
            withdraw shares from vault, returning the amount of
            assets to be transferred to the receiver
        */
        (uint256 assets, uint256 protocolFees) = _redeem(id, msg.sender, shares);

        // transfer eth to receiver factoring in fees/shares
        (bool success,) = payable(receiver).call{value: assets}("");
        if (!success) {
            revert Errors.MultiVault_TransferFailed();
        }

        _transferFeesToProtocolVault(protocolFees);

        return assets;
    }

    /* -------------------------- */
    /*   Deposit/Redeem Triple    */
    /* -------------------------- */

    /// @notice deposits assets of underlying tokens into a triple vault and grants ownership of 'shares' to 'reciever'
    /// *payable msg.value amount of eth to deposit
    /// @dev assets parameter is omitted in favor of msg.value, unlike in ERC4626
    /// @param receiver the address to receive the shares
    /// @param id the vault ID of the triple
    /// @return shares the amount of shares minted
    /// NOTE: this function will revert if the minimum deposit amount of eth is not met and
    ///       if the vault ID does not exist/is not a triple.
    function depositTriple(address receiver, uint256 id)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (!isTripleId(id)) {
            revert Errors.MultiVault_VaultNotTriple();
        }

        if (_hasCounterStake(id, receiver)) {
            revert Errors.MultiVault_HasCounterStake();
        }

        // deposit eth into vault and mint shares for the receiver
        (uint256 shares, uint256 protocolFees) = _deposit(receiver, id, msg.value);

        _transferFeesToProtocolVault(protocolFees);

        // transfer eth from sender to the MultiVault
        uint256 userDepositAfterProtocolFees = msg.value - protocolFees;

        // distribute atom shares for all 3 atoms that underlie the triple
        uint256 atomDepositFraction = atomDepositFractionAmount(userDepositAfterProtocolFees, id);
        _depositAtomFraction(id, receiver, atomDepositFraction);

        return shares;
    }

    /// @notice redeems 'shares' number of shares from the triple vault and send 'assets' eth
    ///         from the multiVault to 'reciever' factoring in exit fees
    /// @param shares the amount of shares to redeem
    /// @param receiver the address to receiver the assets
    /// @param id the vault ID of the triple
    /// @return assets the amount of assets/eth withdrawn
    function redeemTriple(uint256 shares, address receiver, uint256 id) external nonReentrant returns (uint256) {
        if (!isTripleId(id)) {
            revert Errors.MultiVault_VaultNotTriple();
        }

        /*
            withdraw shares from vault, returning the amount of
            assets to be transferred to the receiver
        */
        (uint256 assets, uint256 protocolFees) = _redeem(id, msg.sender, shares);

        // transfer eth to receiver factoring in fees/shares
        (bool success,) = payable(receiver).call{value: assets}("");
        if (!success) {
            revert Errors.MultiVault_TransferFailed();
        }

        _transferFeesToProtocolVault(protocolFees);

        return assets;
    }

    /* =================================================== */
    /*                 INTERNAL METHODS                    */
    /* =================================================== */

    /// @dev transfer fees to the protocol vault
    function _transferFeesToProtocolVault(uint256 value) internal {
        if (value == 0) return;

        (bool success,) = payable(generalConfig.protocolVault).call{value: value}("");
        if (!success) {
            revert Errors.MultiVault_TransferFailed();
        }

        emit FeesTransferred(msg.sender, generalConfig.protocolVault, value);
    }

    /// @dev _depositAtomFraction - divides amount across the three atoms composing the triple and issues the receiver shares
    /// NOTE: assumes funds have already been transferred to this contract
    function _depositAtomFraction(uint256 id, address receiver, uint256 amount) internal {
        // load atom IDs
        uint256[3] memory atomsIds;
        (atomsIds[0], atomsIds[1], atomsIds[2]) = getTripleAtoms(id);

        // floor div, so perAtom is slightly less than 1/3 of total input amount
        uint256 perAtom = amount / 3;

        // distribute proportional shares to each atom
        for (uint256 i = 0; i < 3; i++) {
            // deposit assets into each atom vault and mint shares for the receiver
            uint256 shares = _depositIntoVault(atomsIds[i], receiver, perAtom);

            // update the mapping which tracks atom shares
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
    ) internal returns (uint256) {
        uint256 entryFee = entryFeeAmount(assets, id);
        uint256 atomDepositFraction = atomDepositFractionAmount(assets, id);

        uint256 userAssets = assets - entryFee - atomDepositFraction;

        if (userAssets <= 0) {
            revert Errors.MultiVault_InsufficientDepositAmountToCoverFees();
        }

        // changes in vault's total assets
        // if the vault is an atom vault `atomDepositFraction` is 0
        uint256 totalAssetsDelta = assets - atomDepositFraction;

        uint256 sharesForReceiver;

        if (vaults[id].totalShares == generalConfig.minShare) {
            sharesForReceiver = assets; // shares owed to receiver
        } else {
            // user receives entryFeeAmount less shares than assets deposited into the vault
            sharesForReceiver = convertToShares(userAssets, id);
        }

        // changes in vault's total shares
        uint256 totalSharesDelta = sharesForReceiver;

        // set vault totals (assets and shares)
        _setVaultTotals(id, vaults[id].totalAssets + totalAssetsDelta, vaults[id].totalShares + totalSharesDelta);

        // mint `sharesOwed` shares to sender factoring in fees
        _mint(receiver, id, sharesForReceiver);

        emit Deposited(msg.sender, receiver, vaults[id].balanceOf[receiver], assets, sharesForReceiver, id);

        return sharesForReceiver;
    }

    /// @dev deposit assets into a vault upon creation
    /// change the vault's total assets, total shares and balanceOf mappings to reflect the deposit
    /// Additionally, initializes a counter vault with ghost shares.
    function _depositOnVaultCreation(uint256 id, address receiver, uint256 assets) internal {
        bool isAtomWallet = receiver == computeAtomWalletAddr(id);

        // ghost shares minted to the zero address upon vault creation
        uint256 sharesForZeroAddress = generalConfig.minShare;

        // ghost shares for the counter vault
        uint256 assetsForZeroAddressInCounterVault = generalConfig.minShare;

        uint256 sharesForReceiver = assets;

        // changes in vault's total assets or total shares
        uint256 totalDelta = isAtomWallet ? sharesForReceiver : sharesForReceiver + sharesForZeroAddress;

        // set vault totals for the vault
        _setVaultTotals(id, vaults[id].totalAssets + totalDelta, vaults[id].totalShares + totalDelta);

        // mint `sharesOwed` shares to sender factoring in fees
        _mint(receiver, id, sharesForReceiver);

        // mint `sharesForZeroAddress` shares to zero address to initialize the vault
        if (!isAtomWallet) {
            _mint(address(0), id, sharesForZeroAddress);
        }

        /*
         * Initialize the counter triple vault with ghost shares if it is a triple creation flow
         */
        if (isTripleId(id)) {
            uint256 counterVaultId = getCounterIdFromTriple(id);

            // set vault totals
            _setVaultTotals(
                counterVaultId,
                vaults[counterVaultId].totalAssets + assetsForZeroAddressInCounterVault,
                vaults[counterVaultId].totalShares + sharesForZeroAddress
            );

            // mint `sharesForZeroAddress` shares to zero address to initialize the vault
            _mint(address(0), counterVaultId, sharesForZeroAddress);
        }

        emit Deposited(msg.sender, receiver, vaults[id].balanceOf[receiver], assets, totalDelta, id);
    }

    /// @notice Internal function to encapsulate the common deposit logic for both atoms and triples
    /// @param receiver the address to receive the shares
    /// @param id the vault ID of the atom or triple
    /// @param value the amount of eth to deposit
    /// @return shares the amount of shares minted
    /// @return protocolFees the amount of protocol fees deducted
    function _deposit(address receiver, uint256 id, uint256 value) internal returns (uint256, uint256) {
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
        uint256 protocolFees = protocolFeeAmount(msg.value, id);
        uint256 userDepositAfterProtocolFees = msg.value - protocolFees;

        uint256 shares = _depositIntoVault(id, receiver, userDepositAfterProtocolFees);

        return (shares, protocolFees);
    }

    /// @dev redeem shares out of a given vault
    /// change the vault's total assets, total shares and balanceOf mappings to reflect the withdrawal
    /// @return assetsForReceiver the amount of assets/eth to be transferred to the receiver
    /// @return protocolFees the amount of protocol fees deducted
    function _redeem(uint256 id, address owner, uint256 shares) internal returns (uint256, uint256) {
        if (shares == 0) {
            revert Errors.MultiVault_DepositOrWithdrawZeroShares();
        }

        if (vaults[id].balanceOf[msg.sender] < shares) {
            revert Errors.MultiVault_InsufficientSharesInVault();
        }

        uint256 remainingShares = vaults[id].totalShares - shares;
        if (remainingShares < generalConfig.minShare) {
            revert Errors.MultiVault_InsufficientRemainingSharesInVault(remainingShares);
        }

        (uint256 assetsForReceiver, uint256 protocolFees, uint256 exitFees) = getRedeemValues(shares, id);

        // set vault totals (assets and shares)
        _setVaultTotals(
            id,
            vaults[id].totalAssets - (assetsForReceiver + protocolFees), // totalAssetsDelta
            vaults[id].totalShares - shares // totalSharesDelta
        );

        // burn shares, then transfer assets to receiver
        _burn(owner, id, shares);

        emit Redeemed(msg.sender, owner, vaults[id].balanceOf[owner], assetsForReceiver, shares, exitFees, id);

        return (assetsForReceiver, protocolFees);
    }

    /// @dev mint vault shares of vault ID `id` to address `to`
    function _mint(address to, uint256 id, uint256 amount) internal {
        vaults[id].balanceOf[to] += amount;
    }

    /// @dev burn `amount` vault shares of vault ID `id` from address `from`
    function _burn(address from, uint256 id, uint256 amount) internal {
        if (from == address(0)) revert Errors.MultiVault_BurnFromZeroAddress();

        uint256 fromBalance = vaults[id].balanceOf[from];
        if (fromBalance < amount) {
            revert Errors.MultiVault_BurnInsufficientBalance();
        }

        unchecked {
            vaults[id].balanceOf[from] = fromBalance - amount;
        }
    }

    /// @dev set total assets and shares for a vault
    function _setVaultTotals(uint256 id, uint256 totalAssets, uint256 totalShares) internal {
        vaults[id].totalAssets = totalAssets;
        vaults[id].totalShares = totalShares;
    }

    /// @dev internal method for vault creation
    function _createVault() internal returns (uint256) {
        uint256 id = ++count;
        return id;
    }

    /// @dev internal method to validate the timelock constraints
    function _validateTimelock(bytes32 operationHash) internal view {
        Timelock memory timelock = timelocks[operationHash];

        if (timelock.readyTime == 0) {
            revert Errors.MultiVault_OperationNotScheduled();
        }
        if (timelock.executed) {
            revert Errors.MultiVault_OperationAlreadyExecuted();
        }
        if (timelock.readyTime > block.timestamp) {
            revert Errors.MultiVault_TimelockNotExpired();
        }
    }

    /* =================================================== */
    /*               RESTRICTED FUNCTIONS                  */
    /* =================================================== */

    /// @dev pause the pausable contract methods
    function pause() external onlyAdmin {
        _pause();
    }

    /// @dev unpause the pausable contract methods
    function unpause() external onlyAdmin {
        _unpause();
    }

    /// @dev schedule an operation to be executed after a delay
    /// @param operationId unique identifier for the operation
    /// @param data data to be executed
    function scheduleOperation(bytes32 operationId, bytes calldata data) external onlyAdmin {
        uint256 minDelay = generalConfig.minDelay;

        // Generate the operation hash
        bytes32 operationHash = keccak256(abi.encodePacked(operationId, data, minDelay));

        // Check timelock constraints and schedule the operation
        if (timelocks[operationHash].readyTime != 0) {
            revert Errors.MultiVault_OperationAlreadyScheduled();
        }

        // calculate the time when the operation can be executed
        uint256 readyTime = block.timestamp + minDelay;

        timelocks[operationHash] = Timelock({data: data, readyTime: readyTime, executed: false});
    }

    /// @dev execute a scheduled operation
    /// @param operationId unique identifier for the operation
    /// @param data data to be executed
    function cancelOperation(bytes32 operationId, bytes calldata data) external onlyAdmin {
        // Generate the operation hash
        bytes32 operationHash = keccak256(abi.encodePacked(operationId, data, generalConfig.minDelay));

        // Check timelock constraints and cancel the operation
        Timelock memory timelock = timelocks[operationHash];

        if (timelock.readyTime == 0) {
            revert Errors.MultiVault_OperationNotScheduled();
        }
        if (timelock.executed) {
            revert Errors.MultiVault_OperationAlreadyExecuted();
        }

        delete timelocks[operationHash];
    }

    /// @dev set admin
    /// @param admin address of the new admin
    function setAdmin(address admin) external onlyAdmin {
        // Generate the operation hash
        bytes memory data = abi.encodeWithSelector(EthMultiVault.setAdmin.selector, admin);
        bytes32 opHash = keccak256(abi.encodePacked(SET_ADMIN, data, generalConfig.minDelay));

        // Check timelock constraints
        _validateTimelock(opHash);

        // Execute the operation
        generalConfig.admin = admin;

        // Mark the operation as executed
        timelocks[opHash].executed = true;
    }

    /// @dev set protocol vault
    /// @param protocolVault address of the new protocol vault
    function setProtocolVault(address protocolVault) external onlyAdmin {
        generalConfig.protocolVault = protocolVault;
    }

    /// @dev sets the minimum deposit amount for atoms and triples
    /// @param minDeposit new minimum deposit amount
    function setMinDeposit(uint256 minDeposit) external onlyAdmin {
        generalConfig.minDeposit = minDeposit;
    }

    /// @dev sets the minimum share amount for atoms and triples
    /// @param minShare new minimum share amount
    function setMinShare(uint256 minShare) external onlyAdmin {
        generalConfig.minShare = minShare;
    }

    /// @dev sets the atom URI max length
    /// @param atomUriMaxLength new atom URI max length
    function setAtomUriMaxLength(uint256 atomUriMaxLength) external onlyAdmin {
        generalConfig.atomUriMaxLength = atomUriMaxLength;
    }

    /// @dev sets the atom share lock fee
    /// @param atomWalletInitialDepositAmount new atom share lock fee
    function setAtomWalletInitialDepositAmount(uint256 atomWalletInitialDepositAmount) external onlyAdmin {
        atomConfig.atomWalletInitialDepositAmount = atomWalletInitialDepositAmount;
    }

    /// @dev sets the atom creation fee
    /// @param atomCreationProtocolFee new atom creation fee
    function setAtomCreationProtocolFee(uint256 atomCreationProtocolFee) external onlyAdmin {
        atomConfig.atomCreationProtocolFee = atomCreationProtocolFee;
    }

    /// @dev sets fee charged in wei when creating a triple to protocol vault
    /// @param tripleCreationProtocolFee new fee in wei
    function setTripleCreationProtocolFee(uint256 tripleCreationProtocolFee) external onlyAdmin {
        tripleConfig.tripleCreationProtocolFee = tripleCreationProtocolFee;
    }

    /// @dev sets the atom deposit fraction percentage for atoms used in triples
    ///      (number to be divided by `generalConfig.feeDenominator`)
    /// @param atomDepositFractionForTriple new atom deposit fraction percentage
    function setAtomDepositFractionForTriple(uint256 atomDepositFractionForTriple) external onlyAdmin {
        tripleConfig.atomDepositFractionForTriple = atomDepositFractionForTriple;
    }

    /// @dev sets entry fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default entry fee, id = n changes fees for vault n specifically
    /// @dev entry fee cannot be set greater than `generalConfig.feeDenominator` (which represents 100%)
    /// @param id vault id to set entry fee for
    /// @param entryFee entry fee to set
    function setEntryFee(uint256 id, uint256 entryFee) external onlyAdmin {
        if (entryFee > generalConfig.feeDenominator) {
            revert Errors.MultiVault_InvalidFeeSet();
        }

        vaultFees[id].entryFee = entryFee;
    }

    /// @dev sets exit fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default exit fee, id = n changes fees for vault n specifically
    /// @dev admin cannot set the exit fee to be greater than `maxExitFeePercentage`, which is
    ///      set to be the 10% of `generalConfig.feeDenominator` (which represents 100%), to avoid
    ///      being able to prevent users from withdrawing their assets
    /// @param id vault id to set exit fee for
    /// @param exitFee exit fee to set
    function setExitFee(uint256 id, uint256 exitFee) external onlyAdmin {
        uint256 maxExitFeePercentage = generalConfig.feeDenominator / 10;

        if (exitFee > maxExitFeePercentage) {
            revert Errors.MultiVault_InvalidExitFee();
        }

        // Generate the operation hash
        bytes memory data = abi.encodeWithSelector(EthMultiVault.setExitFee.selector, id, exitFee);
        bytes32 opHash = keccak256(abi.encodePacked(SET_EXIT_FEE, data, generalConfig.minDelay));

        // Check timelock constraints
        _validateTimelock(opHash);

        // Execute the operation
        vaultFees[id].exitFee = exitFee;

        // Mark the operation as executed
        timelocks[opHash].executed = true;
    }

    /// @dev sets protocol fees for the specified vault (id=0 sets the default fees for all vaults)
    ///      id = 0 changes the default protocol fee, id = n changes fees for vault n specifically
    /// @dev protocol fee cannot be set greater than `generalConfig.feeDenominator` (which represents 100%)
    /// @param id vault id to set protocol fee for
    /// @param protocolFee protocol fee to set
    function setProtocolFee(uint256 id, uint256 protocolFee) external onlyAdmin {
        if (protocolFee > generalConfig.feeDenominator) {
            revert Errors.MultiVault_InvalidFeeSet();
        }

        vaultFees[id].protocolFee = protocolFee;
    }

    /* =================================================== */
    /*                    MODIFIERS                        */
    /* =================================================== */

    modifier onlyAdmin() {
        if (msg.sender != generalConfig.admin) {
            revert Errors.MultiVault_AdminOnly();
        }
        _;
    }

    /* =================================================== */
    /*                     FALLBACK                        */
    /* =================================================== */

    /// @notice fallback function to decompress the calldata and call the appropriate function
    fallback() external payable {
        LibZip.cdFallback();
    }

    /// @notice contract does not accept ETH donations
    receive() external payable {
        revert Errors.MultiVault_ReceiveNotAllowed();
    }
}
