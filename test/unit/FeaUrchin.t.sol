// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {FeaUrchin} from "src/FeaUrchin.sol";
import {EthMultiVault} from "src/EthMultiVault.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";

import {console2 as console} from "forge-std/console2.sol";

contract FeaUrchinTest is Test, EthMultiVaultBase {
    FeaUrchin feaUrchin;
    address admin = address(1);
    address user1 = address(2);
    address user2 = address(3);
    uint256 constant FEE_NUMERATOR = 100; // 1%
    uint256 constant FEE_DENOMINATOR = 10000;

    function setUp() external {
        _setUp(); // Sets up EthMultiVault
        feaUrchin = new FeaUrchin(
            IEthMultiVault(address(ethMultiVault)),
            admin,
            FEE_NUMERATOR,
            FEE_DENOMINATOR
        );
        
        // Fund test accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function testInitialState() public {
        assertEq(address(feaUrchin.ethMultiVault()), address(ethMultiVault));
        assertEq(feaUrchin.owner(), admin);
        assertEq(feaUrchin.feeNumerator(), FEE_NUMERATOR);
        assertEq(feaUrchin.feeDenominator(), FEE_DENOMINATOR);
        assertEq(feaUrchin.totalAssetsMoved(), 0);
        assertEq(feaUrchin.totalAssetsStaked(), 0);
        assertEq(feaUrchin.totalFeesCollected(), 0);
        assertEq(feaUrchin.uniqueUsersCount(), 0);
    }

    function testSetFee() public {
        uint256 newNumerator = 200;
        uint256 newDenominator = 10000;

        vm.prank(admin);
        feaUrchin.setFee(newNumerator, newDenominator);

        assertEq(feaUrchin.feeNumerator(), newNumerator);
        assertEq(feaUrchin.feeDenominator(), newDenominator);
    }

    function testSetFeeNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        feaUrchin.setFee(200, 10000);
    }

    function testCreateAtom() public {
        uint256 depositAmount = 1 ether;
        bytes memory atomUri = "test_atom";
        
        vm.startPrank(user1);
        uint256 termId = feaUrchin.createAtom{value: depositAmount}(atomUri);
        vm.stopPrank();

        // Check user tracking
        assertTrue(feaUrchin.isUniqueUser(user1));
        assertEq(feaUrchin.uniqueUsersCount(), 1);

        // Check fee calculations
        uint256 expectedFee = (depositAmount * FEE_NUMERATOR) / FEE_DENOMINATOR;
        assertEq(feaUrchin.totalFeesCollected(), expectedFee);
        assertEq(feaUrchin.totalAssetsMoved(), depositAmount);
        assertEq(feaUrchin.totalAssetsStaked(), depositAmount);
    }

    function testCreateTriple() public {
        // First create three atoms
        vm.startPrank(user1);
        uint256 atomCost = feaUrchin.getAtomCost();
        uint256 subjectId = feaUrchin.createAtom{value: atomCost}("subject");
        uint256 predicateId = feaUrchin.createAtom{value: atomCost}("predicate");
        uint256 objectId = feaUrchin.createAtom{value: atomCost}("object");

        uint256 tripleCost = feaUrchin.getTripleCost();
        uint256 termId = feaUrchin.createTriple{value: tripleCost}(subjectId, predicateId, objectId);
        vm.stopPrank();

        // Verify triple creation
        assertTrue(ethMultiVault.isTripleId(termId));
        
        // Check fee calculations
        uint256 totalDeposited = atomCost * 3 + tripleCost;
        uint256 expectedTotalFee = (totalDeposited * FEE_NUMERATOR) / FEE_DENOMINATOR;
        assertEq(feaUrchin.totalFeesCollected(), expectedTotalFee);
        assertEq(feaUrchin.totalAssetsMoved(), totalDeposited);
        assertEq(feaUrchin.totalAssetsStaked(), totalDeposited);
    }

    function testWithdrawFees() public {
        // First make some deposits to generate fees
        uint256 depositAmount = 1 ether;
        vm.prank(user1);
        feaUrchin.createAtom{value: depositAmount}("test_atom");

        uint256 expectedFee = (depositAmount * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 adminBalanceBefore = admin.balance;

        vm.prank(admin);
        feaUrchin.withdrawFees(payable(admin));

        assertEq(admin.balance - adminBalanceBefore, expectedFee);
    }

    function testBatchOperations() public {
        vm.startPrank(user1);
        
        // Test batch create atom
        bytes[] memory atomUris = new bytes[](2);
        atomUris[0] = "atom1";
        atomUris[1] = "atom2";
        uint256 batchAmount = 2 ether;
        
        uint256[] memory termIds = feaUrchin.batchCreateAtom{value: batchAmount}(atomUris);
        assertEq(termIds.length, 2);
        
        // Test batch create triple
        uint256[] memory subjectIds = new uint256[](2);
        uint256[] memory predicateIds = new uint256[](2);
        uint256[] memory objectIds = new uint256[](2);
        
        for(uint256 i = 0; i < 2; i++) {
            subjectIds[i] = feaUrchin.createAtom{value: 1 ether}(bytes(string(abi.encodePacked("subject", i))));
            predicateIds[i] = feaUrchin.createAtom{value: 1 ether}(bytes(string(abi.encodePacked("predicate", i))));
            objectIds[i] = feaUrchin.createAtom{value: 1 ether}(bytes(string(abi.encodePacked("object", i))));
        }
        
        uint256[] memory tripleIds = feaUrchin.batchCreateTriple{value: 2 ether}(subjectIds, predicateIds, objectIds);
        assertEq(tripleIds.length, 2);
        
        vm.stopPrank();
    }

    function testRedeem() public {
        // First create an atom and get some shares
        vm.startPrank(user1);
        uint256 depositAmount = 1 ether;
        uint256 termId = feaUrchin.createAtom{value: depositAmount}("test_atom");
        
        // Get shares balance
        uint256 shares = feaUrchin.getVaultShares(address(user1), termId, 1); 
        console.log("vault state for user: ", shares);
        
        // Redeem shares
        uint256 balanceBefore = user1.balance;
        console.log("balance before: ", balanceBefore);
        uint256 redeemedAmount = feaUrchin.redeem(shares, user1, termId, 1);
        console.log("redeemedAmount: ", redeemedAmount);
        // Verify redemption
        assertEq(user1.balance - balanceBefore, redeemedAmount);
        vm.stopPrank();
    }
} 
