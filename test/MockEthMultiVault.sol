// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

/**
 * @title  MockEthMultiVault
 * @author 0xIntuition
 * @notice Mock contract used for simulating different share price growth scenarios.
 */
contract MockEthMultiVault {
    /// @notice Decimal precision used for calculations within the contract
    uint256 public constant decimalPrecision = 1e18;

    /// @notice Denominator used for calculating fees
    uint256 public constant feeDenominator = 10000;

    /// @notice Address of the DAO treasury
    address public treasury;

    /// @notice Total assets in the vault
    uint256 public assets;

    /// @notice Total supply of shares in the vault
    uint256 public supply;

    /// @notice Exponential denominator to control exponential growth scaling
    uint256 public expDenominator;

    /// @notice Minimum deposit amount required to deposit into the vault
    uint256 public minDeposit;

    /// @notice Protocol fee percentage
    uint256 public protocolFee;

    /// @notice Entry fee percentage
    uint256 public entryFee;

    /// @notice Exit fee percentage
    uint256 public exitFee;

    /// @notice Error throw when the deposit amount is less than the minimum deposit amount
    error InvalidMinDeposit();

    /// @notice Error throw when the user tries to redeem more shares than they have or when the amount of shares to redeem is zero
    error InvalidAmountOfSharesToRedeem();

    /// @notice Error throw when the transfer of ETH fails
    error EthTransferFailed();

    /// @notice Constructor for the MockEthMultiVault contract
    ///
    /// @param daoTreasury Address of the DAO treasury
    /// @param initialExpDenominator Initial exponential denominator for controlling growth scaling
    /// @param initialMinDeposit Initial minimum deposit amount required to deposit into the vault
    /// @param initialProtocolFee Initial protocol fee percentage
    /// @param initialEntryFee Initial entry fee percentage
    /// @param initialExitFee Initial exit fee percentage
    ///
    /// @dev Initializes the contract with the min share amount to prevent division by zero and inflation attacks
    constructor(
        address daoTreasury,
        uint256 initialExpDenominator,
        uint256 initialMinDeposit,
        uint256 initialProtocolFee,
        uint256 initialEntryFee,
        uint256 initialExitFee
    ) {
        treasury = daoTreasury;
        supply = 1; // minShare 
        expDenominator = initialExpDenominator;
        minDeposit = initialMinDeposit;
        protocolFee = initialProtocolFee;
        entryFee = initialEntryFee;
        exitFee = initialExitFee;
    }

    /// @notice Deposits ETH into the vault and mints shares to the user
    /// @return The amount of shares minted to the user
    function depositAtom() external payable returns (uint256) {
        if (msg.value < minDeposit) {
            revert InvalidMinDeposit();
        }

        uint256 userProtocolFee = _feeOnRawAmount(msg.value, protocolFee);
        uint256 userAssetsAfterProtocolFee = msg.value - userProtocolFee;

        uint256 userEntryFee;

        if (supply == 1) {
            userEntryFee = 0; // charge no entry fee for the first deposit
        } else {
            userEntryFee = _feeOnRawAmount(userAssetsAfterProtocolFee, entryFee);
        }

        uint256 userAssetsAfterTotalFese = userAssetsAfterProtocolFee - userEntryFee;

        uint256 userShares = convertToShares(userAssetsAfterTotalFese);

        assets += userAssetsAfterProtocolFee;
        supply += userShares;

        (bool success,) = treasury.call{value: userProtocolFee}("");
        if (!success) revert EthTransferFailed();

        return userShares;
    }

    /// @notice Redeems shares for ETH from the vault
    /// @param userShares The amount of shares to redeem
    /// @return The amount of ETH returned to the user
    function redeemAtom(uint256 userShares) external returns (uint256) {
        if (userShares == 0 || userShares > supply) {
            revert InvalidAmountOfSharesToRedeem();
        }

        if (supply - userShares < 1) {
            revert InvalidAmountOfSharesToRedeem();
        }

        uint256 remainingShares = supply - userShares;

        uint256 userAssetsBeforeFees = convertToAssets(userShares);

        uint256 userProtocolFee;
        uint256 userExitFee;

        if (remainingShares == 1) {
            exitFee = 0;
            protocolFee = _feeOnRawAmount(userAssetsBeforeFees, protocolFee);
        } else {
            protocolFee = _feeOnRawAmount(userAssetsBeforeFees, protocolFee);
            uint256 userAssetsAfterProtocolFee = userAssetsBeforeFees - protocolFee;
            userExitFee = _feeOnRawAmount(userAssetsAfterProtocolFee, exitFee);
        }

        uint256 userAssetsAfterTotalFees = userAssetsBeforeFees - protocolFee - userExitFee;

        assets -= (userAssetsAfterTotalFees + userProtocolFee);
        supply -= userShares;

        (bool success,) = payable(msg.sender).call{value: userAssetsAfterTotalFees}("");
        if (!success) revert EthTransferFailed();

        (bool success2,) = treasury.call{value: userProtocolFee}("");
        if (!success2) revert EthTransferFailed();

        return userAssetsAfterTotalFees;
    }

    /// @notice Sets the DAO treasury address
    /// @param newTreasury New DAO treasury address
    function setTreasury(address newTreasury) external {
        treasury = newTreasury;
    }

    /// @notice Sets the exponential denominator for controlling growth scaling
    /// @param newExpDenominator New value for the exponential denominator
    function setExpDenominator(uint256 newExpDenominator) external {
        expDenominator = newExpDenominator;
    }

    /// @notice Sets the minimum deposit amount required to deposit into the vault
    /// @param newMinDeposit New minimum deposit amount
    function setMinDeposit(uint256 newMinDeposit) external {
        minDeposit = newMinDeposit;
    }

    /// @notice Sets the protocol fee percentage
    /// @param newProtocolFee New protocol fee percentage
    function setProtocolFee(uint256 newProtocolFee) external {
        protocolFee = newProtocolFee;
    }

    /// @notice Sets the entry fee percentage
    /// @param newEntryFee New entry fee percentage
    function setEntryFee(uint256 newEntryFee) external {
        entryFee = newEntryFee;
    }

    /// @notice Sets the exit fee percentage
    /// @param newExitFee New exit fee percentage
    function setExitFee(uint256 newExitFee) external {
        exitFee = newExitFee;
    }

    /// @notice Calculates the current share price based on the total assets and supply of shares in the vault
    /// @dev Uses a linear formula when assets <= 1 ETH, and a customizable formula when assets > 1 ETH
    function currentSharePrice() external view virtual returns (uint256) {
        uint256 price;

        // Linear growth formula when assets <= 1 ETH
        if (assets <= 1e18) {
            price = (assets * decimalPrecision) / supply;
        }
        // Customizable growth formula when assets > 1 ETH
        else {
            uint256 expPart = (assets * sqrt(assets)) / expDenominator;
            price = (expPart * decimalPrecision) / supply;
        }

        return price;
    }

    /// @notice Converts the deposited assets into shares based on the current share price
    /// @param depositedAssets The amount of assets to convert into shares
    function convertToShares(uint256 depositedAssets) public view virtual returns (uint256) {
        uint256 userShares;

        if (assets <= 1e18) {
            userShares = (depositedAssets * supply) / assets;
        } else {
            uint256 expPart = (assets * sqrt(assets)) / expDenominator;
            userShares = (depositedAssets * supply) / expPart;
        }

        return userShares;
    }

    /// @notice Converts the user shares into assets based on the current share price
    /// @param userShares The amount of shares to convert into assets
    function convertToAssets(uint256 userShares) public view virtual returns (uint256) {
        uint256 userAssets;

        if (assets <= 1e18) {
            userAssets = (userShares * assets) / supply;
        } else {
            uint256 expPart = (assets * sqrt(assets)) / expDenominator;
            userAssets = (userShares * expPart) / supply;
        }

        return userAssets;
    }

    /// @dev Integer square root function (Babylonian method)
    /// @param x Input value to compute the square root of
    /// @return The integer square root of the input value
    function sqrt(uint256 x) public pure returns (uint256) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        uint256 y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }

        return z;
    }

    /// @notice Calculates the fee on a given amount based on the fee percentage
    /// @param amount The amount to calculate the fee on
    /// @param fee The fee percentage to apply
    function _feeOnRawAmount(uint256 amount, uint256 fee) internal pure returns (uint256) {
        return (amount * fee) / feeDenominator;
    }
}
