// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

// Usage: `using StringUtils for uint256;`
// Usage: string memory str = (1e18).wadToString(3);
// Usage: console.log(str);
library StringUtils {
    /// @notice Converts a number to scientific notation with specified decimal places
    /// @param value The number to convert
    /// @param decimals Number of decimal places to show
    /// @return string The formatted string (e.g., "1.57e77")
    function toStringDecimals(uint256 value, uint8 decimals) internal pure returns (string memory) {
        if (value == 0) return "0";

        // Count number of digits before decimal
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        // Calculate exponent
        int256 exponent = int256(digits - 1);

        // Calculate the first digit and the decimals
        uint256 firstDigit = value / (10 ** (digits - 1));
        uint256 remainingDigits = value % (10 ** (digits - 1));

        // Scale remaining digits to desired decimal places
        uint256 scale = 10 ** decimals;
        remainingDigits = (remainingDigits * scale) / (10 ** (digits - 1));

        // Round to nearest decimal
        uint256 roundingCheck = (remainingDigits * 10) / scale;
        if (roundingCheck % 10 >= 5) {
            remainingDigits += 1;
            // Handle carrying over
            if (remainingDigits >= scale) {
                firstDigit += 1;
                remainingDigits = 0;
            }
        }

        // Convert first digit to string
        string memory firstPart = uint256ToString(firstDigit);

        // If no decimals requested or remaining digits are 0
        if (decimals == 0 || remainingDigits == 0) {
            return string.concat(firstPart, "e", int256ToString(exponent));
        }

        // Convert remaining digits to string with leading zeros
        string memory decimalPart = uint256ToString(remainingDigits);
        uint256 decimalLength = bytes(decimalPart).length;

        // Add leading zeros if needed
        string memory zeros = "";
        for (uint8 i = 0; i < decimals - decimalLength; i++) {
            zeros = string.concat(zeros, "0");
        }

        return string.concat(firstPart, ".", zeros, decimalPart, "e", int256ToString(exponent));
    }

    /// @notice Converts a uint256 to its string representation
    /// @param value The number to convert
    /// @return string The string representation
    function uint256ToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);

        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    /// @notice Converts an int256 to its string representation
    /// @param value The number to convert
    /// @return string The string representation
    function int256ToString(int256 value) internal pure returns (string memory) {
        if (value < 0) {
            return string.concat("-", uint256ToString(uint256(-value)));
        }
        return uint256ToString(uint256(value));
    }

    /// @notice Converts a number to a string with 2 decimal places
    /// @param value The number to convert
    /// @return string The formatted string (e.g., "1.57e18")
    function toString(uint256 value) internal pure returns (string memory) {
        return toStringDecimals(value, 2);
    }

    /// @notice Converts a ratio to a percentage string with up to 6 decimal places
    /// @param numerator The top number
    /// @param denominator The bottom number
    /// @return string The percentage (e.g., "50%" or "0.000001%")
    function toPercentage(uint256 numerator, uint256 denominator) internal pure returns (string memory) {
        if (denominator == 0) return "undefined%";
        if (numerator == 0) return "0%";

        // Compute with 6 decimal places of precision (1_000_000)
        uint256 scaledNumerator = numerator * 100_000_000;
        uint256 percentage = scaledNumerator / denominator;

        // If it's a whole number
        if (percentage % 1_000_000 == 0) {
            return string.concat(uint256ToString(percentage / 1_000_000), "%");
        }

        // Convert to string parts
        uint256 wholePart = percentage / 1_000_000;
        uint256 decimalPart = percentage % 1_000_000;

        // Trim trailing zeros from decimal part
        while (decimalPart > 0 && decimalPart % 10 == 0) {
            decimalPart /= 10;
        }

        // If there's no whole part, handle special case for small numbers
        if (wholePart == 0) {
            // Add leading zeros as needed
            uint256 leadingZeros = 0;
            uint256 tempDecimal = decimalPart;
            while (tempDecimal < 100_000 && tempDecimal > 0) {
                leadingZeros++;
                tempDecimal *= 10;
            }

            string memory zeros = "";
            for (uint256 i = 0; i < leadingZeros; i++) {
                zeros = string.concat(zeros, "0");
            }

            return string.concat("0.", zeros, uint256ToString(decimalPart), "%");
        }

        // Regular case with whole number and decimals
        return string.concat(uint256ToString(wholePart), ".", uint256ToString(decimalPart), "%");
    }
}
