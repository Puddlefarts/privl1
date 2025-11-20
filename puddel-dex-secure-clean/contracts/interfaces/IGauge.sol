// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IGauge {
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 amount);
    event Notified(uint256 amount);

    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
    function notifyRewardAmount(uint256 amount) external;

    function earned(address account) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
