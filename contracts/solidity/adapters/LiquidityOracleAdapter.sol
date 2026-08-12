pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract LiquidityOracleAdapter {
    AggregatorV3Interface internal liquidityFeed;

    constructor(address _liquidityFeed) {
        liquidityFeed = AggregatorV3Interface(_liquidityFeed);
    }

    /**
     * Returns the latest liquidity data
     */
    function getLatestLiquidity() public view returns (int) {
        (
            uint80 roundID, 
            int liquidity,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = liquidityFeed.latestRoundData();
        return liquidity;
    }

    /**
     * Returns the liquidity data at a specific round
     */
    function getLiquidityAtRound(uint80 _roundID) public view returns (int) {
        (
            uint80 roundID, 
            int liquidity,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = liquidityFeed.getRoundData(_roundID);
        return liquidity;
    }
}
