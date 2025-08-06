pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {EthMultiVaultBase} from "../../EthMultiVaultBase.sol";
import {Errors} from "../../../src/libraries/Errors.sol";

contract BatchDepositFixTest is EthMultiVaultBase {
    address attacker = address(0x1337);
    uint256 vaultId;

    function setUp() public {
        _setUp();

        vm.deal(attacker, 10 ether);

        vm.deal(address(this), 10 ether);
        vaultId = ethMultiVault.createAtom{value: getAtomCost()}("TestVault");
        console.log("Created vault ID:", vaultId);
    }

    function testBatchDepositExploitPrevented() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = vaultId;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5908.47 ether;

        vm.startPrank(attacker);

        vm.expectRevert(Errors.EthMultiVault_IncorrectETHAmount.selector);
        ethMultiVault.batchDeposit{value: 0}(attacker, ids, amounts);

        vm.stopPrank();

        console.log("[PASS] Exploit prevented - batchDeposit now validates msg.value");
    }

    function testBatchDepositCurveExploitPrevented() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = vaultId;

        uint256[] memory curveIds = new uint256[](1);
        curveIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 ether;

        vm.prank(attacker);

        vm.expectRevert(Errors.EthMultiVault_IncorrectETHAmount.selector);
        ethMultiVault.batchDepositCurve{value: 0}(attacker, ids, curveIds, amounts);

        console.log("[PASS] Exploit prevented - batchDepositCurve now validates msg.value");
    }

    function testBatchDepositValidDeposit() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = vaultId;
        ids[1] = vaultId;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;

        uint256 totalRequired = 3 ether;

        vm.prank(attacker);

        uint256[] memory shares = ethMultiVault.batchDeposit{value: totalRequired}(attacker, ids, amounts);

        assertGt(shares[0], 0, "First deposit should mint shares");
        assertGt(shares[1], 0, "Second deposit should mint shares");

        uint256 totalAssets = vaultTotalAssets(vaultId);
        console.log("Total assets after valid deposits:", totalAssets);

        assertGt(totalAssets, 2.9 ether, "Total assets should reflect deposits");
        assertLt(totalAssets, 3.1 ether, "Total assets should be reasonable");

        console.log("[PASS] Valid deposits work correctly");
    }

    function testExcessETHRejected() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = vaultId;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        vm.prank(attacker);

        vm.expectRevert(Errors.EthMultiVault_IncorrectETHAmount.selector);
        ethMultiVault.batchDeposit{value: 2 ether}(attacker, ids, amounts);

        console.log("[PASS] Excess ETH rejected");
    }
}
