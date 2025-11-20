// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../libraries/SafeMath.sol";
import "../errors/PuddelErrors.sol";

/**
 * @title TestSafeMath
 * @dev Test contract to expose SafeMath library functions for testing
 */
contract TestSafeMath {
    using SafeMath for uint256;

    // Test addition
    function testSafeAdd(uint256 a, uint256 b) external pure returns (uint256) {
        return a.safeAdd(b);
    }

    // Test subtraction
    function testSafeSub(uint256 a, uint256 b) external pure returns (uint256) {
        return a.safeSub(b);
    }

    // Test multiplication
    function testSafeMul(uint256 a, uint256 b) external pure returns (uint256) {
        return a.safeMul(b);
    }

    // Test division
    function testSafeDiv(uint256 a, uint256 b) external pure returns (uint256) {
        return a.safeDiv(b);
    }

    // Test modulo
    function testSafeMod(uint256 a, uint256 b) external pure returns (uint256) {
        return a.safeMod(b);
    }

    // Test square root
    function testSafeSqrt(uint256 a) external pure returns (uint256) {
        return a.safeSqrt();
    }

    // Test multiply and divide
    function testSafeMulDiv(uint256 a, uint256 b, uint256 c) external pure returns (uint256) {
        return a.safeMulDiv(b, c);
    }

    // Test percentage calculation
    function testSafePercentage(uint256 amount, uint256 percentage, uint256 basisPoints) external pure returns (uint256) {
        return SafeMath.safePercentage(amount, percentage, basisPoints);
    }

    // Test type casting
    function testToUint112(uint256 value) external pure returns (uint112) {
        return SafeMath.toUint112(value);
    }

    function testToUint32(uint256 value) external pure returns (uint32) {
        return SafeMath.toUint32(value);
    }

    // Test increment/decrement
    function testSafeIncrement(uint256 a) external pure returns (uint256) {
        return a.safeIncrement();
    }

    function testSafeDecrement(uint256 a) external pure returns (uint256) {
        return a.safeDecrement();
    }

    // Test overflow detection
    function testWouldOverflowAdd(uint256 a, uint256 b) external pure returns (bool) {
        return SafeMath.wouldOverflowAdd(a, b);
    }

    function testWouldOverflowMul(uint256 a, uint256 b) external pure returns (bool) {
        return SafeMath.wouldOverflowMul(a, b);
    }

    // Test utility functions
    function testMin(uint256 a, uint256 b) external pure returns (uint256) {
        return SafeMath.min(a, b);
    }

    function testMax(uint256 a, uint256 b) external pure returns (uint256) {
        return SafeMath.max(a, b);
    }

    function testAverage(uint256 a, uint256 b) external pure returns (uint256) {
        return SafeMath.average(a, b);
    }

    function testAbsDiff(uint256 a, uint256 b) external pure returns (uint256) {
        return SafeMath.absDiff(a, b);
    }

    // Test compound interest
    function testSafeCompoundInterest(
        uint256 principal,
        uint256 rate,
        uint256 periods,
        uint256 basisPoints
    ) external pure returns (uint256) {
        return SafeMath.safeCompoundInterest(principal, rate, periods, basisPoints);
    }

    // Test real-world AMM calculations similar to what PuddelPair uses
    function testAMMCalculation(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut) {
        // This simulates the getAmountOut calculation with fee
        uint256 amountInWithFee = amountIn.safeMul(997);
        uint256 numerator = amountInWithFee.safeMul(reserveOut);
        uint256 denominator = reserveIn.safeMul(1000).safeAdd(amountInWithFee);
        amountOut = numerator.safeDiv(denominator);
    }

    // Test liquidity calculation similar to PuddelPair
    function testLiquidityCalculation(
        uint256 amount0,
        uint256 amount1,
        uint256 totalSupply,
        uint256 reserve0,
        uint256 reserve1
    ) external pure returns (uint256 liquidity) {
        if (totalSupply == 0) {
            // Initial liquidity
            liquidity = amount0.safeMul(amount1).safeSqrt().safeSub(1000); // MINIMUM_LIQUIDITY
        } else {
            // Subsequent liquidity
            uint256 liquidity0 = amount0.safeMulDiv(totalSupply, reserve0);
            uint256 liquidity1 = amount1.safeMulDiv(totalSupply, reserve1);
            liquidity = SafeMath.min(liquidity0, liquidity1);
        }
    }

    // Test K invariant calculation
    function testKInvariant(
        uint256 balance0,
        uint256 balance1,
        uint256 amount0In,
        uint256 amount1In
    ) external pure returns (uint256 k) {
        uint256 balance0Adjusted = balance0.safeMul(1000).safeSub(amount0In.safeMul(3));
        uint256 balance1Adjusted = balance1.safeMul(1000).safeSub(amount1In.safeMul(3));
        k = balance0Adjusted.safeMul(balance1Adjusted);
    }

    // Test edge case with maximum values
    function testMaxValueOperations() external pure returns (bool) {
        uint256 maxUint = type(uint256).max;
        
        // These should not revert
        uint256 halfMax = maxUint / 2;
        halfMax.safeAdd(halfMax); // Should equal maxUint - 1
        
        maxUint.safeSub(1);
        maxUint.safeDiv(2);
        
        return true;
    }
}