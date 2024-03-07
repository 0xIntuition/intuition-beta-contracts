// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title  IntuitionProxy
 * @author 0xIntuition
 * @notice Core contract of the Intuition protocol. This contract is the base proxy contract used
 *         for all upgradeable Intuition smart contracts.
 */
contract IntuitionProxy is TransparentUpgradeableProxy {
  /**
   * @notice The constructor for the IntuitionProxy contract
   * @param _logic address - Address of the logic contract
   * @param _initialOwner address - Address of the initial owner of the proxy contract
   * @param _data bytes memory - Init data to send to the logic contract after initialization (can be empty)
   */
  constructor(
    address _logic,
    address _initialOwner,
    bytes memory _data
  ) TransparentUpgradeableProxy(_logic, _initialOwner, _data) {}
}
