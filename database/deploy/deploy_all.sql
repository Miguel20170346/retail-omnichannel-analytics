-- =====================================================================
-- MASTER DEPLOYMENT SCRIPT: RETAIL OMNICHANNEL ANALYTICS
-- Target Database: Oracle Database 19c / 21c / 23ai
-- Schema: RETAIL_OLTP | Tablespace: TS_RETAIL_OMNICANAL_OLTP
-- =====================================================================
SET ECHO OFF
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SPOOL deploy_retail_bi.log

PROMPT =====================================================================
PROMPT [STEP 1/14] DDL: Creating OLTP Normalized Schema (17 Tables)
PROMPT =====================================================================
@@../ddl/01_oltp_tables.sql

PROMPT =====================================================================
PROMPT [STEP 2/14] DML: Seeding Catalogs and September Baseline Transactions
PROMPT =====================================================================
@@../dml/01_seed_catalog_and_september.sql

PROMPT =====================================================================
PROMPT [STEP 3/14] DML: Seeding 9-Month Full Historical Sales (Jan - Aug)
PROMPT =====================================================================
@@../dml/02_seed_history_jan_aug.sql

PROMPT =====================================================================
PROMPT [STEP 4/14] DML: Injecting Controlled Quality Test Cases
PROMPT =====================================================================
@@../dml/03_controlled_error_cases.sql

PROMPT =====================================================================
PROMPT [STEP 5/14] PL/SQL: Compiling Multi-Currency Conversion Engine (PKG_DIVISAS)
PROMPT =====================================================================
@@../plsql/pkg_divisas.sql

PROMPT =====================================================================
PROMPT [STEP 6/14] DDL & PL/SQL: Audit Log Infrastructure and Error Handling
PROMPT =====================================================================
@@../plsql/pkg_auditoria.sql

PROMPT =====================================================================
PROMPT [STEP 7/14] DDL: Staging Area Definition
PROMPT =====================================================================
@@../ddl/02_staging_tables.sql

PROMPT =====================================================================
PROMPT [STEP 8/14] DDL: Kimball Star Schema Data Warehouse (Fact & 7 Dimensions)
PROMPT =====================================================================
@@../ddl/03_dw_star_schema.sql

PROMPT =====================================================================
PROMPT [STEP 9/14] PL/SQL: Data Quality & Governance Engine (PKG_CALIDAD_DATOS)
PROMPT =====================================================================
@@../plsql/pkg_calidad_datos.sql

PROMPT =====================================================================
PROMPT [STEP 10/14] DDL: Electronic Invoicing (JSON-Relational & SHA-256 Signature)
PROMPT =====================================================================
@@../ddl/04_facturas_json.sql

PROMPT =====================================================================
PROMPT [STEP 11/14] DDL: Pre-aggregated Materialized Views for Power BI Layer
PROMPT =====================================================================
@@../ddl/05_materialized_views.sql

PROMPT =====================================================================
PROMPT [STEP 12/14] PL/SQL: Core ETL & Pipeline Orchestration (PKG_ETL_VENTAS)
PROMPT =====================================================================
@@../plsql/pkg_etl_ventas.sql

PROMPT =====================================================================
PROMPT [STEP 13/14] Pipeline Execution: Triggering End-to-End Extraction & Load
PROMPT =====================================================================
BEGIN
    PKG_ETL_VENTAS.PR_EJECUTAR_ETL_COMPLETO;
END;
/

PROMPT =====================================================================
PROMPT [STEP 14/14] Automated QA Integration Test Battery (36 Tests)
PROMPT =====================================================================
@@../tests/01_qa_integration_36_tests.sql

PROMPT =====================================================================
PROMPT Validating Mathematical Reconciliation (Zero-Discrepancy Check)
PROMPT =====================================================================
@@../tests/02_reconciliation_checks.sql

PROMPT =====================================================================
PROMPT Historical 9-Month Volume & KPI Verification
PROMPT =====================================================================
@@../tests/04_historical_validation.sql

SPOOL OFF
PROMPT =====================================================================
PROMPT DEPLOYMENT AND DATA PIPELINE EXECUTED WITH 100% SUCCESS!
PROMPT See deploy_retail_bi.log for execution log details.
PROMPT =====================================================================
