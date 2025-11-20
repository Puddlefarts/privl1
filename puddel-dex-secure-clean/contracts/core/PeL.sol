// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IERC20.sol";

/**
 * @title PeL - PUDDeL Governance & Utility Token
 * @notice ERC20 token with role-based minting for the PUDDeL ecosystem
 * @dev Minting rights controlled by MINTER_ROLE, granted to Minter contract
 */
contract PeL is IERC20 {
    string public constant name = "PUDDeL";
    string public constant symbol = "PeL";
    uint8 public constant decimals = 18;

    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    // Role-based access control
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(bytes32 => mapping(address => bool)) private _roles;
    address public admin;

    event RoleGranted(bytes32 indexed role, address indexed account);
    event RoleRevoked(bytes32 indexed role, address indexed account);

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "PeL: unauthorized");
        _;
    }

    constructor(address _admin, uint256 initialSupply) {
        require(_admin != address(0), "PeL: zero address");
        admin = _admin;
        _grantRole(ADMIN_ROLE, _admin);

        if (initialSupply > 0) {
            _mint(_admin, initialSupply);
        }
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function grantRole(bytes32 role, address account) external onlyRole(ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(ADMIN_ROLE) {
        _revokeRole(role, account);
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!_roles[role][account]) {
            _roles[role][account] = true;
            emit RoleGranted(role, account);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (_roles[role][account]) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account);
        }
    }

    /**
     * @notice Mint new PeL tokens - only callable by Minter contract
     * @param to Address to receive minted tokens
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "PeL: mint to zero address");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "PeL: insufficient allowance");
            allowance[from][msg.sender] = currentAllowance - amount;
        }
        return _transfer(from, to, amount);
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        require(from != address(0), "PeL: transfer from zero address");
        require(to != address(0), "PeL: transfer to zero address");
        require(balanceOf[from] >= amount, "PeL: insufficient balance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
