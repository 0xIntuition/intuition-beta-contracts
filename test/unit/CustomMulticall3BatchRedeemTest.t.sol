// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {CustomMulticall3BatchRedeem} from "src/utils/CustomMulticall3BatchRedeem.sol";
import {Errors} from "src/libraries/Errors.sol";

import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";

contract CustomMulticall3BatchRedeemTest is EthMultiVaultBase {
    TransparentUpgradeableProxy public customMulticall3BatchRedeemProxy;
    CustomMulticall3BatchRedeem public customMulticall3BatchRedeem;

    function setUp() public {
        _setUp();

        customMulticall3BatchRedeem = new CustomMulticall3BatchRedeem();
        customMulticall3BatchRedeemProxy =
            new TransparentUpgradeableProxy(address(customMulticall3BatchRedeem), msg.sender, "");
        customMulticall3BatchRedeem = CustomMulticall3BatchRedeem(address(customMulticall3BatchRedeemProxy));
        customMulticall3BatchRedeem.initialize(address(ethMultiVault), msg.sender);
    }

    function test_batchRedeem() external {
        uint256 testDepositAmount = 0.01 ether;
        uint256 atomCost = ethMultiVault.getAtomCost();
        uint256 tripleCost = ethMultiVault.getTripleCost();

        // alice creates a few atoms and triples and deposits some assets into each
        vm.startPrank(alice);

        address[] memory emptyArray = new address[](0);
        // owners are same as receivers in this example
        address[] memory owners = new address[](3);
        owners[0] = alice;
        owners[1] = alice;
        owners[2] = alice;

        uint256[] memory atomIds = new uint256[](3);
        uint256[] memory atomShares = new uint256[](3);

        uint256[] memory tripleIds = new uint256[](2);
        uint256[] memory tripleShares = new uint256[](2);

        for (uint256 i = 0; i < 3; i++) {
            uint256 id = ethMultiVault.createAtom{value: atomCost}(bytes(abi.encodePacked("alice", i)));
            atomIds[i] = id;
            uint256 shares = ethMultiVault.depositAtom{value: testDepositAmount}(alice, id);
            atomShares[i] = shares;
        }

        uint256 newTripleId = ethMultiVault.createTriple{value: tripleCost}(atomIds[0], atomIds[1], atomIds[2]);
        tripleIds[0] = newTripleId;
        uint256 newTripleShares = ethMultiVault.depositTriple{value: testDepositAmount}(alice, tripleIds[0]);
        tripleShares[0] = newTripleShares;

        newTripleId = ethMultiVault.createTriple{value: tripleCost}(atomIds[1], atomIds[0], atomIds[2]);
        tripleIds[1] = newTripleId;
        newTripleShares = ethMultiVault.depositTriple{value: testDepositAmount}(alice, tripleIds[1]);
        tripleShares[1] = newTripleShares;

        // alice approves the customMulticall3BatchRedeem contract to redeem her assets
        ethMultiVault.approveRedeemer(address(customMulticall3BatchRedeemProxy));

        assertEq(ethMultiVault.redemptionApprovals(alice, address(customMulticall3BatchRedeemProxy)), true);

        vm.stopPrank();

        vm.startPrank(msg.sender);

        // case 1: should revert if zero length array
        vm.expectRevert(Errors.CustomMulticall3_EmptyArray.selector);
        customMulticall3BatchRedeem.batchRedeem(emptyArray, atomShares, owners, atomIds, false);

        address[] memory shorterOwnersArray = new address[](2);
        shorterOwnersArray[0] = alice;
        shorterOwnersArray[1] = alice;

        // case 2: should revert if arrays are not the same length
        vm.expectRevert(Errors.CustomMulticall3_ArraysNotSameLength.selector);
        customMulticall3BatchRedeem.batchRedeem(owners, atomShares, shorterOwnersArray, atomIds, false);

        // case 3: should batch redeem from atom vaults

        uint256 aliceBalanceBefore = address(alice).balance;
        customMulticall3BatchRedeem.batchRedeem(owners, atomShares, owners, atomIds, false);
        assertGt(address(alice).balance, aliceBalanceBefore);

        // case 4: should batch redeem from triple vaults

        aliceBalanceBefore = address(alice).balance;
        customMulticall3BatchRedeem.batchRedeem(shorterOwnersArray, tripleShares, shorterOwnersArray, tripleIds, true);
        assertGt(address(alice).balance, aliceBalanceBefore);

        vm.stopPrank();
    }
}
