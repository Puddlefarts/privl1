// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IERC20.sol";

interface IFeeDistributor {
    event Harvested(address indexed pair, uint256 amt0, uint256 amt1);
    event RevenueSplit(address indexed token, uint256 toVe, uint256 toTreasury, uint256 toBurn, uint256 toEmergency);
    event SplitsUpdated(uint16 veBps, uint16 treasuryBps, uint16 burnBps, uint16 emergencyBps);

    function harvest(address pair) external;
    function setSplits(uint16 veBps, uint16 treasuryBps, uint16 burnBps, uint16 emergencyBps) external;

    function splits() external view returns (uint16 veBps, uint16 treasuryBps, uint16 burnBps, uint16 emergencyBps);
}
