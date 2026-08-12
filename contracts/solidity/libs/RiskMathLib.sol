pragma solidity ^0.8.0;

library RiskMathLib {
    // Volatility, Sharpe/Sortino, and z-score calculations

    // Calculate volatility
    function calculateVolatility(uint256[] memory returns) internal pure returns (uint256) {
        uint256 mean = calculateMean(returns);
        uint256 variance = 0;
        for (uint256 i = 0; i < returns.length; i++) {
            variance += (returns[i] - mean) ** 2;
        }
        return sqrt(variance / returns.length);
    }

    // Calculate Sharpe ratio
    function calculateSharpeRatio(uint256[] memory returns, uint256 riskFreeRate) internal pure returns (uint256) {
        uint256 mean = calculateMean(returns);
        uint256 volatility = calculateVolatility(returns);
        return (mean - riskFreeRate) / volatility;
    }

    // Calculate Sortino ratio
    function calculateSortinoRatio(uint256[] memory returns, uint256 riskFreeRate) internal pure returns (uint256) {
        uint256 mean = calculateMean(returns);
        uint256 downsideDeviation = calculateDownsideDeviation(returns, riskFreeRate);
        return (mean - riskFreeRate) / downsideDeviation;
    }

    // Calculate z-score
    function calculateZScore(uint256 value, uint256 mean, uint256 stdDev) internal pure returns (uint256) {
        return (value - mean) / stdDev;
    }

    // Helper function to calculate mean
    function calculateMean(uint256[] memory values) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < values.length; i++) {
            total += values[i];
        }
        return total / values.length;
    }

    // Helper function to calculate downside deviation
    function calculateDownsideDeviation(uint256[] memory returns, uint256 riskFreeRate) internal pure returns (uint256) {
        uint256 downsideDeviation = 0;
        for (uint256 i = 0; i < returns.length; i++) {
            if (returns[i] < riskFreeRate) {
                downsideDeviation += (returns[i] - riskFreeRate) ** 2;
            }
        }
        return sqrt(downsideDeviation / returns.length);
    }

    // Helper function to calculate square root
    function sqrt(uint256 x) internal pure returns (uint256) {
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
