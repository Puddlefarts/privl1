// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IVoter.sol";
import "../interfaces/IVotingEscrow.sol";
import "../security/ReentrancyGuard.sol";

/**
 * @title Voter - Gauge Weight Management & Epoch Snapshots
 * @notice Users allocate veNFT voting power across gauges
 * @dev Maintains per-epoch snapshots for bribe distribution
 */
contract Voter is IVoter, ReentrancyGuard {
    IVotingEscrow public immutable ve;
    uint256 public immutable EPOCH_LEN;

    // Gauge registry
    mapping(address => bool) public override isGauge;
    mapping(address => address) public gaugeToPair;
    mapping(address => address) public gaugeToBribe;
    address[] private _gauges;

    // Current weights
    mapping(address => uint256) public override gaugeWeight;
    uint256 public override totalWeight;

    // Per-token voting state: tokenId => gauge => weight allocated
    mapping(uint256 => mapping(address => uint256)) public override votes;
    mapping(uint256 => uint256) public tokenTotalVotes; // total weight allocated by tokenId
    mapping(uint256 => address[]) public tokenVotedGauges; // gauges voted for by tokenId

    // Epoch snapshots for bribes
    mapping(uint256 => mapping(address => uint256)) public override epochGaugeWeight;
    mapping(uint256 => uint256) public override epochTotalWeight;
    mapping(uint256 => bool) public epochSnapshotted;

    // Access control
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    mapping(bytes32 => mapping(address => bool)) private _roles;

    modifier onlyRole(bytes32 role) {
        require(_roles[role][msg.sender], "Voter: unauthorized");
        _;
    }

    constructor(IVotingEscrow _ve, uint256 epochLen, address admin) {
        ve = _ve;
        EPOCH_LEN = epochLen;
        _roles[ADMIN_ROLE][admin] = true;
    }

    function currentEpoch() public view override returns (uint256) {
        return block.timestamp / EPOCH_LEN;
    }

    function gauges() external view override returns (address[] memory) {
        return _gauges;
    }

    /**
     * @notice Add a new gauge (admin only)
     * @param pair The liquidity pair address
     * @param gauge The gauge contract
     * @param bribe The bribe contract
     */
    function addGauge(address pair, address gauge, address bribe) external override onlyRole(ADMIN_ROLE) {
        require(pair != address(0) && gauge != address(0), "Voter: zero address");
        require(!isGauge[gauge], "Voter: gauge exists");

        isGauge[gauge] = true;
        gaugeToPair[gauge] = pair;
        gaugeToBribe[gauge] = bribe;
        _gauges.push(gauge);

        emit GaugeAdded(pair, gauge, bribe);
    }

    /**
     * @notice Vote with a veNFT to allocate weight across gauges
     * @param tokenId The veNFT to vote with
     * @param gaugeList Array of gauges to vote for
     * @param weights Array of weights (will be normalized to voting power)
     */
    function vote(
        uint256 tokenId,
        address[] calldata gaugeList,
        uint256[] calldata weights
    ) external override nonReentrant {
        require(ve.ownerOf(tokenId) == msg.sender, "Voter: not owner");
        require(gaugeList.length == weights.length && gaugeList.length > 0, "Voter: length mismatch");

        uint256 epoch = currentEpoch();
        uint256 power = ve.votingPower(tokenId);
        require(power > 0, "Voter: no voting power");

        // Reset previous votes for this token
        _resetToken(tokenId);

        // Calculate total weight requested
        uint256 totalRequested;
        for (uint i = 0; i < weights.length; i++) {
            require(weights[i] > 0, "Voter: zero weight");
            require(isGauge[gaugeList[i]], "Voter: not a gauge");
            totalRequested += weights[i];
        }
        require(totalRequested > 0, "Voter: zero total weight");

        // Normalize and apply votes
        for (uint i = 0; i < gaugeList.length; i++) {
            if (weights[i] == 0) continue;

            // Proportionally allocate power based on weight
            uint256 allocatedPower = (power * weights[i]) / totalRequested;

            votes[tokenId][gaugeList[i]] = allocatedPower;
            tokenVotedGauges[tokenId].push(gaugeList[i]);

            gaugeWeight[gaugeList[i]] += allocatedPower;
            totalWeight += allocatedPower;

            // Update epoch snapshot
            epochGaugeWeight[epoch][gaugeList[i]] += allocatedPower;

            emit Voted(tokenId, gaugeList[i], allocatedPower, epoch);
        }

        tokenTotalVotes[tokenId] = power;
        epochTotalWeight[epoch] += power;
        epochSnapshotted[epoch] = true;
    }

    /**
     * @notice Reset all votes for a tokenId
     * @param tokenId The veNFT to reset
     */
    function reset(uint256 tokenId) external override nonReentrant {
        require(ve.ownerOf(tokenId) == msg.sender, "Voter: not owner");
        _resetToken(tokenId);
        emit Reset(tokenId, currentEpoch());
    }

    /**
     * @dev Internal: reset votes for a token
     */
    function _resetToken(uint256 tokenId) internal {
        address[] storage votedGauges = tokenVotedGauges[tokenId];
        uint256 totalVotes = tokenTotalVotes[tokenId];

        if (totalVotes == 0) return;

        for (uint i = 0; i < votedGauges.length; i++) {
            address gauge = votedGauges[i];
            uint256 weight = votes[tokenId][gauge];

            gaugeWeight[gauge] -= weight;
            totalWeight -= weight;

            delete votes[tokenId][gauge];
        }

        delete tokenVotedGauges[tokenId];
        delete tokenTotalVotes[tokenId];
    }

    /**
     * @notice Snapshot current weights for an epoch (optional helper)
     * @dev Vote() automatically snapshots, but this can be called for manual snapshot
     */
    function snapshot() external {
        uint256 epoch = currentEpoch();
        if (!epochSnapshotted[epoch]) {
            epochTotalWeight[epoch] = totalWeight;
            epochSnapshotted[epoch] = true;
        }
    }
}
