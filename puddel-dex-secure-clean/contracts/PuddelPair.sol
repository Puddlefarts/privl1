// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IERC20.sol";
import "./interfaces/IPuddelPair.sol";
import "./interfaces/IPuddelFactory.sol";
import "./errors/PuddelErrors.sol";
import "./libraries/SafeMath.sol";
import "./security/ReentrancyGuard.sol";

contract PuddelPair is IPuddelPair, ReentrancyGuard {
    using SafeMath for uint256;
    string public constant name = 'PuddelPair LP';
    string public constant symbol = 'PLP';
    uint8 public constant decimals = 18;

    // Swap fee configuration: 0.25% (25 basis points)
    uint16 public constant FEE_BPS = 25;
    uint16 public constant FEE_DENOM = 10000;
    
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    
    address public factory;
    address public token0;
    address public token1;
    
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;
    
    uint public constant MINIMUM_LIQUIDITY = 1000;
    
    // Events are inherited from interface
    
    // Removed custom lock - using OpenZeppelin ReentrancyGuard instead
    
    constructor() {
        factory = msg.sender;
    }
    
    function initialize(address _token0, address _token1) external {
        if (msg.sender != factory) {
            revert PuddelErrors.Forbidden(msg.sender);
        }
        token0 = _token0;
        token1 = _token1;
    }
    
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }
    
    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.safeAdd(value);
        balanceOf[to] = balanceOf[to].safeAdd(value);
        emit Transfer(address(0), to, value);
    }
    
    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].safeSub(value);
        totalSupply = totalSupply.safeSub(value);
        emit Transfer(from, address(0), value);
    }
    
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        if (balance0 > type(uint112).max) {
            revert PuddelErrors.IntegerOverflow(balance0, type(uint112).max);
        }
        if (balance1 > type(uint112).max) {
            revert PuddelErrors.IntegerOverflow(balance1, type(uint112).max);
        }
        // Secure timestamp handling - prevents overflow and maintains consistency
        uint32 blockTimestamp = SafeMath.toUint32(block.timestamp & 0xFFFFFFFF);
        reserve0 = SafeMath.toUint112(balance0);
        reserve1 = SafeMath.toUint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // Protocol fee: if feeTo is set, mint liquidity to feeTo based on growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IPuddelFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = SafeMath.safeSqrt(uint(_reserve0).safeMul(uint(_reserve1)));
                uint rootKLast = SafeMath.safeSqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply.safeMul(rootK.safeSub(rootKLast));
                    // denominator = (rootK * 5) + rootKLast means we take 1/6 of the growth
                    // This gives ~0.05% protocol fee on the 0.25% swap fee
                    uint denominator = rootK.safeMul(5).safeAdd(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
        return feeOn;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert PuddelErrors.TransferFailed(token, address(this), to, value);
        }
    }
    
    // MINT FUNCTION WITH BUG FIX
    function mint(address to) external nonReentrant returns (uint liquidity) {
        if (to == address(0)) {
            revert PuddelErrors.InvalidAddress(to);
        }

        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0.safeSub(_reserve0);
        uint amount1 = balance1.safeSub(_reserve1);

        // Mint protocol fee if enabled
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply <= MINIMUM_LIQUIDITY) {
            liquidity = amount0.safeMul(amount1).safeSqrt().safeSub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            uint256 liquidity0 = amount0.safeMulDiv(_totalSupply, _reserve0);
            uint256 liquidity1 = amount1.safeMulDiv(_totalSupply, _reserve1);
            liquidity = SafeMath.min(liquidity0, liquidity1);
        }
        if (liquidity <= 0) {
            revert PuddelErrors.InsufficientLiquidityMinted(liquidity, 1);
        }
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).safeMul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // BURN FUNCTION FOR REMOVING LIQUIDITY
    function burn(address to) external nonReentrant returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

        // Mint protocol fee if enabled
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.safeMulDiv(balance0, _totalSupply); // using balances ensures pro-rata distribution
        amount1 = liquidity.safeMulDiv(balance1, _totalSupply); // using balances ensures pro-rata distribution
        if (amount0 <= 0 || amount1 <= 0) {
            revert PuddelErrors.InsufficientLiquidityToBurn(liquidity, _totalSupply);
        }
        _burn(address(this), liquidity);

        // Update reserves BEFORE external calls to prevent reentrancy
        balance0 = balance0.safeSub(amount0);
        balance1 = balance1.safeSub(amount1);
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).safeMul(reserve1); // reserve0 and reserve1 are up-to-date

        // External calls AFTER state updates
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // SWAP FUNCTION - CORE AMM FUNCTIONALITY (REENTRANCY-SAFE)
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external nonReentrant {
        if (amount0Out == 0 && amount1Out == 0) {
            revert PuddelErrors.InsufficientOutputAmount(amount0Out + amount1Out, 1);
        }
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        if (amount0Out >= _reserve0 || amount1Out >= _reserve1) {
            revert PuddelErrors.InsufficientLiquidity(_reserve0 + _reserve1, amount0Out + amount1Out);
        }

        address _token0 = token0;
        address _token1 = token1;
        if (to == _token0 || to == _token1) {
            revert PuddelErrors.InvalidAddress(to);
        }

        // STEP 1: Get current balances BEFORE any external calls
        uint balance0Before = IERC20(_token0).balanceOf(address(this));
        uint balance1Before = IERC20(_token1).balanceOf(address(this));
        
        // Calculate expected amounts in based on current balances vs reserves
        uint256 reserve0AfterOut = uint256(_reserve0).safeSub(amount0Out);
        uint256 reserve1AfterOut = uint256(_reserve1).safeSub(amount1Out);
        uint amount0In = balance0Before > reserve0AfterOut ? balance0Before.safeSub(reserve0AfterOut) : 0;
        uint amount1In = balance1Before > reserve1AfterOut ? balance1Before.safeSub(reserve1AfterOut) : 0;
        
        if (amount0In <= 0 && amount1In <= 0) {
            revert PuddelErrors.InsufficientInputAmount(amount0In.safeAdd(amount1In), 1);
        }

        // STEP 2: Validate K invariant BEFORE external calls (using expected post-transfer balances)
        uint expectedBalance0 = balance0Before.safeSub(amount0Out);
        uint expectedBalance1 = balance1Before.safeSub(amount1Out);
        
        uint balance0Adjusted = expectedBalance0.safeMul(FEE_DENOM).safeSub(amount0In.safeMul(FEE_BPS));
        uint balance1Adjusted = expectedBalance1.safeMul(FEE_DENOM).safeSub(amount1In.safeMul(FEE_BPS));
        uint256 currentK = balance0Adjusted.safeMul(balance1Adjusted);
        uint256 requiredK = uint(_reserve0).safeMul(_reserve1).safeMul(uint256(FEE_DENOM).safeMul(FEE_DENOM));
        if (currentK < requiredK) {
            revert PuddelErrors.KInvariantViolated(currentK, requiredK);
        }

        // STEP 3: External calls (potential reentrancy point - but state already validated)
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
        
        // STEP 4: Update state variables (CEI pattern - Effects after Interactions)
        uint balance0After = IERC20(_token0).balanceOf(address(this));
        uint balance1After = IERC20(_token1).balanceOf(address(this));
        _update(balance0After, balance1After, _reserve0, _reserve1);
        
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external nonReentrant {
        address _token0 = token0;
        address _token1 = token1;
        uint256 token0Balance = IERC20(_token0).balanceOf(address(this));
        uint256 token1Balance = IERC20(_token1).balanceOf(address(this));
        _safeTransfer(_token0, to, token0Balance.safeSub(reserve0));
        _safeTransfer(_token1, to, token1Balance.safeSub(reserve1));
    }

    // force reserves to match balances
    function sync() external nonReentrant {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    // ERC20 FUNCTIONS
    function approve(address spender, uint value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        if (to == address(0)) {
            revert PuddelErrors.InvalidAddress(to);
        }
        if (balanceOf[msg.sender] < value) {
            revert PuddelErrors.InsufficientBalance(balanceOf[msg.sender], value);
        }
        balanceOf[msg.sender] = balanceOf[msg.sender].safeSub(value);
        balanceOf[to] = balanceOf[to].safeAdd(value);
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (to == address(0)) {
            revert PuddelErrors.InvalidAddress(to);
        }
        if (balanceOf[from] < value) {
            revert PuddelErrors.InsufficientBalance(balanceOf[from], value);
        }
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance != type(uint).max) {
            if (currentAllowance < value) {
                revert PuddelErrors.InsufficientAllowance(currentAllowance, value);
            }
            allowance[from][msg.sender] = allowance[from][msg.sender].safeSub(value);
        }
        balanceOf[from] = balanceOf[from].safeSub(value);
        balanceOf[to] = balanceOf[to].safeAdd(value);
        emit Transfer(from, to, value);
        return true;
    }

    // NOTE: sqrt and min functions are now provided by SafeMath library

    // Missing interface functions (minimal implementations)
    bytes32 public constant DOMAIN_SEPARATOR = keccak256("PuddelPair");
    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    
    mapping(address => uint) public nonces;
    uint public kLast;
    uint public price0CumulativeLast;
    uint public price1CumulativeLast;

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        if (deadline < block.timestamp) {
            revert PuddelErrors.DeadlineExpired(deadline, block.timestamp);
        }
        if (owner == address(0)) {
            revert PuddelErrors.InvalidAddress(owner);
        }
        
        uint currentValidNonce = nonces[owner];
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, currentValidNonce, deadline))
            )
        );
        
        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress != owner) {
            revert PuddelErrors.InvalidSignature(owner, recoveredAddress);
        }
        
        nonces[owner] = currentValidNonce.safeIncrement();
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }
}