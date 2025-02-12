// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FeaUrchin is Ownable {
    IEthMultiVault public immutable ethMultiVault;
    uint256 public feeNumerator;
    uint256 public feeDenominator;

    error ETHTransferFailed();

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
        fee = amount * feeNumerator / feeDenominator;
        netValue = amount - fee;
        return (fee, netValue);
    }

    modifier trackUser() {
        _trackUser(msg.sender);
        _;
    }

    function getAtomCost() public view returns (uint256 atomCost) {
        uint256 targetAmount = ethMultiVault.getAtomCost();
        atomCost = (targetAmount * feeDenominator) / (feeDenominator - feeNumerator);
    }

    function getTripleCost() public view returns (uint256 tripleCost) {
        uint256 targetAmount = ethMultiVault.getTripleCost();
        tripleCost = (targetAmount * feeDenominator) / (feeDenominator - feeNumerator);
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
        termId = ethMultiVault.createTriple{value: netValue}(subjectId, predicateId, objectId);
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
        shares = _deposit(netValue, receiver, id, curveId);
        emit Deposited(msg.sender, id, curveId, netValue, fee);
        return shares;
    }

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

    function _sendETH(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert ETHTransferFailed();
    }

    function redeem(uint256 shares, address receiver, uint256 id, uint256 curveId)
        external
        trackUser
        returns (uint256)
    {
        uint256 redeemedAssets = _redeem(shares, id, curveId);
        (uint256 fee, uint256 netAmount) = _processRedeem(redeemedAssets);
        _sendETH(receiver, netAmount);
        emit Redeemed(msg.sender, id, curveId, netAmount, fee);
        return netAmount;
    }

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

    function withdrawFees(address payable recipient) external onlyOwner {
        uint256 amount = address(this).balance;
        _sendETH(recipient, amount);
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
        ones = new uint256[](length);
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

        shares = new uint256[](count);
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
        assets = new uint256[](count);
        uint256 totalFee;
        uint256 totalNetValue;

        for (uint256 i = 0; i < count; i++) {
            assets[i] = _redeem(shares[i], ids[i], curveIds[i]);
            (uint256 fee, uint256 netValue) = _processRedeem(assets[i]);
            totalFee += fee;
            totalNetValue += netValue;
        }

        _sendETH(receiver, totalNetValue);
        emit BatchRedeemed(msg.sender, ids, curveIds, totalNetValue, totalFee);
        return assets;
    }

    receive() external payable {}
}
