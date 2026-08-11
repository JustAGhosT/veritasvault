pragma solidity ^0.8.0;

library HealthFactorLib {
    // LTV and collateral health calculations

    // Calculate Loan-to-Value (LTV) ratio
    function calculateLTV(uint256 loanAmount, uint256 collateralValue) internal pure returns (uint256) {
        require(collateralValue > 0, "Collateral value must be greater than 0");
        return (loanAmount * 100) / collateralValue;
    }

    // Calculate collateral health factor
    function calculateHealthFactor(uint256 collateralValue, uint256 loanAmount, uint256 liquidationThreshold) internal pure returns (uint256) {
        require(collateralValue > 0, "Collateral value must be greater than 0");
        require(liquidationThreshold > 0, "Liquidation threshold must be greater than 0");
        return (collateralValue * liquidationThreshold) / loanAmount;
    }
}
