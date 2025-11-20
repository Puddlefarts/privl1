// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library NetworkConfig {
    struct Config {
        address WAVAX;
        uint256 minimumLiquidity;
        uint256 maxDeadlineExtension;
        uint256 maxPathLength;
        uint256 defaultSlippageBps; // basis points (100 = 1%)
        uint256 maxSlippageBps;
        bool emergencyMode;
    }

    // Get default configuration
    function getDefaultConfig() internal pure returns (Config memory) {
        return Config({
            WAVAX: address(0),
            minimumLiquidity: 1000,
            maxDeadlineExtension: 7 days,
            maxPathLength: 10,
            defaultSlippageBps: 50, // 0.5%
            maxSlippageBps: 5000, // 50%
            emergencyMode: false
        });
    }

    function validateConfig(Config memory config) internal pure {
        require(config.WAVAX != address(0), "NetworkConfig: INVALID_WAVAX");
        require(config.minimumLiquidity > 0, "NetworkConfig: INVALID_MIN_LIQUIDITY");
        require(config.maxDeadlineExtension > 0, "NetworkConfig: INVALID_MAX_DEADLINE");
        require(config.maxPathLength >= 2, "NetworkConfig: INVALID_MAX_PATH_LENGTH");
        require(config.defaultSlippageBps <= config.maxSlippageBps, "NetworkConfig: INVALID_SLIPPAGE");
    }

    // Avalanche Fuji Testnet
    function getFujiConfig() internal pure returns (Config memory) {
        return Config({
            WAVAX: 0xd00ae08403B9bbb9124bB305C09058E32C39A48c,
            minimumLiquidity: 1000,
            maxDeadlineExtension: 7 days,
            maxPathLength: 10,
            defaultSlippageBps: 50, // 0.5%
            maxSlippageBps: 5000, // 50%
            emergencyMode: false
        });
    }

    // Avalanche Mainnet
    function getMainnetConfig() internal pure returns (Config memory) {
        return Config({
            WAVAX: 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7,
            minimumLiquidity: 1000,
            maxDeadlineExtension: 7 days,
            maxPathLength: 10,
            defaultSlippageBps: 30, // 0.3% (tighter for mainnet)
            maxSlippageBps: 3000, // 30% (more conservative for mainnet)
            emergencyMode: false
        });
    }

    // Local/Development
    function getLocalConfig(address wavaxAddress) internal pure returns (Config memory) {
        return Config({
            WAVAX: wavaxAddress,
            minimumLiquidity: 100, // Lower for testing
            maxDeadlineExtension: 1 days,
            maxPathLength: 5,
            defaultSlippageBps: 100, // 1% (more lenient for testing)
            maxSlippageBps: 10000, // 100% (allow high slippage for testing)
            emergencyMode: false
        });
    }
}