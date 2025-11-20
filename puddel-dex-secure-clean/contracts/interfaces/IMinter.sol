// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IMinter {
    event EpochRolled(uint256 indexed epoch, uint256 emission, uint256 totalWeight);
    event EmissionUpdated(uint256 newEmission);

    function updateEpoch() external;
    function setEmissionPerEpoch(uint256 newEmission) external;

    function currentEpoch() external view returns (uint256);
    function emissionPerEpoch() external view returns (uint256);
    function lastEpoch() external view returns (uint256);
}
