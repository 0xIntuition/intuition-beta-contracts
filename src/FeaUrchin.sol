// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEthMultiVault} from "interfaces/IEthMultiVault.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeTransferLib} from "@openzeppelin/contracts/utils/SafeTransferLib.sol";

contract FeaUrchin is Ownable {
    IEthMultiVault public immutable ethMultiVault;
    uint256 public feeNumerator;
    uint256 public feeDenominator;

    event Deposited(address indexed user, address indexed vault, uint256 assets, uint256 fee);
    event Redeemed(address indexed user, address indexed vault, uint256 assets, uint256 fee);
    event CurveDeposited(address indexed user, address indexed vault, uint256 curveId, uint256 assets, uint256 fee);
    event CurveRedeemed(address indexed user, address indexed vault, uint256 curveId, uint256 assets, uint256 fee);
    event FeesWithdrawn(address indexed admin, uint256 amount);
    event NewUser(address indexed user);

    uint256 public totalAssetsProcessed;
    uint256 public totalFeesCollected;
    uint256 public uniqueUsersCount;
    mapping(address => bool) public isUniqueUser;

    constructor(IEthMultiVault _ethMultiVault, address _admin, uint256 _feeNumerator, uint256 _feeDenominator)
        Ownable(_admin)
    {
        ethMultiVault = _ethMultiVault;
        feeNumerator = _feeNumerator;
        feeDenominator = _feeDenominator;
    }

    function setFee(uint256 _feeNumerator, uint256 _feeDenominator) external onlyOwner {
        feeNumerator = _feeNumerator;
        feeDenominator = _feeDenominator;
    }

    function applyFee(uint256 amount) public view returns (uint256) {
        return amount * feeNumerator / feeDenominator;
    }

    modifier trackUser() {
        _trackUser(msg.sender);
        _;
    }

    function _processDeposit(uint256 amount) internal returns (uint256 netValue, uint256 fee) {
        fee = applyFee(amount);
        netValue = amount - fee;
        totalAssetsProcessed += amount;
        totalFeesCollected += fee;
    }

    function _processRedeem(uint256 assets, address receiver) internal returns (uint256 netAmount, uint256 fee) {
        fee = applyFee(assets);
        netAmount = assets - fee;
        totalAssetsProcessed += assets;
        totalFeesCollected += fee;
        SafeTransferLib.safeTransferETH(receiver, netAmount);
    }

    function createAtom(bytes calldata atomUri) external payable trackUser returns (uint256) {
        (uint256 netValue, uint256 fee) = _processDeposit(msg.value);
        emit Deposited(msg.sender, address(ethMultiVault), msg.value, fee);
        return ethMultiVault.createAtom{value: netValue}(atomUri);
    }

    function createTriple(uint256 subjectId, uint256 predicateId, uint256 objectId)
        external
        payable
        trackUser
        returns (uint256)
    {
        (uint256 netValue, uint256 fee) = _processDeposit(msg.value);
        emit Deposited(msg.sender, address(ethMultiVault), msg.value, fee);
        return ethMultiVault.createTriple{value: netValue}(subjectId, predicateId, objectId);
    }

    function depositAtom(address receiver, uint256 id) external payable trackUser returns (uint256) {
        (uint256 netValue, uint256 fee) = _processDeposit(msg.value);
        emit Deposited(msg.sender, address(ethMultiVault), msg.value, fee);
        return ethMultiVault.depositAtom{value: netValue}(receiver, id);
    }

    function depositTriple(address receiver, uint256 id) external payable trackUser returns (uint256) {
        (uint256 netValue, uint256 fee) = _processDeposit(msg.value);
        emit Deposited(msg.sender, address(ethMultiVault), msg.value, fee);
        return ethMultiVault.depositTriple{value: netValue}(receiver, id);
    }

    function depositAtomCurve(address receiver, uint256 id, uint256 curveId) external payable trackUser returns (uint256) {
        (uint256 netValue, uint256 fee) = _processDeposit(msg.value);
        emit CurveDeposited(msg.sender, address(ethMultiVault), curveId, msg.value, fee);
        return ethMultiVault.depositAtomCurve{value: netValue}(receiver, id, curveId);
    }

    function depositTripleCurve(address receiver, uint256 id, uint256 curveId) external payable trackUser returns (uint256) {
        (uint256 netValue, uint256 fee) = _processDeposit(msg.value);
        emit CurveDeposited(msg.sender, address(ethMultiVault), curveId, msg.value, fee);
        return ethMultiVault.depositTripleCurve{value: netValue}(receiver, id, curveId);
    }

    function redeemAtom(uint256 shares, address receiver, uint256 id) external trackUser returns (uint256) {
        uint256 assets = ethMultiVault.redeemAtom(shares, address(this), id);
        (uint256 netAmount, uint256 fee) = _processRedeem(assets, receiver);
        emit Redeemed(msg.sender, address(ethMultiVault), assets, fee);
        return netAmount;
    }

    function redeemTriple(uint256 shares, address receiver, uint256 id) external trackUser returns (uint256) {
        uint256 assets = ethMultiVault.redeemTriple(shares, address(this), id);
        (uint256 netAmount, uint256 fee) = _processRedeem(assets, receiver);
        emit Redeemed(msg.sender, address(ethMultiVault), assets, fee);
        return netAmount;
    }

    function redeemAtomCurve(uint256 shares, address receiver, uint256 id, uint256 curveId) external trackUser returns (uint256) {
        uint256 assets = ethMultiVault.redeemAtomCurve(shares, address(this), id, curveId);
        (uint256 netAmount, uint256 fee) = _processRedeem(assets, receiver);
        emit CurveRedeemed(msg.sender, address(ethMultiVault), curveId, assets, fee);
        return netAmount;
    }

    function redeemTripleCurve(uint256 shares, address receiver, uint256 id, uint256 curveId) external trackUser returns (uint256) {
        uint256 assets = ethMultiVault.redeemTripleCurve(shares, address(this), id, curveId);
        (uint256 netAmount, uint256 fee) = _processRedeem(assets, receiver);
        emit CurveRedeemed(msg.sender, address(ethMultiVault), curveId, assets, fee);
        return netAmount;
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

    receive() external payable {}
}
