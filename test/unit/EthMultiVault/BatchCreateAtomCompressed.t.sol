// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {EthMultiVaultBase} from "../../EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "../../helpers/EthMultiVaultHelpers.sol";
import {Errors} from "../../../src/libraries/Errors.sol";

contract BatchCreateAtomCompressedTest is
    EthMultiVaultBase,
    EthMultiVaultHelpers
{
    function setUp() external {
        _setUp();
    }

    function testBatchCreateAtomCompressed() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 atomsToCreate = 3;
        bytes[] memory atomData = new bytes[](atomsToCreate);
        for (uint256 i = 0; i < atomsToCreate; i++) {
            atomData[i] = abi.encodePacked(bytes("atom"), i);
        }

        uint256 testAtomCost = getAtomCost();

        // snapshots before creating a triple
        uint256 protocolVaultBalanceBefore = address(getProtocolVault())
            .balance;

        uint256[] memory totalAssetsBefore = new uint256[](atomsToCreate);
        uint256[] memory totalSharesBefore = new uint256[](atomsToCreate);
        for (uint256 i = 0; i < atomsToCreate; i++) {
            totalAssetsBefore[i] = vaultTotalAssets(i + 1);
            totalSharesBefore[i] = vaultTotalShares(i + 1);
        }

        uint256[] memory ids = ethMultiVault.batchCreateAtom{
            value: testAtomCost * atomsToCreate
        }(atomData);

        assertEq(ids.length, atomsToCreate);

        for (uint256 i = 0; i < atomsToCreate; i++) {
            checkDepositOnAtomVaultCreation(
                ids[i],
                testAtomCost,
                totalAssetsBefore[i],
                totalSharesBefore[i]
            );
        }

        checkProtocolVaultBalanceOnVaultBatchCreation(
            ids,
            protocolVaultBalanceBefore
        );

        vm.stopPrank();
    }

    function testBatchCreateAtomCompressedInsufficientBalance() external {
        vm.startPrank(alice, alice);

        // test values
        uint256 atomsToCreate = 3;
        bytes[] memory atomData = new bytes[](atomsToCreate);
        for (uint256 i = 0; i < atomsToCreate; i++) {
            atomData[i] = bytes("atom");
        }

        uint256 testAtomCost = getAtomCost();

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.MultiVault_InsufficientBalance.selector
            )
        );
        ethMultiVault.batchCreateAtom{
            value: testAtomCost * (atomsToCreate - 1)
        }(atomData);

        vm.stopPrank();
    }

    function getAtomCost()
        public
        view
        override
        returns (uint256)
    {
        return EthMultiVaultBase.getAtomCost();
    }
}
