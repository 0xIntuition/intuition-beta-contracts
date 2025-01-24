// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "./BaseTest.sol";

contract MyTest is BaseTest {
    function test_depositCurve() external {
        _setUp();

        vm.startPrank(actors.alice);

        uint256 atomCost = state.vault.getAtomCost();
        uint256 atomDeposit = config.general.minDeposit * 10;
        uint256 curveId = 2;

        // Alice creates the atom.
        uint256 atom1 = state.vault.createAtom{ value: atomCost }("atom1");

        // Alice deposits into the atom.
        uint256 aliceShares = state.vault.depositAtomCurve{ value: atomDeposit }(
            actors.alice,
            atom1,
            curveId
        );

        // Redeem all shares
        uint256 assetsReceived = state.vault.redeemAtomCurve(
            aliceShares,
            actors.alice,
            atom1,
            curveId
        );

        assertGt(assetsReceived, 0);

        vm.stopPrank();
    }
}
