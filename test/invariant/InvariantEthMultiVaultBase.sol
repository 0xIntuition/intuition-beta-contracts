// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVaultBase} from "../EthMultiVaultBase.sol";

contract InvariantEthMultiVaultBase is EthMultiVaultBase {
    // inherit setup from AtomBase and generate fuzz actors
    function setUp() public virtual {
        _setUp();
    }

    /*//////////// ETHMULTIVAULT INVARIANTS ///////////////////////////////////////////////////*/

    //// VAULTS ////

    function invariant_ethMultiVault_asset_solvency() internal view {
        uint256 totalAssetsAcrossAllVaults;
        for (uint256 i = 1; i <= ethMultiVault.count(); i++) {
            totalAssetsAcrossAllVaults += super.vaultTotalAssets(i);
        }

        uint256 totalAssetsAcrossAllCounterTripleVaults;
        uint256 counterTripleId = type(uint256).max - 1;
        for (uint256 i = 1; i <= ethMultiVault.count(); i++) {
            if (ethMultiVault.isTripleId(i)) {
                totalAssetsAcrossAllCounterTripleVaults += super.vaultTotalAssets(counterTripleId);
                counterTripleId--;
            }
        }

        totalAssetsAcrossAllVaults += totalAssetsAcrossAllCounterTripleVaults;

        assertLe(totalAssetsAcrossAllVaults, address(ethMultiVault).balance);
    }

    function invariant_ethMultiVault_share_solvency() internal view {
        for (uint256 i = 1; i <= ethMultiVault.count(); i++) {
            assertLe(super.vaultTotalShares(i), super.vaultTotalAssets(i));
        }

        uint256 counterTripleId = type(uint256).max;
        for (uint256 i = 1; i <= ethMultiVault.count(); i++) {
            if (ethMultiVault.isTripleId(i)) {
                assertLe(super.vaultTotalShares(counterTripleId), super.vaultTotalAssets(counterTripleId));
                counterTripleId--;
            }
        }
    }
}
