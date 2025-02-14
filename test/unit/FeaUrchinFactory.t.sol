// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {FeaUrchinFactory} from "src/FeaUrchinFactory.sol";
import {FeaUrchin} from "src/FeaUrchin.sol";
import {IEthMultiVault} from "src/interfaces/IEthMultiVault.sol";

contract FeaUrchinFactoryTest is Test {
    FeaUrchinFactory public factory;
    address alice;
    address bob;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        factory = new FeaUrchinFactory(IEthMultiVault(address(1))); // Using a mock address for EthMultiVault
    }

    function test_deployFeaUrchin() public {
        vm.startPrank(alice);
        
        uint256 feeNumerator = 1;
        uint256 feeDenominator = 10;
        
        FeaUrchin feaUrchin = factory.deployFeaUrchin(feeNumerator, feeDenominator);
        
        assertEq(feaUrchin.owner(), alice);
        assertEq(feaUrchin.feeNumerator(), feeNumerator);
        assertEq(feaUrchin.feeDenominator(), feeDenominator);
        assertEq(address(feaUrchin.ethMultiVault()), address(1));
        
        vm.stopPrank();
    }

    function test_multipleDeployments() public {
        vm.startPrank(alice);
        FeaUrchin feaUrchin1 = factory.deployFeaUrchin(1, 10);
        assertEq(feaUrchin1.owner(), alice);
        vm.stopPrank();

        vm.startPrank(bob);
        FeaUrchin feaUrchin2 = factory.deployFeaUrchin(2, 20);
        assertEq(feaUrchin2.owner(), bob);
        vm.stopPrank();

        // Ensure they're different instances
        assertTrue(address(feaUrchin1) != address(feaUrchin2));
    }
} 