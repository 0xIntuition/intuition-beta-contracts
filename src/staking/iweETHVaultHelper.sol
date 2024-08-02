// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

interface IiWeETHVault {
    function userStakes(address user)
        external
        view
        returns (
            uint256 userWeETHBalance,
            uint256 lastRecordedExchangeRate,
            uint256 accruedYield,
            uint256 lastUpdateTime,
            uint256 timeWeightedBalance
        );
}

contract iWeETHVaultHelper {
    uint256 public constant POINTS_RATE = 1000; // 1000 points per 1 ether per day (PoC idea)

    function getUserPoints(address vault, address user) external view returns (uint256) {
        IiWeETHVault iWeETHVault = IiWeETHVault(vault);

        (uint256 userWeETHBalance,,, uint256 lastUpdateTime, uint256 timeWeightedBalance) = iWeETHVault.userStakes(user);

        uint256 elapsedTime = block.timestamp - lastUpdateTime;
        uint256 additionalTWAB = userWeETHBalance * elapsedTime;
        uint256 totalTWAB = timeWeightedBalance + additionalTWAB;

        uint256 points = totalTWAB * POINTS_RATE / 1 ether / 1 days;
        return points;
    }
}
