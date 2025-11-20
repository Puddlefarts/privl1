// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IMinter.sol";
import "../interfaces/IVoter.sol";
import "../interfaces/IGauge.sol";
import "../interfaces/IERC20.sol";
import "../security/ReentrancyGuard.sol";

/**
 * @title Minter - Epoch Management & Emission Distribution
 * @notice Manages weekly epochs and distributes PeL emissions to gauges
 * @dev Permissionless updateEpoch() - anyone can trigger the weekly roll
 */
contract Minter is IMinter, ReentrancyGuard {
    uint256 public immutable EPOCH_LEN;
    uint256 public override lastEpoch;
    uint256 public override emissionPerEpoch;

    IVoter public immutable voter;
    IERC20 public immutable pel; // Must have mint() function

    // Emission decay (optional)
    uint16 public decayBps; // Basis points to decay per epoch (e.g., 100 = 1% decay)
    uint256 public constant MAX_EMISSION = 1_000_000e18; // Safety cap

    // Access control
    bytes32 public constant OPS_ROLE = keccak256("OPS_ROLE");
    mapping(bytes32 => mapping(address => bool)) private _roles;
    address public admin;

    modifier onlyRole(bytes32 role) {
        require(_roles[role][msg.sender], "Minter: unauthorized");
        _;
    }

    constructor(
        IERC20 _pel,
        IVoter _voter,
        uint256 epochLen,
        uint256 initialEmission,
        address _admin
    ) {
        pel = _pel;
        voter = _voter;
        EPOCH_LEN = epochLen;
        emissionPerEpoch = initialEmission;
        lastEpoch = block.timestamp / epochLen;
        admin = _admin;
        _roles[OPS_ROLE][_admin] = true;
    }

    function currentEpoch() public view override returns (uint256) {
        return block.timestamp / EPOCH_LEN;
    }

    /**
     * @notice Roll to next epoch and distribute emissions (permissionless)
     * @dev Can only be called once per epoch
     */
    function updateEpoch() external override nonReentrant {
        uint256 epoch = currentEpoch();
        require(epoch > lastEpoch, "Minter: already updated");

        lastEpoch = epoch;

        // Get gauge weights from previous epoch
        uint256 _totalWeight = voter.epochTotalWeight(epoch - 1);
        uint256 emission = emissionPerEpoch;

        if (_totalWeight == 0) {
            emit EpochRolled(epoch, 0, 0);
            return; // No gauges to distribute to
        }

        // Distribute to each gauge pro-rata by weight
        address[] memory gauges = voter.gauges();
        for (uint i = 0; i < gauges.length; i++) {
            address gauge = gauges[i];
            uint256 gaugeWeight = voter.epochGaugeWeight(epoch - 1, gauge);

            if (gaugeWeight > 0) {
                uint256 amount = (emission * gaugeWeight) / _totalWeight;

                // Mint PeL to this contract
                _mintPeL(amount);

                // Approve gauge and notify
                require(pel.approve(gauge, amount), "Minter: approve failed");
                IGauge(gauge).notifyRewardAmount(amount);
            }
        }

        // Apply decay if configured
        if (decayBps > 0 && emissionPerEpoch > 0) {
            emissionPerEpoch = (emissionPerEpoch * (10000 - decayBps)) / 10000;
        }

        emit EpochRolled(epoch, emission, _totalWeight);
    }

    /**
     * @notice Update emission per epoch (OPS only, with bounds)
     * @param newEmission New emission amount per epoch
     */
    function setEmissionPerEpoch(uint256 newEmission) external override onlyRole(OPS_ROLE) {
        require(newEmission <= MAX_EMISSION, "Minter: exceeds max");
        emissionPerEpoch = newEmission;
        emit EmissionUpdated(newEmission);
    }

    /**
     * @notice Set emission decay rate (OPS only)
     * @param newDecayBps Decay in basis points (max 1000 = 10%)
     */
    function setDecayBps(uint16 newDecayBps) external onlyRole(OPS_ROLE) {
        require(newDecayBps <= 1000, "Minter: decay too high");
        decayBps = newDecayBps;
    }

    /**
     * @dev Internal mint function
     * @dev Assumes PeL has mint(address,uint256) function with MINTER_ROLE granted
     */
    function _mintPeL(uint256 amount) internal {
        // Call mint function on PeL contract
        (bool success, ) = address(pel).call(
            abi.encodeWithSignature("mint(address,uint256)", address(this), amount)
        );
        require(success, "Minter: mint failed");
    }

    /**
     * @notice Grant role (admin only)
     */
    function grantRole(bytes32 role, address account) external {
        require(msg.sender == admin, "Minter: not admin");
        _roles[role][account] = true;
    }
}
