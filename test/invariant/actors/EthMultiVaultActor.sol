// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {EthMultiVault} from "src/EthMultiVault.sol";
import {EthMultiVaultHelpers} from "../../helpers/EthMultiVaultHelpers.sol";

contract EthMultiVaultActor is Test, EthMultiVaultHelpers {
    // actor arrays
    uint256[] public actorPks;
    address[] public actors;
    address internal currentActor;

    // actor contract
    EthMultiVault public actEthMultiVault;

    // ghost variables
    uint256 public numberOfCalls;
    uint256 public numberOfAtoms;
    uint256 public numberOfDeposits;
    uint256 public numberOfRedeems;

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    constructor(EthMultiVault _actEthMultiVault) {
        actEthMultiVault = _actEthMultiVault;
        // load and fund actors
        for (uint256 i = 0; i < 10; i++) {
            actorPks.push(i + 1);
            actors.push(vm.addr(actorPks[i]));
        }
        //actors.push(msg.sender);
    }

    function getVaultTotalAssets(uint256 vaultId) public view returns (uint256 totalAssets) {
        (totalAssets,) = actEthMultiVault.vaults(vaultId);
    }

    function getVaultTotalShares(uint256 vaultId) public view returns (uint256 totalShares) {
        (, totalShares) = actEthMultiVault.vaults(vaultId);
    }

    function getVaultBalanceForAddress(uint256 vaultId, address user) public view returns (uint256) {
        (uint256 shares,) = actEthMultiVault.getVaultStateForUser(vaultId, user);
        return shares;
    }

    function getAssetsForReceiverBeforeFees(uint256 shares, uint256 vaultId) public view returns (uint256) {
        (, uint256 calculatedAssetsForReceiver, uint256 protocolFees, uint256 atomDepositFraction, uint256 exitFees) =
            actEthMultiVault.getRedeemAssetsAndFees(shares, vaultId);
        return calculatedAssetsForReceiver + protocolFees + atomDepositFraction + exitFees;
    }

    function createAtom(bytes calldata _data, uint256 msgValue, uint256 actorIndexSeed)
        public
        useActor(actorIndexSeed)
        returns (uint256)
    {
        numberOfCalls++;
        numberOfAtoms++;
        emit log_named_uint(
            "==================================== ACTOR createAtom START ====================================",
            6000000009
        );
        emit log_named_address("currentActor-----", currentActor);
        emit log_named_uint("currentActor.balance", currentActor.balance);
        emit log_named_uint("msgValue------------", msgValue);
        if (currentActor.balance < getAtomCost()) {
            vm.deal(currentActor, 1 ether);
        }
        if (msgValue < getAtomCost()) {
            msgValue = getAtomCost();
        }
        if (msgValue > currentActor.balance) {
            if (msgValue > 1 ether) {
                vm.deal(currentActor, 1 ether);
                msgValue = 1 ether;
            } else {
                vm.deal(currentActor, msgValue);
            }
        }
        emit log_named_uint("msg.sender.balance Right before create", currentActor.balance);
        emit log_named_address("msg.sender-----", currentActor);

        uint256 totalAssetsBefore = vaultTotalAssets(ethMultiVault.count() + 1);
        uint256 totalSharesBefore = vaultTotalShares(ethMultiVault.count() + 1);

        uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;

        // create atom
        uint256 id = actEthMultiVault.createAtom{value: msgValue}(_data);
        assertEq(id, actEthMultiVault.count());

        checkDepositOnAtomVaultCreation(id, msgValue, totalAssetsBefore, totalSharesBefore);

        uint256 userDeposit = msgValue - getAtomCost();

        checkProtocolVaultBalanceOnVaultCreation(id, userDeposit, protocolVaultBalanceBefore);

        // logs
        emit log_named_uint(
            "------------------------------------ POST STATE ------------------------------------------", 6000000009
        );
        emit log_named_uint("msg.sender.balance", currentActor.balance);
        emit log_named_uint("vaultTotalShares--", getVaultTotalAssets(id));
        emit log_named_uint("vaultTAssets------", getVaultTotalShares(id));
        emit log_named_uint(
            "==================================== ACTOR createAtom END ====================================", id
        );
        return id;
    }

    function depositAtom(
        address _receiver,
        uint256 _vaultId,
        uint256 msgValue,
        bytes calldata _data,
        uint256 actorIndexSeed
    ) public useActor(actorIndexSeed) returns (uint256) {
        numberOfCalls++;
        numberOfDeposits++;
        emit log_named_uint(
            "==================================== ACTOR depositAtom ====================================", 6000000009
        );
        emit log_named_address("currentActor-----", currentActor);
        emit log_named_uint("currentActor.balance", currentActor.balance);
        emit log_named_uint("msgValue------------", msgValue);
        // bound _receiver to msg.sender always
        _receiver = currentActor;
        uint256 shares;
        // if no atom exist yet, create and deposit on one
        if (actEthMultiVault.count() == 0) {
            vm.deal(currentActor, getAtomCost());
            _vaultId = actEthMultiVault.createAtom{value: getAtomCost()}(_data);
            emit log_named_uint("vaultTotalAssets----", getVaultTotalShares(_vaultId));
            emit log_named_uint("vaultTotalShares----", getVaultTotalAssets(_vaultId));
            emit log_named_uint("vaultBalanceOf------", getVaultBalanceForAddress(_vaultId, currentActor));
            msgValue = bound(msgValue, getMinDeposit(), 10 ether);
            vm.deal(currentActor, msgValue);
            emit log_named_uint("|||||||||||||||||||||||||||||||||||BRANCH 1|||||||||||||||||||||||||||||||||||", 1);

            uint256 totalAssetsBefore = vaultTotalAssets(_vaultId);
            uint256 totalSharesBefore = vaultTotalShares(_vaultId);

            uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;

            shares = actEthMultiVault.depositAtom{value: msgValue}(_receiver, _vaultId);

            checkDepositIntoVault(
                msgValue - getProtocolFeeAmount(msgValue, _vaultId), _vaultId, totalAssetsBefore, totalSharesBefore
            );

            checkProtocolVaultBalance(_vaultId, msgValue, protocolVaultBalanceBefore);
        } else {
            // deposit on existing vault
            // bound _vaultId between 1 and count()
            if (_vaultId == 0 || _vaultId > actEthMultiVault.count()) {
                _vaultId = bound(_vaultId, 1, actEthMultiVault.count());
            }
            emit log_named_uint("vaultTotalAssets----", getVaultTotalShares(_vaultId));
            emit log_named_uint("vaultTotalShares----", getVaultTotalAssets(_vaultId));
            emit log_named_uint("vaultBalanceOf------", getVaultBalanceForAddress(_vaultId, currentActor));
            // bound msgValue to between minDeposit and 10 ether
            msgValue = bound(msgValue, getAtomCost(), 10 ether);
            vm.deal(currentActor, msgValue);
            emit log_named_uint("|||||||||||||||||||||||||||||||||||BRANCH 2|||||||||||||||||||||||||||||||||||", 2);

            uint256 totalAssetsBefore = vaultTotalAssets(_vaultId);
            uint256 totalSharesBefore = vaultTotalShares(_vaultId);

            uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;

            shares = actEthMultiVault.depositAtom{value: msgValue}(_receiver, _vaultId);

            checkDepositIntoVault(
                msgValue - getProtocolFeeAmount(msgValue, _vaultId), _vaultId, totalAssetsBefore, totalSharesBefore
            );

            checkProtocolVaultBalance(_vaultId, msgValue, protocolVaultBalanceBefore);
        }
        // deposit atom
        emit log_named_uint("balance currentActor", currentActor.balance);
        emit log_named_uint("balance EthMultiVaultbal-", address(actEthMultiVault).balance);
        emit log_named_uint("balance this--------", address(this).balance);
        // logs
        emit log_named_uint(
            "------------------------------------ POST STATE -------------------------------------------", 6000000009
        );
        emit log_named_uint("vaultTotalShares----", getVaultTotalAssets(_vaultId));
        emit log_named_uint("vaultTAssets--------", getVaultTotalShares(_vaultId));
        emit log_named_uint("vaultBalanceOf------", getVaultBalanceForAddress(_vaultId, currentActor));
        emit log_named_uint(
            "==================================== ACTOR depositAtom ====================================", shares
        );
        return shares;
    }

    function redeemAtom(
        uint256 _shares2Redeem,
        address _receiver,
        uint256 _vaultId,
        uint256 msgValue,
        bytes calldata _data,
        uint256 actorIndexSeed
    ) public useActor(actorIndexSeed) returns (uint256) {
        numberOfCalls++;
        numberOfRedeems++;
        emit log_named_uint(
            "==================================== ACTOR redeemAtom START ====================================",
            6000000009
        );
        emit log_named_address("currentActor-----", currentActor);
        emit log_named_uint("currentActor.balance", currentActor.balance);
        emit log_named_uint("msgValue------------", msgValue);
        // if no atom vaults exist create one and deposit on it
        if (actEthMultiVault.count() == 0) {
            vm.deal(currentActor, getAtomCost());
            _vaultId = actEthMultiVault.createAtom{value: getAtomCost()}(_data);
            msgValue = bound(msgValue, getMinDeposit(), 10 ether);
            vm.deal(currentActor, msgValue);
            emit log_named_uint("|||||||||||||||||||||||||||||||||||BRANCH 1|||||||||||||||||||||||||||||||||||", 1);
            _shares2Redeem = actEthMultiVault.depositAtom{value: msgValue}(currentActor, 1);
        } else {
            // vault exists
            // bound _vaultId between 1 and count()
            if (_vaultId == 0 || _vaultId > actEthMultiVault.count()) {
                _vaultId = bound(_vaultId, 1, actEthMultiVault.count());
            }
            // if vault balance of the selected vault is 0, deposit minDeposit
            if (getVaultBalanceForAddress(_vaultId, currentActor) == 0) {
                vm.deal(currentActor, 10 ether);
                emit log_named_uint("vaultTShares--", getVaultTotalAssets(_vaultId));
                emit log_named_uint("vaultTAssets--", getVaultTotalShares(_vaultId));
                emit log_named_uint("vaultBalanceOf", getVaultBalanceForAddress(_vaultId, currentActor));
                msgValue = bound(msgValue, getAtomCost(), 10 ether);
                emit log_named_uint("REEEE getVaultTotalAssets(_vaultId)", getVaultTotalAssets(_vaultId));
                emit log_named_uint("REEEE getVaultTotalShares(_vaultId)", getVaultTotalShares(_vaultId));
                emit log_named_uint("|||||||||||||||||||||||||||||||BRANCH 2||||||||||||||||||||||||||||||||||||", 2);
                _shares2Redeem = actEthMultiVault.depositAtom{value: msgValue}(currentActor, _vaultId);
                emit log_named_uint("_shares2Redeem", _shares2Redeem);
            } else {
                emit log_named_uint("|||||||||||||||||||||||||||||||BRANCH 3||||||||||||||||||||||||||||||||||||", 3);
                // bound _shares2Redeem to between 1 and vaultBalanceOf
                _shares2Redeem = bound(_shares2Redeem, 1, getVaultBalanceForAddress(_vaultId, currentActor));
                emit log_named_uint("_shares2Redeem", _shares2Redeem);
            }
        }
        // use the redeemer as the receiver always
        _receiver = currentActor;

        emit log_named_uint("before vaultTotalShares--", getVaultTotalAssets(_vaultId));
        emit log_named_uint("before vaultTAssets------", getVaultTotalShares(_vaultId));
        emit log_named_uint("before vaultBalanceOf----", getVaultBalanceForAddress(_vaultId, currentActor));

        // snapshots before redeem
        uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;
        uint256 userSharesBeforeRedeem = getSharesInVault(_vaultId, _receiver);
        uint256 userBalanceBeforeRedeem = address(_receiver).balance;

        uint256 assetsForReceiverBeforeFees = getAssetsForReceiverBeforeFees(userSharesBeforeRedeem, _vaultId);

        // redeem atom
        uint256 assetsForReceiver = actEthMultiVault.redeemAtom(_shares2Redeem, _receiver, _vaultId);

        checkProtocolVaultBalance(_vaultId, assetsForReceiverBeforeFees, protocolVaultBalanceBefore);

        assertEq(getSharesInVault(_vaultId, _receiver), userSharesBeforeRedeem - _shares2Redeem);
        assertEq(address(_receiver).balance - userBalanceBeforeRedeem, assetsForReceiver);

        // logs
        emit log_named_uint(
            "------------------------------------ POST STATE -------------------------------------------", 6000000009
        );
        emit log_named_uint("vaultTotalShares--", getVaultTotalAssets(_vaultId));
        emit log_named_uint("vaultTAssets------", getVaultTotalShares(_vaultId));
        emit log_named_uint("vaultBalanceOf----", getVaultBalanceForAddress(_vaultId, currentActor));
        emit log_named_uint(
            "==================================== ACTOR redeemAtom END ====================================",
            assetsForReceiver
        );
        return assetsForReceiver;
    }

    receive() external payable {}
}
