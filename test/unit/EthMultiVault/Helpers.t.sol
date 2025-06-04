// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "forge-std/Test.sol";

import {AtomWallet} from "src/AtomWallet.sol";
import {Errors} from "src/libraries/Errors.sol";
import {EthMultiVaultBase} from "test/EthMultiVaultBase.sol";
import {EthMultiVaultHelpers} from "test/helpers/EthMultiVaultHelpers.sol";

contract HelpersTest is EthMultiVaultBase, EthMultiVaultHelpers {
    function setUp() external {
        _setUp();
    }

    function testMaxRedeem() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // test values
        uint256 testAtomCost = getAtomCost();
        uint256 testMinDesposit = getMinDeposit();
        uint256 testDepositAmount = testMinDesposit;

        // execute interaction - create atoms
        uint256 id = ethMultiVault.createAtom{value: testAtomCost}("atom1");

        // execute interaction - deposit atoms
        ethMultiVault.depositAtom{value: testDepositAmount}(alice, id);

        vm.stopPrank();

        /// @notice on vault creation all shares are minted to the caller's atom wallet
        address atomWallet = ethMultiVault.computeAtomWalletAddr(id);

        uint256 redeemableSharesAtomWallet = ethMultiVault.maxRedeem(atomWallet, id);
        uint256 redeemablesharesUser = ethMultiVault.maxRedeem(alice, id);

        assertEq(redeemableSharesAtomWallet + redeemablesharesUser + getMinShare(), vaultTotalShares(id));

        uint256 redeemablesharesFromUserWithNoDeposits = ethMultiVault.maxRedeem(bob, id);
        assertEq(redeemablesharesFromUserWithNoDeposits, 0);
    }

    function testDeployAtomWallet() external {
        // test values
        uint256 atomId = 1;

        // should not be able to deploy atom wallet for atom that has not been created yet
        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultDoesNotExist.selector));
        // execute interaction - deploy atom wallet
        ethMultiVault.deployAtomWallet(atomId);

        // execute interaction - create atoms and a triple
        uint256 atomId1 = ethMultiVault.createAtom{value: getAtomCost()}("atom1");
        uint256 atomId2 = ethMultiVault.createAtom{value: getAtomCost()}("atom2");
        uint256 atomId3 = ethMultiVault.createAtom{value: getAtomCost()}("atom3");

        uint256 tripleId = ethMultiVault.createTriple{value: getTripleCost()}(atomId1, atomId2, atomId3);

        address atomWalletAddress = ethMultiVault.deployAtomWallet(atomId);

        address computedAddress = ethMultiVault.computeAtomWalletAddr(atomId);

        // verify the returned atomWallet address is not zero
        assertNotEq(atomWalletAddress, address(0));

        // verify atomWallet is a contract
        assertTrue(isContract(atomWalletAddress));

        // verify the computed address matches the actual wallet address
        assertEq(computedAddress, atomWalletAddress);

        // should not be able to deploy an atom wallet for a triple vault
        vm.expectRevert(abi.encodeWithSelector(Errors.EthMultiVault_VaultNotAtom.selector));
        // execute interaction - deploy atom wallet
        ethMultiVault.deployAtomWallet(tripleId);

        // try to deploy atom wallet for an atom that has already been created (should return the same address)
        address atomWalletAddressAlreadyCreated = ethMultiVault.deployAtomWallet(atomId);
        assertEq(atomWalletAddress, atomWalletAddressAlreadyCreated);
    }

    function testAtomWalletOwnershipClaim() external {
        // execute interaction - create atom
        uint256 atomId = ethMultiVault.createAtom{value: getAtomCost()}("atom1");

        address atomWalletAddress = ethMultiVault.deployAtomWallet(atomId);
        address payable atomWallet = payable(atomWalletAddress);

        (, bytes memory returnData1) = atomWallet.call(abi.encodeWithSelector(AtomWallet.owner.selector));

        address atomWalletOwner = abi.decode(returnData1, (address));
        address atomWarden = ethMultiVault.getAtomWarden();

        assertEq(atomWalletOwner, atomWarden);

        vm.startPrank(atomWarden, atomWarden);

        (bool success,) = atomWallet.call(abi.encodeWithSelector(AtomWallet.transferOwnership.selector, address(0xabc)));
        assertEq(success, true);

        vm.stopPrank();

        vm.startPrank(address(0xabc), address(0xabc));

        (bool success2,) = atomWallet.call(abi.encodeWithSelector(AtomWallet.acceptOwnership.selector));
        assertEq(success2, true);

        (, bytes memory returnData2) = atomWallet.call(abi.encodeWithSelector(AtomWallet.owner.selector));

        address newOwner = abi.decode(returnData2, (address));

        // verify the new owner is set after the ownership claim is accepted
        assertEq(newOwner, address(0xabc));

        vm.stopPrank();

        vm.startPrank(atomWarden, atomWarden);

        // should revert when the atom wallet has already been claimed
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector));

        (bool success3,) =
            atomWallet.call(abi.encodeWithSelector(AtomWallet.transferOwnership.selector, address(0x456)));
        assertEq(success3, false);

        vm.stopPrank();

        // msg.sender = admin, can set a new atomWarden
        vm.startPrank(msg.sender, msg.sender);

        ethMultiVault.setAtomWarden(address(0xdef));

        (, bytes memory returnData3) = atomWallet.call(abi.encodeWithSelector(AtomWallet.owner.selector));

        address atomWalletOwnerAfterUpdate = abi.decode(returnData3, (address));

        // Changing the atomWarden should not affect the ownership of the atom wallet if it has been claimed
        assertEq(atomWalletOwnerAfterUpdate, address(0xabc));

        address atomWardenAfterUpdate = ethMultiVault.getAtomWarden();

        // verify the atomWarden has been updated
        assertEq(atomWardenAfterUpdate, address(0xdef));

        vm.stopPrank();
    }

    function testPlainEtherTransferToContractShouldRevert() external {
        // prank call from alice
        // as both msg.sender and tx.origin
        vm.startPrank(alice, alice);

        // should revert if plain ether transfer is attempted
        vm.expectRevert();
        payable(address(ethMultiVault)).transfer(1 ether);

        vm.stopPrank();
    }

    function isContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function getAtomCost() public view override returns (uint256) {
        return EthMultiVaultBase.getAtomCost();
    }
}
