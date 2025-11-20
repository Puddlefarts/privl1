// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRouter {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
}

interface IERC20Simple {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract MaliciousReentrant {
    IRouter public router;
    bool public attacking = false;
    
    constructor(address _router) {
        router = IRouter(_router);
    }
    
    function attemptReentrantAddLiquidity(
        address tokenA,
        address tokenB,
        uint amount,
        uint amount2,
        uint deadline
    ) external {
        IERC20Simple(tokenA).approve(address(router), amount * 2);
        IERC20Simple(tokenB).approve(address(router), amount2 * 2);
        
        attacking = true;
        router.addLiquidity(tokenA, tokenB, amount, amount2, 0, 0, address(this), deadline);
    }
    
    function attemptReentrantSwap(
        uint amountIn,
        address[] calldata path,
        uint deadline
    ) external {
        IERC20Simple(path[0]).approve(address(router), amountIn * 2);
        
        attacking = true;
        router.swapExactTokensForTokens(amountIn, 0, path, address(this), deadline);
    }
    
    function attemptReentrantRemoveLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint deadline
    ) external {
        attacking = true;
        router.removeLiquidity(tokenA, tokenB, liquidity, 0, 0, address(this), deadline);
    }
    
    function attemptCrossFunctionReentrancy(
        address tokenA,
        address tokenB,
        uint amount,
        uint deadline
    ) external {
        IERC20Simple(tokenA).approve(address(router), amount * 2);
        IERC20Simple(tokenB).approve(address(router), amount * 2);
        
        attacking = true;
        router.addLiquidity(tokenA, tokenB, amount, amount, 0, 0, address(this), deadline);
    }
    
    // This function would be called during token transfer to attempt reentrancy
    receive() external payable {
        if (attacking) {
            attacking = false;
            // Try to call router again - this should fail with reentrancy guard
            address[] memory path = new address[](2);
            path[0] = address(0); // This will fail anyway, but tests the reentrancy
            path[1] = address(0);
            router.swapExactTokensForTokens(1000, 0, path, address(this), block.timestamp + 3600);
        }
    }
}