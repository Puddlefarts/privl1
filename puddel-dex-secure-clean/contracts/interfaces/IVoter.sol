// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVoter {
    event Voted(uint256 indexed tokenId, address indexed gauge, uint256 weight, uint256 epoch);
    event Reset(uint256 indexed tokenId, uint256 epoch);
    event GaugeAdded(address indexed pair, address indexed gauge, address indexed bribe);
    event GaugeRemoved(address indexed gauge);

    function vote(uint256 tokenId, address[] calldata gauges, uint256[] calldata weights) external;
    function reset(uint256 tokenId) external;
    function addGauge(address pair, address gauge, address bribe) external;

    function currentEpoch() external view returns (uint256);
    function gaugeWeight(address gauge) external view returns (uint256);
    function totalWeight() external view returns (uint256);
    function epochGaugeWeight(uint256 epoch, address gauge) external view returns (uint256);
    function epochTotalWeight(uint256 epoch) external view returns (uint256);
    function votes(uint256 tokenId, address gauge) external view returns (uint256);
    function isGauge(address gauge) external view returns (bool);
    function gauges() external view returns (address[] memory);
}
