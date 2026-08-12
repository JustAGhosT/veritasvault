---
document_type: overview
classification: internal
status: draft
version: 0.1.0
last_updated: '2026-08-12'
applies_to:
- Core
reviewers:
- '@tech-lead'
priority: p2
next_review: '2026-11-12'
---

# Market Data Platform

A scalable, flexible platform for storing, querying, and archiving diverse market data objects, optimized for derivative pricing and market tracking.  
Built on Azure services with a C# backend, and designed for future interoperability with Python applications.

---

## 📚 Project Overview

This solution stores various types of market data — spot prices, forward curves, yield curves, and volatility surfaces — in Azure Cosmos DB for hot storage, with long-term archival to Azure Data Lake.

It follows a **phased delivery**:

- **Phase 1:** Temporal Data (Official, Intraday) — CosmosDB storage
- **Phase 2:** Live Data (Streaming, Latest Value Only) — CosmosDB optimized container
- **Phase 3:** Archival to Azure Data Lake — cold storage for historical analytics

---

## 🧪 Testing & Code Coverage

### Running Tests with Coverage

Tests automatically collect coverage data when run:

```bash
dotnet test
```

### Generating Coverage Reports

To generate HTML coverage reports:

**Using VS Code Task:**

1. Press `Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (macOS)
2. Type "Tasks: Run Task"
3. Select "Generate Coverage Report"

**Using Terminal:**

- Windows: `powershell -ExecutionPolicy Bypass -File .\tests\vv.Infrastructure.Tests\Generate-CoverageReport.ps1`
- Linux/macOS: `./tests/vv.Infrastructure.Tests/generate-coverage-report.sh`

The report will be generated at `tests/vv.Infrastructure.Tests/CoverageReport/index.html` and automatically opened in your browser.

### Current Coverage Status

- Line coverage: 11.5% (54 of 468 lines)
- Branch coverage: 9.2% (14 of 152 branches)

#### Areas Needing Coverage Improvement:

- vv.Infrastructure: 1.5% line coverage
- Validation Components
- Data Mapping Classes

---

## 🗂 Folder Structure

```plaintext
MarketDataPlatform/
├── src/
│   ├── MarketData.Domain/          # POCOs, Interfaces, Schemas
│   │   ├── Models/
│   │   │   ├── Interfaces/
│   │   │   │   └── IMarketDataObject.cs
│   │   │   ├── FxSpotPriceObject.cs
│   │   │   ├── ...
│   │   └── Schemas/
│   │       ├── FxSpotPriceObject.json
│   │       ├── ...
│   ├── MarketData.Infrastructure/  # CosmosDB / Data Lake clients
        ├── Cosmos/
        │   ├── CosmosClientFactory.cs     # Create and manage Cosmos DB client connections cleanly
        │   ├── MarketDataRepository.cs    # Saving and querying market data objects
        │   ├── VersionManager.cs          # Managing document versions (initial simple version, later extendable)
        └── Common/
            ├── Configuration.cs (later for config handling)
            └── RetryPolicy.cs (optional retries, etc.)
