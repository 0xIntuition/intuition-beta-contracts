// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {EthMultiVault} from "src/EthMultiVault.sol";

/**
 * @title  EthMultiVaultV2
 * @notice V2 test version of the original EthMultiVault contract, used for testing upgradeability features
 */
/// @custom:oz-upgrades-from EthMultiVault
contract EthMultiVaultV2 is EthMultiVault {
    /// @notice test variable to test the upgradeability of the contract
    /// @dev this variable has also been added here to demonstrate how to properly extend the storage layout of the contract
    bytes32 public VERSION = "V2";

    /// @notice Initializes the MultiVault contract
    /// @param _generalConfig General configuration struct
    /// @param _atomConfig Atom configuration struct
    /// @param _tripleConfig Triple configuration struct
    /// @param _walletConfig Wallet configuration struct
    /// @param _defaultVaultFees Default vault fees struct
    /// @dev This function is called only once (during contract deployment)
    function initialize(
        GeneralConfig memory _generalConfig,
        AtomConfig memory _atomConfig,
        TripleConfig memory _tripleConfig,
        WalletConfig memory _walletConfig,
        VaultFees memory _defaultVaultFees
    ) external initializer {
        __ReentrancyGuard_init();
        __Pausable_init();

        generalConfig = _generalConfig;
        atomConfig = _atomConfig;
        tripleConfig = _tripleConfig;
        walletConfig = _walletConfig;

        vaultFees[0] = VaultFees({
            entryFee: _defaultVaultFees.entryFee,
            exitFee: _defaultVaultFees.exitFee,
            protocolFee: _defaultVaultFees.protocolFee
        });
    }
}
