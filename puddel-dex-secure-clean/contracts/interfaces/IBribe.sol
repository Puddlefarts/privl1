// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IERC20.sol";

interface IBribe {
    event BribeDeposited(uint256 indexed epoch, address indexed token, uint256 amount, address indexed from);
    event BribeClaimed(uint256 indexed epoch, address indexed token, address indexed to, uint256 amount);

    function depositBribe(IERC20 token, uint256 amount, uint256 epoch) external;
    function claim(uint256 tokenId, address[] calldata tokens, uint256[] calldata epochs) external;
    function claimable(uint256 tokenId, IERC20 token, uint256 epoch) external view returns (uint256);
}