│   ├── MarketData.Functions/       # Azure Function Apps for background processing
│   ├── MarketData.Application/     # Ingestion, Query Handlers
│   ├── MarketData.Functions/       # Azure Function Apps for background processing│   ├── MarketData.Api/              # (Optional) ASP.NET Web API
│   └── MarketData.Scripts/         # CLI tools: backfill, monitor, archive
│
├── tests/                          # Unit and Integration Tests
├── docs/                           # Documentation
│   ├── Architecture.md
│   ├── UsageFromPython.md
│   ├── APIContracts.md
│   └── DeveloperGuide.md
├── MarketDataPlatform.sln          # Solution File
└── README.md                       # This file
```

---

## 🎨 Design Principles

### Common Interface: `IMarketDataObject`

All market data types share a base interface ensuring the following metadata is always present:

```csharp
public interface IMarketDataObject
{
    string Id { get; set; }
    string SchemaVersion { get; set; }
    string Version { get; set; }
    string AssetId { get; set; }
    string AssetClass { get; set; }
    string DataType { get; set; }
    List<string> Tags { get; set; }
    string DocumentType { get; set; }
    DateTime Timestamp { get; set; }
}
```

---

### Concrete Market Data Classes

| Class                   | Description                          |
| :---------------------- | :----------------------------------- |
| `SpotPriceData`         | Represents a spot price for an asset |
| `ForwardPriceData`      | Represents forward curve points      |
| `YieldCurveData`        | Represents a yield curve (rates)     |
| `VolatilitySurfaceData` | Represents a volatility surface      |

Each implements `IMarketDataObject` and adds **specific payload fields**.

---

## 📦 JSON Schema Definitions

Each market data object type has an associated **JSON Schema** to validate documents:

| Schema                        | Purpose                                |
| :---------------------------- | :------------------------------------- |
| `PriceEquitySchema.json`      | Spot price schema for equities         |
| `ForwardFxSchema.json`        | Forward price schema for FX pairs      |
| `YieldCurveRatesSchema.json`  | Yield curve schema for interest rates  |
| `VolSurfaceEquitySchema.json` | Volatility surface schema for equities |

Each schema mandates metadata + payload structure, ensuring **consistency and validation** across ingestion.

---

## 🏗 Azure Cosmos DB Design (Phase 1)

| Design Choice | Details                                                                     |
| :------------ | :-------------------------------------------------------------------------- |
| Database      | Azure CosmosDB (Core SQL API)                                               |
| Partition Key | `/assetId`                                                                  |
| Containers    | `marketdata-history` (temporal), later `marketdata-live` (live)             |
| Indexing      | Composite indexes on `[assetId, timestamp]` and `[documentType, timestamp]` |
| ID Format     | `<dataType>.<assetclass>/<asset>/<date>/<documentType>/<version>`           |
| Example ID    | `price.equity/XYZ/20250427/official/1`                                      |

---

## 🧠 Version Management Strategy

- Initially: Use CosmosDB query (`ORDER BY version DESC LIMIT 1`) to determine latest version.
- Later: Upgrade to an **atomic version counter** stored separately for efficient writes at scale.

✅ The design supports **easy migration** without breaking changes.

---

## 🌎 Python Interoperability

This system is designed for **easy integration with Python** in future phases.

- All models serialize cleanly into **flat JSON**.
- APIs (if built) will use **REST/gRPC**, accessible easily from Python clients.
- Documentation will include sample Python scripts to **ingest/query market data**.

Future docs: see `docs/UsageFromPython.md`

---

## 🚀 Next Planned Steps

- **Phase 1 Execution:** Build ingestion pipeline for temporal data (official / intraday).
- **Phase 2 Expansion:** Introduce live data container (`marketdata-live`) optimized for overwrites / low-latency reads.
- **Phase 3 Rollout:** Setup Azure Data Lake archival, backfilling historical CosmosDB data.
- **Enhancements:** Implement automatic version counter service, schema registry validation at ingestion, and possibly a Market Data API for client querying.

---

## 📋 Example: Spot Price Object

```json
{
  "id": "price.equity/XYZ/20250427/official/1",
  "schemaVersion": "0.0",
  "version": "1",
  "assetId": "XYZ",
  "assetClass": "equity",
  "dataType": "price",
  "tags": ["spot"],
  "documentType": "official",
  "timestamp": "2025-04-27T00:00:00Z",
  "price": 105.34
}
```

---

## ✨ Guiding Principles

- **Scalable by design** — support for GB–TB data volumes.
- **Flexible schema** — adapt quickly to new market data types.
- **Performance-focused** — partitioning, indexing, efficient Cosmos usage.
- **Minimal duplication** — clear interface abstraction.
- **Interoperable** — C# now, Python next.

---

# 📢 Status: 🔵 Phase 1 - In Progress
