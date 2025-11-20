// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IFeeDistributor.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IPuddelPair.sol";
import "../security/ReentrancyGuard.sol";

/**
 * @title FeeDistributor - Protocol Fee Management
 * @notice Receives protocol LP fees, burns them, and splits revenue
 * @dev Set as Factory.feeTo() to receive fee-on LP mints
 */
contract FeeDistributor is IFeeDistributor, ReentrancyGuard {
    // Revenue split configuration (in basis points, must sum to 10000)
    uint16 public veBps;        // To veNFT stakers
    uint16 public treasuryBps;  // To treasury
    uint16 public burnBps;      // Buy & burn PeL
    uint16 public emergencyBps; // Emergency fund

    address public treasury;
    address public emergencyFund;
    address public veRewards; // Contract that distributes to ve holders

    IERC20 public immutable pel;

    // Access control
    bytes32 public constant OPS_ROLE = keccak256("OPS_ROLE");
    mapping(bytes32 => mapping(address => bool)) private _roles;
    address public admin;

    modifier onlyRole(bytes32 role) {
        require(_roles[role][msg.sender], "FeeDistributor: unauthorized");
        _;
    }

    constructor(
        IERC20 _pel,
        address _treasury,
        address _emergencyFund,
        address _veRewards,
        address _admin
    ) {
        pel = _pel;
        treasury = _treasury;
        emergencyFund = _emergencyFund;
        veRewards = _veRewards;
        admin = _admin;
        _roles[OPS_ROLE][_admin] = true;

        // Default split: 40% ve, 30% treasury, 20% burn, 10% emergency
        veBps = 4000;
        treasuryBps = 3000;
        burnBps = 2000;
        emergencyBps = 1000;
    }

    /**
     * @notice Harvest protocol fees from a pair
     * @param pair The liquidity pair address
     * @dev Burns LP tokens to get underlying tokens, then splits revenue
     */
    function harvest(address pair) external override nonReentrant {
        IPuddelPair lpToken = IPuddelPair(pair);

        // Get LP balance (protocol fees minted to this contract)
        uint256 lpBalance = lpToken.balanceOf(address(this));
        require(lpBalance > 0, "FeeDistributor: no LP to harvest");

        // Transfer LP to pair for burning
        require(lpToken.transfer(pair, lpBalance), "FeeDistributor: transfer failed");

        // Burn LP to get token0 and token1
        (uint256 amount0, uint256 amount1) = lpToken.burn(address(this));

        emit Harvested(pair, amount0, amount1);

        // Get token addresses
        address token0 = lpToken.token0();
        address token1 = lpToken.token1();

        // Split each token according to configured percentages
        _splitRevenue(IERC20(token0), amount0);
        _splitRevenue(IERC20(token1), amount1);
    }

    /**
     * @dev Internal revenue split logic
     */
    function _splitRevenue(IERC20 token, uint256 amount) internal {
        if (amount == 0) return;

        uint256 toVe = (amount * veBps) / 10000;
        uint256 toTreasury = (amount * treasuryBps) / 10000;
        uint256 toBurn = (amount * burnBps) / 10000;
        uint256 toEmergency = amount - toVe - toTreasury - toBurn; // Remaining goes to emergency

        // Send to ve rewards contract
        if (toVe > 0 && veRewards != address(0)) {
            require(token.transfer(veRewards, toVe), "FeeDistributor: ve transfer failed");
        }

        // Send to treasury
        if (toTreasury > 0) {
            require(token.transfer(treasury, toTreasury), "FeeDistributor: treasury transfer failed");
        }

        // Buy & burn PeL (simplified: just burn the tokens for now)
        // TODO: Implement swap to PeL + burn via router
        if (toBurn > 0) {
            // For now, send to treasury (implement swap logic later)
            require(token.transfer(treasury, toBurn), "FeeDistributor: burn transfer failed");
        }

        // Send to emergency fund
        if (toEmergency > 0) {
            require(token.transfer(emergencyFund, toEmergency), "FeeDistributor: emergency transfer failed");
        }

        emit RevenueSplit(address(token), toVe, toTreasury, toBurn, toEmergency);
    }

    /**
     * @notice Update revenue splits (OPS only, with bounds)
     * @dev Must sum to 10000 (100%)
     */
    function setSplits(
        uint16 _veBps,
        uint16 _treasuryBps,
        uint16 _burnBps,
        uint16 _emergencyBps
    ) external override onlyRole(OPS_ROLE) {
        require(
            _veBps + _treasuryBps + _burnBps + _emergencyBps == 10000,
            "FeeDistributor: must sum to 10000"
        );

        veBps = _veBps;
        treasuryBps = _treasuryBps;
        burnBps = _burnBps;
        emergencyBps = _emergencyBps;

        emit SplitsUpdated(_veBps, _treasuryBps, _burnBps, _emergencyBps);
    }

    /**
     * @notice Get current split configuration
     */
    function splits() external view override returns (uint16, uint16, uint16, uint16) {
        return (veBps, treasuryBps, burnBps, emergencyBps);
    }

    /**
     * @notice Update addresses (OPS only)
     */
    function setTreasury(address _treasury) external onlyRole(OPS_ROLE) {
        require(_treasury != address(0), "FeeDistributor: zero address");
        treasury = _treasury;
    }

    function setEmergencyFund(address _emergencyFund) external onlyRole(OPS_ROLE) {
        require(_emergencyFund != address(0), "FeeDistributor: zero address");
        emergencyFund = _emergencyFund;
    }

    function setVeRewards(address _veRewards) external onlyRole(OPS_ROLE) {
        veRewards = _veRewards;
    }
}
