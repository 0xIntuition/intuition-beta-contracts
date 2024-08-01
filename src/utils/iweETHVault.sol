// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface WeETH is IERC20 {
    function getRate() external view returns (uint256);
}

contract iWeETHVault is ERC20, Ownable {
    WeETH public weETHContract;

    struct Stake {
        uint256 amountStakedInWeETH;
        uint256 initialExchangeRate;
    }

    mapping(address => Stake[]) public userStakes;

    uint256 public constant SCRAPE_PERCENTAGE = 10; // 10%

    event Deposited(address indexed user, uint256 amount, uint256 exchangeRate);
    event Redeemed(address indexed user, uint256 amount, uint256 yield, uint256 fee);

    constructor(address _weETHContract, address owner) ERC20("iWeETH", "iweETH") Ownable(owner) {
        weETHContract = WeETH(_weETHContract);
    }

    function deposit(uint256 amount) external {
        uint256 exchangeRate = weETHContract.getRate();
        weETHContract.transferFrom(msg.sender, address(this), amount);

        userStakes[msg.sender].push(Stake({
            amountStakedInWeETH: amount,
            initialExchangeRate: exchangeRate
        }));

        _mint(msg.sender, amount);

        emit Deposited(msg.sender, amount, exchangeRate);
    }

    function redeem(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint256 currentExchangeRate = weETHContract.getRate();
        uint256 totalYield = 0;
        uint256 remainingAmount = amount;

        // Iterate through stakes to calculate yield and update or remove stakes
        for (uint256 i = 0; i < userStakes[msg.sender].length && remainingAmount > 0; i++) {
            Stake storage stake = userStakes[msg.sender][i];

            if (stake.amountStakedInWeETH > 0) {
                uint256 redeemAmount = remainingAmount < stake.amountStakedInWeETH ? remainingAmount : stake.amountStakedInWeETH;
                uint256 yield = ((currentExchangeRate - stake.initialExchangeRate) * redeemAmount) / 1 ether;
                totalYield += yield;
                stake.amountStakedInWeETH -= redeemAmount;
                remainingAmount -= redeemAmount;

                if (stake.amountStakedInWeETH == 0) {
                    // Remove the stake if fully redeemed
                    _removeStake(msg.sender, i);
                    i--; // Adjust index after removal
                }
            }
        }

        uint256 fee = (totalYield * SCRAPE_PERCENTAGE) / 100;
        uint256 yieldAfterFee = totalYield - fee;

        _burn(msg.sender, amount);
        weETHContract.transfer(msg.sender, amount + yieldAfterFee);

        emit Redeemed(msg.sender, amount, totalYield, fee);
    }

    function _removeStake(address user, uint256 index) internal {
        require(index < userStakes[user].length, "Index out of bounds");

        // Move the last stake to the deleted position to maintain the array structure
        if (index < userStakes[user].length - 1) {
            userStakes[user][index] = userStakes[user][userStakes[user].length - 1];
        }

        userStakes[user].pop();
    }

    function getUserStakes(address user) external view returns (Stake[] memory) {
        return userStakes[user];
    }
}
