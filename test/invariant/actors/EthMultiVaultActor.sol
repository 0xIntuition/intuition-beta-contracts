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
    uint256 public numberOfAtomDeposits;
    uint256 public numberOfAtomRedeems;
    uint256 public numberOfTriples;
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
        actors.push(msg.sender);
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

    function createAtom(bytes calldata data, uint256 msgValue, uint256 actorIndexSeed)
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
        uint256 id = actEthMultiVault.createAtom{value: msgValue}(data);
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
        address receiver,
        uint256 vaultId,
        uint256 msgValue,
        bytes calldata data,
        uint256 actorIndexSeed
    ) public useActor(actorIndexSeed) returns (uint256) {
        numberOfCalls++;
        numberOfAtomDeposits++;
        emit log_named_uint(
            "==================================== ACTOR depositAtom ====================================", 6000000009
        );
        emit log_named_address("currentActor-----", currentActor);
        emit log_named_uint("currentActor.balance", currentActor.balance);
        emit log_named_uint("msgValue------------", msgValue);
        // bound receiver to msg.sender always
        receiver = currentActor;
        uint256 shares;
        // if no atom exist yet, create and deposit on one
        if (actEthMultiVault.count() == 0) {
            vm.deal(currentActor, getAtomCost());
            vaultId = actEthMultiVault.createAtom{value: getAtomCost()}(data);
            emit log_named_uint("vaultTotalAssets----", getVaultTotalShares(vaultId));
            emit log_named_uint("vaultTotalShares----", getVaultTotalAssets(vaultId));
            emit log_named_uint("vaultBalanceOf------", getVaultBalanceForAddress(vaultId, currentActor));
            msgValue = bound(msgValue, getMinDeposit(), 10 ether);
            vm.deal(currentActor, msgValue);
            emit log_named_uint("|||||||||||||||||||||||||||||||||||BRANCH 1|||||||||||||||||||||||||||||||||||", 1);

            uint256 totalAssetsBefore = vaultTotalAssets(vaultId);
            uint256 totalSharesBefore = vaultTotalShares(vaultId);

            uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;

            shares = actEthMultiVault.depositAtom{value: msgValue}(receiver, vaultId);

            checkDepositIntoVault(
                msgValue - getProtocolFeeAmount(msgValue, vaultId), vaultId, totalAssetsBefore, totalSharesBefore
            );

            checkProtocolVaultBalance(vaultId, msgValue, protocolVaultBalanceBefore);
        } else {
            // deposit on existing vault
            // bound vaultId between 1 and count()
            if (vaultId == 0 || vaultId > actEthMultiVault.count()) {
                vaultId = bound(vaultId, 1, actEthMultiVault.count());
            }
            emit log_named_uint("vaultTotalAssets----", getVaultTotalShares(vaultId));
            emit log_named_uint("vaultTotalShares----", getVaultTotalAssets(vaultId));
            emit log_named_uint("vaultBalanceOf------", getVaultBalanceForAddress(vaultId, currentActor));
            // bound msgValue to between minDeposit and 10 ether
            msgValue = bound(msgValue, getAtomCost(), 10 ether);
            vm.deal(currentActor, msgValue);
            emit log_named_uint("|||||||||||||||||||||||||||||||||||BRANCH 2|||||||||||||||||||||||||||||||||||", 2);

            uint256 totalAssetsBefore = vaultTotalAssets(vaultId);
            uint256 totalSharesBefore = vaultTotalShares(vaultId);

            uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;

            shares = actEthMultiVault.depositAtom{value: msgValue}(receiver, vaultId);

            checkDepositIntoVault(
                msgValue - getProtocolFeeAmount(msgValue, vaultId), vaultId, totalAssetsBefore, totalSharesBefore
            );

            checkProtocolVaultBalance(vaultId, msgValue, protocolVaultBalanceBefore);
        }
        // deposit atom
        emit log_named_uint("balance currentActor", currentActor.balance);
        emit log_named_uint("balance EthMultiVaultbal-", address(actEthMultiVault).balance);
        emit log_named_uint("balance this--------", address(this).balance);
        // logs
        emit log_named_uint(
            "------------------------------------ POST STATE -------------------------------------------", 6000000009
        );
        emit log_named_uint("vaultTotalShares----", getVaultTotalAssets(vaultId));
        emit log_named_uint("vaultTAssets--------", getVaultTotalShares(vaultId));
        emit log_named_uint("vaultBalanceOf------", getVaultBalanceForAddress(vaultId, currentActor));
        emit log_named_uint(
            "==================================== ACTOR depositAtom ====================================", shares
        );
        return shares;
    }

    function redeemAtom(
        uint256 shares2Redeem,
        address receiver,
        uint256 vaultId,
        uint256 msgValue,
        bytes calldata data,
        uint256 actorIndexSeed
    ) public useActor(actorIndexSeed) returns (uint256) {
        numberOfCalls++;
        numberOfAtomRedeems++;
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
            vaultId = actEthMultiVault.createAtom{value: getAtomCost()}(data);
            msgValue = bound(msgValue, getMinDeposit(), 10 ether);
            vm.deal(currentActor, msgValue);
            emit log_named_uint("|||||||||||||||||||||||||||||||||||BRANCH 1|||||||||||||||||||||||||||||||||||", 1);
            shares2Redeem = actEthMultiVault.depositAtom{value: msgValue}(currentActor, 1);
        } else {
            // vault exists
            // bound vaultId between 1 and count()
            if (vaultId == 0 || vaultId > actEthMultiVault.count()) {
                vaultId = bound(vaultId, 1, actEthMultiVault.count());
            }
            // if vault balance of the selected vault is 0, deposit minDeposit
            if (getVaultBalanceForAddress(vaultId, currentActor) == 0) {
                vm.deal(currentActor, 10 ether);
                emit log_named_uint("vaultTShares--", getVaultTotalAssets(vaultId));
                emit log_named_uint("vaultTAssets--", getVaultTotalShares(vaultId));
                emit log_named_uint("vaultBalanceOf", getVaultBalanceForAddress(vaultId, currentActor));
                msgValue = bound(msgValue, getAtomCost(), 10 ether);
                emit log_named_uint("REEEE getVaultTotalAssets(vaultId)", getVaultTotalAssets(vaultId));
                emit log_named_uint("REEEE getVaultTotalShares(vaultId)", getVaultTotalShares(vaultId));
                emit log_named_uint("|||||||||||||||||||||||||||||||BRANCH 2||||||||||||||||||||||||||||||||||||", 2);
                shares2Redeem = actEthMultiVault.depositAtom{value: msgValue}(currentActor, vaultId);
                emit log_named_uint("shares2Redeem", shares2Redeem);
            } else {
                emit log_named_uint("|||||||||||||||||||||||||||||||BRANCH 3||||||||||||||||||||||||||||||||||||", 3);
                // bound shares2Redeem to between 1 and vaultBalanceOf
                shares2Redeem = bound(shares2Redeem, 1, getVaultBalanceForAddress(vaultId, currentActor));
                emit log_named_uint("shares2Redeem", shares2Redeem);
            }
        }
        // use the redeemer as the receiver always
        receiver = currentActor;

        emit log_named_uint("before vaultTotalShares--", getVaultTotalAssets(vaultId));
        emit log_named_uint("before vaultTAssets------", getVaultTotalShares(vaultId));
        emit log_named_uint("before vaultBalanceOf----", getVaultBalanceForAddress(vaultId, currentActor));

        // snapshots before redeem
        uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;
        uint256 userSharesBeforeRedeem = getSharesInVault(vaultId, receiver);
        uint256 userBalanceBeforeRedeem = address(receiver).balance;

        uint256 assetsForReceiverBeforeFees = getAssetsForReceiverBeforeFees(userSharesBeforeRedeem, vaultId);

        // redeem atom
        uint256 assetsForReceiver = actEthMultiVault.redeemAtom(shares2Redeem, receiver, vaultId);

        checkProtocolVaultBalance(vaultId, assetsForReceiverBeforeFees, protocolVaultBalanceBefore);

        assertEq(getSharesInVault(vaultId, receiver), userSharesBeforeRedeem - shares2Redeem);
        assertEq(address(receiver).balance - userBalanceBeforeRedeem, assetsForReceiver);

        // logs
        emit log_named_uint(
            "------------------------------------ POST STATE -------------------------------------------", 6000000009
        );
        emit log_named_uint("vaultTotalShares--", getVaultTotalAssets(vaultId));
        emit log_named_uint("vaultTAssets------", getVaultTotalShares(vaultId));
        emit log_named_uint("vaultBalanceOf----", getVaultBalanceForAddress(vaultId, currentActor));
        emit log_named_uint(
            "==================================== ACTOR redeemAtom END ====================================",
            assetsForReceiver
        );
        return assetsForReceiver;
    }

    function createTriple(
        uint256 subjectId,
        uint256 predicateId,
        uint256 objectId,
        uint256 msgValue,
        uint256 actorIndexSeed
    ) public useActor(actorIndexSeed) returns (uint256) {
        numberOfCalls++;
        numberOfTriples++;
        emit log_named_uint(
            "==================================== ACTOR createTriple START ====================================",
            6000000009
        );
        emit log_named_address("currentActor-----", currentActor);
        emit log_named_uint("currentActor.balance", currentActor.balance);
        emit log_named_uint("msgValue------------", msgValue);
        if (currentActor.balance < getTripleCost()) {
            vm.deal(currentActor, 1 ether);
        }
        if (msgValue < getTripleCost()) {
            msgValue = getTripleCost();
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

        uint256 vaultId = _createTripleChecks(msgValue, subjectId, predicateId, objectId);

        // logs
        emit log_named_uint(
            "------------------------------------ POST STATE ------------------------------------------", 6000000009
        );
        emit log_named_uint("msg.sender.balance", currentActor.balance);
        emit log_named_uint("vaultTotalShares--", getVaultTotalAssets(vaultId));
        emit log_named_uint("vaultTAssets------", getVaultTotalShares(vaultId));
        emit log_named_uint(
            "==================================== ACTOR createTriple END ====================================", vaultId
        );
        return vaultId;
    }

    function depositTriple(address receiver, uint256 vaultId, uint256 msgValue, uint256 actorIndexSeed)
        public
        useActor(actorIndexSeed)
        returns (uint256)
    {
        numberOfCalls++;
        numberOfTripleDeposits++;
        emit log_named_uint(
            "==================================== ACTOR depositTriple ====================================", 6000000009
        );
        emit log_named_address("currentActor-----", currentActor);
        emit log_named_uint("currentActor.balance", currentActor.balance);
        emit log_named_uint("msgValue------------", msgValue);
        // bound receiver to msg.sender always
        receiver = currentActor;
        uint256 shares;
        // if no triple exist yet, create and deposit on one
        if (actEthMultiVault.count() == 0) {
            vm.deal(currentActor, getTripleCost());
            vaultId = actEthMultiVault.createTriple{value: getTripleCost()}(1, 2, 3);
            emit log_named_uint("vaultTotalAssets----", getVaultTotalShares(vaultId));
            emit log_named_uint("vaultTotalShares----", getVaultTotalAssets(vaultId));
            emit log_named_uint("vaultBalanceOf------", getVaultBalanceForAddress(vaultId, currentActor));
            msgValue = bound(msgValue, getMinDeposit(), 10 ether);
            vm.deal(currentActor, msgValue);
            emit log_named_uint("|||||||||||||||||||||||||||||||||||BRANCH 1|||||||||||||||||||||||||||||||||||", 1);

            _createTripleChecks(msgValue, 1, 2, 3);
        } else {
            // vault exists
            if (vaultId == 0 || vaultId > actEthMultiVault.count()) {
                uint256[] memory tripleVaults = new uint256[](actEthMultiVault.count());
                uint256 tripleVaultsCount = 0;
                for (uint256 i = 1; i <= actEthMultiVault.count(); i++) {
                    if (actEthMultiVault.isTripleId(i)) {
                        tripleVaults[tripleVaultsCount] = i;
                        tripleVaultsCount++;
                    }
                }

                vaultId = tripleVaults[bound(actorIndexSeed, 0, tripleVaultsCount - 1)];
            }

            emit log_named_uint("vaultTotalAssets----", getVaultTotalShares(vaultId));
            emit log_named_uint("vaultTotalShares----", getVaultTotalAssets(vaultId));
            emit log_named_uint("vaultBalanceOf------", getVaultBalanceForAddress(vaultId, currentActor));
            // bound msgValue to between minDeposit and 10 ether
            msgValue = bound(msgValue, getTripleCost(), 10 ether);
            vm.deal(currentActor, msgValue);
            emit log_named_uint("|||||||||||||||||||||||||||||||||||BRANCH 2|||||||||||||||||||||||||||||||||||", 2);

            shares = _depositTripleChecks(vaultId, msgValue, receiver);
        }
        // deposit triple
        emit log_named_uint("balance currentActor", currentActor.balance);
        emit log_named_uint("balance EthMultiVaultbal-", address(actEthMultiVault).balance);
        emit log_named_uint("balance this--------", address(this).balance);
        // logs
        emit log_named_uint(
            "------------------------------------ POST STATE -------------------------------------------", 6000000009
        );
        emit log_named_uint("vaultTotalShares----", getVaultTotalAssets(vaultId));
        emit log_named_uint("vaultTAssets--------", getVaultTotalShares(vaultId));
        emit log_named_uint("vaultBalanceOf------", getVaultBalanceForAddress(vaultId, currentActor));
        emit log_named_uint(
            "==================================== ACTOR depositTriple ====================================", shares
        );
        return shares;
    }

    function redeemTriple(
        uint256 shares2Redeem,
        address receiver,
        uint256 vaultId,
        uint256 msgValue,
        uint256 actorIndexSeed
    ) public useActor(actorIndexSeed) returns (uint256) {
        numberOfCalls++;
        numberOfTripleRedeems++;
        emit log_named_uint(
            "==================================== ACTOR redeemTriple START ====================================",
            6000000009
        );
        emit log_named_address("currentActor-----", currentActor);
        emit log_named_uint("currentActor.balance", currentActor.balance);
        emit log_named_uint("msgValue------------", msgValue);
        // if no triple vaults exist create one and deposit on it
        if (actEthMultiVault.count() == 0) {
            vm.deal(currentActor, getTripleCost());
            vaultId = _createTripleChecks(msgValue, 1, 2, 3);

            msgValue = bound(msgValue, getMinDeposit(), 10 ether);
            vm.deal(currentActor, msgValue);
            emit log_named_uint("|||||||||||||||||||||||||||||||||||BRANCH 1|||||||||||||||||||||||||||||||||||", 1);
            shares2Redeem = _depositTripleChecks(vaultId, msgValue, currentActor);
        } else {
            // vault exists
            if (vaultId == 0 || vaultId > actEthMultiVault.count()) {
                uint256[] memory tripleVaults = new uint256[](actEthMultiVault.count());
                uint256 tripleVaultsCount = 0;
                for (uint256 i = 1; i <= actEthMultiVault.count(); i++) {
                    if (actEthMultiVault.isTripleId(i)) {
                        tripleVaults[tripleVaultsCount] = i;
                        tripleVaultsCount++;
                    }
                }

                vaultId = tripleVaults[bound(actorIndexSeed, 0, tripleVaultsCount - 1)];
            }

            // if vault balance of the selected vault is 0, deposit minDeposit
            if (getVaultBalanceForAddress(vaultId, currentActor) == 0) {
                vm.deal(currentActor, 10 ether);
                emit log_named_uint("vaultTShares--", getVaultTotalAssets(vaultId));
                emit log_named_uint("vaultTAssets--", getVaultTotalShares(vaultId));
                emit log_named_uint("vaultBalanceOf", getVaultBalanceForAddress(vaultId, currentActor));
                msgValue = bound(msgValue, getTripleCost(), 10 ether);
                emit log_named_uint("REEEE getVaultTotalAssets(vaultId)", getVaultTotalAssets(vaultId));
                emit log_named_uint("REEEE getVaultTotalShares(vaultId)", getVaultTotalShares(vaultId));
                emit log_named_uint("|||||||||||||||||||||||||||||||BRANCH 2||||||||||||||||||||||||||||||||||||", 2);
                shares2Redeem = actEthMultiVault.depositTriple{value: msgValue}(currentActor, vaultId);
                _depositTripleChecks(vaultId, msgValue, receiver);
                emit log_named_uint("shares2Redeem", shares2Redeem);
            } else {
                emit log_named_uint("|||||||||||||||||||||||||||||||BRANCH 3||||||||||||||||||||||||||||||||||||", 3);
                // bound shares2Redeem to between 1 and vaultBalanceOf
                shares2Redeem = bound(shares2Redeem, 1, getVaultBalanceForAddress(vaultId, currentActor));
                emit log_named_uint("shares2Redeem", shares2Redeem);
            }
        }
        // use the redeemer as the receiver always
        receiver = currentActor;

        emit log_named_uint("before vaultTotalShares--", getVaultTotalAssets(vaultId));
        emit log_named_uint("before vaultTAssets------", getVaultTotalShares(vaultId));
        emit log_named_uint("before vaultBalanceOf----", getVaultBalanceForAddress(vaultId, currentActor));

        uint256 assetsForReceiver = _redeemTripleChecks(shares2Redeem, receiver, vaultId);

        // logs
        emit log_named_uint(
            "------------------------------------ POST STATE -------------------------------------------", 6000000009
        );
        emit log_named_uint("vaultTotalShares--", getVaultTotalAssets(vaultId));
        emit log_named_uint("vaultTAssets------", getVaultTotalShares(vaultId));
        emit log_named_uint("vaultBalanceOf----", getVaultBalanceForAddress(vaultId, currentActor));
        emit log_named_uint(
            "==================================== ACTOR redeemTriple END ====================================",
            assetsForReceiver
        );
        return assetsForReceiver;
    }

    function _createTripleChecks(uint256 msgValue, uint256 subjectId, uint256 predicateId, uint256 objectId)
        internal
        returns (uint256 vaultId)
    {
        uint256 totalAssetsBefore = vaultTotalAssets(ethMultiVault.count() + 1);
        uint256 totalSharesBefore = vaultTotalShares(ethMultiVault.count() + 1);

        uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;

        uint256[3] memory totalAssetsBeforeAtomVaults =
            [vaultTotalAssets(subjectId), vaultTotalAssets(predicateId), vaultTotalAssets(objectId)];
        uint256[3] memory totalSharesBeforeAtomVaults =
            [vaultTotalShares(subjectId), vaultTotalShares(predicateId), vaultTotalShares(objectId)];

        // create triple
        vaultId = actEthMultiVault.createTriple{value: msgValue}(subjectId, predicateId, objectId);
        assertEq(vaultId, actEthMultiVault.count());

        checkDepositOnTripleVaultCreation(vaultId, msgValue, totalAssetsBefore, totalSharesBefore);

        // snapshots after creating a triple
        assertEq(
            protocolVaultBalanceBefore,
            // protocolVaultBalanceAfterLessFees
            address(getProtocolVault()).balance - protocolFeeAmount(msgValue - getTripleCost(), vaultId)
                - getTripleCreationProtocolFee()
        );

        _checkUnderlyingAtomDepositsOnTripleCreation(
            [subjectId, predicateId, objectId],
            totalAssetsBeforeAtomVaults,
            totalSharesBeforeAtomVaults,
            msgValue - getTripleCost()
        );
    }

    function _checkUnderlyingAtomDepositsOnTripleCreation(
        uint256[3] memory atomIds,
        uint256[3] memory totalAssetsBeforeAtomVaults,
        uint256[3] memory totalSharesBeforeAtomVaults,
        uint256 userDeposit
    ) internal {
        uint256 protocolDepositFee = protocolFeeAmount(userDeposit, atomIds[0]);
        uint256 userDepositAfterProtocolFees = userDeposit - protocolDepositFee;

        uint256 atomDepositFraction = atomDepositFractionAmount(userDepositAfterProtocolFees, atomIds[0]);
        uint256 distributeAmountPerAtomVault = atomDepositFraction / 3;

        uint256 atomDepositFractionOnTripleCreationPerAtom = getAtomDepositFractionOnTripleCreation() / 3;

        for (uint256 i = 0; i < 3; i++) {
            checkAtomDepositIntoVaultOnTripleVaultCreation(
                distributeAmountPerAtomVault,
                atomDepositFractionOnTripleCreationPerAtom,
                atomIds[i],
                totalAssetsBeforeAtomVaults[i],
                totalSharesBeforeAtomVaults[i]
            );
        }
    }

    function _depositTripleChecks(uint256 vaultId, uint256 msgValue, address receiver)
        internal
        returns (uint256 shares)
    {
        uint256 totalAssetsBefore = vaultTotalAssets(vaultId);
        uint256 totalSharesBefore = vaultTotalShares(vaultId);

        uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;

        (uint256 subjectId, uint256 predicateId, uint256 objectId) = actEthMultiVault.getTripleAtoms(vaultId);

        uint256[3] memory totalAssetsBeforeAtomVaults =
            [vaultTotalAssets(subjectId), vaultTotalAssets(predicateId), vaultTotalAssets(objectId)];
        uint256[3] memory totalSharesBeforeAtomVaults =
            [vaultTotalShares(subjectId), vaultTotalShares(predicateId), vaultTotalShares(objectId)];

        // deposit triple
        shares = actEthMultiVault.depositTriple{value: msgValue}(receiver, vaultId);

        uint256 userDepositAfterProtocolFees = msgValue - getProtocolFeeAmount(msgValue, vaultId);

        checkDepositIntoVault(userDepositAfterProtocolFees, vaultId, totalAssetsBefore, totalSharesBefore);

        checkProtocolVaultBalance(vaultId, msgValue, protocolVaultBalanceBefore);

        uint256 amountToDistribute = atomDepositFractionAmount(userDepositAfterProtocolFees, vaultId);
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
        uint256 protocolVaultBalanceBefore = address(getProtocolVault()).balance;
        uint256 userSharesBeforeRedeem = getSharesInVault(vaultId, receiver);
        uint256 userBalanceBeforeRedeem = address(receiver).balance;

        uint256 assetsForReceiverBeforeFees = getAssetsForReceiverBeforeFees(userSharesBeforeRedeem, vaultId);
        // redeem triple
        assetsForReceiver = actEthMultiVault.redeemTriple(shares2Redeem, receiver, vaultId);

        checkProtocolVaultBalance(vaultId, assetsForReceiverBeforeFees, protocolVaultBalanceBefore);

        assertEq(getSharesInVault(vaultId, receiver), userSharesBeforeRedeem - shares2Redeem);
        assertEq(address(receiver).balance - userBalanceBeforeRedeem, assetsForReceiver);
    }
}
