pragma solidity ^0.8.0;

import "../libs/TvlMathLib.sol";
import "../libs/RiskMathLib.sol";
import "../libs/RiskScoreLib.sol";
import "../adapters/PriceOracleAdapter.sol";
import "../adapters/LiquidityOracleAdapter.sol";

contract VeritasVaultView {
    using TvlMathLib for uint256[];
    using RiskMathLib for uint256[];
    using RiskScoreLib for uint256[];

    PriceOracleAdapter public priceOracle;
    LiquidityOracleAdapter public liquidityOracle;

    constructor(address _priceOracle, address _liquidityOracle) {
        priceOracle = PriceOracleAdapter(_priceOracle);
        liquidityOracle = LiquidityOracleAdapter(_liquidityOracle);
    }

    /**
     * Returns the consolidated TVL
     */
    function getConsolidatedTVL(uint256[] memory tvlValues) public pure returns (uint256) {
        return tvlValues.calculateTVL();
    }

    /**
     * Returns the consolidated risk score
     */
    function getConsolidatedRiskScore(
        uint256[] memory returns,
        uint256 riskFreeRate,
        uint256[] memory tvlValues
    ) public view returns (uint256) {
        return RiskScoreLib.calculateRiskScore(returns, riskFreeRate, tvlValues, priceOracle, liquidityOracle);
    }
}
