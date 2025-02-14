// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {console2 as console} from "forge-std/console2.sol";

/**
 * @title  FeaUrchin
 * @author 0xIntuition
 * @notice A fee-taking wrapper contract for the EthMultiVault that enables customizable
 *         fee structures for atom and triple operations. This contract acts as an
 *         intermediary layer between users and the EthMultiVault, collecting fees
 *         while maintaining full compatibility with the vault's functionality.
 *
 * @notice The contract implements a percentage-based fee system where fees are
 *         calculated using a numerator/denominator pair. All operations that involve
 *         asset transfers (deposits, creations) include fee collection. The collected
 *         fees can be withdrawn by the contract administrator.
 *
 * @dev    This contract inherits from OpenZeppelin's Ownable for admin functionality.
 *         It maintains its own accounting of total assets moved, staked, and fees
 *         collected. The contract also tracks unique users for analytics purposes.
 */
contract FeaUrchin is Ownable {
    /// @notice The EthMultiVault instance this contract interacts with
    IEthMultiVault public immutable ethMultiVault;
    /// @notice The numerator of the fee fraction
    uint256 public feeNumerator;
    /// @notice The denominator of the fee fraction
    uint256 public feeDenominator;

    /// @notice Total amount of assets that have moved through this contract
    uint256 public totalAssetsMoved;
    /// @notice Total amount of assets currently staked through this contract
    uint256 public totalAssetsStaked;
    /// @notice Total amount of fees collected by this contract
    uint256 public totalFeesCollected;
    /// @notice Number of unique users who have interacted with this contract
    uint256 public uniqueUsersCount;
    /// @notice Mapping to track whether an address has interacted with this contract
    mapping(address => bool) public isUniqueUser;

    /// @notice Mapping of user -> term -> curve -> shares purchased via this contract
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) userShares;

    /// @notice Thrown when an ETH transfer fails
    error ETHTransferFailed();

    /// @notice Emitted when a user deposits assets
    /// @param user The address of the user who deposited
    /// @param id The ID of the atom or triple
    /// @param curveId The ID of the bonding curve used
    /// @param assets The amount of assets deposited (after fees)
    /// @param fee The amount of fees collected
    event Deposited(address indexed user, uint256 indexed id, uint256 indexed curveId, uint256 assets, uint256 fee);
    
    /// @notice Emitted when a user redeems shares
    /// @param user The address of the user who redeemed
    /// @param id The ID of the atom or triple
    /// @param curveId The ID of the bonding curve used
    /// @param assets The amount of assets redeemed (after fees)
    /// @param fee The amount of fees collected
    event Redeemed(address indexed user, uint256 indexed id, uint256 indexed curveId, uint256 assets, uint256 fee);
    
    /// @notice Emitted when the admin withdraws collected fees
    /// @param admin The address of the admin who withdrew fees
    /// @param amount The amount of fees withdrawn
    event FeesWithdrawn(address indexed admin, uint256 amount);
    
    /// @notice Emitted when a new user interacts with the contract for the first time
    /// @param user The address of the new user
    event NewUser(address indexed user);
    
    /// @notice Emitted when the fee parameters are changed
    /// @param newNumerator The new fee numerator
    /// @param newDenominator The new fee denominator
    event FeeChanged(uint256 newNumerator, uint256 newDenominator);
    
    /// @notice Emitted when a batch deposit operation is performed
    /// @param user The address of the user who performed the batch deposit
    /// @param ids The IDs of the atoms or triples
    /// @param curveIds The IDs of the bonding curves used
    /// @param totalAssets The total amount of assets deposited (after fees)
    /// @param totalFee The total amount of fees collected
    event BatchDeposited(
        address indexed user, uint256[] ids, uint256[] curveIds, uint256 totalAssets, uint256 totalFee
    );
    
    /// @notice Emitted when a batch redeem operation is performed
    /// @param user The address of the user who performed the batch redeem
    /// @param ids The IDs of the atoms or triples
    /// @param curveIds The IDs of the bonding curves used
    /// @param totalAssets The total amount of assets redeemed (after fees)
    /// @param totalFee The total amount of fees collected
    event BatchRedeemed(address indexed user, uint256[] ids, uint256[] curveIds, uint256 totalAssets, uint256 totalFee);



    /// @notice Constructor that initializes the contract with its core parameters
    /// @param _ethMultiVault The EthMultiVault contract this will interact with
    /// @param _admin The address that will be set as the contract admin
    /// @param _feeNumerator The numerator of the fee fraction
    /// @param _feeDenominator The denominator of the fee fraction
    constructor(IEthMultiVault _ethMultiVault, address _admin, uint256 _feeNumerator, uint256 _feeDenominator)
        Ownable(_admin)
    {
        ethMultiVault = _ethMultiVault;
        feeNumerator = _feeNumerator;
        feeDenominator = _feeDenominator;
        emit FeeChanged(_feeNumerator, _feeDenominator);
    }

    /// @notice Allows the admin to update the fee parameters
    /// @param _feeNumerator The new fee numerator
    /// @param _feeDenominator The new fee denominator
    function setFee(uint256 _feeNumerator, uint256 _feeDenominator) external onlyOwner {
        feeNumerator = _feeNumerator;
        feeDenominator = _feeDenominator;
        emit FeeChanged(_feeNumerator, _feeDenominator);
    }

    /// @notice Calculates the fee and net value for a given amount
    /// @param amount The amount to calculate fees for
    /// @return fee The calculated fee amount
    /// @return netValue The amount after fees are deducted
    function applyFee(uint256 amount) public view returns (uint256 fee, uint256 netValue) {
        fee = amount * feeNumerator / feeDenominator;
        netValue = amount - fee;
        return (fee, netValue);
    }

    /// @notice Modifier that tracks unique users
    modifier trackUser() {
        _trackUser(msg.sender);
        _;
    }

    function _getVaultShares(address user, uint256 termId, uint256 bondingCurveId) internal view returns (uint256 shares) {
      if (bondingCurveId == 1) {
        (shares,) = ethMultiVault.getVaultStateForUser(termId, user);
      } else {
        (shares,) = ethMultiVault.getVaultStateForUserCurve(termId, bondingCurveId, user);
      }
    }

    function getVaultShares(address user, uint256 termId, uint256 bondingCurveId) external view returns (uint256 shares) {
        return userShares[user][termId][bondingCurveId];
    }

    /// @notice Calculates the total cost to create an atom, including fees
    /// @return atomCost The total cost including fees
    function getAtomCost() public view returns (uint256 atomCost) {
        uint256 targetAmount = ethMultiVault.getAtomCost();
        atomCost = (targetAmount * feeDenominator) / (feeDenominator - feeNumerator);
    }

    /// @notice Calculates the total cost to create a triple, including fees
    /// @return tripleCost The total cost including fees
    function getTripleCost() public view returns (uint256 tripleCost) {
        uint256 targetAmount = ethMultiVault.getTripleCost();
        tripleCost = (targetAmount * feeDenominator) / (feeDenominator - feeNumerator);
    }

    /// @dev Internal function to process deposits and update accounting
    /// @param amount The amount being deposited
    /// @return fee The calculated fee amount
    /// @return netValue The amount after fees
    function _processDeposit(uint256 amount) internal returns (uint256 fee, uint256 netValue) {
        (fee, netValue) = applyFee(amount);
        totalAssetsMoved += amount;
        totalAssetsStaked += amount;
        totalFeesCollected += fee;
        return (fee, netValue);
    }

    /// @dev Internal function to process redemptions and update accounting
    /// @param assets The amount being redeemed
    /// @return fee The calculated fee amount
    /// @return netValue The amount after fees
    function _processRedeem(uint256 assets) internal returns (uint256 fee, uint256 netValue) {
        (fee, netValue) = applyFee(assets);
        totalAssetsMoved += assets;
        totalAssetsStaked -= assets;
        totalFeesCollected += fee;
        return (fee, netValue);
    }

    /// @notice Creates a new atom with the provided URI
    /// @param atomUri The URI data for the atom
    /// @return termId The ID of the created atom
    function createAtom(bytes calldata atomUri) external payable trackUser returns (uint256 termId) {
        (uint256 fee, uint256 netValue) = _processDeposit(msg.value);
        termId = ethMultiVault.createAtom{value: netValue}(atomUri);
        userShares[msg.sender][termId][1] = _getVaultShares(address(this), termId, 1); 
        emit Deposited(msg.sender, termId, 1, netValue, fee);
        return termId;
    }

    /// @notice Creates a new triple with the provided subject, predicate, and object IDs
    /// @param subjectId The ID of the subject atom/triple
    /// @param predicateId The ID of the predicate atom/triple
    /// @param objectId The ID of the object atom/triple
    /// @return termId The ID of the created triple
    function createTriple(uint256 subjectId, uint256 predicateId, uint256 objectId)
        external
        payable
        trackUser
        returns (uint256 termId)
    {
        (uint256 fee, uint256 netValue) = _processDeposit(msg.value);
        termId = ethMultiVault.createTriple{value: netValue}(subjectId, predicateId, objectId);
        userShares[msg.sender][termId][1] = _getVaultShares(address(this), termId, 1); 
        emit Deposited(msg.sender, termId, 1, netValue, fee);
        return termId;
    }

    /// @notice Deposits assets for an atom or triple
    /// @param receiver The address that will receive the shares
    /// @param id The ID of the atom or triple
    /// @param curveId The ID of the bonding curve to use
    /// @return shares The number of shares received
    function deposit(address receiver, uint256 id, uint256 curveId)
        external
        payable
        trackUser
        returns (uint256 shares)
    {
        (uint256 fee, uint256 netValue) = _processDeposit(msg.value);
        shares = _deposit(netValue, receiver, id, curveId);
        userShares[receiver][id][curveId] += shares;
        emit Deposited(receiver, id, curveId, netValue, fee);
        return shares;
    }

    /// @dev Internal function to handle deposits to the vault
    /// @param value The amount to deposit
    /// @param receiver The address that will receive the shares
    /// @param id The ID of the atom or triple
    /// @param curveId The ID of the bonding curve to use
    /// @return shares The number of shares received
    function _deposit(uint256 value, address receiver, uint256 id, uint256 curveId) internal returns (uint256 shares) {
        if (curveId == 1) {
            shares = ethMultiVault.isTripleId(id)
                ? ethMultiVault.depositTriple{value: value}(receiver, id)
                : ethMultiVault.depositAtom{value: value}(receiver, id);
        } else {
            shares = ethMultiVault.isTripleId(id)
                ? ethMultiVault.depositTripleCurve{value: value}(receiver, id, curveId)
                : ethMultiVault.depositAtomCurve{value: value}(receiver, id, curveId);
        }
        return shares;
    }

    /// @dev Internal function to send ETH
    /// @param to The address to send ETH to
    /// @param amount The amount of ETH to send
    function _sendETH(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert ETHTransferFailed();
    }

    /// @notice Redeems shares for an atom or triple
    /// @param shares The number of shares to redeem
    /// @param receiver The address that will receive the assets
    /// @param id The ID of the atom or triple
    /// @param curveId The ID of the bonding curve to use
    /// @return The amount of assets received
    function redeem(uint256 shares, address receiver, uint256 id, uint256 curveId)
        external
        trackUser
        returns (uint256)
    {
      console.log("shares: ", shares);
      console.log("userShares: ", userShares[receiver][id][curveId]);
      require(shares <= userShares[receiver][id][curveId]);

      uint256 redeemedAssets = _redeem(shares, id, curveId);
        (uint256 fee, uint256 netAmount) = _processRedeem(redeemedAssets);
        userShares[receiver][id][curveId] -= shares;
        _sendETH(receiver, netAmount);
        emit Redeemed(receiver, id, curveId, netAmount, fee);
        return netAmount;
    }

    /// @dev Internal function to handle redemptions from the vault
    /// @param shares The number of shares to redeem
    /// @param id The ID of the atom or triple
    /// @param curveId The ID of the bonding curve to use
    /// @return assets The amount of assets received
    function _redeem(uint256 shares, uint256 id, uint256 curveId) internal returns (uint256 assets) {
        if (curveId == 1) {
            assets = ethMultiVault.isTripleId(id)
                ? ethMultiVault.redeemTriple(shares, address(this), id)
                : ethMultiVault.redeemAtom(shares, address(this), id);
        } else {
            assets = ethMultiVault.isTripleId(id)
                ? ethMultiVault.redeemTripleCurve(shares, address(this), id, curveId)
                : ethMultiVault.redeemAtomCurve(shares, address(this), id, curveId);
        }
        return assets;
    }

    /// @notice Allows the admin to withdraw collected fees
    /// @param recipient The address that will receive the fees
    function withdrawFees(address payable recipient) external onlyOwner {
        uint256 amount = address(this).balance;
        _sendETH(recipient, amount);
        emit FeesWithdrawn(msg.sender, amount);
    }

    /// @dev Internal function to track unique users
    /// @param user The address of the user to track
    function _trackUser(address user) internal {
        if (!isUniqueUser[user]) {
            isUniqueUser[user] = true;
            uniqueUsersCount++;
            emit NewUser(user);
        }
    }

    /// @dev Internal function to create an array of ones
    /// @param length The length of the array to create
    /// @return ones An array filled with ones
    function _ones(uint256 length) internal returns (uint256[] memory ones) {
        ones = new uint256[](length);
        for (uint256 i; i < length;) {
            ones[i] = 1;
            unchecked {
                ++i;
            }
        }
        return ones;
    }

    /// @notice Creates multiple atoms in a single transaction
    /// @param atomUris The URIs for the atoms to create
    /// @return termIds The IDs of the created atoms
    function batchCreateAtom(bytes[] calldata atomUris) external payable trackUser returns (uint256[] memory termIds) {
        (uint256 fee, uint256 netValue) = _processDeposit(msg.value);
        termIds = ethMultiVault.batchCreateAtom{value: netValue}(atomUris);
        for (uint256 i = 0; i < termIds.length; i++) {
          userShares[msg.sender][termIds[i]][1] = _getVaultShares(address(this), termIds[i], 1); 
        }
        emit BatchDeposited(msg.sender, termIds, _ones(termIds.length), netValue, fee);
        return termIds;
    }

    /// @notice Creates multiple triples in a single transaction
    /// @param subjectIds The IDs of the subject atoms/triples
    /// @param predicateIds The IDs of the predicate atoms/triples
    /// @param objectIds The IDs of the object atoms/triples
    /// @return termIds The IDs of the created triples
    function batchCreateTriple(
        uint256[] calldata subjectIds,
        uint256[] calldata predicateIds,
        uint256[] calldata objectIds
    ) external payable trackUser returns (uint256[] memory termIds) {
        (uint256 fee, uint256 netValue) = _processDeposit(msg.value);
        termIds = ethMultiVault.batchCreateTriple{value: netValue}(subjectIds, predicateIds, objectIds);
        for (uint256 i = 0; i < termIds.length; i++) {
          userShares[msg.sender][termIds[i]][1] = _getVaultShares(address(this), termIds[i], 1); 
        }
        emit BatchDeposited(msg.sender, termIds, _ones(termIds.length), netValue, fee);
        return termIds;
    }

    /// @notice Deposits assets for multiple atoms or triples in a single transaction
    /// @param receiver The address that will receive the shares
    /// @param ids The IDs of the atoms or triples
    /// @param curveIds The IDs of the bonding curves to use
    /// @return shares The numbers of shares received
    function batchDeposit(address receiver, uint256[] calldata ids, uint256[] calldata curveIds)
        external
        payable
        trackUser
        returns (uint256[] memory shares)
    {
        require(ids.length == curveIds.length, "Array length mismatch");
        uint256 count = ids.length;
        (uint256 totalFee, uint256 totalNetValue) = _processDeposit(msg.value);
        uint256 valuePerItem = totalNetValue / count;

        shares = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            shares[i] = _deposit(valuePerItem, receiver, ids[i], curveIds[i]);
            userShares[receiver][ids[i]][curveIds[i]] += shares[i];
        }

        emit BatchDeposited(msg.sender, ids, curveIds, totalNetValue, totalFee);
        return shares;
    }

    /// @notice Redeems shares for multiple atoms or triples in a single transaction
    /// @param shares The numbers of shares to redeem
    /// @param receiver The address that will receive the assets
    /// @param ids The IDs of the atoms or triples
    /// @param curveIds The IDs of the bonding curves to use
    /// @return assets The amounts of assets received
    function batchRedeem(
        uint256[] calldata shares,
        address receiver,
        uint256[] calldata ids,
        uint256[] calldata curveIds
    ) external trackUser returns (uint256[] memory assets) {
        require(shares.length == ids.length && ids.length == curveIds.length, "Array length mismatch");
        uint256 count = ids.length;
        assets = new uint256[](count);
        uint256 totalFee;
        uint256 totalNetValue;

        for (uint256 i = 0; i < count; i++) {
            assets[i] = _redeem(shares[i], ids[i], curveIds[i]);
            userShares[receiver][ids[i]][curveIds[i]] -= shares[i];
            (uint256 fee, uint256 netValue) = _processRedeem(assets[i]);
            totalFee += fee;
            totalNetValue += netValue;
        }

        _sendETH(receiver, totalNetValue);
        emit BatchRedeemed(receiver, ids, curveIds, totalNetValue, totalFee);
        return assets;
    }

    /// @notice Allows the contract to receive ETH
    receive() external payable {}
}
