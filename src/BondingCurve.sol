// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {ProgressiveCurve} from "src/ProgressiveCurve.sol";
import {IBaseCurve} from "src/interfaces/IBaseCurve.sol";
import {IBondingCurveRegistry} from "src/interfaces/IBondingCurveRegistry.sol";
import {AdminControl} from "src/utils/AdminControl.sol";
import {IModel} from "src/interfaces/IModel.sol";
import {Errors} from "src/libraries/Errors.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {IBondingCurve} from "src/interfaces/IBondingCurve.sol";

contract BondingCurve is Initializable, ReentrancyGuardUpgradeable, PausableUpgradeable, IBondingCurve, IModel {
    using FixedPointMathLib for uint256;

    /// @notice Bonding Curve Configurations
    BondingCurveConfig public bondingCurveConfig;

    /// @notice Admin control contract
    AdminControl public adminControl;

    /// @notice Eth Multi Vault contract
    IEthMultiVault public ethMultiVault;

    /// @notice Bonding Curve Vaults (termId -> curveId -> vaultState)
    mapping(uint256 vaultId => mapping(uint256 curveId => VaultState vaultState)) public bondingCurveVaults;

    /// @notice Gap for upgrade safety
    uint256[50] private __gap;

    /// @notice Initializes the BondingCurve contract
    /// @param _bondingCurveConfig Bonding curve configuration
    /// @param _adminControl Admin control contract
    /// @param _ethMultiVault Eth Multi Vault contract
    function init(BondingCurveConfig memory _bondingCurveConfig, address _adminControl, address _ethMultiVault)
        external
        initializer
    {
        bondingCurveConfig = _bondingCurveConfig;
        adminControl = AdminControl(address(_adminControl));
        ethMultiVault = IEthMultiVault(address(_ethMultiVault));
    }

    modifier onlyAdmin() {
        if (msg.sender != adminControl.getGeneralConfig().admin) {
            revert Errors.EthMultiVault_OnlyAdmin();
        }
        _;
    }

    function pause() external onlyAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    /// @dev returns the bonding curve config
    /// @return bondingCurveConfig the bonding curve config
    function getBondingCurveConfig() external view returns (BondingCurveConfig memory) {
        return bondingCurveConfig;
    }

    function setBondingCurveConfig(BondingCurveConfig memory _bondingCurveConfig) external onlyAdmin {
        bondingCurveConfig = _bondingCurveConfig;
    }

    function setAdminControl(AdminControl _adminControl) external onlyAdmin {
        if (address(_adminControl) == address(0)) {
            revert Errors.EthMultiVault_AdminControlNotSet();
        }
        adminControl = _adminControl;
    }

    function setEthMultiVault(address _ethMultiVault) external onlyAdmin {
        if (_ethMultiVault == address(0)) {
            revert Errors.EthMultiVault_EthMultiVaultNotSet();
        }
        ethMultiVault = IEthMultiVault(_ethMultiVault);
    }

    // Entirely separate logic from the normal depositAtom function
    function depositAtomCurve(address receiver, uint256 atomId, uint256 curveId)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (msg.sender != receiver && !adminControl.isApproved(receiver, msg.sender)) {
            revert Errors.EthMultiVault_SenderNotApproved();
        }

        if (atomId == 0 || atomId > ethMultiVault.count()) {
            revert Errors.EthMultiVault_VaultDoesNotExist();
        }

        if (ethMultiVault.isTripleId(atomId)) {
            revert Errors.EthMultiVault_VaultNotAtom();
        }

        if (msg.value < adminControl.getGeneralConfig().minDeposit) {
            revert Errors.EthMultiVault_MinimumDeposit();
        }

        uint256 protocolFee = ethMultiVault.protocolFeeAmount(msg.value, atomId);
        uint256 userDepositAfterprotocolFee = msg.value - protocolFee;

        // deposit eth into vault and mint shares for the receiver
        uint256 shares = _depositCurve(receiver, atomId, curveId, userDepositAfterprotocolFee);

        _transferFeesToProtocolMultisig(protocolFee);

        return shares;
    }

    function redeemAtomCurve(uint256 shares, address receiver, uint256 atomId, uint256 curveId)
        external
        nonReentrant
        returns (uint256)
    {
        if (atomId == 0 || atomId > ethMultiVault.count()) {
            revert Errors.EthMultiVault_VaultDoesNotExist();
        }

        if (ethMultiVault.isTripleId(atomId)) {
            revert Errors.EthMultiVault_VaultNotAtom();
        }

        /*
            withdraw shares from vault, returning the amount of
            assets to be transferred to the receiver
        */
        (uint256 assets, uint256 protocolFee) = _redeemCurve(atomId, curveId, msg.sender, receiver, shares);

        _transferAssetsToReceiver(assets, receiver);
        _transferFeesToProtocolMultisig(protocolFee);

        return assets;
    }

    function depositTripleCurve(address receiver, uint256 tripleId, uint256 curveId)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (msg.sender != receiver && !adminControl.isApproved(receiver, msg.sender)) {
            revert Errors.EthMultiVault_SenderNotApproved();
        }

        if (!ethMultiVault.isTripleId(tripleId)) {
            revert Errors.EthMultiVault_VaultNotTriple();
        }

        if (_hasCounterStakeCurve(tripleId, curveId, receiver)) {
            revert Errors.EthMultiVault_HasCounterStake();
        }

        if (msg.value < adminControl.getGeneralConfig().minDeposit) {
            revert Errors.EthMultiVault_MinimumDeposit();
        }

        uint256 protocolFee = ethMultiVault.protocolFeeAmount(msg.value, tripleId);
        uint256 userDepositAfterprotocolFee = msg.value - protocolFee;

        // deposit eth into vault and mint shares for the receiver
        uint256 shares = _depositCurve(receiver, tripleId, curveId, userDepositAfterprotocolFee);

        // distribute atom shares for all 3 atoms that underly the triple
        uint256 atomDepositFraction = ethMultiVault.atomDepositFractionAmount(userDepositAfterprotocolFee, tripleId);

        // deposit assets into each underlying atom vault and mint shares for the receiver
        if (atomDepositFraction > 0) {
            _depositAtomFractionCurve(tripleId, curveId, receiver, atomDepositFraction);
        }

        _transferFeesToProtocolMultisig(protocolFee);

        return shares;
    }

    function redeemTripleCurve(uint256 shares, address receiver, uint256 tripleId, uint256 curveId)
        external
        nonReentrant
        returns (uint256)
    {
        if (!ethMultiVault.isTripleId(tripleId)) {
            revert Errors.EthMultiVault_VaultNotTriple();
        }

        /*
            withdraw shares from vault, returning the amount of
            assets to be transferred to the receiver
        */
        (uint256 assets, uint256 protocolFee) = _redeemCurve(tripleId, curveId, msg.sender, receiver, shares);

        _transferAssetsToReceiver(assets, receiver);
        _transferFeesToProtocolMultisig(protocolFee);

        return assets;
    }

    function _depositAtomFractionCurve(uint256 tripleId, uint256 curveId, address receiver, uint256 amount) internal {
        // load atom IDs
        uint256[3] memory atomsIds;
        (atomsIds[0], atomsIds[1], atomsIds[2]) = ethMultiVault.getTripleAtoms(tripleId);

        // floor div, so perAtom is slightly less than 1/3 of total input amount
        uint256 perAtom = amount / 3;

        // distribute proportional shares to each atom
        for (uint256 i = 0; i < 3; i++) {
            // deposit assets into each atom vault and mint shares for the receiver
            _depositCurve(receiver, atomsIds[i], curveId, perAtom);
        }
    }

    function _depositCurve(address receiver, uint256 id, uint256 curveId, uint256 value) internal returns (uint256) {
        if (previewDepositCurve(value, id, curveId) == 0) {
            revert Errors.EthMultiVault_DepositOrWithdrawZeroShares();
        }

        if (value + bondingCurveVaults[id][curveId].totalAssets > _registry().getCurveMaxAssets(curveId)) {
            revert Errors.EthMultiVault_DepositExceedsMaxAssets();
        }

        (uint256 totalAssetsDelta, uint256 sharesForReceiver, uint256 userAssetsAfterTotalFees, uint256 entryFee) =
            getDepositSharesAndFeesCurve(value, id, curveId);

        if (totalAssetsDelta == 0) {
            revert Errors.EthMultiVault_InsufficientDepositAmountToCoverFees();
        }

        // Increment pro rata vault ledger instead of curve vault ledger by fees
        if (entryFee > 0) {
            ethMultiVault.incrementVault(id, entryFee);
        }

        // Increment curve vault ledger by amount of assets left over after fees
        _increaseCurveVaultTotals(id, curveId, userAssetsAfterTotalFees, sharesForReceiver);

        // mint `sharesOwed` shares to sender factoring in fees
        _mintCurve(receiver, id, curveId, sharesForReceiver);

        // This will be revised after syncing with BE
        emit DepositedCurve(
            msg.sender,
            receiver,
            bondingCurveVaults[id][curveId].balanceOf[receiver],
            userAssetsAfterTotalFees,
            sharesForReceiver,
            entryFee,
            id,
            // isTripleId(id), // <-- Omitted because of stack too deep
            false
        );

        return sharesForReceiver;
    }

    function _redeemCurve(uint256 id, uint256 curveId, address sender, address receiver, uint256 shares)
        internal
        returns (uint256, uint256)
    {
        if (shares == 0) {
            revert Errors.EthMultiVault_DepositOrWithdrawZeroShares();
        }

        if (maxRedeemCurve(sender, id, curveId) < shares) {
            revert Errors.EthMultiVault_InsufficientSharesInVault();
        }

        (, uint256 assetsForReceiver, uint256 protocolFee, uint256 exitFee) =
            getRedeemAssetsAndFeesCurve(shares, id, curveId);

        // Increment pro rata vault ledger instead of curve vault ledger by fees
        if (exitFee > 0) {
            ethMultiVault.incrementVault(id, exitFee);
        }

        // Decrement curve vault ledger by amount of assets left over after fees
        _decreaseCurveVaultTotals(id, curveId, assetsForReceiver + protocolFee + exitFee, shares);

        // burn shares, then transfer assets to receiver
        _burnCurve(sender, id, curveId, shares);

        // Omitting this because of stack too deep, we can figure out what BE actually needs and trim this.
        emit RedeemedCurve(
            sender,
            receiver,
            bondingCurveVaults[id][curveId].balanceOf[sender],
            assetsForReceiver,
            shares, /*exitFee,*/
            id,
            curveId
        );

        return (assetsForReceiver, protocolFee);
    }

    function _mintCurve(address to, uint256 id, uint256 curveId, uint256 amount) internal {
        bondingCurveVaults[id][curveId].balanceOf[to] += amount;
    }

    function _burnCurve(address from, uint256 id, uint256 curveId, uint256 amount) internal {
        if (from == address(0)) revert Errors.EthMultiVault_BurnFromZeroAddress();

        uint256 fromBalance = bondingCurveVaults[id][curveId].balanceOf[from];
        if (fromBalance < amount) {
            revert Errors.EthMultiVault_BurnInsufficientBalance();
        }

        unchecked {
            bondingCurveVaults[id][curveId].balanceOf[from] = fromBalance - amount;
        }
    }

    function _increaseCurveVaultTotals(uint256 id, uint256 curveId, uint256 assetsDelta, uint256 sharesDelta)
        internal
    {
        // Share price can only change when vault totals change
        uint256 oldSharePrice = currentSharePriceCurve(id, curveId);
        bondingCurveVaults[id][curveId].totalAssets += assetsDelta;
        bondingCurveVaults[id][curveId].totalShares += sharesDelta;
        uint256 newSharePrice = currentSharePriceCurve(id, curveId);
        emit SharePriceChangedCurve(id, curveId, newSharePrice, oldSharePrice);
    }

    function _decreaseCurveVaultTotals(uint256 id, uint256 curveId, uint256 assetsDelta, uint256 sharesDelta)
        internal
    {
        // Share price can only change when vault totals change
        uint256 oldSharePrice = currentSharePriceCurve(id, curveId);
        bondingCurveVaults[id][curveId].totalAssets -= assetsDelta;
        bondingCurveVaults[id][curveId].totalShares -= sharesDelta;
        uint256 newSharePrice = currentSharePriceCurve(id, curveId);
        emit SharePriceChangedCurve(id, curveId, newSharePrice, oldSharePrice);
    }

    function getDepositSharesAndFeesCurve(uint256 assets, uint256 id, uint256 curveId)
        public
        view
        returns (uint256, uint256, uint256, uint256)
    {
        uint256 atomDepositFraction = ethMultiVault.atomDepositFractionAmount(assets, id);
        uint256 userAssetsAfterAtomDepositFraction = assets - atomDepositFraction;

        // changes in vault's total assets
        // if the vault is an atom vault `atomDepositFraction` is 0
        uint256 totalAssetsDelta = assets - atomDepositFraction;

        uint256 entryFee;

        if (bondingCurveVaults[id][curveId].totalShares == adminControl.getGeneralConfig().minShare) {
            entryFee = 0;
        } else {
            entryFee = ethMultiVault.entryFeeAmount(userAssetsAfterAtomDepositFraction, id);
        }

        // amount of assets that goes towards minting shares for the receiver
        uint256 userAssetsAfterTotalFees = userAssetsAfterAtomDepositFraction - entryFee;

        // user receives amount of shares as calculated by `convertToShares`
        uint256 sharesForReceiver = convertToSharesCurve(userAssetsAfterTotalFees, id, curveId);

        return (totalAssetsDelta, sharesForReceiver, userAssetsAfterTotalFees, entryFee);
    }

    function getRedeemAssetsAndFeesCurve(uint256 shares, uint256 id, uint256 curveId)
        public
        view
        returns (uint256, uint256, uint256, uint256)
    {
        uint256 remainingShares = bondingCurveVaults[id][curveId].totalShares - shares;

        uint256 assetsForReceiverBeforeFees = convertToAssetsCurve(shares, id, curveId);
        uint256 protocolFee;
        uint256 exitFee;

        /*
         * if the redeem amount results in a zero share balance for
         * the associated vault, no exit fee is charged to avoid
         * admin accumulating disproportionate fee revenue via ghost
         * shares. Also, in case of an emergency redemption (i.e. when the
         * contract is paused), no exit fees are charged either.
         */
        if (paused()) {
            exitFee = 0;
            protocolFee = 0;
        } else if (remainingShares == adminControl.getGeneralConfig().minShare) {
            exitFee = 0;
            protocolFee = ethMultiVault.protocolFeeAmount(assetsForReceiverBeforeFees, id);
        } else {
            protocolFee = ethMultiVault.protocolFeeAmount(assetsForReceiverBeforeFees, id);
            uint256 assetsForReceiverAfterprotocolFee = assetsForReceiverBeforeFees - protocolFee;
            exitFee = ethMultiVault.exitFeeAmount(assetsForReceiverAfterprotocolFee, id);
        }

        uint256 totalUserAssets = assetsForReceiverBeforeFees;
        uint256 assetsForReceiver = assetsForReceiverBeforeFees - exitFee - protocolFee;

        return (totalUserAssets, assetsForReceiver, protocolFee, exitFee);
    }

    /// @notice returns the current share price for the given vault id and curve id
    /// @param id vault id to get corresponding share price for
    /// @param curveId curve id to get corresponding share price for
    /// @return price current share price for the given vault id and curve id, scaled by adminControl.generalConfig.decimalPrecision
    function currentSharePriceCurve(uint256 id, uint256 curveId) public view returns (uint256) {
        uint256 supply = bondingCurveVaults[id][curveId].totalShares;
        uint256 totalAssets = bondingCurveVaults[id][curveId].totalAssets;
        uint256 basePrice = supply == 0 ? 0 : _registry().currentPrice(supply, curveId);
        uint256 price = basePrice;

        // Pool Ratio Adjustment
        if (totalAssets != 0 && supply != 0) {
            uint256 totalSharesInAssetSpace = _registry().convertToAssets(supply, supply, totalAssets, curveId);
            if (totalSharesInAssetSpace != 0) {
                price = price.mulDiv(
                    totalAssets * adminControl.getGeneralConfig().decimalPrecision, totalSharesInAssetSpace
                );
            }
        }
        return price;
    }

    function maxDepositCurve(uint256 curveId) public view returns (uint256) {
        return _registry().getCurveMaxAssets(curveId);
    }

    function maxRedeemCurve(address sender, uint256 id, uint256 curveId) public view returns (uint256) {
        uint256 shares = bondingCurveVaults[id][curveId].balanceOf[sender];
        return shares;
    }

    function convertToSharesCurve(uint256 assets, uint256 id, uint256 curveId) public view returns (uint256) {
        uint256 supply = bondingCurveVaults[id][curveId].totalShares;
        uint256 totalAssets = bondingCurveVaults[id][curveId].totalAssets;

        uint256 shares = _registry().previewDeposit(assets, totalAssets, supply, curveId);

        // Pool Ratio Adjustment
        if (totalAssets != 0 && supply != 0) {
            uint256 totalAssetsInShareSpace = _registry().convertToShares(totalAssets, 0, supply, curveId);
            if (totalAssetsInShareSpace != 0) {
                shares = shares * supply / totalAssetsInShareSpace;
            }
        }
        return shares;
    }

    function convertToAssetsCurve(uint256 shares, uint256 id, uint256 curveId) public view returns (uint256) {
        uint256 supply = bondingCurveVaults[id][curveId].totalShares;
        uint256 totalAssets = bondingCurveVaults[id][curveId].totalAssets;
        uint256 assets = _registry().previewRedeem(shares, supply, totalAssets, curveId);

        // Pool Ratio Adjustment
        if (totalAssets != 0 && supply != 0) {
            uint256 totalSharesInAssetSpace = _registry().convertToAssets(supply, supply, totalAssets, curveId);
            if (totalSharesInAssetSpace != 0) {
                assets = assets * totalAssets / totalSharesInAssetSpace;
            }
        }
        return assets;
    }

    function previewDepositCurve(
        uint256 assets, // should always be msg.value
        uint256 id,
        uint256 curveId
    ) public view returns (uint256) {
        (, uint256 sharesForReceiver,,) = getDepositSharesAndFeesCurve(assets, id, curveId);
        return sharesForReceiver;
    }

    function previewRedeemCurve(uint256 shares, uint256 id, uint256 curveId) public view returns (uint256) {
        (, uint256 assetsForReceiver,,) = getRedeemAssetsAndFeesCurve(shares, id, curveId);
        return assetsForReceiver;
    }

    function getVaultStateForUserCurve(uint256 vaultId, uint256 curveId, address receiver)
        external
        view
        returns (uint256, uint256)
    {
        uint256 shares = bondingCurveVaults[vaultId][curveId].balanceOf[receiver];
        (uint256 totalUserAssets,,,) = getRedeemAssetsAndFeesCurve(shares, vaultId, curveId);
        return (shares, totalUserAssets);
    }

    function _transferAssetsToReceiver(uint256 assets, address receiver) internal {
        (bool success,) = payable(receiver).call{value: assets}("");
        if (!success) {
            revert Errors.EthMultiVault_TransferFailed();
        }
    }

    function _transferFeesToProtocolMultisig(uint256 value) internal {
        if (value == 0) return;

        if (value > address(this).balance) {
            revert Errors.EthMultiVault_InsufficientBalance();
        }

        (bool success,) = payable(adminControl.getGeneralConfig().protocolMultisig).call{value: value}("");
        if (!success) {
            revert Errors.EthMultiVault_TransferFailed();
        }

        emit FeesTransferred(msg.sender, adminControl.getGeneralConfig().protocolMultisig, value);
    }

    function _hasCounterStakeCurve(uint256 id, uint256 curveId, address receiver) internal view returns (bool) {
        if (!ethMultiVault.isTripleId(id)) {
            revert Errors.EthMultiVault_VaultNotTriple();
        }

        return bondingCurveVaults[type(uint256).max - id][curveId].balanceOf[receiver] > 0;
    }

    function _registry() internal view returns (IBondingCurveRegistry) {
        return IBondingCurveRegistry(bondingCurveConfig.registry);
    }
}
