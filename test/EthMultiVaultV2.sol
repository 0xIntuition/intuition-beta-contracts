// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVault} from "src/EthMultiVault.sol";
import {AdminControl} from "src/utils/AdminControl.sol";

/**
 * @title  EthMultiVaultV2
 * @notice V2 test version of the original EthMultiVault contract, used for testing upgradeability features
 */
/// @custom:oz-upgrades-from EthMultiVault
contract EthMultiVaultV2 is EthMultiVault {
    /// @notice test variable to test the upgradeability of the contract
    /// @dev this variable has also been added here to demonstrate how to properly extend the storage layout of the contract
    bytes32 public VERSION;

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    /// @notice Initializes the EthMultiVaultV2 contract
    /// @dev This function is called only once (during contract deployment)
    function initV2(address _adminControl) external reinitializer(2) {
        __ReentrancyGuard_init();
        __Pausable_init();

        VERSION = "V2";

        adminControl = AdminControl(_adminControl);
    }
}
