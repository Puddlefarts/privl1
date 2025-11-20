// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../errors/PuddelErrors.sol";

/**
 * @title SafeMath
 * @dev Comprehensive safe mathematical operations library with overflow/underflow protection
 * @notice Enhanced version with custom errors and gas optimizations for Solidity 0.8+
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on overflow.
     * @param a First operand
     * @param b Second operand
     * @return result The sum of a and b
     */
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256 result) {
        unchecked {
            result = a + b;
            if (result < a) {
                revert PuddelErrors.IntegerOverflow(result, type(uint256).max);
            }
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on underflow.
     * @param a Minuend
     * @param b Subtrahend  
     * @return result The difference of a and b
     */
    function safeSub(uint256 a, uint256 b) internal pure returns (uint256 result) {
        if (b > a) {
            revert PuddelErrors.IntegerUnderflow(a, b);
        }
        unchecked {
            result = a - b;
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     * @param a First factor
     * @param b Second factor
     * @return result The product of a and b
     */
    function safeMul(uint256 a, uint256 b) internal pure returns (uint256 result) {
        if (a == 0) {
            return 0;
        }
        
        unchecked {
            result = a * b;
            if (result / a != b) {
                revert PuddelErrors.IntegerOverflow(result, type(uint256).max);
            }
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on division by zero.
     * @param a Dividend
     * @param b Divisor
     * @return result The quotient of a and b
     */
    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256 result) {
        if (b == 0) {
            revert PuddelErrors.DivisionByZero();
        }
        result = a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, reverting on division by zero.
     * @param a Dividend
     * @param b Divisor
     * @return result The remainder of a divided by b
     */
    function safeMod(uint256 a, uint256 b) internal pure returns (uint256 result) {
        if (b == 0) {
            revert PuddelErrors.DivisionByZero();
        }
        result = a % b;
    }

    /**
     * @dev Returns the square root of a number, reverting if the input is invalid.
     * @param a The number to find the square root of
     * @return result The square root of a
     */
    function safeSqrt(uint256 a) internal pure returns (uint256 result) {
        if (a == 0) {
            return 0;
        }
        
        // For large numbers, use the Babylonian method with overflow protection
        if (a > 3) {
            result = a;
            uint256 x = safeDiv(safeAdd(a, 1), 2);
            while (x < result) {
                result = x;
                x = safeDiv(safeAdd(safeDiv(a, x), x), 2);
            }
        } else {
            result = 1;
        }
        
        // Verify the result is correct
        if (safeMul(result, result) > a || safeMul(safeAdd(result, 1), safeAdd(result, 1)) <= a) {
            revert PuddelErrors.SquareRootFailed(a);
        }
    }

    /**
     * @dev Returns the minimum of two numbers.
     * @param a First number
     * @param b Second number
     * @return The smaller of a and b
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the maximum of two numbers.
     * @param a First number
     * @param b Second number
     * @return The larger of a and b
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Safe casting from uint256 to uint112, reverting on overflow.
     * @param value The value to cast
     * @return The value cast to uint112
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        if (value > type(uint112).max) {
            revert PuddelErrors.IntegerOverflow(value, type(uint112).max);
        }
        return uint112(value);
    }

    /**
     * @dev Safe casting from uint256 to uint32, reverting on overflow.
     * @param value The value to cast
     * @return The value cast to uint32
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        if (value > type(uint32).max) {
            revert PuddelErrors.IntegerOverflow(value, type(uint32).max);
        }
        return uint32(value);
    }

    /**
     * @dev Safely calculates percentage with overflow protection.
     * @param amount The base amount
     * @param percentage The percentage (in basis points, e.g., 250 = 2.5%)
     * @param basisPoints The basis points divisor (typically 10000 for percentages)
     * @return result The calculated percentage amount
     */
    function safePercentage(uint256 amount, uint256 percentage, uint256 basisPoints) internal pure returns (uint256 result) {
        if (basisPoints == 0) {
            revert PuddelErrors.DivisionByZero();
        }
        
        // Use mulDiv to prevent intermediate overflow
        result = safeMulDiv(amount, percentage, basisPoints);
    }

    /**
     * @dev Safely multiplies two numbers and divides by a third, preventing intermediate overflow.
     * @param a First factor
     * @param b Second factor
     * @param c Divisor
     * @return result The result of (a * b) / c
     */
    function safeMulDiv(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 result) {
        if (c == 0) {
            revert PuddelErrors.DivisionByZero();
        }
        
        // Handle simple cases
        if (a == 0 || b == 0) {
            return 0;
        }
        
        // Check for potential overflow in multiplication
        if (a <= type(uint256).max / b) {
            // No overflow risk, use standard calculation
            result = (a * b) / c;
        } else {
            // Risk of overflow, use alternative calculation
            // This uses the identity: (a * b) / c = a * (b / c) + (a * (b % c)) / c
            uint256 quotient = b / c;
            uint256 remainder = b % c;
            
            result = safeMul(a, quotient);
            if (remainder > 0) {
                result = safeAdd(result, safeDiv(safeMul(a, remainder), c));
            }
        }
    }

    /**
     * @dev Safely calculates the average of two numbers, preventing overflow.
     * @param a First number
     * @param b Second number
     * @return The average of a and b
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we use (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2)
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }

    /**
     * @dev Safely calculates compound interest with overflow protection.
     * @param principal The principal amount
     * @param rate The interest rate per period (in basis points)
     * @param periods The number of periods
     * @param basisPoints The basis points divisor
     * @return result The final amount after compound interest
     */
    function safeCompoundInterest(
        uint256 principal,
        uint256 rate,
        uint256 periods,
        uint256 basisPoints
    ) internal pure returns (uint256 result) {
        if (periods == 0) {
            return principal;
        }
        
        result = principal;
        
        for (uint256 i = 0; i < periods; i++) {
            uint256 interest = safePercentage(result, rate, basisPoints);
            result = safeAdd(result, interest);
        }
    }

    /**
     * @dev Safely calculates the absolute difference between two numbers.
     * @param a First number
     * @param b Second number
     * @return The absolute difference between a and b
     */
    function absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    /**
     * @dev Checks if addition would overflow.
     * @param a First operand
     * @param b Second operand
     * @return true if addition would overflow
     */
    function wouldOverflowAdd(uint256 a, uint256 b) internal pure returns (bool) {
        return a > type(uint256).max - b;
    }

    /**
     * @dev Checks if multiplication would overflow.
     * @param a First factor
     * @param b Second factor
     * @return true if multiplication would overflow
     */
    function wouldOverflowMul(uint256 a, uint256 b) internal pure returns (bool) {
        if (a == 0) return false;
        return b > type(uint256).max / a;
    }

    /**
     * @dev Safely increments a value by 1, reverting on overflow.
     * @param a The value to increment
     * @return The incremented value
     */
    function safeIncrement(uint256 a) internal pure returns (uint256) {
        if (a == type(uint256).max) {
            revert PuddelErrors.IntegerOverflow(a, type(uint256).max);
        }
        return a + 1;
    }

    /**
     * @dev Safely decrements a value by 1, reverting on underflow.
     * @param a The value to decrement
     * @return The decremented value
     */
    function safeDecrement(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            revert PuddelErrors.IntegerUnderflow(a, 1);
        }
        return a - 1;
    }
}