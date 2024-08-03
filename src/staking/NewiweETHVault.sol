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
    uint256 public constant MIN_DEPOSIT = 0.001 ether;

    struct Stake {
        uint256 userWeETHBalance;
        uint256 lastRecordedExchangeRate;
        uint256 accruedYield;
        uint256 lastUpdateTime;
        uint256 timeWeightedBalance;
    }

    mapping(address => Stake) public userStakes;

    uint256 public constant SCRAPE_PERCENTAGE = 10; // 10%

    event Deposited(address indexed user, uint256 amount, uint256 exchangeRate);
    event Redeemed(address indexed user, uint256 amount, uint256 yield, uint256 fee);

    constructor(address _weETHContract, address owner) ERC20("iWeETH", "iweETH") Ownable(owner) {
        weETHContract = WeETH(_weETHContract);
    }

    function deposit(uint256 amount) external {
        require(amount >= MIN_DEPOSIT, "Deposit amount is too low");

        uint256 exchangeRate = weETHContract.getRate();
        weETHContract.transferFrom(msg.sender, address(this), amount);

        Stake storage stake = userStakes[msg.sender];

        if (stake.userWeETHBalance > 0) {
            // Calculate and update accrued yield up to the point of the new deposit
            uint256 newAccruedYield =
                ((exchangeRate - stake.lastRecordedExchangeRate) * stake.userWeETHBalance) / 1 ether;
            stake.accruedYield += newAccruedYield;

            // Update TWAB
            _updateTWAB(msg.sender);
        }

        // Update the stake with the new deposit
        stake.userWeETHBalance += amount;
        stake.lastRecordedExchangeRate = exchangeRate;
        stake.lastUpdateTime = block.timestamp;

        _mint(msg.sender, amount);

        emit Deposited(msg.sender, amount, exchangeRate);
    }

    function redeem(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint256 currentExchangeRate = weETHContract.getRate();
        Stake storage stake = userStakes[msg.sender];

        // Calculate the total yield up to the point of redeeming
        uint256 newAccruedYield =
            ((currentExchangeRate - stake.lastRecordedExchangeRate) * stake.userWeETHBalance) / 1 ether;
        uint256 totalYield = stake.accruedYield + newAccruedYield;

        // Update TWAB
        _updateTWAB(msg.sender);

        // Calculate the proportion of the yield and fee based on the amount redeemed
        uint256 proportion = amount * 1 ether / stake.userWeETHBalance;
        uint256 yield = totalYield * proportion / 1 ether;
        uint256 fee = (yield * SCRAPE_PERCENTAGE) / 100;
        uint256 yieldAfterFee = yield - fee;

        // Update the stake amount and accrued yield
        stake.userWeETHBalance -= amount;
        stake.accruedYield = (totalYield - yield) * stake.userWeETHBalance / 1 ether;
        stake.lastRecordedExchangeRate = currentExchangeRate;
        stake.lastUpdateTime = block.timestamp;

        _burn(msg.sender, amount);
        weETHContract.transfer(msg.sender, amount + yieldAfterFee);
        weETHContract.transfer(owner(), fee);

        emit Redeemed(msg.sender, amount, yield, fee);
    }

    function _updateTWAB(address user) internal {
        Stake storage stake = userStakes[user];
        uint256 elapsedTime = block.timestamp - stake.lastUpdateTime;
        stake.timeWeightedBalance += stake.userWeETHBalance * elapsedTime;
        stake.lastUpdateTime = block.timestamp;
    }

    function getUserStake(address user) external view returns (Stake memory) {
        return userStakes[user];
    }

    function getUserTWAB(address user) external view returns (uint256) {
        Stake storage stake = userStakes[user];
        uint256 elapsedTime = block.timestamp - stake.lastUpdateTime;
        uint256 additionalTWAB = stake.userWeETHBalance * elapsedTime;
        return stake.timeWeightedBalance + additionalTWAB;
    }
}
