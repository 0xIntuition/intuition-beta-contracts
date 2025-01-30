// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "./BaseTest.sol";

import { console2 as console } from "forge-std/console2.sol";

contract MyTest is BaseTest {
    // function test_depositCurve() external {
    //     string memory atomString = "atom1";
    //     uint256 atomId = createAtom(actors.alice, atomString);
    //
    //     uint256 aliceShares = depositAtom(actors.alice, atomId);
    //     uint256 aliceReturns = redeemAtom(actors.alice, atomId);
    //
    //     console.log("Alice Shares: %s", aliceShares);
    //     console.log("Alice Returns: %s", aliceReturns);
    //
    //     // uint256 atomCost = state.vault.getAtomCost();
    //     // uint256 atomDeposit = config.general.minDeposit;
    //     // uint256 curveId = 2;
    //     //
    //     // // Alice creates the atom.
    //     // uint256 atom1 = state.vault.createAtom{ value: atomCost }("atom1");
    //     //
    //     // // Alice deposits into the atom.
    //     // uint256 aliceShares = state.vault.depositAtomCurve{ value: atomDeposit }(
    //     //     actors.actors.alice,
    //     //     atom1,
    //     //     curveId
    //     // );
    //     //
    //     // // Redeem all shares
    //     // uint256 assetsReceived = state.vault.redeemAtomCurve(
    //     //     aliceShares,
    //     //     actors.actors.alice,
    //     //     atom1,
    //     //     curveId
    //     // );
    //     //
    //     // assertGt(assetsReceived, 0);
    //     //
    //     // vm.stopPrank();
    // }
    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                            Atoms & Triples                            │
    // ╰───────────────────────────────────────────────────────────────────────╯
    // ────────────────────────────── Creation ───────────────────────────
    // function createTriple(
    //     address _who,
    //     uint256 _subjectId,
    //     uint256 _predicateId,
    //     uint256 _objectId
    // ) internal returns (uint256 tripleId) {
    //     require(state.vault.currentSharePrice(_subjectId) != 0, "subject already exists");
    //     require(state.vault.currentSharePrice(_predicateId) != 0, "prediacte already exists");
    //     require(state.vault.currentSharePrice(_objectId) != 0, "object already exists");
    //
    //     vm.startPrank(_who);
    //     tripleId = state.vault.createTriple{ value: state.vault.getTripleCost() }(
    //         _subjectId,
    //         _predicateId,
    //         _objectId
    //     );
    //     vm.stopPrank();
    // }
    //
    // function createAtom(address _who, string memory _label) internal returns (uint256 atomId) {
    //     uint256 atomCost = state.vault.getAtomCost();
    //
    //     vm.startPrank(_who);
    //     atomId = state.vault.createAtom{ value: atomCost }(bytes(_label));
    //     vm.stopPrank();
    // }
    //
    // // ────────────────────────────── Deposits ───────────────────────────
    //
    // function depositAtom(
    //     address _who,
    //     uint256 _atomId,
    //     uint256 _curveId,
    //     uint256 _amount
    // ) internal returns (uint256 shares) {
    //     vm.startPrank(_who);
    //     shares = state.vault.depositAtomCurve{ value: _amount }(_who, _atomId, _curveId);
    //     vm.stopPrank();
    // }
    //
    // function depositAtom(address _who, uint256 _atomId) internal returns (uint256 shares) {
    //     uint256 atomCost = state.vault.getAtomCost();
    //     uint256 curveId = 2;
    //     shares = depositAtom(_who, _atomId, curveId, atomCost);
    // }
    //
    // // ───────────────────────────── Redemptions ─────────────────────────────
    //
    // function redeemAtom(
    //     address _who,
    //     uint256 _atomId,
    //     uint256 _curveId,
    //     uint256 _amount
    // ) internal returns (uint256 assets) {
    //     vm.startPrank(_who);
    //     assets = state.vault.redeemAtomCurve(_amount, _who, _atomId, _curveId);
    //     vm.stopPrank();
    // }
    //
    // function redeemAtom(address _who, uint256 _atomId) internal returns (uint256 assets) {
    //     vm.startPrank(_who);
    //     uint256 curveId = 2;
    //     (uint256 shareBalance, ) = state.vault.getVaultStateForUserCurve(_atomId, curveId, _who);
    //     assets = state.vault.redeemAtomCurve(shareBalance, _who, _atomId, curveId);
    //     vm.stopPrank();
    // }
    //
    // // ────────────────────────────── Balances ───────────────────────────
    //
    // function vaultBalance(
    //     address _who,
    //     uint256 _vaultId,
    //     uint256 _curveId
    // ) internal view returns (uint256 shares, uint256 assets) {
    //     (shares, assets) = state.vault.getVaultStateForUserCurve(_vaultId, _curveId, _who);
    // }
    //
    // function vaultBalance(
    //     address _who,
    //     uint256 _vaultId
    // ) internal returns (uint256 shares, uint256 assets) {
    //     uint256 curveId = 2;
    //     (shares, assets) = vaultBalance(_who, _vaultId, curveId);
    // }
}
