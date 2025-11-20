// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IPuddelFactory.sol";
import "./PuddelPair.sol";
import "./access/Ownable.sol";
import "./security/Pausable.sol";
import "./security/ReentrancyGuard.sol";
import "./utils/InputValidator.sol";
import "./errors/PuddelErrors.sol";

contract PuddelFactory is IPuddelFactory, Ownable, Pausable, ReentrancyGuard {
    using InputValidator for address;
    using InputValidator for uint256;
    bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(PuddelPair).creationCode));

    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    // Event is inherited from interface

    constructor(address _feeToSetter) Ownable(_feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override whenNotPaused nonReentrant returns (address pair) {
        InputValidator.validateTokenPair(tokenA, tokenB);
        
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (getPair[token0][token1] != address(0)) {
            revert PuddelErrors.PairAlreadyExists(token0, token1, getPair[token0][token1]);
        }
        
        bytes memory bytecode = type(PuddelPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        // Update state BEFORE external call to prevent reentrancy
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        
        // External call AFTER state updates
        IPuddelPair(pair).initialize(token0, token1);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override onlyOwner {
        // _feeTo can be zero address to disable fees
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override onlyOwner {
        InputValidator.validateAddress(_feeToSetter);
        feeToSetter = _feeToSetter;
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
            payable(to).transfer(amount);
        } else {
            InputValidator.validateAddress(token);
            (bool success, bytes memory data) = token.call(
                abi.encodeWithSelector(0xa9059cbb, to, amount)
            );
            require(success && (data.length == 0 || abi.decode(data, (bool))), 'PuddelFactory: TRANSFER_FAILED');
        }
    }
}