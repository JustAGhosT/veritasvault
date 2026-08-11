# VeritasVault

## Contract Inventory (Stateless-First)

### Layer

#### Math Libraries

- **TvlMathLib.sol**: Safe-math helpers for TVL, APR, APY, basis-point operations (pure)
- **RiskMathLib.sol**: Volatility, Sharpe/Sortino, z-score calculations (pure)

#### Oracle Adapters

- **PriceOracleAdapter.sol**: Normalize chain-specific price feeds to unified format (view)
- **LiquidityOracleAdapter.sol**: Fetch & scale on-chain DEX liquidity data (view)

#### Analytics Modules

- **RiskScoreLib.sol**: Compose math + oracle data => risk score (pure)
- **HealthFactorLib.sol**: LTV / collateral health calculation (pure)

#### Cross-Chain Encoding

- **BridgeEncoder.sol**: ABI ↔ FA2 packing/unpacking for bridge messages (pure)

#### Verification Utilities

- **SigVerifier.sol**: ECDSA/Ed25519 signature checks for off-chain attestations (pure)

#### Coordination (minimal state)

- **MetricsCoordinator.sol**: Stores oracle addresses + pushes aggregated metrics; only owner-settable config

#### Facades / Entry Points

- **VeritasVaultView.sol**: Stateless read-only facade exposing consolidated TVL & risk endpoints

Note: All business logic lives in libraries to maximize purity. Stateful contracts only store config/owner pointers.

## Repository Layout (Monorepo)

```
veritasvault-chain/
│
├── contracts/                # Generated + hand-written chain code
│   ├── solidity/
│   │   ├── libs/            # *_Lib.sol (stateless)
│   │   ├── adapters/        # Oracle adapters
│   │   ├── utils/           # Reusable helpers (SafeCast, FixedPoint)
│   │   ├── facades/
│   │   └── coordinators/
│   └── tezos/
│       ├── michelson/       # *.tz output
│       └── ligo/            # Optional higher-level sources
│
├── dsl/                      # Domain-specific language
│   ├── spec/                # EBNF, type system docs
│   ├── examples/            # VV sample programs
│   └── src/
│       └── ...              # Parser, IR, tests
│
├── compiler/                # Rust-based codegen
│   ├── src/
│   └── wasm/
│
├── deployments/
│   ├── hardhat/             # EVM deploy scripts + config
│   └── taqueria/            # Tezos deploy scripts
│
├── test/
│   ├── unit/                # JS/TS & Python fast-check
│   └── integration/         # Cross-chain parity tests
│
├── scripts/                 # Dev & maintenance tooling
│
├── ci/                      # GitHub Actions, gas snapshots
│
└── docs/                    # MkDocs site, tutorials, audit reports
```

## NPM / Package Scopes

- **@veritasvault/dsl-compiler**: CLI & WASM pkg
- **@veritasvault/evm-libs**: Precompiled Solidity libraries & ABIs
- **@veritasvault/tezos-libs**: Michelson binaries & views

## Next Steps

1. Confirm contract list with stakeholders.
2. Stub library interfaces in both targets to unblock DSL codegen.
3. Integrate folders into existing VV GitHub org.
