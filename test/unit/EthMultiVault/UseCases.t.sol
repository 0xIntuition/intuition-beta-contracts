// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {EthMultiVaultBase} from "../../EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "../../helpers/EthMultiVaultHelpers.sol";
import {Errors} from "../../../src/libraries/Errors.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

contract UseCasesTest is EthMultiVaultBase, EthMultiVaultHelpers {
    using FixedPointMathLib for uint256;

    struct UseCase {
        uint256 value;
        uint256 userShares;
        uint256 atomWalletShares;
        uint256 totalShares;
        uint256 totalAssets;
        uint256 protocolVaultAssets;
    }

    UseCase[] useCases;

    function setUp() external {
        _setUp();
    }

    function testUseCasesCreateAtom() external {
        useCases.push(
            UseCase({
                value: 300000000100000,
                userShares: 0,
                atomWalletShares: 100000000000000,
                totalShares: 100000000100000,
                totalAssets: 100000000100000,
                protocolVaultAssets: 200000000000000
            })
        );
        useCases.push(
            UseCase({
                value: 300000000100001,
                userShares: 0,
                atomWalletShares: 100000000000000,
                totalShares: 100000000100000,
                totalAssets: 100000000100000,
                protocolVaultAssets: 200000000000001
            })
        );
        useCases.push(
            UseCase({
                value: 1000000000000000000,
                userShares: 989702999999901000,
                atomWalletShares: 100000000000000,
                totalShares: 989803000000001000,
                totalAssets: 989803000000001000,
                protocolVaultAssets: 10196999999999000
            })
        );
        useCases.push(
            UseCase({
                value: 10000000000000000000,
                userShares: 9899702999999901000,
                atomWalletShares: 100000000000000,
                totalShares: 9899803000000001000,
                totalAssets: 9899803000000001000,
                protocolVaultAssets: 100196999999999000
            })
        );
        useCases.push(
            UseCase({
                value: 100000000000000000000,
                userShares: 98999702999999901000,
                atomWalletShares: 100000000000000,
                totalShares: 98999803000000001000,
                totalAssets: 98999803000000001000,
                protocolVaultAssets: 1000196999999999000
            })
        );
        useCases.push(
            UseCase({
                value: 1000000000000000000000,
                userShares: 989999702999999901000,
                atomWalletShares: 100000000000000,
                totalShares: 989999803000000001000,
                totalAssets: 989999803000000001000,
                protocolVaultAssets: 10000196999999999000
            })
        );
        useCases.push(
            UseCase({
                value: 10000000000000000000000,
                userShares: 9899999702999999901000,
                atomWalletShares: 100000000000000,
                totalShares: 9899999803000000001000,
                totalAssets: 9899999803000000001000,
                protocolVaultAssets: 100000196999999999000
            })
        );

        uint256 length = useCases.length;
        uint256 protocolVaultBalanceBefore;

        for (uint256 i = 0; i < length; i++) {
            UseCase storage u = useCases[i];

            vm.startPrank(rich, rich);

            uint256 id = ethMultiVault.createAtom{value: u.value}(abi.encodePacked("atom", i));

            uint256 userShares = vaultBalanceOf(id, rich);
            uint256 atomWalletShares = vaultBalanceOf(id, address(getAtomWalletAddr(id)));
            uint256 totalShares = vaultTotalShares(id);
            uint256 totalAssets = vaultTotalAssets(id);
            uint256 protocolVaultAssets = address(getProtocolVault()).balance;

            assertEq(userShares, u.userShares);
            assertEq(atomWalletShares, u.atomWalletShares);
            assertEq(totalShares, u.totalShares);
            assertEq(totalAssets, u.totalAssets);
            assertEq(protocolVaultAssets, u.protocolVaultAssets + protocolVaultBalanceBefore);

            protocolVaultBalanceBefore = protocolVaultAssets;

            vm.stopPrank();
        }
    }
}
