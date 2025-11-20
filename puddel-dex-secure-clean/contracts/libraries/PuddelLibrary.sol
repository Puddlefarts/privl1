// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '../interfaces/IPuddelPair.sol';
import '../interfaces/IPuddelFactory.sol';
import '../errors/PuddelErrors.sol';
import './SafeMath.sol';

library PuddelLibrary {
    using SafeMath for uint256;
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) {
            revert PuddelErrors.InvalidAddress(tokenA);
        }
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) {
            revert PuddelErrors.InvalidAddress(token0);
        }
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'1e9c06d49fc11e505ed2c4299a1eb8262f1d2ab19120a2d492682f5447155769' // init code hash
            )))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        address pair = IPuddelFactory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            return (0, 0);
        }
        (uint reserve0, uint reserve1,) = IPuddelPair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        if (amountA == 0) {
            revert PuddelErrors.InvalidAmount(amountA, 1, type(uint256).max);
        }
        if (reserveA == 0 || reserveB == 0) {
            revert PuddelErrors.InsufficientLiquidity(reserveA.safeAdd(reserveB), 1);
        }
        amountB = amountA.safeMulDiv(reserveB, reserveA);
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        if (amountIn == 0) {
            revert PuddelErrors.InsufficientInputAmount(amountIn, 1);
        }
        if (reserveIn == 0 || reserveOut == 0) {
            revert PuddelErrors.InsufficientLiquidity(reserveIn.safeAdd(reserveOut), 1);
        }
        uint amountInWithFee = amountIn.safeMul(997);
        uint numerator = amountInWithFee.safeMul(reserveOut);
        uint denominator = reserveIn.safeMul(1000).safeAdd(amountInWithFee);
        amountOut = numerator.safeDiv(denominator);
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        if (amountOut == 0) {
            revert PuddelErrors.InsufficientOutputAmount(amountOut, 1);
        }
        if (reserveIn == 0 || reserveOut == 0) {
            revert PuddelErrors.InsufficientLiquidity(reserveIn.safeAdd(reserveOut), 1);
        }
        uint numerator = reserveIn.safeMul(amountOut).safeMul(1000);
        uint denominator = reserveOut.safeSub(amountOut).safeMul(997);
        amountIn = numerator.safeDiv(denominator).safeIncrement();
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        if (path.length < 2) {
            revert PuddelErrors.InvalidPath(path.length, 2, type(uint256).max);
        }
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        if (path.length < 2) {
            revert PuddelErrors.InvalidPath(path.length, 2, type(uint256).max);
        }
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}