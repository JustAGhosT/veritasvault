pragma solidity ^0.8.0;

import "./RiskMathLib.sol";
import "./TvlMathLib.sol";
import "../adapters/PriceOracleAdapter.sol";
import "../adapters/LiquidityOracleAdapter.sol";

library RiskScoreLib {
    using RiskMathLib for uint256[];
    using TvlMathLib for uint256[];

    // Compose math and oracle data to calculate risk score
    function calculateRiskScore(
        uint256[] memory returns,
        uint256 riskFreeRate,
        uint256[] memory tvlValues,
        PriceOracleAdapter priceOracle,
        LiquidityOracleAdapter liquidityOracle
    ) internal view returns (uint256) {
        uint256 volatility = returns.calculateVolatility();
        uint256 sharpeRatio = returns.calculateSharpeRatio(riskFreeRate);
        uint256 sortinoRatio = returns.calculateSortinoRatio(riskFreeRate);
        uint256 tvl = tvlValues.calculateTVL();
        int latestPrice = priceOracle.getLatestPrice();
        int latestLiquidity = liquidityOracle.getLatestLiquidity();

        // Combine the calculated values to derive the risk score
        uint256 riskScore = (volatility + sharpeRatio + sortinoRatio + tvl + uint256(latestPrice) + uint256(latestLiquidity)) / 6;
        return riskScore;
    }
}
