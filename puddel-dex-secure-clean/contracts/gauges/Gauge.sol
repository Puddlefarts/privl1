// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IGauge.sol";
import "../interfaces/IERC20.sol";
import "../security/ReentrancyGuard.sol";

/**
 * @title Gauge - LP Staking & Emissions Distribution
 * @notice Stake LP tokens to earn PeL emissions
 * @dev Time-weighted reward distribution (Synthetix StakingRewards model)
 */
contract Gauge is IGauge, ReentrancyGuard {
    IERC20 public immutable lpToken;
    IERC20 public immutable rewardToken; // PeL

    // Time-weighted reward state
    uint256 public rewardRate; // Rewards per second
    uint256 public periodFinish; // When current reward period ends
    uint256 public lastUpdateTime; // Last time rewardPerTokenStored was updated
    uint256 public rewardPerTokenStored;

    uint256 public constant DURATION = 7 days; // Distribute rewards over 7 days

    uint256 public override totalSupply;

    mapping(address => uint256) public override balanceOf;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    // Access control
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    mapping(bytes32 => mapping(address => bool)) private _roles;
    address public admin;

    modifier onlyRole(bytes32 role) {
        require(_roles[role][msg.sender], "Gauge: unauthorized");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(IERC20 _lpToken, IERC20 _rewardToken, address _admin) {
        lpToken = _lpToken;
        rewardToken = _rewardToken;
        admin = _admin;
        _roles[MINTER_ROLE][_admin] = true; // Will be transferred to Minter later
    }

    /**
     * @notice Calculate time-weighted reward per token
     * @dev Implements Synthetix formula: rewardPerTokenStored + (timeSinceLastUpdate * rewardRate * 1e18 / totalSupply)
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored + (
            (lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18 / totalSupply
        );
    }

    /**
     * @notice Get the applicable time for reward calculations
     * @dev Returns current time if rewards are still ongoing, or periodFinish if ended
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function earned(address account) public view override returns (uint256) {
        return
            (balanceOf[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 +
            rewards[account];
    }

    /**
     * @notice Stake LP tokens
     * @param amount Amount of LP tokens to stake
     */
    function deposit(uint256 amount) external override nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Gauge: zero amount");

        totalSupply += amount;
        balanceOf[msg.sender] += amount;

        require(lpToken.transferFrom(msg.sender, address(this), amount), "Gauge: transfer failed");

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstake LP tokens
     * @param amount Amount of LP tokens to withdraw
     */
    function withdraw(uint256 amount) external override nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Gauge: zero amount");
        require(balanceOf[msg.sender] >= amount, "Gauge: insufficient balance");

        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;

        require(lpToken.transfer(msg.sender, amount), "Gauge: transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Claim accumulated rewards
     */
    function getReward() external override nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            require(rewardToken.transfer(msg.sender, reward), "Gauge: transfer failed");
            emit RewardPaid(msg.sender, reward);
        }
    }

    /**
     * @notice Notify gauge of new rewards (called by Minter)
     * @param amount Amount of PeL rewards to distribute over DURATION (7 days)
     * @dev Implements time-weighted distribution:
     *      - If period ended: start new period with rate = amount / DURATION
     *      - If period ongoing: add to existing rate = (amount + leftover) / DURATION
     */
    function notifyRewardAmount(uint256 amount) external override onlyRole(MINTER_ROLE) updateReward(address(0)) {
        require(amount > 0, "Gauge: zero reward");

        // Transfer rewards from Minter to this contract
        require(rewardToken.transferFrom(msg.sender, address(this), amount), "Gauge: transfer failed");

        if (block.timestamp >= periodFinish) {
            // Previous period finished, start fresh
            rewardRate = amount / DURATION;
        } else {
            // Period still ongoing, add to existing rewards
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (amount + leftover) / DURATION;
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + DURATION;

        emit Notified(amount);
    }

    /**
     * @notice Grant role (admin only)
     */
    function grantRole(bytes32 role, address account) external {
        require(msg.sender == admin, "Gauge: not admin");
        _roles[role][account] = true;
    }

    /**
     * @notice Revoke role (admin only)
     */
    function revokeRole(bytes32 role, address account) external {
        require(msg.sender == admin, "Gauge: not admin");
        _roles[role][account] = false;
    }
}
