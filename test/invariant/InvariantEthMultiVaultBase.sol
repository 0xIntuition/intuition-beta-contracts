pragma solidity ^0.8.18;

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
        assertLe(totalAssetsAcrossAllVaults, address(ethMultiVault).balance);
    }

    function invariant_ethMultiVault_share_solvency() internal view {
        for (uint256 i = 1; i <= ethMultiVault.count(); i++) {
            assertLe(super.vaultTotalShares(i), super.vaultTotalAssets(i));
        }
    }
}
