// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {EthMultiVault} from "src/EthMultiVault.sol";
import {EthMultiVaultHelpers} from "../../helpers/EthMultiVaultHelpers.sol";

contract EthMultiVaultSingleVaultActor is Test, EthMultiVaultHelpers {
    // actor arrays
    uint256[] public actorPks;
    address[] public actors;
    address internal currentActor;
    // actor contract
    EthMultiVault public actEthMultiVault;

    // ghost variables
    uint256 public numberOfCalls;
    uint256 public numberOfAtomDeposits;
    uint256 public numberOfAtomRedeems;
    uint256 public numberOfTripleDeposits;
    uint256 public numberOfTripleRedeems;

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
    }

    receive() external payable {}

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
        (, uint256 calculatedAssetsForReceiver, uint256 protocolFees, uint256 exitFees) =
            actEthMultiVault.getRedeemAssetsAndFees(shares, vaultId);
        return calculatedAssetsForReceiver + protocolFees + exitFees;
    }

    function depositAtom(address _receiver, uint256 msgValue, uint256 actorIndexSeed)
        public
        useActor(actorIndexSeed)
        returns (uint256)
    {
        numberOfCalls++;
        numberOfAtomDeposits++;
        emit log_named_uint(
            "==================================== ACTOR depositAtom START ====================================",
            6000000009
        );
        emit log_named_address("currentActor-----", currentActor);
        emit log_named_uint("currentActor.balance", currentActor.balance);
        emit log_named_uint("msgValue------------", msgValue);
        uint256 _vaultId = 1;
        emit log_named_uint("vaultTotalAssets----", getVaultTotalAssets(_vaultId));
        emit log_named_uint("vaultTotalShares----", getVaultTotalShares(_vaultId));
        emit log_named_uint("vaultBalanceOf------", getVaultBalanceForAddress(_vaultId, currentActor));
        // bound _receiver to msg.sender always
        _receiver = currentActor;
        // bound msgValue to between minDeposit and 10 ether
        msgValue = bound(msgValue, getAtomCost(), 10 ether);
        vm.deal(currentActor, msgValue);

        uint256 totalAssetsBefore = vaultTotalAssets(_vaultId);
        uint256 totalSharesBefore = vaultTotalShares(_vaultId);

        uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;

        // deposit atom
        uint256 shares = actEthMultiVault.depositAtom{value: msgValue}(_receiver, _vaultId);

        checkDepositIntoVault(
            msgValue - getProtocolFeeAmount(msgValue, _vaultId), _vaultId, totalAssetsBefore, totalSharesBefore
        );

        checkProtocolVaultBalance(_vaultId, msgValue, protocolVaultBalanceBefore);

        // logs
        emit log_named_uint(
            "------------------------------------ POST STATE -------------------------------------------", 6000000009
        );
        emit log_named_uint("balance currentActor", currentActor.balance);
        emit log_named_uint("balance EthMultiVaultbal-", address(actEthMultiVault).balance);
        emit log_named_uint("balance this--------", address(this).balance);
        emit log_named_uint("vaultTotalShares----", getVaultTotalShares(_vaultId));
        emit log_named_uint("vaultTAssets--------", getVaultTotalAssets(_vaultId));
        emit log_named_uint("vaultBalanceOf------", getVaultBalanceForAddress(_vaultId, currentActor));
        emit log_named_uint(
            "==================================== ACTOR depositAtom END ====================================", shares
        );
        return shares;
    }

    function redeemAtom(uint256 _shares2Redeem, address _receiver, uint256 msgValue, uint256 actorIndexSeed)
        public
        useActor(actorIndexSeed)
        returns (uint256)
    {
        numberOfCalls++;
        numberOfAtomRedeems++;
        emit log_named_uint(
            "==================================== ACTOR redeemAtom START ====================================",
            6000000009
        );
        emit log_named_address("currentActor-----", currentActor);
        emit log_named_uint("currentActor.balance", currentActor.balance);
        emit log_named_uint("msgValue------------", msgValue);
        uint256 _vaultId = 1;
        // if vault balance of the selected vault is 0, deposit minDeposit
        if (getVaultBalanceForAddress(_vaultId, currentActor) == 0) {
            vm.deal(currentActor, 10 ether);
            msgValue = bound(msgValue, getAtomCost(), 10 ether);
            _shares2Redeem = actEthMultiVault.depositAtom{value: msgValue}(currentActor, _vaultId);
            emit log_named_uint("_shares2Redeem", _shares2Redeem);
        } else {
            // bound _shares2Redeem to between 1 and vaultBalanceOf
            _shares2Redeem = bound(_shares2Redeem, 1, getVaultBalanceForAddress(_vaultId, currentActor));
            emit log_named_uint("_shares2Redeem", _shares2Redeem);
        }
        // use the redeemer as the receiver always
        _receiver = currentActor;

        emit log_named_uint("before vaultTotalShares--", getVaultTotalShares(_vaultId));
        emit log_named_uint("before vaultTAssets------", getVaultTotalAssets(_vaultId));
        emit log_named_uint("before vaultBalanceOf----", getVaultBalanceForAddress(_vaultId, currentActor));

        // snapshots before redeem
        uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;
        uint256 userSharesBeforeRedeem = getSharesInVault(_vaultId, _receiver);
        uint256 userBalanceBeforeRedeem = address(_receiver).balance;

        uint256 assetsForReceiverBeforeFees = getAssetsForReceiverBeforeFees(userSharesBeforeRedeem, _vaultId);

        // redeem atom
        uint256 assetsForReceiver = actEthMultiVault.redeemAtom(_shares2Redeem, _receiver, _vaultId);

        checkProtocolVaultBalance(_vaultId, assetsForReceiverBeforeFees, protocolVaultBalanceBefore);

        // snapshots after redeem
        uint256 userSharesAfterRedeem = getSharesInVault(_vaultId, _receiver);
        uint256 userBalanceAfterRedeem = address(_receiver).balance;

        assertEq(userSharesAfterRedeem, userSharesBeforeRedeem - _shares2Redeem);
        assertEq(userBalanceAfterRedeem - userBalanceBeforeRedeem, assetsForReceiver);

        // logs
        emit log_named_uint(
            "------------------------------------ POST STATE -------------------------------------------", 6000000009
        );
        emit log_named_uint("vaultTotalShares--", getVaultTotalShares(_vaultId));
        emit log_named_uint("vaultTAssets------", getVaultTotalAssets(_vaultId));
        emit log_named_uint("vaultBalanceOf----", getVaultBalanceForAddress(_vaultId, currentActor));
        emit log_named_uint(
            "==================================== ACTOR redeemAtom END ====================================",
            assetsForReceiver
        );
        return assetsForReceiver;
    }

   function depositTriple(address receiver, uint256 msgValue, uint256 actorIndexSeed)
        public
        useActor(actorIndexSeed)
        returns (uint256)
    {
        numberOfCalls++;
        numberOfTripleDeposits++;
        emit log_named_uint(
            "==================================== ACTOR depositTriple START ====================================",
            6000000009
        );
        emit log_named_address("currentActor-----", currentActor);
        emit log_named_uint("currentActor.balance", currentActor.balance);
        emit log_named_uint("msgValue------------", msgValue);
        uint256 vaultId = 4;
        emit log_named_uint("vaultTotalAssets----", getVaultTotalAssets(vaultId));
        emit log_named_uint("vaultTotalShares----", getVaultTotalShares(vaultId));
        emit log_named_uint("vaultBalanceOf------", getVaultBalanceForAddress(vaultId, currentActor));
        // bound _receiver to msg.sender always
        receiver = currentActor;
        // bound msgValue to between minDeposit and 10 ether
        msgValue = bound(msgValue, getTripleCost(), 10 ether);
        vm.deal(currentActor, msgValue);

        // deposit triple
        uint256 shares = _depositTripleChecks(vaultId, msgValue, receiver);

        // logs
        emit log_named_uint(
            "------------------------------------ POST STATE -------------------------------------------", 6000000009
        );
        emit log_named_uint("balance currentActor", currentActor.balance);
        emit log_named_uint("balance EthMultiVaultbal-", address(actEthMultiVault).balance);
        emit log_named_uint("balance this--------", address(this).balance);
        emit log_named_uint("vaultTotalShares----", getVaultTotalShares(vaultId));
        emit log_named_uint("vaultTAssets--------", getVaultTotalAssets(vaultId));
        emit log_named_uint("vaultBalanceOf------", getVaultBalanceForAddress(vaultId, currentActor));
        emit log_named_uint(
            "==================================== ACTOR depositTriple END ====================================", shares
        );
        return shares;
    }

    function redeemTriple(uint256 shares2Redeem, address receiver, uint256 msgValue, uint256 actorIndexSeed)
        public
        useActor(actorIndexSeed)
        returns (uint256)
    {
        numberOfCalls++;
        numberOfTripleRedeems++;
        emit log_named_uint(
            "==================================== ACTOR redeemTriple START ====================================",
            6000000009
        );
        emit log_named_address("currentActor-----", currentActor);
        emit log_named_uint("currentActor.balance", currentActor.balance);
        emit log_named_uint("msgValue------------", msgValue);
        uint256 vaultId = 4;
        // if vault balance of the selected vault is 0, deposit minDeposit
        if (getVaultBalanceForAddress(vaultId, currentActor) == 0) {
            vm.deal(currentActor, 10 ether);
            msgValue = bound(msgValue, getTripleCost(), 10 ether);
            shares2Redeem = actEthMultiVault.depositTriple{value: msgValue}(currentActor, vaultId);
            emit log_named_uint("_shares2Redeem", shares2Redeem);
        } else {
            // bound _shares2Redeem to between 1 and vaultBalanceOf
            shares2Redeem = bound(shares2Redeem, 1, getVaultBalanceForAddress(vaultId, currentActor));
            emit log_named_uint("_shares2Redeem", shares2Redeem);
        }
        // use the redeemer as the receiver always
        receiver = currentActor;

        emit log_named_uint("before vaultTotalShares--", getVaultTotalShares(vaultId));
        emit log_named_uint("before vaultTAssets------", getVaultTotalAssets(vaultId));
        emit log_named_uint("before vaultBalanceOf----", getVaultBalanceForAddress(vaultId, currentActor));

        // redeem triple
        uint256 assetsForReceiver = _redeemTripleChecks(shares2Redeem, receiver, vaultId);
        
        // logs
        emit log_named_uint(
            "------------------------------------ POST STATE -------------------------------------------", 6000000009
        );
        emit log_named_uint("vaultTotalShares--", getVaultTotalShares(vaultId));
        emit log_named_uint("vaultTAssets------", getVaultTotalAssets(vaultId));
        emit log_named_uint("vaultBalanceOf----", getVaultBalanceForAddress(vaultId, currentActor));
        emit log_named_uint(
            "==================================== ACTOR redeemTriple END ====================================",
            assetsForReceiver
        );
        return assetsForReceiver;
    }

       function _depositTripleChecks(
        uint256 vaultId,
        uint256 msgValue,
        address receiver
    ) internal returns (uint256 shares) {
        uint256 totalAssetsBefore = vaultTotalAssets(vaultId);
        uint256 totalSharesBefore = vaultTotalShares(vaultId);

        uint256 protocolVaultBalanceBefore = address(getProtocolVault())
            .balance;

        (
            uint256 subjectId,
            uint256 predicateId,
            uint256 objectId
        ) = actEthMultiVault.getTripleAtoms(vaultId);

        uint256[3] memory totalAssetsBeforeAtomVaults = [
            vaultTotalAssets(subjectId),
            vaultTotalAssets(predicateId),
            vaultTotalAssets(objectId)
        ];
        uint256[3] memory totalSharesBeforeAtomVaults = [
            vaultTotalShares(subjectId),
            vaultTotalShares(predicateId),
            vaultTotalShares(objectId)
        ];

        shares = actEthMultiVault.depositTriple{value: msgValue}(
            receiver,
            vaultId
        );

        uint256 userDepositAfterProtocolFees = msgValue -
            getProtocolFeeAmount(msgValue, vaultId);

        checkDepositIntoVault(
            userDepositAfterProtocolFees,
            vaultId,
            totalAssetsBefore,
            totalSharesBefore
        );

        checkProtocolVaultBalance(
            vaultId,
            msgValue,
            protocolVaultBalanceBefore
        );

        uint256 amountToDistribute = atomDepositFractionAmount(
            userDepositAfterProtocolFees,
            vaultId
        );
        uint256 distributeAmountPerAtomVault = amountToDistribute / 3;

        checkDepositIntoVault(
            distributeAmountPerAtomVault,
            subjectId,
            totalAssetsBeforeAtomVaults[0],
            totalSharesBeforeAtomVaults[0]
        );

        checkDepositIntoVault(
            distributeAmountPerAtomVault,
            predicateId,
            totalAssetsBeforeAtomVaults[1],
            totalSharesBeforeAtomVaults[1]
        );

        checkDepositIntoVault(
            distributeAmountPerAtomVault,
            objectId,
            totalAssetsBeforeAtomVaults[2],
            totalSharesBeforeAtomVaults[2]
        );
    }

    function _redeemTripleChecks(
        uint256 shares2Redeem,
        address receiver,
        uint256 vaultId
    ) internal returns (uint256 assetsForReceiver) {
        // snapshots before redeem
        uint256 protocolVaultBalanceBefore = address(getProtocolVault())
            .balance;
        uint256 userSharesBeforeRedeem = getSharesInVault(vaultId, receiver);
        uint256 userBalanceBeforeRedeem = address(receiver).balance;

        uint256 assetsForReceiverBeforeFees = getAssetsForReceiverBeforeFees(
            userSharesBeforeRedeem,
            vaultId
        );
        // redeem triple
        assetsForReceiver = actEthMultiVault.redeemTriple(
            shares2Redeem,
            receiver,
            vaultId
        );

        checkProtocolVaultBalance(
            vaultId,
            assetsForReceiverBeforeFees,
            protocolVaultBalanceBefore
        );

        assertEq(
            getSharesInVault(vaultId, receiver),
            userSharesBeforeRedeem - shares2Redeem
        );
        assertEq(
            address(receiver).balance - userBalanceBeforeRedeem,
            assetsForReceiver
        );
    }
}
