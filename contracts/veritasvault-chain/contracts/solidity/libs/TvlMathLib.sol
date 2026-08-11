pragma solidity ^0.8.0;

library TvlMathLib {
    // Safe-math helpers for TVL, APR, APY, and basis-point operations

    // Calculate TVL (Total Value Locked)
    function calculateTVL(uint256[] memory values) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < values.length; i++) {
            total += values[i];
        }
        return total;
    }

    // Calculate APR (Annual Percentage Rate)
    function calculateAPR(uint256 principal, uint256 interest, uint256 timePeriod) internal pure returns (uint256) {
        require(timePeriod > 0, "Time period must be greater than 0");
        return (interest * 365 * 100) / (principal * timePeriod);
    }

    // Calculate APY (Annual Percentage Yield)
    function calculateAPY(uint256 principal, uint256 interest, uint256 timePeriod) internal pure returns (uint256) {
        require(timePeriod > 0, "Time period must be greater than 0");
        uint256 apr = calculateAPR(principal, interest, timePeriod);
        return ((1 + apr / 100) ** 365) - 1;
    }

    // Basis-point operations
    function addBasisPoints(uint256 value, uint256 basisPoints) internal pure returns (uint256) {
        return value + (value * basisPoints) / 10000;
    }

    function subtractBasisPoints(uint256 value, uint256 basisPoints) internal pure returns (uint256) {
        return value - (value * basisPoints) / 10000;
    }
}
