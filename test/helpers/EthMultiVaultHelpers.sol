// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {EthMultiVaultBase} from "../EthMultiVaultBase.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";

abstract contract EthMultiVaultHelpers is EthMultiVaultBase {
    using FixedPointMathLib for uint256;

    function getAdmin() public view returns (address admin) {
        (admin, , , , ) = ethMultiVault.generalConfig();
    }

    function getProtocolVault() public view returns (address protocolVault) {
        (, protocolVault, , , ) = ethMultiVault.generalConfig();
    }

    function getFeeDenominator() public view returns (uint256 feeDenominator) {
        (, , feeDenominator, , ) = ethMultiVault.generalConfig();
    }

    function getEntryFee(uint256 _id) public view returns (uint256 entryFee) {
        (entryFee, , ) = ethMultiVault.vaultFees(_id);
    }

    function getExitFee(uint256 _id) public view returns (uint256 exitFee) {
        (, exitFee, ) = ethMultiVault.vaultFees(_id);
    }

    function getProtocolFee(
        uint256 _id
    ) public view returns (uint256 protocolFee) {
        (, , protocolFee) = ethMultiVault.vaultFees(_id);
    }

    function getAtomCost()
        public
        view
        virtual
        override
        returns (uint256 atomCost)
    {
        (atomCost, ) = ethMultiVault.atomConfig();
    }

    function getAtomCreationFee()
        public
        view
        returns (uint256 atomCreationFee)
    {
        (, atomCreationFee) = ethMultiVault.atomConfig();
    }

    function getTripleCreationFee()
        public
        view
        returns (uint256 tripleCreationFee)
    {
        (tripleCreationFee, ) = ethMultiVault.tripleConfig();
    }

    function getMinDeposit() public view returns (uint256 minDeposit) {
        (, , , minDeposit, ) = ethMultiVault.generalConfig();
    }

    function getMinShare() public view returns (uint256 minShare) {
        (, , , , minShare) = ethMultiVault.generalConfig();
    }

    function getAtomEquityFee()
        public
        view
        returns (uint256 atomEquityFeeForTriple)
    {
        (, atomEquityFeeForTriple) = ethMultiVault.tripleConfig();
    }

    function getAtomWalletAddr(uint256 id) public view returns (address) {
        return ethMultiVault.computeAtomWalletAddr(id);
    }

    function convertToShares(
        uint256 assets,
        uint256 id
    ) public view returns (uint256) {
        return ethMultiVault.convertToShares(assets, id);
    }

    function convertToAssets(
        uint256 shares,
        uint256 id
    ) public view returns (uint256) {
        return ethMultiVault.convertToAssets(shares, id);
    }

    function getSharesInVault(
        uint256 vaultId,
        address user
    ) public view returns (uint256) {
        return ethMultiVault.getVaultBalance(vaultId, user);
    }

    function checkDepositIntoVault(
        uint256 amount,
        uint256 id,
        uint256 totalAssetsBefore,
        uint256 totalSharesBefore
    ) public {
        // calculate expected total assets delta
        uint256 totalAssetsDeltaExpected = amount -
            atomEquityFeeAmount(amount, id) -
            protocolFeeAmount(amount, id);

        // calculate expected total shares delta
        uint256 sharesForDepositor = totalSharesBefore == getMinShare()
            ? amount - getProtocolFee(id)
            : previewDeposit(amount, id);
        uint256 totalSharesDeltaExpected = sharesForDepositor;

        // vault's total assets should have gone up
        uint256 totalAssetsDeltaGot = vaultTotalAssets(id) - totalAssetsBefore;
        assertEq(totalAssetsDeltaExpected, totalAssetsDeltaGot);

        // vault's total shares should have gone up
        uint256 totalSharesDeltaGot = vaultTotalShares(id) - totalSharesBefore;
        assertEq(totalSharesDeltaExpected, totalSharesDeltaGot);
    }

    function checkDepositOnAtomVaultCreation(
        uint256 id,
        uint256 atomCost,
        uint256 totalAssetsBefore,
        uint256 totalSharesBefore
    ) public {
        // calculate expected total assets delta
        uint256 assetsDeposited = atomCost - getAtomCreationFee();
        uint256 totalAssetsDeltaExpected = assetsDeposited - getProtocolFee(id);

        // calculate expected total shares delta
        uint256 sharesForDepositor = totalAssetsDeltaExpected;
        uint256 sharesForZeroAddress = getMinShare();
        uint256 totalSharesDeltaExpected = sharesForDepositor +
            sharesForZeroAddress;

        // vault's total assets should have gone up
        uint256 totalAssetsDeltaGot = vaultTotalAssets(id) - totalAssetsBefore;
        assertEq(totalAssetsDeltaExpected, totalAssetsDeltaGot);

        // vault's total shares should have gone up
        uint256 totalSharesDeltaGot = vaultTotalShares(id) - totalSharesBefore;
        assertEq(totalSharesDeltaExpected, totalSharesDeltaGot);
    }

    function checkDepositOnTripleVaultCreation(
        uint256 id,
        uint256 atomCost,
        uint256 totalAssetsBefore,
        uint256 totalSharesBefore
    ) public {
        // calculate expected total assets delta
        uint256 assetsDeposited = atomCost - getTripleCreationFee();
        uint256 totalAssetsDeltaExpected = assetsDeposited - getProtocolFee(id);

        // calculate expected total shares delta
        uint256 sharesForDepositor = totalAssetsDeltaExpected;
        uint256 sharesForZeroAddress = getMinShare();
        uint256 totalSharesDeltaExpected = sharesForDepositor +
            sharesForZeroAddress;

        // vault's total assets should have gone up
        uint256 totalAssetsDeltaGot = vaultTotalAssets(id) - totalAssetsBefore;
        assertEq(totalAssetsDeltaExpected, totalAssetsDeltaGot);

        // vault's total shares should have gone up
        uint256 totalSharesDeltaGot = vaultTotalShares(id) - totalSharesBefore;
        assertEq(totalSharesDeltaExpected, totalSharesDeltaGot);
    }

    function checkProtocolVaultBalanceOnVaultCreation(
        uint256 id,
        uint256 protocolVaultBalanceBefore
    ) public {
        // calculate expected protocol vault balance delta
        uint256 protocolVaultBalanceDeltaExpected = getAtomCreationFee() +
            getProtocolFee(id);

        // protocol vault's balance should have gone up
        uint256 protocolVaultBalanceDeltaGot = address(getProtocolVault())
            .balance - protocolVaultBalanceBefore;
        assertEq(
            protocolVaultBalanceDeltaExpected,
            protocolVaultBalanceDeltaGot
        );
    }

    function checkProtocolVaultBalanceOnVaultBatchCreation(
        uint256[] memory ids,
        uint256 protocolVaultBalanceBefore
    ) public {
        uint256 length = ids.length;
        uint256 protocolFees;

        for (uint256 i = 0; i < length; i++) {
            // calculate expected protocol vault balance delta
            protocolFees += getProtocolFee(i);
        }

        uint256 protocolVaultBalanceDeltaExpected = getAtomCreationFee() *
            length +
            protocolFees;

        // protocol vault's balance should have gone up
        uint256 protocolVaultBalanceDeltaGot = address(getProtocolVault())
            .balance - protocolVaultBalanceBefore;
        assertEq(
            protocolVaultBalanceDeltaExpected,
            protocolVaultBalanceDeltaGot
        );
    }

    function checkProtocolVaultBalance(
        uint256 id,
        uint256 protocolVaultBalanceBefore
    ) public {
        // calculate expected protocol vault balance delta
        uint256 protocolVaultBalanceDeltaExpected = getProtocolFee(id);

        // protocol vault's balance should have gone up
        uint256 protocolVaultBalanceDeltaGot = address(getProtocolVault())
            .balance - protocolVaultBalanceBefore;
        assertEq(
            protocolVaultBalanceDeltaExpected,
            protocolVaultBalanceDeltaGot
        );
    }
}
