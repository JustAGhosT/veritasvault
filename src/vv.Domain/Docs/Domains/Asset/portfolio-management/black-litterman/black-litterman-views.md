---
document_type: guide
classification: internal
status: draft
version: 0.1.0
last_updated: "2025-05-31"
applies_to:
  - Core
reviewers:
  - "@tech-lead"
priority: p2
next_review: "2026-05-31"
---

```src/vv.Domain/Docs/Domains/Asset/black-litterman-views.md
# Black-Litterman Views

> Techniques for generating and specifying investor views

---

## Overview

Investor views are a critical component of the Black-Litterman model. This document details approaches for generating, specifying, and calibrating views for use in the model.

## View Specification Framework

### View Types

The Black-Litterman model supports two main types of views:

1. **Absolute Views**: Direct statements about expected returns for specific assets
   * Example: "Asset A will return 5%"
   * Mathematical representation: $E(R_A) = 5\%$

2. **Relative Views**: Comparative statements between assets
   * Example: "Asset A will outperform Asset B by 2%"
   * Mathematical representation: $E(R_A) - E(R_B) = 2\%$

### View Matrix Formulation

Views are formally expressed using a view matrix P and a view vector Q:

$$P \times E(R) = Q + \varepsilon$$

Where:
- $P$ is the $k \times n$ view matrix defining the assets involved in each view
- $E(R)$ is the $n \times 1$ expected return vector
- $Q$ is the $k \times 1$ vector of view values
- $\varepsilon$ represents the uncertainty in the views, $\varepsilon \sim N(0, \Omega)$

#### Example P Matrix Construction

For a universe with 4 assets (A, B, C, D) and these views:
1. "Asset A will return 5%"
2. "Asset B will outperform Asset C by 2%"

The P matrix and Q vector would be:

$$P = \begin{bmatrix}
1 & 0 & 0 & 0 \\
0 & 1 & -1 & 0
\end{bmatrix}$$

$$Q = \begin{bmatrix}
0.05 \\
0.02
\end{bmatrix}$$

## View Generation Techniques

### Quantitative Methods

Several quantitative approaches can generate views:

1. **Factor Model Forecasts**:
   * Use factor exposures and factor return forecasts
   * $E(R) = Bf + \alpha$
   * Where B is the factor exposure matrix and f is the factor return vector

2. **Time Series Models**:
   * Apply ARIMA, GARCH, or machine learning models to forecast returns
   * Support with statistical significance testing

3. **Valuation Models**:
   * Dividend discount models for equity
   * Yield curve models for fixed income
   * Relative value metrics (P/E, P/B, etc.)

4. **Cross-Asset Signals**:
   * Credit spreads as signals for equity
   * Commodity price changes for related equities
   * Volatility surface changes for directional views

### Qualitative Methods

Qualitative views can be incorporated through structured processes:

1. **Expert Panels**:
   * Structured elicitation from investment professionals
   * Delphi method for consensus formation
   * Scenario-based view development

2. **View Standardization**:
   * Standard templates for view submission
   * Calibration tests for consistent scaling
   * Historical performance tracking of contributors

3. **Market Sentiment Analysis**:
   * News sentiment quantification
   * Social media analysis
   * Analyst recommendation aggregation

## Confidence Specification

### Confidence Calibration

View confidence is specified through the $\Omega$ matrix, with several approaches available:

1. **Statistical Confidence**:
   * Based on statistical significance of forecasts
   * $\Omega_{ii} = \sigma^2 / t_{stat}^2$
   * Where $\sigma^2$ is variance and $t_{stat}$ is the t-statistic of the forecast

2. **Proportional to Market Variance**:
   * $\Omega_{ii} = \frac{1}{c_i} (P\Sigma P^T)_{ii}$
   * Where $c_i \in [0,1]$ represents confidence in view $i$

3. **Historical Accuracy**:
   * Based on historical forecasting accuracy
   * $\Omega_{ii} = MSE_i$ (Mean Squared Error of past forecasts)

4. **Confidence Surveys**:
   * Direct elicitation of confidence intervals
   * Conversion to standard deviation estimates

### Confidence Scaling

For consistent confidence scaling:

1. **Percentage Confidence**:
   * 100%: View fully overrides equilibrium
   * 50%: View and equilibrium equally weighted
   * 0%: View ignored, equilibrium prevails

2. **Confidence Translation**:
   * Convert confidence percentage to $\Omega$ value
   * $\Omega_{ii} = (P\Sigma P^T)_{ii} \times \frac{1-c_i}{c_i}$
   * Where $c_i \in (0,1]$ is confidence percentage

> **ERRATA — see ADR-0001 §D1**
> (`docs/adr/0001-black-litterman-model-conventions.md`, repository root).
> The implemented form includes $\tau$:
> $\Omega_{ii} = (P(\tau\Sigma)P^T)_{ii}\times\frac{1-c_i}{c_i}$, matching
> `calibrate_omega` in [black-litterman-implementation.md](./black-litterman-implementation.md).
> Endpoint handling is defined rather than left to the formula: $c_i = 0$ **drops
> the view's row from $P$ and $Q$** (exactly equivalent to the $\Omega\to\infty$
> limit, and numerically clean where clamping is not), and $c_i = 1$ gives
> $\Omega_{ii} = 0$, which is well-posed only in the covariance form of the
> posterior, not the precision form.

## Multiple View Management

### Consistency Checking

When incorporating multiple views, consistency should be verified:

1. **Internal Consistency**:
   * Detect and resolve contradictory views
   * Example: "A > B" and "B > A" cannot both be true

2. **Equilibrium Divergence**:
   * Assess aggregate divergence from equilibrium
   * Use statistical measures to identify outlier views

3. **Factor Alignment**:
   * Check if views align with underlying risk factors
   * Identify unintentional factor bets

### View Combining Approaches

Several approaches exist for managing multiple views:

1. **Equal Weighting**:
   * Assign equal confidence to all views
   * Simple but potentially suboptimal

2. **Track Record Weighting**:
   * Weight views by historical accuracy
   * More weight to historically accurate sources

3. **Hierarchical Aggregation**:
   * Aggregate views from lower to higher levels
   * Resolve conflicts at each level

4. **Entropy Pooling**:
   * Use information theory to optimally combine views
   * Minimize information loss while respecting all views

## View Updating Process

### Temporal Considerations

Views should be regularly updated using a structured process:

1. **View Horizon**:
   * Match view horizon to investment horizon
   * Short-term vs. long-term views

2. **Decay Functions**:
   * Implement decay functions for aging views
   * $\Omega_t = \Omega_0 \times e^{kt}$ where $k$ is decay rate and $t$ is time

3. **Event-Based Updates**:
   * Trigger view updates based on significant events
   * Market surprises, earnings releases, etc.

4. **Systematic Review Calendar**:
   * Regular schedule for view updates
   * Documentation of view changes and rationale

## VeritasVault Implementation

VeritasVault provides tools for efficient view management:

1. **View Builder Interface**:
   * Intuitive interface for view specification
   * Absolute and relative view templates
   * Confidence calibration tools

2. **View Library**:
   * Database of historical views and accuracy
   * View categorization and tagging

3. **View Analytics**:
   * Visualization of view impact on allocation
   * Contribution analysis of views
   * Consistency checking tools

4. **View Integration Framework**:
   * API for automated view generation
   * Integration with factor models and other view sources
   * Workflow tools for view review and approval

## Best Practices

1. **Start Small**: Begin with a few high-conviction views
2. **Calibrate Carefully**: Ensure proper confidence calibration
3. **Document Views**: Maintain clear documentation of view rationale
4. **Track Performance**: Monitor view accuracy over time
5. **Update Systematically**: Establish a regular view update process
6. **Balance Sources**: Combine quantitative and qualitative inputs
7. **Consider Constraints**: Account for implementation constraints in view formulation

For more detailed information on specific aspects, see:
* [Black-Litterman Overview](./black-litterman-overview.md)
* [Black-Litterman Model](./black-litterman-model.md)
* [Black-Litterman Implementation](./black-litterman-implementation.md)
* [Black-Litterman Validation](./black-litterman-validation.md)
```
