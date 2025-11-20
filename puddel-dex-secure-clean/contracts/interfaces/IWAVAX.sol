// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IWAVAX {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}