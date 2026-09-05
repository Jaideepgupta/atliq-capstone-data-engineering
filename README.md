# AtliQ Commerce – End-to-End Batch Data Engineering

> **End-to-end batch data engineering project using Azure SQL, Azure Data Factory, ADLS Gen2, Azure Databricks, dbt Core, GitHub Actions and Microsoft Fabric.**

[![CI](https://img.shields.io/badge/CI-GitHub%20Actions-blue)](.github/workflows/ci.yml)
[![dbt tests](https://img.shields.io/badge/dbt%20tests-18%2F18%20passing-brightgreen)](#dbt-validation)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](#license)

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Business Problem](#business-problem)
- [Source Data](#source-data)
- [Data Engineering Architecture](#data-engineering-architecture)
  - [1. OLTP – Azure SQL](#1-oltp--azure-sql)
  - [2. Ingestion – Azure Data Factory](#2-ingestion--azure-data-factory)
  - [3. Bronze – ADLS Gen2 / Databricks](#3-bronze--adls-gen2--databricks)
  - [4. Silver – Azure Databricks](#4-silver--azure-databricks)
- [Gold Layer – dbt](#gold-layer--dbt)
- [dbt Validation](#dbt-validation)
- [Data Quality & Reconciliation](#data-quality--reconciliation)
- [Nightly Batch & Reliability](#nightly-batch--reliability)
- [Idempotency Proof](#idempotency-proof)
- [Microsoft Fabric / Power BI](#microsoft-fabric--power-bi)
- [CI/CD – GitHub Actions](#cicd--github-actions)
- [Evidence Gallery](#evidence-gallery)
- [Repository Structure](#repository-structure)
- [Key Engineering Decisions](#key-engineering-decisions)
- [Issues Faced & Resolutions](#issues-faced--resolutions)
- [Security](#security)
- [Getting Started](#getting-started)
- [Local dbt Commands](#local-dbt-commands)
- [Dataset Scale](#dataset-scale)
- [Skills Demonstrated](#skills-demonstrated)
- [What I'd Do Differently at Scale](#what-id-do-differently-at-scale)
- [Infrastructure & Cost Notes](#infrastructure--cost-notes)
- [Project Documentation](#project-documentation)
- [Project Outcome](#project-outcome)
- [License](#license)
- [Author](#author)

---

## Project Overview

This project builds an end-to-end analytical data platform for an e-commerce business.

The solution separates the operational OLTP workload from analytical processing and reporting:

```text
Azure SQL / CSV
      ↓
Azure Data Factory
      ↓
ADLS Gen2 – Bronze
      ↓
Azure Databricks – Silver
      ↓
dbt Core – Gold
      ↓
Microsoft Fabric / Power BI
```

The repository contains the implementation, transformation code, pipeline exports, dashboard artifacts, CI/CD configuration, project evidence and detailed technical documentation.

---

## Architecture

![AtliQ Commerce Architecture](atliq_commerce_architecture.svg)

### Architecture Flow

| Layer | Technology | Responsibility |
|---|---|---|
| Source | Azure SQL | Operational OLTP data |
| Source | CSV | Marketing spend and supplier pricing |
| Ingestion | Azure Data Factory | Metadata-driven ingestion and orchestration |
| Storage | ADLS Gen2 | Durable Bronze/raw storage |
| Transformation | Azure Databricks | Bronze → Silver processing and enrichment |
| Analytical Modeling | dbt Core | Silver → Gold dimensional models and tests |
| Consumption | Microsoft Fabric / Power BI | Business analytics and dashboards |
| DevOps | GitHub + GitHub Actions | Version control and CI/CD |

---

## Business Problem

The operational database supports the e-commerce application, but leadership needs analytical answers such as:

- How is revenue changing over time?
- Which products generate the most revenue?
- Which cities contribute the most revenue?
- How can customer and sales performance be analyzed?
- How can supplier cost be used to understand profitability?

Running heavy analytical queries directly against the live OLTP database can affect application performance. Therefore, this project creates a separate analytical processing path and synchronizes the data through a nightly batch.

---

## Source Data

### Azure SQL – OLTP

The operational database contains:

- `customers`
- `products`
- `orders`
- `order_items`
- `payments`

### Marketing Spend

`marketing_spend.csv`

```text
spend_date
channel
campaign
spend_amount
clicks
```

### Supplier Price List

`supplier_price_list.csv`

```text
product_id
product_name
supplier_name
supplier_cost
effective_date
```

The supplier price list is used to enrich product/sales data for cost and profitability analysis.

Marketing spend is modeled separately from sales because the available source data does not contain a reliable sale-to-campaign attribution key. A date-only join could multiply sales when several campaigns/channels exist on the same date.

---

# Data Engineering Architecture

## 1. OLTP – Azure SQL

Azure SQL acts as the operational source system.

The normalized OLTP model is designed for transactional workloads, with separate tables for customers, products, orders, order items and payments.

The project also uses an ETL control table and watermark concepts for incremental ingestion.

---

## 2. Ingestion – Azure Data Factory

Azure Data Factory handles source extraction and orchestration.

Main pipelines:

### `pl_sql_to_raw`

SQL extraction and raw ingestion flow.

### `pl_sql_to_adls`

Landing/orchestration flow for ADLS-oriented Bronze storage.

### `pl_master_batch`

Master pipeline coordinating the end-to-end batch process.

High-level orchestration:

```text
pl_sql_to_raw
      ↓
pl_sql_to_adls
      ↓
Databricks_Bronze_to_Gold
```

Pipeline JSON exports and implementation screenshots are available in:

`evidence/M2_ADF/`

---

## 3. Bronze – ADLS Gen2 / Databricks

Bronze is the source-oriented landing layer.

Its purpose is to:

- Preserve ingested source data.
- Separate ingestion from transformation.
- Provide durable cloud storage.
- Provide a repeatable input for downstream processing.

The SQL-derived Bronze data is stored as Parquet.

---

## 4. Silver – Azure Databricks

Azure Databricks performs the main distributed transformation and enrichment work.

The Silver layer is responsible for:

- Cleaning and standardizing source data.
- Applying appropriate data types.
- Transforming source structures.
- Enriching sales with product information.
- Enriching sales with supplier cost.
- Applying incremental MERGE/upsert logic where appropriate.

Databricks implementation evidence is available in:

`evidence/M3_SILVER/`

---

# Gold Layer – dbt

The analytical Gold layer is managed with dbt Core.

Unity Catalog:

```text
atliq
```

Relevant schemas include:

```text
atliq.bronze
atliq.silver
atliq.gold
atliq.ci
```

## Gold Model

The central sales fact uses the grain:

> **One row per order item**

### Dimensions

- `dim_customer`
- `dim_product`
- `dim_date`

### Facts

- `fact_sales`
- `fact_marketing_spend`

### Intermediate

- `int_sales_enriched`

### Staging

- `stg_customers`
- `stg_marketing_spend`
- `stg_order_items`
- `stg_orders`
- `stg_payments`
- `stg_products`
- `stg_supplier_price_list`

The current dbt implementation materializes staging and intermediate models as views in the `atliq.gold` schema, while the analytical marts are materialized as tables.

---

## dbt Validation

The project currently contains:

- **13 dbt models**
- **18 data tests**
- **7 sources**

Validation results:

```text
dbt run
13 / 13 models passed

dbt test
18 / 18 tests passed
0 warnings
0 errors
0 skipped tests
```

Tests include:

- Not-null checks
- Uniqueness checks
- Relationship checks

dbt evidence is available in:

`evidence/M4_GOLD_DBT/`

---

# Data Quality & Reconciliation

Key validation performed during the implementation:

| Check | Result | Notes |
|---|---:|---|
| Customer duplicate check | 0 duplicate rows | On natural/business key |
| Product duplicate check | 0 duplicate rows | On natural/business key |
| Fact order-item uniqueness | 0 duplicate rows | `fact_sales` grain = one row per order item |
| Date referential integrity | 0 orphan rows | `fact_sales.date_key` → `dim_date` |
| Supplier cost completeness | 798 / 798 products matched | 100% of products have a supplier cost |
| Gross revenue | ₹2,126,260.00 | Sum of `fact_sales.revenue` |
| Supplier cost | ₹656,785.28 | Sum of matched supplier cost across sold units |
| Gross profit | ₹1,469,474.72 | Gross revenue − supplier cost |
| Profit reconciliation difference | 0.00 | Gold-layer profit vs. independently recomputed value |

> Currency shown as INR (₹) — update to match your actual source currency if different.

These checks validate both structural integrity and the financial calculations used by the analytical model.

---

# Nightly Batch & Reliability

The solution is designed as a nightly batch process.

```text
Azure SQL / CSV
      ↓
ADF ingestion
      ↓
ADLS Bronze
      ↓
Databricks Bronze → Silver
      ↓
dbt Gold
      ↓
Fabric reporting
```

The scheduled processing is designed around retry-safe behavior:

- Same-day Bronze data can be overwritten on retry.
- Silver fact processing uses MERGE/business-key logic.
- Gold models are rebuilt from curated upstream data.

The project also includes nightly execution evidence in:

`evidence/M5_NIGHTLY_SYNC/`

## Idempotency Proof

To validate retry-safety, the full nightly flow was executed **twice in succession** against the same source snapshot, with `fact_sales` compared before and after the second run:

| Metric | Run 1 | Run 2 | Match? |
|---|---:|---:|---|
| `fact_sales` row count | *[fill in]* | *[fill in]* | ✅ / ❌ |
| Total `gross_revenue` | *[fill in]* | *[fill in]* | ✅ / ❌ |
| Total `supplier_cost` | *[fill in]* | *[fill in]* | ✅ / ❌ |

> **Action needed:** replace the placeholders above with the actual two-run values (screenshot or query output goes in `evidence/M5_NIGHTLY_SYNC/idempotency_proof.png`). Until filled in, treat this as an open validation item rather than a completed one — don't present it as finished in interviews or on a resume until the numbers are in.

---

# Microsoft Fabric / Power BI

## Executive Dashboard

**AtliQ Commerce Executive Sales & Performance Dashboard**

The dashboard includes executive KPIs and analytical views including:

- Revenue trend
- Top products by revenue
- Top cities by revenue
- Revenue by category

Dashboard artifacts and evidence are available in:

`evidence/M6_FABRIC/`

Files include the editable Power BI/Fabric report artifact, PDF export, dashboard screenshot and data-model screenshot.

> **Live demo:** infrastructure has been torn down after project completion to avoid ongoing Azure costs (see [Infrastructure & Cost Notes](#infrastructure--cost-notes)). The PBIX/Fabric report file and screenshots in `evidence/M6_FABRIC/` are the source of truth for reviewing the dashboard.

---

# CI/CD – GitHub Actions

The dbt project is integrated with GitHub Actions.

Workflow:

`.github/workflows/ci.yml`

The CI process:

1. Checks out the repository.
2. Installs the required dbt tooling.
3. Uses Databricks connection values supplied through GitHub Secrets.
4. Runs the dbt CI build.
5. Uses dbt tests as data-quality gates.

Secrets are not hard-coded in the repository.

CI/CD evidence is available in:

`evidence/M7_CICD/`

---

# Evidence Gallery

The repository contains implementation screenshots and artifacts for each milestone.

## M2 – Azure Data Factory

### Master Pipeline

![ADF Master Pipeline](evidence/M2_ADF/pl_master_batch.png)

### SQL → ADLS

![ADF SQL to ADLS](evidence/M2_ADF/pl_sql_to_adls.png)

### SQL → Raw

![ADF SQL to Raw](evidence/M2_ADF/pl_sql_to_raw.png)

[Open all M2 ADF evidence](evidence/M2_ADF/)

---

## M3 – Databricks Silver

### Bronze → Silver Transformation

![Databricks Bronze to Silver](evidence/M3_SILVER/01_Bronze_to_Silver.png)

[Open all M3 Silver evidence](evidence/M3_SILVER/)

---

## M4 – dbt Gold

### dbt DAG / Lineage

![dbt DAG Lineage](evidence/M4_GOLD_DBT/DAG_Lineage.png)

### dbt Sources

![dbt Sources](evidence/M4_GOLD_DBT/dbt_Sources.png)

### dbt Tests

![dbt Test Results](evidence/M4_GOLD_DBT/dbt_test.png)

[Open all M4 Gold/dbt evidence](evidence/M4_GOLD_DBT/)

---

## M5 – Nightly Execution

### Nightly Run

![Nightly Run](evidence/M5_NIGHTLY_SYNC/Nightly%20Run.png)

[Open all M5 evidence](evidence/M5_NIGHTLY_SYNC/)

---

## M6 – Microsoft Fabric

### Executive Dashboard

![AtliQ Commerce Dashboard](evidence/M6_FABRIC/Dashboard.png)

### Data Model

![Fabric Data Model](evidence/M6_FABRIC/Data%20Model.png)

[Open all M6 Fabric evidence](evidence/M6_FABRIC/)

---

## M7 – CI/CD

GitHub Actions screenshots and supporting evidence are available in:

`evidence/M7_CICD/`

[Open all M7 CI/CD evidence](evidence/M7_CICD/)

---

# Repository Structure

```text
.
├── .github/
│   └── workflows/
│       └── ci.yml
│
├── dbt_project/
│   ├── models/
│   ├── tests/
│   ├── macros/
│   ├── analyses/
│   ├── dbt_project.yml
│   └── profiles.yml
│
├── evidence/
│   ├── M1_OLTP/
│   ├── M2_ADF/
│   ├── M3_SILVER/
│   ├── M4_GOLD_DBT/
│   ├── M5_NIGHTLY_SYNC/
│   ├── M6_FABRIC/
│   └── M7_CICD/
│
├── atliq_commerce_architecture.svg
├── Cdebasics_AtliQ_End_to_End_Data_Engineering_Project_Report.pdf
├── Cdebasics_AtliQ_End_to_End_Data_Engineering_Project_Report.docx
├── .gitignore
└── README.md
```

---

# Key Engineering Decisions

### Why separate OLTP and analytics?

The operational database is optimized for transactions, while the downstream analytical platform is optimized for reporting and aggregation. This protects the application workload from heavy analytical queries.

### Why ADLS Gen2?

ADLS provides durable cloud storage independently of compute. Data can remain available even when Databricks compute is stopped.

### Why Databricks?

Databricks provides scalable distributed processing for Bronze/Silver transformation, enrichment and incremental workloads.

### Why dbt?

dbt provides SQL-based analytical modeling, dependency management, testing and documentation.

### Why ADF?

ADF provides managed ingestion and orchestration between the operational source, storage and transformation workloads.

### Why GitHub Actions?

GitHub Actions provides automated CI validation so dbt changes can be tested consistently.

### Why not directly join sales and marketing by date?

Because several campaigns or channels may exist on the same date. Without a sale-to-campaign attribution key, a direct join can duplicate sales and produce incorrect metrics.

---

# Issues Faced & Resolutions

### PowerShell execution policy

Local dbt activation/scripts were initially blocked.

**Resolution:** Used a process-scoped PowerShell execution-policy change.

### dbt–Databricks connection

The initial dbt connection required correction of the environment variables and Databricks host configuration.

**Resolution:** Configured the connection through environment variables and validated it with `dbt debug`.

### Credential security

A Databricks token was accidentally exposed during troubleshooting.

**Resolution:** The credential was replaced. The repository uses environment variables and GitHub Secrets rather than storing the actual credential.

### GitHub Actions authentication

CI initially failed because the Databricks authentication secret was stale.

**Resolution:** The GitHub secret was updated and the CI workflow subsequently passed.

### Catalog naming

The Unity Catalog used by the project is:

```text
atliq
```

Consistent catalog naming avoids object-not-found errors.

---

# Security

Never commit:

- Databricks tokens
- Passwords
- `.env` files containing secrets
- Connection strings containing credentials

Use environment variables, GitHub Secrets or an appropriate secret-management service.

---

# Getting Started

This project was built against live Azure/Databricks/Fabric resources; the sections below let a reviewer either reproduce it or navigate straight to the evidence if they don't have Azure access.

### Prerequisites

- Azure subscription with permissions to create: Azure SQL Database, Azure Data Factory, ADLS Gen2 storage account, Azure Databricks workspace (Unity Catalog enabled)
- Microsoft Fabric capacity (or Power BI Pro/Premium) for the reporting layer
- Python 3.9+ and `dbt-databricks` installed locally
- A GitHub repository with Actions enabled, and the following repo secrets configured:
  - `DATABRICKS_HOST`
  - `DATABRICKS_HTTP_PATH`
  - `DATABRICKS_TOKEN`

### Setup Steps

1. **Provision infrastructure** — create the Azure SQL database, ADLS Gen2 account (with `bronze`/`silver`/`gold` containers or equivalent), and Databricks workspace with Unity Catalog pointed at the `atliq` catalog.
2. **Load source data** — restore/seed the OLTP tables (`customers`, `products`, `orders`, `order_items`, `payments`) into Azure SQL, and upload `marketing_spend.csv` / `supplier_price_list.csv` to a landing location ADF can reach.
3. **Deploy ADF pipelines** — import `pl_sql_to_raw`, `pl_sql_to_adls`, and `pl_master_batch` (JSON exports in `evidence/M2_ADF/`) into your Data Factory instance and point linked services at your own Azure SQL and ADLS accounts.
4. **Run Bronze → Silver in Databricks** — attach the Silver notebooks/jobs to a running cluster and execute against the Bronze data landed by ADF.
5. **Configure and run dbt**
   ```powershell
   cd dbt_project
   cp profiles.yml.example ~/.dbt/profiles.yml   # if you don't already keep profiles.yml locally
   dbt debug
   dbt run
   dbt test
   ```
6. **Connect Fabric/Power BI** to the `atliq.gold` schema and open/rebuild the executive dashboard.
7. **Wire up CI** — set the three Databricks secrets in your GitHub repo settings so `.github/workflows/ci.yml` can run `dbt build` on every push.

> **Don't have Azure access?** Everything above is documented step-by-step, with real output, in `evidence/` and in the full project report (`Cdebasics_AtliQ_End_to_End_Data_Engineering_Project_Report.pdf`). You don't need to stand up the infrastructure to review the work.

---

# Local dbt Commands

From the dbt project directory:

```powershell
cd dbt_project
dbt debug
dbt run
dbt test
dbt build
```

Connection credentials should be supplied securely through environment variables.

---

# Dataset Scale

> **Action needed:** fill in actual figures below — recruiters and reviewers look for these to gauge whether this is a toy dataset or a representative one.

| Table / Source | Approx. Row Count | Notes |
|---|---:|---|
| `customers` | *[fill in]* | |
| `products` | 798 | Matches supplier cost completeness check |
| `orders` | *[fill in]* | |
| `order_items` | *[fill in]* | Drives `fact_sales` grain |
| `payments` | *[fill in]* | |
| `marketing_spend.csv` | *[fill in]* | |
| Total Bronze data volume | *[fill in, e.g. ~X MB/GB]* | Parquet, uncompressed/compressed |

---

# Skills Demonstrated

Mapped to common data engineering job requirements:

| Skill Area | Where Demonstrated |
|---|---|
| Incremental / CDC-style loading | Watermark-based ADF ingestion, Databricks MERGE/upsert logic in Silver |
| Orchestration | ADF master pipeline coordinating multi-stage batch (`pl_master_batch`) |
| Distributed data processing | Azure Databricks Bronze → Silver transformation and enrichment |
| Dimensional modeling | Star schema Gold layer (`dim_customer`, `dim_product`, `dim_date`, `fact_sales`, `fact_marketing_spend`) |
| Data quality / testing | 18 dbt tests (not-null, uniqueness, relationships) as CI quality gates |
| Analytics engineering (dbt) | Staging → intermediate → mart layering, sources, materializations |
| CI/CD for data pipelines | GitHub Actions running `dbt build` on every change, secrets management |
| Data governance | Unity Catalog schema separation (`bronze`/`silver`/`gold`/`ci`) |
| Reliability engineering | Retry-safe Bronze overwrite, idempotent Silver MERGE, rebuildable Gold |
| BI / reporting | Microsoft Fabric & Power BI executive dashboard with KPI design |

---

# What I'd Do Differently at Scale

- **Batch vs. streaming**: at higher order volumes, move order/payment ingestion to a change-data-capture or streaming pattern (e.g., Debezium/Event Hubs → Databricks Structured Streaming) instead of nightly full/incremental batch, to reduce reporting latency.
- **Partitioning strategy**: partition Bronze/Silver Parquet by ingestion date (and possibly by a high-cardinality dimension like region) to keep file sizes manageable and speed up downstream reads as volume grows.
- **Data contracts**: introduce schema contracts/validation at the ADF landing stage so upstream source changes fail fast in ingestion rather than surfacing as dbt test failures in Gold.
- **Cost-based cluster sizing**: move from a fixed Databricks cluster config to autoscaling/job clusters sized to actual Silver workload volume, and add cluster idle-timeout policies.
- **Observability**: add pipeline-level alerting (e.g., ADF alerts, dbt artifacts posted to Slack/Teams) rather than relying on manual evidence checks after each run.

---

# Infrastructure & Cost Notes

To avoid ongoing Azure/Databricks/Fabric costs after project completion, the live infrastructure (Azure SQL, ADF, Databricks workspace, Fabric capacity) has been torn down. All pipeline configurations, dbt models, and outputs are preserved as:

- Pipeline JSON exports (`evidence/M2_ADF/`)
- Notebook/job screenshots and logic (`evidence/M3_SILVER/`)
- Full dbt project source (`dbt_project/`)
- Dashboard artifacts and PBIX/Fabric report file (`evidence/M6_FABRIC/`)

This keeps the project reproducible without maintaining a live, billable environment.

---

# Project Documentation

## Detailed Project Report

The repository contains both PDF and Word versions of the detailed project documentation.

- **PDF:** `Cdebasics_AtliQ_End_to_End_Data_Engineering_Project_Report.pdf`
- **DOCX:** `Cdebasics_AtliQ_End_to_End_Data_Engineering_Project_Report.docx`

The report documents the implementation, architecture, design decisions, validation, troubleshooting and learning outcomes.

---

# Project Outcome

This project demonstrates an end-to-end batch data engineering workflow covering:

- OLTP data modeling
- Incremental ingestion
- ADLS Gen2 data lake storage
- Bronze / Silver / Gold architecture
- Azure Databricks transformation
- Unity Catalog
- Dimensional modeling
- dbt transformation and testing
- Data-quality validation
- Nightly orchestration
- Retry/idempotency-oriented processing
- Microsoft Fabric analytics
- Git version control
- GitHub Actions CI/CD
- Technical documentation
- Implementation evidence

---

# License

> **Action needed:** choose and add an actual `LICENSE` file to the repo root (MIT is a common choice for portfolio projects) and update this section/badge to match.

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

# Author

**Jaideep Gupta**

Data Engineering / Analytics Engineering Portfolio Project

**Technologies:** Azure SQL • Azure Data Factory • ADLS Gen2 • Databricks • Unity Catalog • dbt • Microsoft Fabric • Power BI • GitHub Actions
