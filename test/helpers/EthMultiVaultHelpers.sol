// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {EthMultiVaultBase} from "../EthMultiVaultBase.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";

abstract contract EthMultiVaultHelpers is Test, EthMultiVaultBase {
    using FixedPointMathLib for uint256;

    function getAdmin() public view returns (address admin) {
        (admin,,,,,,,) = ethMultiVault.generalConfig();
    }

    function getProtocolVault() public view returns (address protocolVault) {
        (, protocolVault,,,,,,) = ethMultiVault.generalConfig();
    }

    function getFeeDenominator() public view returns (uint256 feeDenominator) {
        (,, feeDenominator,,,,,) = ethMultiVault.generalConfig();
    }

    function getEntryFee(uint256 _id) public view returns (uint256 entryFee) {
        (entryFee,,) = ethMultiVault.vaultFees(_id);
    }

    function getExitFee(uint256 _id) public view returns (uint256 exitFee) {
        (, exitFee,) = ethMultiVault.vaultFees(_id);
    }

    function getProtocolFee(uint256 _id) public view returns (uint256 protocolFee) {
        (,, protocolFee) = ethMultiVault.vaultFees(_id);
    }

    function getProtocolFeeAmount(uint256 _assets, uint256 _id) public view returns (uint256 protocolFee) {
        protocolFee = ethMultiVault.protocolFeeAmount(_assets, _id);
    }

    function getAtomWalletInitialDepositAmount() public view virtual returns (uint256 atomWalletInitialDepositAmount) {
        (atomWalletInitialDepositAmount,) = ethMultiVault.atomConfig();
    }

    function getAtomCreationProtocolFee() public view returns (uint256 atomCreationProtocolFee) {
        (, atomCreationProtocolFee) = ethMultiVault.atomConfig();
    }

    function getTripleCreationProtocolFee() public view returns (uint256 tripleCreationProtocolFee) {
        (tripleCreationProtocolFee,,) = ethMultiVault.tripleConfig();
    }

    function getMinDeposit() public view returns (uint256 minDeposit) {
        (,,, minDeposit,,,,) = ethMultiVault.generalConfig();
    }

    function getMinShare() public view returns (uint256 minShare) {
        (,,,, minShare,,,) = ethMultiVault.generalConfig();
    }

    function getAtomUriMaxLength() public view returns (uint256 atomUriMaxLength) {
        (,,,,, atomUriMaxLength,,) = ethMultiVault.generalConfig();
    }

    function getMinDelay() public view returns (uint256 minDelay) {
        (,,,,,,, minDelay) = ethMultiVault.generalConfig();
    }

    function getAtomDepositFractionOnTripleCreation()
        public
        view
        returns (uint256 atomDepositFractionOnTripleCreation)
    {
        (, atomDepositFractionOnTripleCreation,) = ethMultiVault.tripleConfig();
    }

    function getAtomDepositFraction() public view returns (uint256 atomDepositFractionForTriple) {
        (,, atomDepositFractionForTriple) = ethMultiVault.tripleConfig();
    }

    function getAtomWalletAddr(uint256 id) public view returns (address) {
        return ethMultiVault.computeAtomWalletAddr(id);
    }

    function convertToShares(uint256 assets, uint256 id) public view returns (uint256) {
        return ethMultiVault.convertToShares(assets, id);
    }

    function convertToAssets(uint256 shares, uint256 id) public view returns (uint256) {
        return ethMultiVault.convertToAssets(shares, id);
    }

    function getSharesInVault(uint256 vaultId, address user) public view returns (uint256) {
        (uint256 shares,) = ethMultiVault.getVaultStateForUser(vaultId, user);
        return shares;
    }

    function checkDepositIntoVault(uint256 amount, uint256 id, uint256 totalAssetsBefore, uint256 totalSharesBefore)
        public
        payable
    {
        uint256 atomDepositFraction = atomDepositFractionAmount(amount, id);
        uint256 userAssetsAfterAtomDepositFraction = amount - atomDepositFraction;

        uint256 totalAssetsDeltaExpected = userAssetsAfterAtomDepositFraction;

        uint256 entryFee;

        if (totalSharesBefore == getMinShare()) {
            entryFee = 0;
        } else {
            entryFee = entryFeeAmount(userAssetsAfterAtomDepositFraction, id);
        }

        uint256 userAssetsAfterTotalFees = userAssetsAfterAtomDepositFraction - entryFee;

        uint256 totalAssetsDeltaGot = vaultTotalAssets(id) - totalAssetsBefore;
        uint256 totalSharesDeltaGot = vaultTotalShares(id) - totalSharesBefore;

        assertEq(totalAssetsDeltaExpected, totalAssetsDeltaGot);

        uint256 totalSharesDeltaExpected;
        if (totalSharesBefore == 0) {
            totalSharesDeltaExpected = userAssetsAfterTotalFees;
        } else {
            totalSharesDeltaExpected = userAssetsAfterTotalFees.mulDiv(totalSharesBefore, totalAssetsBefore);
        }

        // Assert the calculated shares delta is as expected based on the backwards calculation from `convertToShares`
        assertEq(totalSharesDeltaExpected, totalSharesDeltaGot);
    }

    function checkAtomDepositIntoVaultOnTripleVaultCreation(
        uint256 proportionalAmount,
        uint256 staticAmount,
        uint256 id,
        uint256 totalAssetsBefore,
        uint256 totalSharesBefore
    ) public payable {
        uint256 totalAssetsDeltaExpected = proportionalAmount + staticAmount;
        uint256 totalAssetsDeltaGot = vaultTotalAssets(id) - totalAssetsBefore;

        assertEq(totalAssetsDeltaExpected, totalAssetsDeltaGot);

        uint256 entryFee = entryFeeAmount(proportionalAmount, id);
        uint256 userAssetsAfterEntryFee = proportionalAmount - entryFee;

        uint256 totalSharesDeltaExpected = userAssetsAfterEntryFee.mulDiv(totalSharesBefore, totalAssetsBefore);
        uint256 totalSharesDeltaGot = vaultTotalShares(id) - totalSharesBefore;

        assertEq(totalSharesDeltaExpected, totalSharesDeltaGot);
    }

    function checkDepositOnAtomVaultCreation(
        uint256 id,
        uint256 value, // msg.value
        uint256 totalAssetsBefore,
        uint256 totalSharesBefore
    ) public view {
        uint256 sharesForZeroAddress = getMinShare();
        uint256 sharesForAtomWallet = getAtomWalletInitialDepositAmount();
        uint256 userDeposit = value - getAtomCost();
        uint256 assets = userDeposit - getProtocolFeeAmount(userDeposit, id);
        uint256 sharesForDepositor = assets;

        // calculate expected total assets delta
        uint256 totalAssetsDeltaExpected = sharesForDepositor + sharesForZeroAddress + sharesForAtomWallet;
        // calculate expected total shares delta
        uint256 totalSharesDeltaExpected = sharesForDepositor + sharesForZeroAddress + sharesForAtomWallet;

        // vault's total assets should have gone up
        uint256 totalAssetsDeltaGot = vaultTotalAssets(id) - totalAssetsBefore;
        assertEq(totalAssetsDeltaExpected, totalAssetsDeltaGot);

        // vault's total shares should have gone up
        uint256 totalSharesDeltaGot = vaultTotalShares(id) - totalSharesBefore;
        assertEq(totalSharesDeltaExpected, totalSharesDeltaGot);
    }

    function checkDepositOnTripleVaultCreation(
        uint256 id,
        uint256 value,
        uint256 totalAssetsBefore,
        uint256 totalSharesBefore
    ) public view {
        // calculate expected total assets delta
        uint256 userDeposit = value - getTripleCost();
        uint256 protocolDepositFee = protocolFeeAmount(userDeposit, id);
        uint256 userDepositAfterProtocolFees = userDeposit - protocolDepositFee;
        uint256 atomDepositFraction = atomDepositFractionAmount(userDepositAfterProtocolFees, id);

        uint256 sharesForZeroAddress = getMinShare();

        uint256 totalAssetsDeltaExpected = userDepositAfterProtocolFees - atomDepositFraction + sharesForZeroAddress;

        // calculate expected total shares delta
        uint256 sharesForDepositor = userDepositAfterProtocolFees - atomDepositFraction;
        uint256 totalSharesDeltaExpected = sharesForDepositor + sharesForZeroAddress;

        // vault's total assets should have gone up
        uint256 totalAssetsDeltaGot = vaultTotalAssets(id) - totalAssetsBefore;

        uint256 totalSharesDeltaGot = vaultTotalShares(id) - totalSharesBefore;
        assertEq(totalAssetsDeltaExpected, totalAssetsDeltaGot);

        // vault's total shares should have gone up
        // uint256 totalSharesDeltaGot = vaultTotalShares(id) - totalSharesBefore;
        assertEq(totalSharesDeltaExpected, totalSharesDeltaGot);
    }

    function checkProtocolVaultBalanceOnVaultCreation(
        uint256 id,
        uint256 userDeposit,
        uint256 protocolVaultBalanceBefore
    ) public view {
        // calculate expected protocol vault balance delta
        uint256 protocolVaultBalanceDeltaExpected = getAtomCreationProtocolFee() + getProtocolFeeAmount(userDeposit, id);

        uint256 protocolVaultBalanceDeltaGot = address(getProtocolVault()).balance - protocolVaultBalanceBefore;

        assertEq(protocolVaultBalanceDeltaExpected, protocolVaultBalanceDeltaGot);
    }

    function checkProtocolVaultBalanceOnVaultBatchCreation(
        uint256[] memory ids,
        uint256 valuePerAtom,
        uint256 protocolVaultBalanceBefore
    ) public view {
        uint256 length = ids.length;
        uint256 protocolFees;

        for (uint256 i = 0; i < length; i++) {
            // calculate expected protocol vault balance delta
            protocolFees += getProtocolFeeAmount(valuePerAtom, i);
        }

        uint256 protocolVaultBalanceDeltaExpected = getAtomCreationProtocolFee() * length + protocolFees;

        // protocol vault's balance should have gone up
        uint256 protocolVaultBalanceDeltaGot = address(getProtocolVault()).balance - protocolVaultBalanceBefore;

        assertEq(protocolVaultBalanceDeltaExpected, protocolVaultBalanceDeltaGot);
    }

    function checkProtocolVaultBalance(uint256 id, uint256 assets, uint256 protocolVaultBalanceBefore) public view {
        // calculate expected protocol vault balance delta
        uint256 protocolVaultBalanceDeltaExpected = getProtocolFeeAmount(assets, id);

        // protocol vault's balance should have gone up
        uint256 protocolVaultBalanceDeltaGot = address(getProtocolVault()).balance - protocolVaultBalanceBefore;

        assertEq(protocolVaultBalanceDeltaExpected, protocolVaultBalanceDeltaGot);
    }
}
