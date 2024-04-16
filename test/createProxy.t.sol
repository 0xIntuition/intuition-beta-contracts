// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {EthMultiVaultBase} from "./EthMultiVaultBase.sol";
import "solady/utils/ERC1967Factory.sol";

// Bootstrap some data on the contracts by creating a bunch of triples and staking on them
contract CreateProxy is EthMultiVaultBase {
    ERC1967Factory proxyFactory;
    address proxy;

    /// @notice set up test environment
    function setUp() internal {
        _setUp();
    }

    function testThing() external {
        emit log_named_address("test 0", address(0));
        // deploy new proxy factory
        proxyFactory = new ERC1967Factory();
        emit log_named_address("factory address", address(proxyFactory));
        // deploy new proxy for ethMultiVault with (this) as the admin
        proxy = proxyFactory.deploy(address(ethMultiVault), address(this));
        assertEq(proxyFactory.adminOf(proxy), address(this));
        emit log_named_address("proxy address", proxy);
        emit log_named_address("admin address", proxyFactory.adminOf(proxy));
        proxyFactory.changeAdmin(proxy, address(0xbeef));
        assertEq(proxyFactory.adminOf(proxy), address(0xbeef));
    }
}
