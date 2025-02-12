// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEthMultiVault} from "interfaces/IEthMultiVault.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeTransferLib} from "@openzeppelin/contracts/utils/SafeTransferLib.sol";

contract FeaUrchin is Ownable {
    IEthMultiVault public immutable ethMultiVault;
    uint256 public feeNumerator;
    uint256 public feeDenominator;

    event Deposited(address indexed user, uint256 indexed id, uint256 indexed curveId, uint256 assets, uint256 fee);
    event Redeemed(address indexed user, uint256 indexed id, uint256 indexed curveId, uint256 assets, uint256 fee);
    event FeesWithdrawn(address indexed admin, uint256 amount);
    event NewUser(address indexed user);
    event FeeChanged(uint256 newNumerator, uint256 newDenominator);
    event BatchDeposited(
        address indexed user, uint256[] ids, uint256[] curveIds, uint256 totalAssets, uint256 totalFee
    );
    event BatchRedeemed(address indexed user, uint256[] ids, uint256[] curveIds, uint256 totalAssets, uint256 totalFee);

    uint256 public totalAssetsMoved;
    uint256 public totalAssetsStaked;
    uint256 public totalFeesCollected;
    uint256 public uniqueUsersCount;
    mapping(address => bool) public isUniqueUser;

    constructor(IEthMultiVault _ethMultiVault, address _admin, uint256 _feeNumerator, uint256 _feeDenominator)
        Ownable(_admin)
    {
        ethMultiVault = _ethMultiVault;
        feeNumerator = _feeNumerator;
        feeDenominator = _feeDenominator;
        emit FeeChanged(_feeNumerator, _feeDenominator);
    }

    function setFee(uint256 _feeNumerator, uint256 _feeDenominator) external onlyOwner {
        feeNumerator = _feeNumerator;
        feeDenominator = _feeDenominator;
        emit FeeChanged(_feeNumerator, _feeDenominator);
    }

    function applyFee(uint256 amount) public view returns (uint256 fee, uint256 netValue) {
        uint256 fee = amount * feeNumerator / feeDenominator;
        uint256 netValue = amount - fee;
        return (fee, netValue);
    }

    modifier trackUser() {
        _trackUser(msg.sender);
        _;
    }

    function _processDeposit(uint256 amount) internal returns (uint256 fee, uint256 netValue) {
        (fee, netValue) = applyFee(amount);
        totalAssetsMoved += amount;
        totalAssetsStaked += amount;
        totalFeesCollected += fee;
        return (fee, netValue);
    }

    function _processRedeem(uint256 assets) internal returns (uint256 fee, uint256 netValue) {
        (fee, netValue) = applyFee(assets);
        totalAssetsMoved += assets;
        totalAssetsStaked -= assets;
        totalFeesCollected += fee;
        return (fee, netValue);
    }

    function createAtom(bytes calldata atomUri) external payable trackUser returns (uint256 termId) {
        (uint256 fee, uint256 netValue) = _processDeposit(msg.value);
        termId = ethMultiVault.createAtom{value: netValue}(atomUri);
        emit Deposited(msg.sender, termId, 1, netValue, fee);
        return termId;
    }

    function createTriple(uint256 subjectId, uint256 predicateId, uint256 objectId)
        external
        payable
        trackUser
        returns (uint256 termId)
    {
        (uint256 fee, uint256 netValue) = _processDeposit(msg.value);
        uint256 termId = ethMultiVault.createTriple{value: netValue}(subjectId, predicateId, objectId);
        emit Deposited(msg.sender, termId, 1, netValue, fee);
        return termId;
    }

    function deposit(address receiver, uint256 id, uint256 curveId)
        external
        payable
        trackUser
        returns (uint256 shares)
    {
        (uint256 fee, uint256 netValue) = _processDeposit(msg.value);
        uint256 shares = _deposit(netValue, receiver, id, curveId);
        emit Deposited(msg.sender, id, curveId, netValue, fee);
        return shares;
    }

    function _deposit(uint256 value, address receiver, uint256 id, uint256 curveId) internal returns (uint256 shares) {
        if (curveId == 1) {
            shares = ethMultiVault.isTripleId(id)
                ? ethMultiVault.depositTriple{value: netValue}(receiver, id)
                : ethMultiVault.depositAtom{value: netValue}(receiver, id);
        } else {
            shares = ethMultiVault.isTripleId(id)
                ? ethMultiVault.depositTripleCurve{value: netValue}(receiver, id, curveId)
                : ethMultiVault.depositAtomCurve{value: netValue}(receiver, id, curveId);
        }
        return shares;
    }

    function redeem(uint256 shares, address receiver, uint256 id, uint256 curveId)
        external
        trackUser
        returns (uint256)
    {
        uint256 redeemedAssets = _redeem(shares, receiver, id, curveId);
        (uint256 fee, uint256 netAmount) = _processRedeem(assets);
        SafeTransferLib.safeTransferETH(receiver, netAmount);
        emit Redeemed(msg.sender, id, curveId, netAmount, fee);
        return netAmount;
    }

    function _redeem(uint256 shares, address receiver, uint256 id, uint256 curveId) internal returns (uint256 assets) {
        if (curveId == 1) {
            assets = ethMultiVault.isTripleId(id)
                ? ethMultiVault.redeemTriple(shares, receiver, id)
                : ethMultiVault.redeemAtom(shares, receiver, id);
        } else {
            assets = ethMultiVault.isTripleId(id)
                ? ethMultiVault.redeemTripleCurve(shares, receiver, id, curveId)
                : ethMultiVault.redeemAtomCurve(shares, receiver, id, curveId);
        }
        return assets;
    }

    function withdrawFees(address payable recipient) external onlyOwner {
        uint256 amount = address(this).balance;
        SafeTransferLib.safeTransferETH(recipient, amount);
        emit FeesWithdrawn(msg.sender, amount);
    }

    function _trackUser(address user) internal {
        if (!isUniqueUser[user]) {
            isUniqueUser[user] = true;
            uniqueUsersCount++;
            emit NewUser(user);
        }
    }

    function _ones(uint256 length) internal returns (uint256[] memory ones) {
        uint256[] memory ones = new uint256[](length);
        for (uint256 i; i < length;) {
            ones[i] = 1;
            unchecked {
                ++i;
            }
        }
        return ones;
    }

    function batchCreateAtom(bytes[] calldata atomUris) external payable trackUser returns (uint256[] memory termIds) {
        (uint256 fee, uint256 netValue) = _processDeposit(msg.value);
        termIds = ethMultiVault.batchCreateAtom{value: netValue}(atomUris);
        emit BatchDeposited(msg.sender, termIds, _ones(termIds.length), netValue, fee);
        return termIds;
    }

    function batchCreateTriple(
        uint256[] calldata subjectIds,
        uint256[] calldata predicateIds,
        uint256[] calldata objectIds
    ) external payable trackUser returns (uint256[] memory termIds) {
        (uint256 fee, uint256 netValue) = _processDeposit(msg.value);
        termIds = ethMultiVault.batchCreateTriple{value: netValue}(subjectIds, predicateIds, objectIds);
        emit BatchDeposited(msg.sender, termIds, _ones(termIds.length), netValue, fee);
        return termIds;
    }

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

        uint256[] memory shares = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            shares[i] = _deposit(valuePerItem, receiver, ids[i], curveIds[i]);
        }

        emit BatchDeposited(msg.sender, ids, curveIds, totalNetValue, totalFee);
        return shares;
    }

    function batchRedeem(
        uint256[] calldata shares,
        address receiver,
        uint256[] calldata ids,
        uint256[] calldata curveIds
    ) external trackUser returns (uint256[] memory assets) {
        require(shares.length == ids.length && ids.length == curveIds.length, "Array length mismatch");
        uint256 count = ids.length;
        uint256[] memory assets = new uint256[](count);
        uint256 totalFee;
        uint256 totalNetValue;

        for (uint256 i = 0; i < count; i++) {
            assets[i] = _redeem(shares[i], receiver, ids[i], curveIds[i]);
            (uint256 fee, netValue) = _processRedeem(assets[i]);
            totalFee += fee;
            totalNetValue += netValue;
        }

        emit BatchRedeemed(msg.sender, ids, curveIds, totalNetValue, totalFee);
        return assets;
    }

    receive() external payable {}
}
