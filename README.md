# Retail Omnichannel Analytics & Data Warehouse Platform

[![Oracle Database](https://img.shields.io/badge/Oracle-23ai%20%7C%2021c%20%7C%2019c-red.svg?logo=oracle&logoColor=white)](https://www.oracle.com/database/)
[![PL/SQL](https://img.shields.io/badge/Language-PL%2FSQL-orange.svg)]()
[![Kimball Star Schema](https://img.shields.io/badge/Architecture-Kimball%20Star%20Schema-blue.svg)]()
[![Power BI](https://img.shields.io/badge/BI-Power%20BI%20Desktop-yellow.svg?logo=powerbi&logoColor=black)](https://powerbi.microsoft.com/)
[![QA Tests](https://img.shields.io/badge/QA%20Tests-36%2F36%20Passing-brightgreen.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)]()

An enterprise-grade, end-to-end **Business Intelligence, Data Warehousing, and Analytics Platform** for a multinational omnichannel retail corporation operating across 4 countries (**USA, Mexico, Colombia, and Chile**) and 3 sales channels (**Physical Stores, E-Commerce, and Mobile App**).

The platform models the entire data lifecycle: from high-concurrency transactional OLTP systems, multi-currency normalization, automated data quality validation, and Kimball-modeled dimensional data warehousing, through to pre-aggregated materialized views, JSON electronic invoicing with SHA-256 digital signatures, and executive Power BI dashboards.

---

## Architecture Overview

```mermaid
flowchart TD
    subgraph OLTP ["1. Transactional Layer (OLTP - 3NF)"]
        O1["17 Relational Tables<br/>(Sales, Customers, Products, Branches, Promotions)"]
        O2["Multi-Currency Engine<br/>(USD, MXN, COP, CLP)"]
    end

    subgraph Governance ["2. Data Quality & Audit Pipeline"]
        G1["PKG_CALIDAD_DATOS<br/>(Validates Constraints, Dates, Prices, Referentials)"]
        G2["LOG_AUDITORIA & LOG_ERRORES<br/>(Quarantines Controlled Error Cases)"]
    end

    subgraph DW ["3. Kimball Star Schema Data Warehouse"]
        S1["Staging Area<br/>(STG_VENTAS)"]
        F1["Fact Table: HECHOS_VENTAS<br/>(2,805 Sales Lines @ USD)"]
        D1["7 Conformed Dimensions<br/>(DIM_TIEMPO, CLIENTE, PRODUCTO, SUCURSAL, CANAL, PROMOCION, EMPLEADO)"]
    end

    subgraph Invoicing ["4. Compliance & Invoicing"]
        J1["JSON Electronic Invoicing<br/>(FACTURAS_ELECTRONICAS)"]
        J2["Cryptographic Signatures<br/>(DBMS_CRYPTO SHA-256)"]
    end

    subgraph Semantic ["5. Pre-Aggregated Semantic Layer"]
        MV1["MV_VENTAS_MENSUALES"]
        MV2["MV_TOP_PRODUCTOS"]
        MV3["MV_UTILIDAD_POR_CATEGORIA"]
        MV4["MV_FRECUENCIA_CLIENTES"]
        MV5["MV_PROMOCIONES_USADAS"]
    end

    subgraph BI ["6. Analytics & Decision Support"]
        PBI["Power BI Executive Dashboard<br/>(5 Interactive Visual Pages)"]
    end

    O1 --> G1
    O2 --> G1
    G1 -->|Clean Data| S1
    G1 -->|Rejected Anomalies| G2
    S1 --> F1
    D1 -.-> F1
    F1 --> J1
    J1 --> J2
    F1 --> MV1 & MV2 & MV3 & MV4 & MV5
    MV1 & MV2 & MV3 & MV4 & MV5 --> PBI
```

---

## Key Business Metrics & Audit Baseline

*Data span: 9 months of full enterprise history (January 1, 2026 – September 30, 2026).*

| Metric | Verified Value | Status |
| :--- | :---: | :---: |
| **Total Valid Transactions** | `1,133` orders | Verified |
| **Loaded Fact Rows (`HECHOS_VENTAS`)** | `2,805` line items | 100% Ingested |
| **Gross Invoiced Revenue** | **$2,222,088.30 USD** | Exact Match |
| **Total Discounts & Promotions Applied** | **$255,637.89 USD** | Exact Match |
| **Net Billed Revenue** | **$1,966,450.41 USD** | Exact Match |
| **Total Cost of Goods Sold (COGS)** | **$1,459,969.00 USD** | Exact Match |
| **Gross Margin / Operating Profit** | **$506,481.41 USD** | **25.76% Margin** |
| **Audit Mathematical Discrepancy** | **$0.00 USD** | Zero Variance |
| **Automated QA Integration Suite** | **36 / 36 Passing** | 100% Green |

---

## Repository Structure

```
├── .gitignore
├── README.md
├── bi/
│   └── Retail Omnicanal.pbix               # 5-Page Executive Power BI Report
├── data/                                   # Bridge Data for Power BI Layer
│   ├── bi_lineas.csv
│   ├── mv_ventas_mensuales.csv
│   ├── mv_top_productos.csv
│   ├── mv_utilidad_por_categoria.csv
│   ├── mv_frecuencia_clientes.csv
│   ├── mv_promociones_usadas.csv
│   ├── resumen_mensual.csv
│   └── export_powerbi_csv.sql              # Script to re-export fresh CSVs
└── database/
    ├── ddl/                                # Data Definition Language
    │   ├── 01_oltp_tables.sql              # 17 Relational 3NF Tables
    │   ├── 02_staging_tables.sql           # ETL Staging Area
    │   ├── 03_dw_star_schema.sql           # Kimball Fact & 7 Dimensions
    │   ├── 04_facturas_json.sql            # JSON Relational & Hash Signatures
    │   └── 05_materialized_views.sql       # 5 Semantic Materialized Views
    ├── dml/                                # Data Manipulation Language
    │   ├── 01_seed_catalog_and_september.sql
    │   ├── 02_seed_history_jan_aug.sql     # 9-Month Historical Expansion
    │   └── 03_controlled_error_cases.sql   # Negative Testing Anomaly Seeds
    ├── plsql/                              # Business Logic Packages
    │   ├── pkg_divisas.sql                 # Multi-Currency Conversion
    │   ├── pkg_auditoria.sql               # Audit & Exception Handling
    │   ├── pkg_calidad_datos.sql           # Data Quality Rule Engine
    │   └── pkg_etl_ventas.sql              # Extraction, Load & Orchestration
    ├── tests/                              # Automated QA & Audit
    │   ├── 01_qa_integration_36_tests.sql  # 36-Point Automated Test Battery
    │   ├── 02_reconciliation_checks.sql   # Zero-Discrepancy Mathematical Check
    │   ├── 03_kpi_business_queries.sql     # Analytical Business Intelligence Queries
    │   ├── 04_historical_validation.sql    # 9-Month Volume Verification
    │   └── 05_mom_monthly_growth.sql       # Month-over-Month Growth Queries
    └── deploy/                             # Orchestration & Deployment
        ├── 00_init_user_tablespace.sql     # Tablespace & Grant Setup (DBA)
        ├── deploy_all.sql                  # Automated Master Pipeline Runner
        └── teardown.sql                    # Clean Slate / Reset Script
```

---

## Dimensional Data Warehouse (Kimball Model)

The Analytical Data Warehouse is modeled following Kimball's Dimensional Architecture to optimize analytical read queries and Power BI slicing.

```mermaid
erDiagram
    HECHOS_VENTAS }o--|| DIM_TIEMPO : "ID_TIEMPO"
    HECHOS_VENTAS }o--|| DIM_CLIENTE : "ID_CLIENTE"
    HECHOS_VENTAS }o--|| DIM_PRODUCTO : "ID_PRODUCTO"
    HECHOS_VENTAS }o--|| DIM_SUCURSAL : "ID_SUCURSAL"
    HECHOS_VENTAS }o--|| DIM_CANAL : "ID_CANAL"
    HECHOS_VENTAS }o--|| DIM_PROMOCION : "ID_PROMOCION"
    HECHOS_VENTAS }o--|| DIM_EMPLEADO : "ID_EMPLEADO"

    HECHOS_VENTAS {
        NUMBER ID_VENTA_LINEA PK
        NUMBER ID_VENTA_ORIGEN
        NUMBER ID_TIEMPO FK
        NUMBER ID_CLIENTE FK
        NUMBER ID_PRODUCTO FK
        NUMBER ID_SUCURSAL FK
        NUMBER ID_CANAL FK
        NUMBER ID_PROMOCION FK
        NUMBER ID_EMPLEADO FK
        NUMBER CANTIDAD
        NUMBER PRECIO_UNITARIO_USD
        NUMBER SUBTOTAL_USD
        NUMBER MONTO_DESCUENTO_USD
        NUMBER MONTO_NETO_USD
        NUMBER COSTO_UNITARIO_USD
        NUMBER COSTO_TOTAL_USD
        NUMBER UTILIDAD_BRUTA_USD
        NUMBER MARGEN_PORCENTAJE
        NUMBER MONTO_IMPUESTO_USD
        NUMBER TOTAL_LINEA_USD
    }

    DIM_TIEMPO {
        NUMBER ID_TIEMPO PK
        DATE FECHA
        NUMBER ANIO
        NUMBER MES
        VARCHAR2 NOMBRE_MES
        NUMBER TRIMESTRE
        NUMBER DIA_SEMANA
        VARCHAR2 FIN_SEMANA_SN
    }

    DIM_CLIENTE {
        NUMBER ID_CLIENTE PK
        VARCHAR2 CODIGO_CLIENTE
        VARCHAR2 NOMBRE_COMPLETO
        VARCHAR2 SEGMENTO
        VARCHAR2 CIUDAD
        VARCHAR2 PAIS
    }

    DIM_PRODUCTO {
        NUMBER ID_PRODUCTO PK
        VARCHAR2 CODIGO_PRODUCTO
        VARCHAR2 NOMBRE
        VARCHAR2 CATEGORIA
        VARCHAR2 MARCA
    }

    DIM_SUCURSAL {
        NUMBER ID_SUCURSAL PK
        VARCHAR2 NOMBRE
        VARCHAR2 CIUDAD
        VARCHAR2 PAIS
        VARCHAR2 TIPO_SUCURSAL
    }

    DIM_CANAL {
        NUMBER ID_CANAL PK
        VARCHAR2 CODIGO_CANAL
        VARCHAR2 NOMBRE
        VARCHAR2 MEDIO_DIGITAL_SN
    }

    DIM_PROMOCION {
        NUMBER ID_PROMOCION PK
        VARCHAR2 CODIGO_PROMOCION
        VARCHAR2 TIPO
        NUMBER PORCENTAJE_DESCUENTO
    }

    DIM_EMPLEADO {
        NUMBER ID_EMPLEADO PK
        VARCHAR2 CODIGO_EMPLEADO
        VARCHAR2 NOMBRE_COMPLETO
        VARCHAR2 CARGO
    }
```

---

## Power BI Executive Dashboard

The Business Intelligence presentation layer (`bi/Retail Omnicanal.pbix`) is organized into 5 executive dashboard views:

1. **Overview Retail Omnicanal**: Executive snapshot featuring Gross Invoiced Sales ($2.22M USD), Net Revenue ($1.97M USD), Profit ($506.48K USD), and Total Transactions (1,133).
2. **Resumen de Ventas**: Monthly breakdown and trend analysis across all four quarters of 2026.
3. **Clientes y Rentabilidad**: Customer segmentation analysis, Pareto distribution, and product margin profitability matrix.
4. **Promociones**: Discount effectiveness analysis comparing promotional sales lift vs. gross margin erosion.
5. **Ventas por País**: Geographic distribution and multi-currency performance across United States, Mexico, Colombia, and Chile.

---

## Deployment Quickstart

### Prerequisites
- **Oracle Database** 19c, 21c, or 23ai (e.g. Oracle Database 23ai Free).
- **Oracle SQL Developer**, **SQLcl**, or **SQL*Plus**.
- **Power BI Desktop** (latest version).

### Step 1: Initialize User & Tablespace (Run as `SYS` / `SYSTEM`)
Connect as `SYS AS SYSDBA` or `SYSTEM` to your pluggable database (e.g. `FREEPDB1`):
```sql
@database/deploy/00_init_user_tablespace.sql
```
*This creates user `RETAIL_OLTP` (password `oracle`) with tablespace `TS_RETAIL_OMNICANAL_OLTP` and necessary grants.*

### Step 2: Run End-to-End Automated Deployment
Connect as `RETAIL_OLTP` to the pluggable database and execute:
```sql
@database/deploy/deploy_all.sql
```
This single master script automatically executes:
1. All 17 OLTP tables and relational constraints.
2. Catalogs and full 9 months of sales data (1,133 transactions).
3. Controlled error cases for quality testing.
4. Currency normalization, audit, and staging infrastructure.
5. Kimball Star Schema Data Warehouse.
6. Data Quality engine and JSON electronic invoicing.
7. Materialized Views.
8. Complete ETL pipeline execution (`PKG_ETL_VENTAS.PR_EJECUTAR_ETL_COMPLETO`).
9. Full QA integration test battery (36 tests) and mathematical zero-discrepancy reconciliation.

### Step 3: Open Analytics Dashboard
Open `bi/Retail Omnicanal.pbix` in **Power BI Desktop**. All visuals will render instantly from the packaged data model.

---

## Technical Highlights & Best Practices

- **Zero-Discrepancy Accounting**: 100% mathematical reconciliation between raw OLTP currencies, Staging calculations, Star Schema fact lines, and Materialized Views.
- **Defensive Data Quality Engine**: Comprehensive automated validation catching negative values, future dates, orphaned foreign keys, and currency anomalies prior to DW ingestion.
- **Cryptographic Compliance**: Electronic invoice generation storing JSON documents with SHA-256 signatures generated via Oracle `DBMS_CRYPTO`.
- **Query Performance Optimization**: Pre-aggregated fast materialized views (`BUILD IMMEDIATE REFRESH COMPLETE`) accelerating Power BI slicing queries by over 95%.
- **Clean Architecture & Separation of Concerns**: Rigorous separation between schema definition (`ddl/`), seed data (`dml/`), stored logic (`plsql/`), test suites (`tests/`), and deployment orchestration (`deploy/`).

---

## Author
Developed as an enterprise-grade Business Intelligence & Data Engineering portfolio project.
