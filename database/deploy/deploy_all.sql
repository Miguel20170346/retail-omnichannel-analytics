-- =====================================================================
-- SCRIPT MAESTRO DE DESPLIEGUE: RETAIL OMNICANAL ANALYTICS
-- Base de Datos: Oracle Database 19c / 21c / 23ai
-- Esquema: RETAIL_OLTP | Tablespace: TS_RETAIL_OMNICANAL_OLTP
-- =====================================================================
SET ECHO OFF
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SPOOL despliegue_retail_bi.log

PROMPT =====================================================================
PROMPT [PASO 1/14] DDL: Creando Modelo Relacional OLTP Normalizado (17 Tablas)
PROMPT =====================================================================
@@../ddl/01_oltp_tables.sql

PROMPT =====================================================================
PROMPT [PASO 2/14] DML: Insertando Catálogos y Ventas Base de Septiembre
PROMPT =====================================================================
@@../dml/01_seed_catalog_and_september.sql

PROMPT =====================================================================
PROMPT [PASO 3/14] DML: Insertando Histórico Completo de 9 Meses (Enero a Agosto)
PROMPT =====================================================================
@@../dml/02_seed_history_jan_aug.sql

PROMPT =====================================================================
PROMPT [PASO 4/14] DML: Insertando Casos de Prueba con Errores Controlados
PROMPT =====================================================================
@@../dml/03_controlled_error_cases.sql

PROMPT =====================================================================
PROMPT [PASO 5/14] PL/SQL: Compilando Motor de Conversión Multidivisa a USD (PKG_DIVISAS)
PROMPT =====================================================================
@@../plsql/pkg_divisas.sql

PROMPT =====================================================================
PROMPT [PASO 6/14] DDL & PL/SQL: Infraestructura de Auditoría y Manejo de Errores
PROMPT =====================================================================
@@../plsql/pkg_auditoria.sql

PROMPT =====================================================================
PROMPT [PASO 7/14] DDL: Creando Capa Intermedia de Staging
PROMPT =====================================================================
@@../ddl/02_staging_tables.sql

PROMPT =====================================================================
PROMPT [PASO 8/14] DDL: Data Warehouse en Modelo Estrella Kimball (Hechos y 7 Dimensiones)
PROMPT =====================================================================
@@../ddl/03_dw_star_schema.sql

PROMPT =====================================================================
PROMPT [PASO 9/14] PL/SQL: Motor de Reglas de Calidad de Datos (PKG_CALIDAD_DATOS)
PROMPT =====================================================================
@@../plsql/pkg_calidad_datos.sql

PROMPT =====================================================================
PROMPT [PASO 10/14] DDL: Facturación Electrónica JSON y Firma Criptográfica SHA-256
PROMPT =====================================================================
@@../ddl/04_facturas_json.sql

PROMPT =====================================================================
PROMPT [PASO 11/14] DDL: Creando Vistas Materializadas para Capa de Power BI
PROMPT =====================================================================
@@../ddl/05_materialized_views.sql

PROMPT =====================================================================
PROMPT [PASO 12/14] PL/SQL: Compilando Paquete Orquestador ETL (PKG_ETL_VENTAS)
PROMPT =====================================================================
@@../plsql/pkg_etl_ventas.sql

PROMPT =====================================================================
PROMPT [PASO 13/14] Ejecución del Pipeline: Extracción, Limpieza y Carga al DW
PROMPT =====================================================================
BEGIN
    PKG_ETL_VENTAS.PR_EJECUTAR_ETL;
END;
/

PROMPT =====================================================================
PROMPT [PASO 14/14] Batería de Pruebas de Integración QA Automatizadas (36 Pruebas)
PROMPT =====================================================================
@@../tests/01_qa_integration_36_tests.sql

PROMPT =====================================================================
PROMPT Validando Conciliación Matemática (Verificación de Cero Diferencias)
PROMPT =====================================================================
@@../tests/02_reconciliation_checks.sql

PROMPT =====================================================================
PROMPT Verificando Volumen Histórico de los 9 Meses y KPIs de Negocio
PROMPT =====================================================================
@@../tests/04_historical_validation.sql

SPOOL OFF
PROMPT =====================================================================
PROMPT ¡DESPLIEGUE Y PIPELINE DE DATOS EJECUTADO AL 100% CON ÉXITO!
PROMPT Revise despliegue_retail_bi.log para ver el detalle de ejecución.
PROMPT =====================================================================
