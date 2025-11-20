// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../access/Ownable.sol";
import "./NetworkConfig.sol";
import "../errors/PuddelErrors.sol";

contract PuddelConfig is Ownable {
    using NetworkConfig for uint256;

    NetworkConfig.Config public currentConfig;
    
    // Events for configuration changes
    event ConfigUpdated(
        address indexed WAVAX,
        uint256 minimumLiquidity,
        uint256 maxDeadlineExtension,
        uint256 maxPathLength,
        uint256 defaultSlippageBps,
        uint256 maxSlippageBps,
        bool emergencyMode
    );
    
    event WAVAXUpdated(address indexed oldWAVAX, address indexed newWAVAX);
    event MinimumLiquidityUpdated(uint256 oldValue, uint256 newValue);
    event MaxDeadlineExtensionUpdated(uint256 oldValue, uint256 newValue);
    event MaxPathLengthUpdated(uint256 oldValue, uint256 newValue);
    event SlippageConfigUpdated(uint256 oldDefault, uint256 newDefault, uint256 oldMax, uint256 newMax);
    event EmergencyModeUpdated(bool enabled);

    constructor(address initialOwner, uint256 chainId) Ownable(initialOwner) {
        _initializeConfig(chainId);
    }

    function _initializeConfig(uint256 chainId) private {
        if (chainId == 43113) {
            // Avalanche Fuji Testnet
            currentConfig = NetworkConfig.getFujiConfig();
        } else if (chainId == 43114) {
            // Avalanche Mainnet
            currentConfig = NetworkConfig.getMainnetConfig();
        } else {
            // Default/Local - will be updated by owner
            currentConfig = NetworkConfig.Config({
                WAVAX: address(0),
                minimumLiquidity: 1000,
                maxDeadlineExtension: 7 days,
                maxPathLength: 10,
                defaultSlippageBps: 50,
                maxSlippageBps: 5000,
                emergencyMode: false
            });
        }
        
        _emitConfigUpdated();
    }

    // Read functions
    function getWAVAX() external view returns (address) {
        return currentConfig.WAVAX;
    }

    function getMinimumLiquidity() external view returns (uint256) {
        return currentConfig.minimumLiquidity;
    }

    function getMaxDeadlineExtension() external view returns (uint256) {
        return currentConfig.maxDeadlineExtension;
    }

    function getMaxPathLength() external view returns (uint256) {
        return currentConfig.maxPathLength;
    }

    function getDefaultSlippageBps() external view returns (uint256) {
        return currentConfig.defaultSlippageBps;
    }

    function getMaxSlippageBps() external view returns (uint256) {
        return currentConfig.maxSlippageBps;
    }

    function isEmergencyMode() external view returns (bool) {
        return currentConfig.emergencyMode;
    }

    function getFullConfig() external view returns (NetworkConfig.Config memory) {
        return currentConfig;
    }

    // Owner-only update functions
    function updateWAVAX(address newWAVAX) external onlyOwner {
        if (newWAVAX == address(0)) {
            revert PuddelErrors.InvalidAddress(newWAVAX);
        }
        address oldWAVAX = currentConfig.WAVAX;
        currentConfig.WAVAX = newWAVAX;
        emit WAVAXUpdated(oldWAVAX, newWAVAX);
        _emitConfigUpdated();
    }

    function updateMinimumLiquidity(uint256 newMinimumLiquidity) external onlyOwner {
        if (newMinimumLiquidity == 0) {
            revert PuddelErrors.InvalidAmount(newMinimumLiquidity, 1, type(uint256).max);
        }
        uint256 oldValue = currentConfig.minimumLiquidity;
        currentConfig.minimumLiquidity = newMinimumLiquidity;
        emit MinimumLiquidityUpdated(oldValue, newMinimumLiquidity);
        _emitConfigUpdated();
    }

    function updateMaxDeadlineExtension(uint256 newMaxDeadlineExtension) external onlyOwner {
        if (newMaxDeadlineExtension == 0 || newMaxDeadlineExtension > 30 days) {
            revert PuddelErrors.InvalidAmount(newMaxDeadlineExtension, 1, 30 days);
        }
        uint256 oldValue = currentConfig.maxDeadlineExtension;
        currentConfig.maxDeadlineExtension = newMaxDeadlineExtension;
        emit MaxDeadlineExtensionUpdated(oldValue, newMaxDeadlineExtension);
        _emitConfigUpdated();
    }

    function updateMaxPathLength(uint256 newMaxPathLength) external onlyOwner {
        if (newMaxPathLength < 2 || newMaxPathLength > 20) {
            revert PuddelErrors.InvalidPath(newMaxPathLength, 2, 20);
        }
        uint256 oldValue = currentConfig.maxPathLength;
        currentConfig.maxPathLength = newMaxPathLength;
        emit MaxPathLengthUpdated(oldValue, newMaxPathLength);
        _emitConfigUpdated();
    }

    function updateSlippageConfig(uint256 newDefaultSlippageBps, uint256 newMaxSlippageBps) external onlyOwner {
        if (newDefaultSlippageBps > newMaxSlippageBps || newMaxSlippageBps > 10000) {
            revert PuddelErrors.InvalidSlippage(newMaxSlippageBps, 10000);
        }
        
        uint256 oldDefault = currentConfig.defaultSlippageBps;
        uint256 oldMax = currentConfig.maxSlippageBps;
        
        currentConfig.defaultSlippageBps = newDefaultSlippageBps;
        currentConfig.maxSlippageBps = newMaxSlippageBps;
        
        emit SlippageConfigUpdated(oldDefault, newDefaultSlippageBps, oldMax, newMaxSlippageBps);
        _emitConfigUpdated();
    }

    function setEmergencyMode(bool enabled) external onlyOwner {
        currentConfig.emergencyMode = enabled;
        emit EmergencyModeUpdated(enabled);
        _emitConfigUpdated();
    }

    function updateFullConfig(NetworkConfig.Config memory newConfig) external onlyOwner {
        if (newConfig.WAVAX == address(0)) {
            revert PuddelErrors.InvalidAddress(newConfig.WAVAX);
        }
        if (newConfig.minimumLiquidity == 0) {
            revert PuddelErrors.InvalidAmount(newConfig.minimumLiquidity, 1, type(uint256).max);
        }
        if (newConfig.maxDeadlineExtension == 0 || newConfig.maxDeadlineExtension > 30 days) {
            revert PuddelErrors.InvalidAmount(newConfig.maxDeadlineExtension, 1, 30 days);
        }
        if (newConfig.maxPathLength < 2 || newConfig.maxPathLength > 20) {
            revert PuddelErrors.InvalidPath(newConfig.maxPathLength, 2, 20);
        }
        if (newConfig.defaultSlippageBps > newConfig.maxSlippageBps || newConfig.maxSlippageBps > 10000) {
            revert PuddelErrors.InvalidSlippage(newConfig.maxSlippageBps, 10000);
        }
        
        currentConfig = newConfig;
        _emitConfigUpdated();
    }

    // Batch configuration for network migration
    function migrateToNetwork(uint256 chainId) external onlyOwner {
        if (chainId == 43113) {
            currentConfig = NetworkConfig.getFujiConfig();
        } else if (chainId == 43114) {
            currentConfig = NetworkConfig.getMainnetConfig();
        } else {
            revert PuddelErrors.InvalidNetworkConfiguration(chainId);
        }
        _emitConfigUpdated();
    }

    function _emitConfigUpdated() private {
        emit ConfigUpdated(
            currentConfig.WAVAX,
            currentConfig.minimumLiquidity,
            currentConfig.maxDeadlineExtension,
            currentConfig.maxPathLength,
            currentConfig.defaultSlippageBps,
            currentConfig.maxSlippageBps,
            currentConfig.emergencyMode
        );
    }
}