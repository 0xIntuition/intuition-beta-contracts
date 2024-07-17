// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";

import {EthMultiVault} from "src/EthMultiVault.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";

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
        (, uint256 calculatedAssetsForReceiver, uint256 protocolFee, uint256 exitFee) =
            actEthMultiVault.getRedeemAssetsAndFees(shares, vaultId);
        return calculatedAssetsForReceiver + protocolFee + exitFee;
    }

    function depositAtom(address receiver, uint256 msgValue, uint256 actorIndexSeed)
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
        uint256 vaultId = 1;
        emit log_named_uint("vaultTotalAssets----", getVaultTotalAssets(vaultId));
        emit log_named_uint("vaultTotalShares----", getVaultTotalShares(vaultId));
        emit log_named_uint("vaultBalanceOf------", getVaultBalanceForAddress(vaultId, currentActor));
        // bound receiver to msg.sender always
        receiver = currentActor;
        // bound msgValue to between minDeposit and 10 ether
        msgValue = bound(msgValue, getAtomCost(), 10 ether);
        vm.deal(currentActor, msgValue);

        uint256 totalAssetsBefore = vaultTotalAssets(vaultId);
        uint256 totalSharesBefore = vaultTotalShares(vaultId);

        uint256 protocolMultisigBalanceBefore = address(getProtocolMultisig()).balance;

        // deposit atom
        uint256 shares = actEthMultiVault.depositAtom{value: msgValue}(receiver, vaultId);

        checkDepositIntoVault(
            msgValue - getProtocolFeeAmount(msgValue, vaultId), vaultId, totalAssetsBefore, totalSharesBefore
        );

        checkProtocolMultisigBalance(vaultId, msgValue, protocolMultisigBalanceBefore);

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
            "==================================== ACTOR depositAtom END ====================================", shares
        );
        return shares;
    }

    function redeemAtom(uint256 shares2Redeem, address receiver, uint256 msgValue, uint256 actorIndexSeed)
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
        uint256 vaultId = 1;
        // if vault balance of the selected vault is 0, deposit minDeposit
        if (getVaultBalanceForAddress(vaultId, currentActor) == 0) {
            vm.deal(currentActor, 10 ether);
            msgValue = bound(msgValue, getAtomCost(), 10 ether);
            shares2Redeem = actEthMultiVault.depositAtom{value: msgValue}(currentActor, vaultId);
            emit log_named_uint("shares2Redeem", shares2Redeem);
        } else {
            // bound shares2Redeem to between 1 and vaultBalanceOf
            shares2Redeem = bound(shares2Redeem, 1, getVaultBalanceForAddress(vaultId, currentActor));
            emit log_named_uint("shares2Redeem", shares2Redeem);
        }
        // use the redeemer as the receiver always
        receiver = currentActor;

        emit log_named_uint("before vaultTotalShares--", getVaultTotalShares(vaultId));
        emit log_named_uint("before vaultTAssets------", getVaultTotalAssets(vaultId));
        emit log_named_uint("before vaultBalanceOf----", getVaultBalanceForAddress(vaultId, currentActor));

        // snapshots before redeem
        uint256 protocolMultisigBalanceBefore = address(getProtocolMultisig()).balance;
        uint256 userSharesBeforeRedeem = getSharesInVault(vaultId, receiver);
        uint256 userBalanceBeforeRedeem = address(receiver).balance;

        uint256 assetsForReceiverBeforeFees = getAssetsForReceiverBeforeFees(userSharesBeforeRedeem, vaultId);

        // redeem atom
        uint256 assetsForReceiver = actEthMultiVault.redeemAtom(shares2Redeem, receiver, vaultId);

        checkProtocolMultisigBalance(vaultId, assetsForReceiverBeforeFees, protocolMultisigBalanceBefore);

        // snapshots after redeem
        uint256 userSharesAfterRedeem = getSharesInVault(vaultId, receiver);
        uint256 userBalanceAfterRedeem = address(receiver).balance;

        assertEq(userSharesAfterRedeem, userSharesBeforeRedeem - shares2Redeem);
        assertEq(userBalanceAfterRedeem - userBalanceBeforeRedeem, assetsForReceiver);

        // logs
        emit log_named_uint(
            "------------------------------------ POST STATE -------------------------------------------", 6000000009
        );
        emit log_named_uint("vaultTotalShares--", getVaultTotalShares(vaultId));
        emit log_named_uint("vaultTAssets------", getVaultTotalAssets(vaultId));
        emit log_named_uint("vaultBalanceOf----", getVaultBalanceForAddress(vaultId, currentActor));
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
        // bound receiver to msg.sender always
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
            emit log_named_uint("shares2Redeem", shares2Redeem);
        } else {
            // bound shares2Redeem to between 1 and vaultBalanceOf
            shares2Redeem = bound(shares2Redeem, 1, getVaultBalanceForAddress(vaultId, currentActor));
            emit log_named_uint("shares2Redeem", shares2Redeem);
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

    function _depositTripleChecks(uint256 vaultId, uint256 msgValue, address receiver)
        internal
        returns (uint256 shares)
    {
        uint256 totalAssetsBefore = vaultTotalAssets(vaultId);
        uint256 totalSharesBefore = vaultTotalShares(vaultId);

        uint256 protocolMultisigBalanceBefore = address(getProtocolMultisig()).balance;

        (uint256 subjectId, uint256 predicateId, uint256 objectId) = actEthMultiVault.getTripleAtoms(vaultId);

        uint256[3] memory totalAssetsBeforeAtomVaults =
            [vaultTotalAssets(subjectId), vaultTotalAssets(predicateId), vaultTotalAssets(objectId)];
        uint256[3] memory totalSharesBeforeAtomVaults =
            [vaultTotalShares(subjectId), vaultTotalShares(predicateId), vaultTotalShares(objectId)];

        shares = actEthMultiVault.depositTriple{value: msgValue}(receiver, vaultId);

        uint256 userDepositAfterprotocolFee = msgValue - getProtocolFeeAmount(msgValue, vaultId);

        checkDepositIntoVault(userDepositAfterprotocolFee, vaultId, totalAssetsBefore, totalSharesBefore);

        checkProtocolMultisigBalance(vaultId, msgValue, protocolMultisigBalanceBefore);

        uint256 amountToDistribute = atomDepositFractionAmount(userDepositAfterprotocolFee, vaultId);
        uint256 distributeAmountPerAtomVault = amountToDistribute / 3;

        checkDepositIntoVault(
            distributeAmountPerAtomVault, subjectId, totalAssetsBeforeAtomVaults[0], totalSharesBeforeAtomVaults[0]
        );

        checkDepositIntoVault(
            distributeAmountPerAtomVault, predicateId, totalAssetsBeforeAtomVaults[1], totalSharesBeforeAtomVaults[1]
        );

        checkDepositIntoVault(
            distributeAmountPerAtomVault, objectId, totalAssetsBeforeAtomVaults[2], totalSharesBeforeAtomVaults[2]
        );
    }

    function _redeemTripleChecks(uint256 shares2Redeem, address receiver, uint256 vaultId)
        internal
        returns (uint256 assetsForReceiver)
    {
        // snapshots before redeem
        uint256 protocolMultisigBalanceBefore = address(getProtocolMultisig()).balance;
        uint256 userSharesBeforeRedeem = getSharesInVault(vaultId, receiver);
        uint256 userBalanceBeforeRedeem = address(receiver).balance;

        uint256 assetsForReceiverBeforeFees = getAssetsForReceiverBeforeFees(userSharesBeforeRedeem, vaultId);
        // redeem triple
        assetsForReceiver = actEthMultiVault.redeemTriple(shares2Redeem, receiver, vaultId);

        checkProtocolMultisigBalance(vaultId, assetsForReceiverBeforeFees, protocolMultisigBalanceBefore);

        assertEq(getSharesInVault(vaultId, receiver), userSharesBeforeRedeem - shares2Redeem);
        assertEq(address(receiver).balance - userBalanceBeforeRedeem, assetsForReceiver);
    }
}
