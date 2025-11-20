// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../config/PuddelConfig.sol";
import "../errors/PuddelErrors.sol";

library InputValidator {

    function validateAddress(address addr) internal pure {
        if (addr == address(0)) {
            revert PuddelErrors.InvalidAddress(addr);
        }
    }

    function validateAddressNotContract(address addr, address contractAddr) internal pure {
        if (addr == contractAddr) {
            revert PuddelErrors.InvalidAddress(addr);
        }
    }

    function validateAmount(uint256 amount) internal pure {
        if (amount == 0) {
            revert PuddelErrors.InvalidAmount(amount, 1, type(uint256).max);
        }
    }

    function validateAmountWithMax(uint256 amount, uint256 maxAmount) internal pure {
        if (amount == 0 || amount > maxAmount) {
            revert PuddelErrors.InvalidAmount(amount, 1, maxAmount);
        }
    }

    function validateMinAmount(uint256 amount, uint256 minAmount) internal pure {
        if (amount < minAmount) {
            revert PuddelErrors.InvalidAmount(amount, minAmount, type(uint256).max);
        }
    }

    function validateArrayLength(uint256 length, uint256 maxLength) internal pure {
        if (length == 0) {
            revert PuddelErrors.EmptyArray();
        }
        if (length > maxLength) {
            revert PuddelErrors.InvalidAmount(length, 1, maxLength);
        }
    }

    function validatePath(address[] memory path, uint256 maxLength) internal pure {
        if (path.length < 2 || path.length > maxLength) {
            revert PuddelErrors.InvalidPath(path.length, 2, maxLength);
        }
        
        for (uint i = 0; i < path.length; i++) {
            validateAddress(path[i]);
            
            // Check for duplicate addresses in path
            for (uint j = i + 1; j < path.length; j++) {
                if (path[i] == path[j]) {
                    revert PuddelErrors.DuplicateAddressInPath(path[i], i, j);
                }
            }
        }
    }

    function validateDeadline(uint256 deadline, uint256 maxExtension) internal view {
        if (deadline < block.timestamp) {
            revert PuddelErrors.DeadlineExpired(deadline, block.timestamp);
        }
        
        // Prevent extremely long deadlines (potential for manipulation)
        if (deadline > block.timestamp + maxExtension) {
            revert PuddelErrors.DeadlineExpired(deadline, block.timestamp);
        }
    }

    function validateSlippageAmounts(
        uint256 amountA,
        uint256 amountB, 
        uint256 amountAMin,
        uint256 amountBMin
    ) internal pure {
        if (amountAMin > amountA || amountBMin > amountB) {
            revert PuddelErrors.InsufficientLiquidityAmounts(amountA, amountB, amountAMin, amountBMin);
        }
        
        // Prevent 100% slippage (likely error)
        if (amountAMin == 0 && amountA > 0) {
            revert PuddelErrors.InvalidSlippage(0, 1);
        }
        if (amountBMin == 0 && amountB > 0) {
            revert PuddelErrors.InvalidSlippage(0, 1);
        }
    }

    function validateLiquidityAmounts(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 minLiquidity
    ) internal pure {
        validateAmount(amountADesired);
        validateAmount(amountBDesired);
        
        validateSlippageAmounts(amountADesired, amountBDesired, amountAMin, amountBMin);
        
        // Ensure minimum viable liquidity
        if (amountADesired < minLiquidity) {
            revert PuddelErrors.InvalidAmount(amountADesired, minLiquidity, type(uint256).max);
        }
        if (amountBDesired < minLiquidity) {
            revert PuddelErrors.InvalidAmount(amountBDesired, minLiquidity, type(uint256).max);
        }
    }

    function validateSwapAmounts(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        uint256 maxPathLength
    ) internal pure {
        validateAmount(amountIn);
        validatePath(path, maxPathLength);
        
        // amountOutMin can be 0 for maximum slippage tolerance
        // but we validate the path to prevent sandwich attacks
    }

    function validateArraysMatch(address[] memory array1, uint256[] memory array2) internal pure {
        if (array1.length != array2.length) {
            revert PuddelErrors.ArrayLengthMismatch(array1.length, array2.length);
        }
    }

    function validateTokenPair(address tokenA, address tokenB) internal pure {
        validateAddress(tokenA);
        validateAddress(tokenB);
        
        if (tokenA == tokenB) {
            revert PuddelErrors.InvalidAddress(tokenA);
        }
    }

    function validateRecipient(address to, address factory, address router) internal pure {
        validateAddress(to);
        validateAddressNotContract(to, factory);
        validateAddressNotContract(to, router);
    }
}