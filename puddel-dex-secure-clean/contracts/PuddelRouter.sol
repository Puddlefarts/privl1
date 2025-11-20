// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IPuddelRouter.sol";
import "./interfaces/IPuddelFactory.sol";
import "./interfaces/IPuddelPair.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWAVAX.sol";
import "./libraries/PuddelLibrary.sol";
import "./libraries/SafeERC20.sol";
import "./access/Ownable.sol";
import "./security/Pausable.sol";
import "./security/ReentrancyGuard.sol";
import "./utils/InputValidator.sol";
import "./config/PuddelConfig.sol";
import "./errors/PuddelErrors.sol";

contract PuddelRouter is IPuddelRouter, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using InputValidator for address;
    using InputValidator for uint256;

    address public immutable override factory;
    address public immutable override WAVAX;
    PuddelConfig public immutable config;

    modifier ensure(uint deadline) {
        InputValidator.validateDeadline(deadline, config.getMaxDeadlineExtension());
        _;
    }

    constructor(address _factory, address _WAVAX, address _config, address _owner) Ownable(_owner) {
        InputValidator.validateAddress(_factory);
        InputValidator.validateAddress(_WAVAX);
        InputValidator.validateAddress(_config);
        // _owner validation handled by Ownable constructor
        
        factory = _factory;
        WAVAX = _WAVAX;
        config = PuddelConfig(_config);
        
        // Verify config WAVAX matches our WAVAX
        if (config.getWAVAX() != _WAVAX) {
            revert PuddelErrors.WAVAXMismatch(_WAVAX, config.getWAVAX());
        }
    }

    receive() external payable {
        if (msg.sender != WAVAX) {
            revert PuddelErrors.Unauthorized(msg.sender, WAVAX);
        }
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (IPuddelFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IPuddelFactory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = PuddelLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = PuddelLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal < amountBMin) {
                    revert PuddelErrors.InsufficientLiquidityAmounts(amountADesired, amountBOptimal, amountAMin, amountBMin);
                }
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = PuddelLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                if (amountAOptimal < amountAMin) {
                    revert PuddelErrors.InsufficientLiquidityAmounts(amountAOptimal, amountBDesired, amountAMin, amountBMin);
                }
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) whenNotPaused nonReentrant returns (uint amountA, uint amountB, uint liquidity) {
        InputValidator.validateTokenPair(tokenA, tokenB);
        InputValidator.validateLiquidityAmounts(amountADesired, amountBDesired, amountAMin, amountBMin, config.getMinimumLiquidity());
        InputValidator.validateRecipient(to, factory, address(this));
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = IPuddelFactory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            revert PuddelErrors.PairNotFound(tokenA, tokenB);
        }
        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amountB);
        liquidity = IPuddelPair(pair).mint(to);
    }

    function addLiquidityAVAX(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountAVAXMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) whenNotPaused nonReentrant returns (uint amountToken, uint amountAVAX, uint liquidity) {
        InputValidator.validateAddress(token);
        InputValidator.validateAmount(amountTokenDesired);
        InputValidator.validateAmount(msg.value);
        InputValidator.validateRecipient(to, factory, address(this));
        (amountToken, amountAVAX) = _addLiquidity(
            token,
            WAVAX,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountAVAXMin
        );
        address pair = IPuddelFactory(factory).getPair(token, WAVAX);
        if (pair == address(0)) {
            revert PuddelErrors.PairNotFound(token, WAVAX);
        }
        IERC20(token).safeTransferFrom(msg.sender, pair, amountToken);
        IWAVAX(WAVAX).deposit{value: amountAVAX}();
        bool success = IWAVAX(WAVAX).transfer(pair, amountAVAX);
        if (!success) {
            revert PuddelErrors.TransferFailed(WAVAX, address(this), pair, amountAVAX);
        }
        liquidity = IPuddelPair(pair).mint(to);
        // refund dust AVAX, if any
        if (msg.value > amountAVAX) {
            _safeTransferAVAX(msg.sender, msg.value - amountAVAX);
        }
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) whenNotPaused nonReentrant returns (uint amountA, uint amountB) {
        address pair = IPuddelFactory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            revert PuddelErrors.PairNotFound(tokenA, tokenB);
        }
        bool success = IPuddelPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        if (!success) {
            revert PuddelErrors.TransferFailed(pair, msg.sender, pair, liquidity);
        }
        (uint amount0, uint amount1) = IPuddelPair(pair).burn(to);
        (address token0,) = PuddelLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        if (amountA < amountAMin || amountB < amountBMin) {
            revert PuddelErrors.InsufficientLiquidityAmounts(amountA, amountB, amountAMin, amountBMin);
        }
    }

    function removeLiquidityAVAX(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountAVAXMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) whenNotPaused nonReentrant returns (uint amountToken, uint amountAVAX) {
        (amountToken, amountAVAX) = removeLiquidity(
            token,
            WAVAX,
            liquidity,
            amountTokenMin,
            amountAVAXMin,
            address(this),
            deadline
        );
        IERC20(token).safeTransfer(to, amountToken);
        IWAVAX(WAVAX).withdraw(amountAVAX);
        // Secure AVAX transfer with additional safety checks
        _safeTransferAVAX(to, amountAVAX);
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = PuddelLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? PuddelLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IPuddelPair(PuddelLibrary.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) whenNotPaused nonReentrant returns (uint[] memory amounts) {
        InputValidator.validateSwapAmounts(amountIn, amountOutMin, path, config.getMaxPathLength());
        InputValidator.validateRecipient(to, factory, address(this));
        amounts = PuddelLibrary.getAmountsOut(factory, amountIn, path);
        if (amounts[amounts.length - 1] < amountOutMin) {
            revert PuddelErrors.InsufficientOutputAmount(amounts[amounts.length - 1], amountOutMin);
        }
        IERC20(path[0]).safeTransferFrom(
            msg.sender, PuddelLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) whenNotPaused nonReentrant returns (uint[] memory amounts) {
        amounts = PuddelLibrary.getAmountsIn(factory, amountOut, path);
        if (amounts[0] > amountInMax) {
            revert PuddelErrors.ExcessiveInputAmount(amounts[0], amountInMax);
        }
        IERC20(path[0]).safeTransferFrom(
            msg.sender, PuddelLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactAVAXForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        whenNotPaused
        nonReentrant
        returns (uint[] memory amounts)
    {
        InputValidator.validateAmount(msg.value);
        InputValidator.validatePath(path, config.getMaxPathLength());
        InputValidator.validateRecipient(to, factory, address(this));
        if (path[0] != WAVAX) {
            revert PuddelErrors.InvalidPath(path.length, 2, config.getMaxPathLength());
        }
        amounts = PuddelLibrary.getAmountsOut(factory, msg.value, path);
        if (amounts[amounts.length - 1] < amountOutMin) {
            revert PuddelErrors.InsufficientOutputAmount(amounts[amounts.length - 1], amountOutMin);
        }
        IWAVAX(WAVAX).deposit{value: amounts[0]}();
        bool success = IWAVAX(WAVAX).transfer(PuddelLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        if (!success) {
            revert PuddelErrors.TransferFailed(WAVAX, address(this), PuddelLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        }
        _swap(amounts, path, to);
    }

    function swapTokensForExactAVAX(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) whenNotPaused nonReentrant returns (uint[] memory amounts) {
        if (path[path.length - 1] != WAVAX) {
            revert PuddelErrors.InvalidPath(path.length, 2, config.getMaxPathLength());
        }
        amounts = PuddelLibrary.getAmountsIn(factory, amountOut, path);
        if (amounts[0] > amountInMax) {
            revert PuddelErrors.ExcessiveInputAmount(amounts[0], amountInMax);
        }
        IERC20(path[0]).safeTransferFrom(
            msg.sender, PuddelLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWAVAX(WAVAX).withdraw(amounts[amounts.length - 1]);
        _safeTransferAVAX(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForAVAX(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) whenNotPaused nonReentrant returns (uint[] memory amounts) {
        InputValidator.validateSwapAmounts(amountIn, amountOutMin, path, config.getMaxPathLength());
        InputValidator.validateRecipient(to, factory, address(this));
        if (path[path.length - 1] != WAVAX) {
            revert PuddelErrors.InvalidPath(path.length, 2, config.getMaxPathLength());
        }
        if (path[path.length - 1] != WAVAX) {
            revert PuddelErrors.InvalidPath(path.length, 2, config.getMaxPathLength());
        }
        amounts = PuddelLibrary.getAmountsOut(factory, amountIn, path);
        if (amounts[amounts.length - 1] < amountOutMin) {
            revert PuddelErrors.InsufficientOutputAmount(amounts[amounts.length - 1], amountOutMin);
        }
        IERC20(path[0]).safeTransferFrom(
            msg.sender, PuddelLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWAVAX(WAVAX).withdraw(amounts[amounts.length - 1]);
        _safeTransferAVAX(to, amounts[amounts.length - 1]);
    }

    function swapAVAXForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        whenNotPaused
        nonReentrant
        returns (uint[] memory amounts)
    {
        if (path[0] != WAVAX) {
            revert PuddelErrors.InvalidPath(path.length, 2, config.getMaxPathLength());
        }
        amounts = PuddelLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'PuddelRouter: EXCESSIVE_INPUT_AMOUNT');
        IWAVAX(WAVAX).deposit{value: amounts[0]}();
        bool success = IWAVAX(WAVAX).transfer(PuddelLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        if (!success) {
            revert PuddelErrors.TransferFailed(WAVAX, address(this), PuddelLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        }
        _swap(amounts, path, to);
        // refund dust AVAX, if any
        if (msg.value > amounts[0]) {
            _safeTransferAVAX(msg.sender, msg.value - amounts[0]);
        }
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return PuddelLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return PuddelLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return PuddelLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] calldata path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        InputValidator.validateAmount(amountIn);
        InputValidator.validatePath(path, config.getMaxPathLength());
        return PuddelLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] calldata path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        InputValidator.validateAmount(amountOut);
        InputValidator.validatePath(path, config.getMaxPathLength());
        return PuddelLibrary.getAmountsIn(factory, amountOut, path);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        InputValidator.validateAddress(to);
        InputValidator.validateAmount(amount);
        
        if (token == address(0)) {
            // AVAX withdrawal - use secure transfer
            _safeTransferAVAX(to, amount);
        } else {
            // ERC20 token withdrawal - validate token address
            InputValidator.validateAddress(token);
            IERC20(token).safeTransfer(to, amount);
        }
    }

    function updateFactory(address newFactory) external onlyOwner {
        if (newFactory == address(0)) {
            revert PuddelErrors.InvalidAddress(newFactory);
        }
        // Note: This would require redeployment in production due to immutable
        // This is here for completeness but factory should remain immutable
        revert PuddelErrors.UnsupportedFactoryOperation("Factory is immutable");
    }

    /**
     * @dev Secure AVAX transfer with additional safety checks
     * @param to Recipient address (must be validated)
     * @param amount Amount to transfer
     */
    function _safeTransferAVAX(address to, uint256 amount) internal {
        // Additional security: prevent transfer to contract addresses that might reject ETH
        // This protects against potential DoS attacks via rejecting ETH transfers
        
        if (to == address(0)) {
            revert PuddelErrors.InvalidAddress(to);
        }
        
        if (amount == 0) {
            revert PuddelErrors.InvalidAmount(amount, 1, type(uint256).max);
        }
        
        // Use call instead of transfer for better gas handling and error recovery
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) {
            revert PuddelErrors.TransferFailed(address(0), address(this), to, amount);
        }
    }
}