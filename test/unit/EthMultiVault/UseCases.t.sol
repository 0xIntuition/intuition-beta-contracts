// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {EthMultiVaultBase} from "../../EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "../../helpers/EthMultiVaultHelpers.sol";
import {Errors} from "../../../src/libraries/Errors.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

contract UseCasesTest is EthMultiVaultBase, EthMultiVaultHelpers {
    using FixedPointMathLib for uint256;

    struct UseCaseAtom {
        uint256 value;
        uint256 userShares;
        uint256 atomWalletShares;
        uint256 totalShares;
        uint256 totalAssets;
        uint256 protocolVaultAssets;
    }

    struct UseCaseTriple {
        uint256 value;
        uint256 userShares;
        uint256 totalSharesPos;
        uint256 totalAssetsPos;
        uint256 totalSharesNeg;
        uint256 totalAssetsNeg;
        uint256 protocolVaultAssets;
        UseCaseAtom subject;
        UseCaseAtom predicate;
        UseCaseAtom obj;
    }

    UseCaseAtom[] useCaseAtoms;
    UseCaseTriple[] useCaseTriples;

    function setUp() external {
        _setUp();
    }

    function testUseCasesCreateAtom() external {
        useCaseAtoms.push(
            UseCaseAtom({
                value: 300000000100000,
                userShares: 0,
                atomWalletShares: 100000000000000,
                totalShares: 100000000100000,
                totalAssets: 100000000100000,
                protocolVaultAssets: 200000000000000
            })
        );
        useCaseAtoms.push(
            UseCaseAtom({
                value: 300000000100001,
                userShares: 0,
                atomWalletShares: 100000000000000,
                totalShares: 100000000100000,
                totalAssets: 100000000100000,
                protocolVaultAssets: 200000000000001
            })
        );
        useCaseAtoms.push(
            UseCaseAtom({
                value: 1000000000000000000,
                userShares: 989702999999901000,
                atomWalletShares: 100000000000000,
                totalShares: 989803000000001000,
                totalAssets: 989803000000001000,
                protocolVaultAssets: 10196999999999000
            })
        );
        useCaseAtoms.push(
            UseCaseAtom({
                value: 10000000000000000000,
                userShares: 9899702999999901000,
                atomWalletShares: 100000000000000,
                totalShares: 9899803000000001000,
                totalAssets: 9899803000000001000,
                protocolVaultAssets: 100196999999999000
            })
        );
        useCaseAtoms.push(
            UseCaseAtom({
                value: 100000000000000000000,
                userShares: 98999702999999901000,
                atomWalletShares: 100000000000000,
                totalShares: 98999803000000001000,
                totalAssets: 98999803000000001000,
                protocolVaultAssets: 1000196999999999000
            })
        );
        useCaseAtoms.push(
            UseCaseAtom({
                value: 1000000000000000000000,
                userShares: 989999702999999901000,
                atomWalletShares: 100000000000000,
                totalShares: 989999803000000001000,
                totalAssets: 989999803000000001000,
                protocolVaultAssets: 10000196999999999000
            })
        );

        uint256 length = useCaseAtoms.length;
        uint256 protocolVaultBalanceBefore;

        for (uint256 i = 0; i < length; i++) {
            UseCaseAtom storage u = useCaseAtoms[i];

            vm.startPrank(rich, rich);

            // create atom
            uint256 id = ethMultiVault.createAtom{value: u.value}(abi.encodePacked("atom", i));

            // atom values
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

    function testUseCasesCreateTriple() external {
        useCaseTriples.push(
            UseCaseTriple({
                value: 500000000200000,
                userShares: 0,
                totalSharesPos: 100000,
                totalAssetsPos: 100000,
                totalSharesNeg: 100000,
                totalAssetsNeg: 100000,
                protocolVaultAssets: 806000000003002,
                subject: UseCaseAtom({
                    value: 500000000200000,
                    userShares: 198000000099000,
                    atomWalletShares: 100000000000000,
                    totalShares: 298000000199000,
                    totalAssets: 398000000199000,
                    protocolVaultAssets: 202000000001000
                }),
                predicate: UseCaseAtom({
                    value: 500000000200001,
                    userShares: 198000000099000,
                    atomWalletShares: 100000000000000,
                    totalShares: 298000000199000,
                    totalAssets: 398000000199000,
                    protocolVaultAssets: 202000000001001
                }),
                obj: UseCaseAtom({
                    value: 500000000200002,
                    userShares: 198000000099001,
                    atomWalletShares: 100000000000000,
                    totalShares: 298000000199001,
                    totalAssets: 398000000199001,
                    protocolVaultAssets: 202000000001001
                })
            })
        );
        useCaseTriples.push(
            UseCaseTriple({
                value: 500000000200001,
                userShares: 0,
                totalSharesPos: 100000,
                totalAssetsPos: 100000,
                totalSharesNeg: 100000,
                totalAssetsNeg: 100000,
                protocolVaultAssets: 806000000003004,
                subject: UseCaseAtom({
                    value: 500000000200001,
                    userShares: 198000000099000,
                    atomWalletShares: 100000000000000,
                    totalShares: 298000000199000,
                    totalAssets: 398000000199000,
                    protocolVaultAssets: 202000000001001
                }),
                predicate: UseCaseAtom({
                    value: 500000000200002,
                    userShares: 198000000099001,
                    atomWalletShares: 100000000000000,
                    totalShares: 298000000199001,
                    totalAssets: 398000000199001,
                    protocolVaultAssets: 202000000001001
                }),
                obj: UseCaseAtom({
                    value: 500000000200003,
                    userShares: 198000000099002,
                    atomWalletShares: 100000000000000,
                    totalShares: 298000000199002,
                    totalAssets: 398000000199002,
                    protocolVaultAssets: 202000000001001
                })
            })
        );
        useCaseTriples.push(
            UseCaseTriple({
                value: 1000000000000000000,
                userShares: 841079249999831700,
                totalSharesPos: 841079249999931700,
                totalAssetsPos: 841079249999931700,
                totalSharesNeg: 100000,
                totalAssetsNeg: 100000,
                protocolVaultAssets: 40785999999995002,
                subject: UseCaseAtom({
                    value: 1000000000000000000,
                    userShares: 1036704487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 1036804487499991595,
                    totalAssets: 1039378249999991100,
                    protocolVaultAssets: 10196999999999000
                }),
                predicate: UseCaseAtom({
                    value: 1000000000000000001,
                    userShares: 1036704487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 1036804487499991595,
                    totalAssets: 1039378249999991100,
                    protocolVaultAssets: 10196999999999001
                }),
                obj: UseCaseAtom({
                    value: 1000000000000000002,
                    userShares: 1036704487499891596,
                    atomWalletShares: 100000000000000,
                    totalShares: 1036804487499991596,
                    totalAssets: 1039378249999991101,
                    protocolVaultAssets: 10196999999999001
                })
            })
        );
        useCaseTriples.push(
            UseCaseTriple({
                value: 10000000000000000000,
                userShares: 8414579249999831700,
                totalSharesPos: 8414579249999931700,
                totalAssetsPos: 8414579249999931700,
                totalSharesNeg: 100000,
                totalAssetsNeg: 100000,
                protocolVaultAssets: 400785999999995002,
                subject: UseCaseAtom({
                    value: 10000000000000000000,
                    userShares: 10369929487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 10370029487499991595,
                    totalAssets: 10394878249999991100,
                    protocolVaultAssets: 100196999999999000
                }),
                predicate: UseCaseAtom({
                    value: 10000000000000000001,
                    userShares: 10369929487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 10370029487499991595,
                    totalAssets: 10394878249999991100,
                    protocolVaultAssets: 100196999999999001
                }),
                obj: UseCaseAtom({
                    value: 10000000000000000002,
                    userShares: 10369929487499891596,
                    atomWalletShares: 100000000000000,
                    totalShares: 10370029487499991596,
                    totalAssets: 10394878249999991101,
                    protocolVaultAssets: 100196999999999001
                })
            })
        );
        useCaseTriples.push(
            UseCaseTriple({
                value: 100000000000000000000,
                userShares: 84149579249999831700,
                totalSharesPos: 84149579249999931700,
                totalAssetsPos: 84149579249999931700,
                totalSharesNeg: 100000,
                totalAssetsNeg: 100000,
                protocolVaultAssets: 4000785999999995002,
                subject: UseCaseAtom({
                    value: 100000000000000000000,
                    userShares: 103702179487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 103702279487499991595,
                    totalAssets: 103949878249999991100,
                    protocolVaultAssets: 1000196999999999000
                }),
                predicate: UseCaseAtom({
                    value: 100000000000000000001,
                    userShares: 103702179487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 103702279487499991595,
                    totalAssets: 103949878249999991100,
                    protocolVaultAssets: 1000196999999999001
                }),
                obj: UseCaseAtom({
                    value: 100000000000000000002,
                    userShares: 103702179487499891596,
                    atomWalletShares: 100000000000000,
                    totalShares: 103702279487499991596,
                    totalAssets: 103949878249999991101,
                    protocolVaultAssets: 1000196999999999001
                })
            })
        );
        useCaseTriples.push(
            UseCaseTriple({
                value: 1000000000000000000000,
                userShares: 841499579249999831700,
                totalSharesPos: 841499579249999931700,
                totalAssetsPos: 841499579249999931700,
                totalSharesNeg: 100000,
                totalAssetsNeg: 100000,
                protocolVaultAssets: 40000785999999995002,
                subject: UseCaseAtom({
                    value: 1000000000000000000000,
                    userShares: 1037024679487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 1037024779487499991595,
                    totalAssets: 1039499878249999991100,
                    protocolVaultAssets: 10000196999999999000
                }),
                predicate: UseCaseAtom({
                    value: 1000000000000000000001,
                    userShares: 1037024679487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 1037024779487499991595,
                    totalAssets: 1039499878249999991100,
                    protocolVaultAssets: 10000196999999999001
                }),
                obj: UseCaseAtom({
                    value: 1000000000000000000002,
                    userShares: 1037024679487499891596,
                    atomWalletShares: 100000000000000,
                    totalShares: 1037024779487499991596,
                    totalAssets: 1039499878249999991101,
                    protocolVaultAssets: 10000196999999999001
                })
            })
        );

        uint256 length = useCaseTriples.length;
        uint256 protocolVaultBalanceBefore;

        for (uint256 i = 0; i < length; i++) {
            UseCaseTriple storage u = useCaseTriples[i];

            vm.startPrank(rich, rich);

            // create atoms
            uint256 subjectId = ethMultiVault.createAtom{value: u.subject.value}(abi.encodePacked("subject", i));
            uint256 predicateId = ethMultiVault.createAtom{value: u.predicate.value}(abi.encodePacked("predicate", i));
            uint256 objectId = ethMultiVault.createAtom{value: u.obj.value}(abi.encodePacked("object", i));

            // create triple
            uint256 id = ethMultiVault.createTriple{value: u.value}(subjectId, predicateId, objectId);

            // check subject atom values
            assertEq(vaultBalanceOf(subjectId, rich), u.subject.userShares);
            assertEq(vaultBalanceOf(subjectId, address(getAtomWalletAddr(subjectId))), u.subject.atomWalletShares);
            assertEq(vaultTotalShares(subjectId), u.subject.totalShares);
            assertEq(vaultTotalAssets(subjectId), u.subject.totalAssets);

            // check predicate atom values
            assertEq(vaultBalanceOf(predicateId, rich), u.predicate.userShares);
            assertEq(vaultBalanceOf(predicateId, address(getAtomWalletAddr(predicateId))), u.predicate.atomWalletShares);
            assertEq(vaultTotalShares(predicateId), u.predicate.totalShares);
            assertEq(vaultTotalAssets(predicateId), u.predicate.totalAssets);

            // check object atom values
            assertEq(vaultBalanceOf(objectId, rich), u.obj.userShares);
            assertEq(vaultBalanceOf(objectId, address(getAtomWalletAddr(objectId))), u.obj.atomWalletShares);
            assertEq(vaultTotalShares(objectId), u.obj.totalShares);
            assertEq(vaultTotalAssets(objectId), u.obj.totalAssets);

            // check positive triple vault
            assertEq(vaultBalanceOf(id, rich), u.userShares);
            assertEq(vaultTotalShares(id), u.totalSharesPos);
            assertEq(vaultTotalAssets(id), u.totalAssetsPos);

            uint256 counterVaultId = getCounterIdFromTriple(id);

            // check negative triple vault
            assertEq(vaultTotalShares(counterVaultId), u.totalSharesNeg);
            assertEq(vaultTotalAssets(counterVaultId), u.totalAssetsNeg);

            uint256 protocolVaultAssets = address(getProtocolVault()).balance;

            // check protocol vault
            assertEq(protocolVaultAssets, u.protocolVaultAssets + protocolVaultBalanceBefore);

            protocolVaultBalanceBefore = protocolVaultAssets;

            vm.stopPrank();
        }
    }
}
