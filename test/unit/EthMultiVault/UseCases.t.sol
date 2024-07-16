// SPDX-License-Identifier: BUSL-1.1
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
        uint256 protocolMultisigAssets;
    }

    struct UseCaseTriple {
        uint256 value;
        uint256 userShares;
        uint256 totalSharesPos;
        uint256 totalAssetsPos;
        uint256 totalSharesNeg;
        uint256 totalAssetsNeg;
        uint256 protocolMultisigAssets;
        UseCaseAtom subject;
        UseCaseAtom predicate;
        UseCaseAtom obj;
    }

    struct UseCaseRedeem {
        uint256 value;
        uint256 shares;
        uint256 assets;
        uint256 totalRemainingShares;
        uint256 totalRemainingAssets;
        uint256 protocolMultisigAssets;
    }

    UseCaseAtom[] useCaseAtoms;
    UseCaseTriple[] useCaseTriples;
    UseCaseRedeem[] useCaseRedeems;

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
                protocolMultisigAssets: 200000000000000
            })
        );
        useCaseAtoms.push(
            UseCaseAtom({
                value: 300000000100001,
                userShares: 0,
                atomWalletShares: 100000000000000,
                totalShares: 100000000100000,
                totalAssets: 100000000100000,
                protocolMultisigAssets: 200000000000001
            })
        );
        useCaseAtoms.push(
            UseCaseAtom({
                value: 1000000000000000000,
                userShares: 989702999999901000,
                atomWalletShares: 100000000000000,
                totalShares: 989803000000001000,
                totalAssets: 989803000000001000,
                protocolMultisigAssets: 10196999999999000
            })
        );
        useCaseAtoms.push(
            UseCaseAtom({
                value: 10000000000000000000,
                userShares: 9899702999999901000,
                atomWalletShares: 100000000000000,
                totalShares: 9899803000000001000,
                totalAssets: 9899803000000001000,
                protocolMultisigAssets: 100196999999999000
            })
        );
        useCaseAtoms.push(
            UseCaseAtom({
                value: 100000000000000000000,
                userShares: 98999702999999901000,
                atomWalletShares: 100000000000000,
                totalShares: 98999803000000001000,
                totalAssets: 98999803000000001000,
                protocolMultisigAssets: 1000196999999999000
            })
        );
        useCaseAtoms.push(
            UseCaseAtom({
                value: 1000000000000000000000,
                userShares: 989999702999999901000,
                atomWalletShares: 100000000000000,
                totalShares: 989999803000000001000,
                totalAssets: 989999803000000001000,
                protocolMultisigAssets: 10000196999999999000
            })
        );

        uint256 length = useCaseAtoms.length;
        uint256 protocolMultisigBalanceBefore;

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
            uint256 protocolMultisigAssets = address(getProtocolMultisig()).balance;

            assertEq(userShares, u.userShares);
            assertEq(atomWalletShares, u.atomWalletShares);
            assertEq(totalShares, u.totalShares);
            assertEq(totalAssets, u.totalAssets);
            assertEq(protocolMultisigAssets, u.protocolMultisigAssets + protocolMultisigBalanceBefore);

            protocolMultisigBalanceBefore = protocolMultisigAssets;

            vm.stopPrank();
        }
    }

    function testUseCasesDepositAtom() external {
        useCaseAtoms.push(
            UseCaseAtom({
                value: 300000000100000,
                userShares: 819530524365958,
                atomWalletShares: 100000000000000,
                totalShares: 919530524465958,
                totalAssets: 991000000397000,
                protocolMultisigAssets: 209000000003000
            })
        );
        useCaseAtoms.push(
            UseCaseAtom({
                value: 300000000100001,
                userShares: 819530524365958,
                atomWalletShares: 100000000000000,
                totalShares: 919530524465958,
                totalAssets: 991000000397000,
                protocolMultisigAssets: 209000000003004
            })
        );
        useCaseAtoms.push(
            UseCaseAtom({
                value: 1000000000000000000,
                userShares: 3748889220983980557,
                atomWalletShares: 100000000000000,
                totalShares: 3748989220984080557,
                totalAssets: 3959803000000001000,
                protocolMultisigAssets: 40196999999999000
            })
        );
        useCaseAtoms.push(
            UseCaseAtom({
                value: 10000000000000000000,
                userShares: 37491616096457688477,
                atomWalletShares: 100000000000000,
                totalShares: 37491716096457788477,
                totalAssets: 39599803000000001000,
                protocolMultisigAssets: 400196999999999000
            })
        );
        useCaseAtoms.push(
            UseCaseAtom({
                value: 100000000000000000000,
                userShares: 374918884846505054817,
                atomWalletShares: 100000000000000,
                totalShares: 374918984846505154817,
                totalAssets: 395999803000000001000,
                protocolMultisigAssets: 4000196999999999000
            })
        );
        useCaseAtoms.push(
            UseCaseAtom({
                value: 1000000000000000000000,
                userShares: 3749191572346509791407,
                atomWalletShares: 100000000000000,
                totalShares: 3749191672346509891407,
                totalAssets: 3959999803000000001000,
                protocolMultisigAssets: 40000196999999999000
            })
        );

        uint256 length = useCaseAtoms.length;
        uint256 protocolMultisigBalanceBefore;

        for (uint256 i = 0; i < length; i++) {
            UseCaseAtom storage u = useCaseAtoms[i];

            vm.startPrank(rich, rich);

            // 1 create atom
            uint256 id = ethMultiVault.createAtom{value: u.value}(abi.encodePacked("atom", i));

            // 3 deposits to the atom
            for (uint256 j = 0; j < 3; j++) {
                ethMultiVault.depositAtom{value: u.value}(rich, id);
            }

            // atom values
            uint256 userShares = vaultBalanceOf(id, rich);
            uint256 atomWalletShares = vaultBalanceOf(id, address(getAtomWalletAddr(id)));
            uint256 totalShares = vaultTotalShares(id);
            uint256 totalAssets = vaultTotalAssets(id);
            uint256 protocolMultisigAssets = address(getProtocolMultisig()).balance;

            assertEq(userShares, u.userShares);
            assertEq(atomWalletShares, u.atomWalletShares);
            assertEq(totalShares, u.totalShares);
            assertEq(totalAssets, u.totalAssets);
            assertEq(protocolMultisigAssets, u.protocolMultisigAssets + protocolMultisigBalanceBefore);

            protocolMultisigBalanceBefore = protocolMultisigAssets;

            vm.stopPrank();
        }
    }

    function testUseCasesRedeemAtom() external {
        useCaseRedeems.push(
            UseCaseRedeem({
                value: 300000000100000,
                shares: 819530524365958,
                assets: 830675569788504,
                totalRemainingShares: 100000000100000,
                totalRemainingAssets: 151492154481026,
                protocolMultisigAssets: 217832276130470
            })
        );
        useCaseRedeems.push(
            UseCaseRedeem({
                value: 300000000100001,
                shares: 819530524365958,
                assets: 830675569788504,
                totalRemainingShares: 100000000100000,
                totalRemainingAssets: 151492154481026,
                protocolMultisigAssets: 217832276130474
            })
        );
        useCaseRedeems.push(
            UseCaseRedeem({
                value: 1000000000000000000,
                shares: 3748889220983980557,
                assets: 3724095382864819517,
                totalRemainingShares: 100000000100000,
                totalRemainingAssets: 196110643367347144,
                protocolMultisigAssets: 79793973767833339
            })
        );
        useCaseRedeems.push(
            UseCaseRedeem({
                value: 10000000000000000000,
                shares: 37491616096457688477,
                assets: 37243515383249751406,
                totalRemainingShares: 100000000100000,
                totalRemainingAssets: 1960290642978322412,
                protocolMultisigAssets: 796193973771926182
            })
        );
        useCaseRedeems.push(
            UseCaseRedeem({
                value: 100000000000000000000,
                shares: 374918884846505054817,
                assets: 372437715383288241292,
                totalRemainingShares: 100000000100000,
                totalRemainingAssets: 19602090642939423277,
                protocolMultisigAssets: 7960193973772335431
            })
        );
        useCaseRedeems.push(
            UseCaseRedeem({
                value: 1000000000000000000000,
                shares: 3749191572346509791407,
                assets: 3724379715383292090248,
                totalRemainingShares: 100000000100000,
                totalRemainingAssets: 196020090642935533396,
                protocolMultisigAssets: 79600193973772376356
            })
        );

        uint256 length = useCaseRedeems.length;
        uint256 protocolMultisigBalanceBefore;

        for (uint256 i = 0; i < length; i++) {
            UseCaseRedeem storage u = useCaseRedeems[i];

            vm.startPrank(rich, rich);

            // 1 create atom
            uint256 id = ethMultiVault.createAtom{value: u.value}(abi.encodePacked("atom", i));

            // 3 deposits to the atom
            for (uint256 j = 0; j < 3; j++) {
                ethMultiVault.depositAtom{value: u.value}(rich, id);
            }

            uint256 shares = vaultBalanceOf(id, rich);

            // 1 redeem total
            uint256 assets = ethMultiVault.redeemAtom(shares, rich, id);

            // atom values
            uint256 sharesAfter = vaultBalanceOf(id, rich);
            uint256 totalShares = vaultTotalShares(id);
            uint256 totalAssets = vaultTotalAssets(id);
            uint256 protocolMultisigAssets = address(getProtocolMultisig()).balance;

            assertEq(shares, u.shares);
            assertEq(0, sharesAfter);
            assertEq(assets, u.assets);
            assertEq(totalShares, u.totalRemainingShares);
            assertEq(totalAssets, u.totalRemainingAssets);
            assertEq(protocolMultisigAssets, u.protocolMultisigAssets + protocolMultisigBalanceBefore);

            protocolMultisigBalanceBefore = protocolMultisigAssets;

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
                protocolMultisigAssets: 806000000003002,
                subject: UseCaseAtom({
                    value: 500000000200000,
                    userShares: 198000000099000,
                    atomWalletShares: 100000000000000,
                    totalShares: 298000000199000,
                    totalAssets: 398000000199000,
                    protocolMultisigAssets: 202000000001000
                }),
                predicate: UseCaseAtom({
                    value: 500000000200001,
                    userShares: 198000000099000,
                    atomWalletShares: 100000000000000,
                    totalShares: 298000000199000,
                    totalAssets: 398000000199000,
                    protocolMultisigAssets: 202000000001001
                }),
                obj: UseCaseAtom({
                    value: 500000000200002,
                    userShares: 198000000099001,
                    atomWalletShares: 100000000000000,
                    totalShares: 298000000199001,
                    totalAssets: 398000000199001,
                    protocolMultisigAssets: 202000000001001
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
                protocolMultisigAssets: 806000000003004,
                subject: UseCaseAtom({
                    value: 500000000200001,
                    userShares: 198000000099000,
                    atomWalletShares: 100000000000000,
                    totalShares: 298000000199000,
                    totalAssets: 398000000199000,
                    protocolMultisigAssets: 202000000001001
                }),
                predicate: UseCaseAtom({
                    value: 500000000200002,
                    userShares: 198000000099001,
                    atomWalletShares: 100000000000000,
                    totalShares: 298000000199001,
                    totalAssets: 398000000199001,
                    protocolMultisigAssets: 202000000001001
                }),
                obj: UseCaseAtom({
                    value: 500000000200003,
                    userShares: 198000000099002,
                    atomWalletShares: 100000000000000,
                    totalShares: 298000000199002,
                    totalAssets: 398000000199002,
                    protocolMultisigAssets: 202000000001001
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
                protocolMultisigAssets: 40785999999995002,
                subject: UseCaseAtom({
                    value: 1000000000000000000,
                    userShares: 1036704487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 1036804487499991595,
                    totalAssets: 1039378249999991100,
                    protocolMultisigAssets: 10196999999999000
                }),
                predicate: UseCaseAtom({
                    value: 1000000000000000001,
                    userShares: 1036704487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 1036804487499991595,
                    totalAssets: 1039378249999991100,
                    protocolMultisigAssets: 10196999999999001
                }),
                obj: UseCaseAtom({
                    value: 1000000000000000002,
                    userShares: 1036704487499891596,
                    atomWalletShares: 100000000000000,
                    totalShares: 1036804487499991596,
                    totalAssets: 1039378249999991101,
                    protocolMultisigAssets: 10196999999999001
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
                protocolMultisigAssets: 400785999999995002,
                subject: UseCaseAtom({
                    value: 10000000000000000000,
                    userShares: 10369929487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 10370029487499991595,
                    totalAssets: 10394878249999991100,
                    protocolMultisigAssets: 100196999999999000
                }),
                predicate: UseCaseAtom({
                    value: 10000000000000000001,
                    userShares: 10369929487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 10370029487499991595,
                    totalAssets: 10394878249999991100,
                    protocolMultisigAssets: 100196999999999001
                }),
                obj: UseCaseAtom({
                    value: 10000000000000000002,
                    userShares: 10369929487499891596,
                    atomWalletShares: 100000000000000,
                    totalShares: 10370029487499991596,
                    totalAssets: 10394878249999991101,
                    protocolMultisigAssets: 100196999999999001
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
                protocolMultisigAssets: 4000785999999995002,
                subject: UseCaseAtom({
                    value: 100000000000000000000,
                    userShares: 103702179487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 103702279487499991595,
                    totalAssets: 103949878249999991100,
                    protocolMultisigAssets: 1000196999999999000
                }),
                predicate: UseCaseAtom({
                    value: 100000000000000000001,
                    userShares: 103702179487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 103702279487499991595,
                    totalAssets: 103949878249999991100,
                    protocolMultisigAssets: 1000196999999999001
                }),
                obj: UseCaseAtom({
                    value: 100000000000000000002,
                    userShares: 103702179487499891596,
                    atomWalletShares: 100000000000000,
                    totalShares: 103702279487499991596,
                    totalAssets: 103949878249999991101,
                    protocolMultisigAssets: 1000196999999999001
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
                protocolMultisigAssets: 40000785999999995002,
                subject: UseCaseAtom({
                    value: 1000000000000000000000,
                    userShares: 1037024679487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 1037024779487499991595,
                    totalAssets: 1039499878249999991100,
                    protocolMultisigAssets: 10000196999999999000
                }),
                predicate: UseCaseAtom({
                    value: 1000000000000000000001,
                    userShares: 1037024679487499891595,
                    atomWalletShares: 100000000000000,
                    totalShares: 1037024779487499991595,
                    totalAssets: 1039499878249999991100,
                    protocolMultisigAssets: 10000196999999999001
                }),
                obj: UseCaseAtom({
                    value: 1000000000000000000002,
                    userShares: 1037024679487499891596,
                    atomWalletShares: 100000000000000,
                    totalShares: 1037024779487499991596,
                    totalAssets: 1039499878249999991101,
                    protocolMultisigAssets: 10000196999999999001
                })
            })
        );

        uint256 length = useCaseTriples.length;
        uint256 protocolMultisigBalanceBefore;

        for (uint256 i = 0; i < length; i++) {
            UseCaseTriple storage u = useCaseTriples[i];

            vm.startPrank(rich, rich);

            // 3 create atoms
            uint256 subjectId = ethMultiVault.createAtom{value: u.subject.value}(abi.encodePacked("subject", i));
            uint256 predicateId = ethMultiVault.createAtom{value: u.predicate.value}(abi.encodePacked("predicate", i));
            uint256 objectId = ethMultiVault.createAtom{value: u.obj.value}(abi.encodePacked("object", i));

            // 1 create triple
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

            uint256 protocolMultisigAssets = address(getProtocolMultisig()).balance;

            // check protocol multisig
            assertEq(protocolMultisigAssets, u.protocolMultisigAssets + protocolMultisigBalanceBefore);

            protocolMultisigBalanceBefore = protocolMultisigAssets;

            vm.stopPrank();
        }
    }

    function testUseCasesDepositTriple() external {
        useCaseTriples.push(
            UseCaseTriple({
                value: 500000000200000,
                userShares: 1210182187985260,
                totalSharesPos: 1210182188085260,
                totalAssetsPos: 1262250000604900,
                totalSharesNeg: 100000,
                totalAssetsNeg: 100000,
                protocolMultisigAssets: 815000000006000,
                subject: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 35081298438694,
                    atomWalletShares: 100000000000000,
                    totalShares: 135081298538694,
                    totalAssets: 274250000129700,
                    protocolMultisigAssets: 200000000000000
                }),
                predicate: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 35081298438694,
                    atomWalletShares: 100000000000000,
                    totalShares: 135081298538694,
                    totalAssets: 274250000129700,
                    protocolMultisigAssets: 200000000000000
                }),
                obj: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 35081298438694,
                    atomWalletShares: 100000000000000,
                    totalShares: 135081298538694,
                    totalAssets: 274250000129700,
                    protocolMultisigAssets: 200000000000000
                })
            })
        );
        useCaseTriples.push(
            UseCaseTriple({
                value: 500000000200001,
                userShares: 1210182187985260,
                totalSharesPos: 1210182188085260,
                totalAssetsPos: 1262250000604900,
                totalSharesNeg: 100000,
                totalAssetsNeg: 100000,
                protocolMultisigAssets: 815000000006004,
                subject: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 35081298438694,
                    atomWalletShares: 100000000000000,
                    totalShares: 135081298538694,
                    totalAssets: 274250000129700,
                    protocolMultisigAssets: 200000000000000
                }),
                predicate: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 35081298438694,
                    atomWalletShares: 100000000000000,
                    totalShares: 135081298538694,
                    totalAssets: 274250000129700,
                    protocolMultisigAssets: 200000000000000
                }),
                obj: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 35081298438694,
                    atomWalletShares: 100000000000000,
                    totalShares: 135081298538694,
                    totalAssets: 274250000129700,
                    protocolMultisigAssets: 200000000000000
                })
            })
        );
        useCaseTriples.push(
            UseCaseTriple({
                value: 1000000000000000000,
                userShares: 3186380266276360948,
                totalSharesPos: 3186380266276460948,
                totalAssetsPos: 3365579249999931700,
                totalSharesNeg: 100000,
                totalAssetsNeg: 100000,
                protocolMultisigAssets: 40794999999998000,
                subject: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 177817911711497789,
                    atomWalletShares: 100000000000000,
                    totalShares: 177917911711597789,
                    totalAssets: 198175250000090100,
                    protocolMultisigAssets: 200000000000000
                }),
                predicate: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 177817911711497789,
                    atomWalletShares: 100000000000000,
                    totalShares: 177917911711597789,
                    totalAssets: 198175250000090100,
                    protocolMultisigAssets: 200000000000000
                }),
                obj: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 177817911711497789,
                    atomWalletShares: 100000000000000,
                    totalShares: 177917911711597789,
                    totalAssets: 198175250000090100,
                    protocolMultisigAssets: 200000000000000
                })
            })
        );
        useCaseTriples.push(
            UseCaseTriple({
                value: 10000000000000000000,
                userShares: 31867698112568949759,
                totalSharesPos: 31867698112569049759,
                totalAssetsPos: 33659579249999931700,
                totalSharesNeg: 100000,
                totalAssetsNeg: 100000,
                protocolMultisigAssets: 400794999999998000,
                subject: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 1780596657413778684,
                    atomWalletShares: 100000000000000,
                    totalShares: 1780696657413878684,
                    totalAssets: 1980175250000090100,
                    protocolMultisigAssets: 200000000000000
                }),
                predicate: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 1780596657413778684,
                    atomWalletShares: 100000000000000,
                    totalShares: 1780696657413878684,
                    totalAssets: 1980175250000090100,
                    protocolMultisigAssets: 200000000000000
                }),
                obj: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 1780596657413778684,
                    atomWalletShares: 100000000000000,
                    totalShares: 1780696657413878684,
                    totalAssets: 1980175250000090100,
                    protocolMultisigAssets: 200000000000000
                })
            })
        );
        useCaseTriples.push(
            UseCaseTriple({
                value: 100000000000000000000,
                userShares: 318680876550323148598,
                totalSharesPos: 318680876550323248598,
                totalAssetsPos: 336599579249999931700,
                totalSharesNeg: 100000,
                totalAssetsNeg: 100000,
                protocolMultisigAssets: 4000794999999998000,
                subject: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 17808391844679118896,
                    atomWalletShares: 100000000000000,
                    totalShares: 17808491844679218896,
                    totalAssets: 19800175250000090100,
                    protocolMultisigAssets: 200000000000000
                }),
                predicate: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 17808391844679118896,
                    atomWalletShares: 100000000000000,
                    totalShares: 17808491844679218896,
                    totalAssets: 19800175250000090100,
                    protocolMultisigAssets: 200000000000000
                }),
                obj: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 17808391844679118896,
                    atomWalletShares: 100000000000000,
                    totalShares: 17808491844679218896,
                    totalAssets: 19800175250000090100,
                    protocolMultisigAssets: 200000000000000
                })
            })
        );
        useCaseTriples.push(
            UseCaseTriple({
                value: 1000000000000000000000,
                userShares: 3186812660925348567881,
                totalSharesPos: 3186812660925348667881,
                totalAssetsPos: 3365999579249999931700,
                totalSharesNeg: 100000,
                totalAssetsNeg: 100000,
                protocolMultisigAssets: 40000794999999998000,
                subject: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 178086344493090406861,
                    atomWalletShares: 100000000000000,
                    totalShares: 178086444493090506861,
                    totalAssets: 198000175250000090100,
                    protocolMultisigAssets: 200000000000000
                }),
                predicate: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 178086344493090406861,
                    atomWalletShares: 100000000000000,
                    totalShares: 178086444493090506861,
                    totalAssets: 198000175250000090100,
                    protocolMultisigAssets: 200000000000000
                }),
                obj: UseCaseAtom({
                    value: 300000000100000,
                    userShares: 178086344493090406861,
                    atomWalletShares: 100000000000000,
                    totalShares: 178086444493090506861,
                    totalAssets: 198000175250000090100,
                    protocolMultisigAssets: 200000000000000
                })
            })
        );

        uint256 length = useCaseTriples.length;
        uint256 protocolMultisigBalanceBefore;

        for (uint256 i = 0; i < length; i++) {
            UseCaseTriple storage u = useCaseTriples[i];

            vm.startPrank(rich, rich);

            // 3 create atoms
            uint256 subjectId = ethMultiVault.createAtom{value: u.subject.value}(abi.encodePacked("subject", i));
            uint256 predicateId = ethMultiVault.createAtom{value: u.predicate.value}(abi.encodePacked("predicate", i));
            uint256 objectId = ethMultiVault.createAtom{value: u.obj.value}(abi.encodePacked("object", i));

            // 1 create triple
            uint256 id = ethMultiVault.createTriple{value: u.value}(subjectId, predicateId, objectId);

            // 3 deposits to the triple
            for (uint256 j = 0; j < 3; j++) {
                ethMultiVault.depositTriple{value: u.value}(rich, id);
            }

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

            uint256 protocolMultisigAssets = address(getProtocolMultisig()).balance;

            // check protocol multisig
            assertEq(protocolMultisigAssets, u.protocolMultisigAssets + protocolMultisigBalanceBefore);

            protocolMultisigBalanceBefore = protocolMultisigAssets;

            vm.stopPrank();
        }
    }

    function testUseCasesRedeemTriple() external {
        useCaseRedeems.push(
            UseCaseRedeem({
                value: 500000000200000,
                shares: 1210182187985260,
                assets: 1249627500495591,
                totalRemainingShares: 100000,
                totalRemainingAssets: 104303,
                protocolMultisigAssets: 827622500011006
            })
        );
        useCaseRedeems.push(
            UseCaseRedeem({
                value: 500000000200001,
                shares: 1210182187985260,
                assets: 1249627500495591,
                totalRemainingShares: 100000,
                totalRemainingAssets: 104303,
                protocolMultisigAssets: 827622500011010
            })
        );
        useCaseRedeems.push(
            UseCaseRedeem({
                value: 1000000000000000000,
                shares: 3186380266276360948,
                assets: 3331923457499827815,
                totalRemainingShares: 100000,
                totalRemainingAssets: 105624,
                protocolMultisigAssets: 74450792499996261
            })
        );
        useCaseRedeems.push(
            UseCaseRedeem({
                value: 10000000000000000000,
                shares: 31867698112568949759,
                assets: 33322983457499827816,
                totalRemainingShares: 100000,
                totalRemainingAssets: 105623,
                protocolMultisigAssets: 737390792499996261
            })
        );
        useCaseRedeems.push(
            UseCaseRedeem({
                value: 100000000000000000000,
                shares: 318680876550323148598,
                assets: 333233583457499827816,
                totalRemainingShares: 100000,
                totalRemainingAssets: 105623,
                protocolMultisigAssets: 7366790792499996261
            })
        );

        uint256 length = useCaseRedeems.length;
        uint256 protocolMultisigBalanceBefore;

        for (uint256 i = 0; i < length; i++) {
            UseCaseRedeem storage u = useCaseRedeems[i];

            vm.startPrank(rich, rich);

            // 3 create atoms
            uint256 subjectId = ethMultiVault.createAtom{value: getAtomCost()}(abi.encodePacked("subject", i));
            uint256 predicateId = ethMultiVault.createAtom{value: getAtomCost()}(abi.encodePacked("predicate", i));
            uint256 objectId = ethMultiVault.createAtom{value: getAtomCost()}(abi.encodePacked("object", i));

            // 1 create triple
            uint256 id = ethMultiVault.createTriple{value: u.value}(subjectId, predicateId, objectId);

            // 3 deposits to the triple
            for (uint256 j = 0; j < 3; j++) {
                ethMultiVault.depositTriple{value: u.value}(rich, id);
            }

            uint256 shares = vaultBalanceOf(id, rich);

            // 1 redeem total
            uint256 assets = ethMultiVault.redeemTriple(shares, rich, id);

            // atom values
            uint256 sharesAfter = vaultBalanceOf(id, rich);
            uint256 totalShares = vaultTotalShares(id);
            uint256 totalAssets = vaultTotalAssets(id);
            uint256 protocolMultisigAssets = address(getProtocolMultisig()).balance;

            assertEq(shares, u.shares);
            assertEq(0, sharesAfter);
            assertEq(assets, u.assets);
            assertEq(totalShares, u.totalRemainingShares);
            assertEq(totalAssets, u.totalRemainingAssets);
            assertEq(protocolMultisigAssets, u.protocolMultisigAssets + protocolMultisigBalanceBefore);

            protocolMultisigBalanceBefore = protocolMultisigAssets;

            vm.stopPrank();
        }
    }
}
