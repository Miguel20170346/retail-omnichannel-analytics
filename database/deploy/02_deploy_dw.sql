-- =====================================================================
-- 02 - DESPLIEGUE DE LA CAPA ANALÍTICA, ETL Y 40 PRUEBAS QA (OMNI_DW)
-- ---------------------------------------------------------------------
-- EJECUTAR COMO: OMNI_DW   (localhost:1521/FREEPDB1)
-- Requisito previo: 01_deploy_oltp.sql (como OMNI_OLTP)
-- =====================================================================
SET ECHO OFF
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SPOOL deploy_02_dw.log

PROMPT === [1/13] Seguridad: 19 Sinónimos Privados hacia OMNI_OLTP ===
@@../security/02_synonyms_dw_to_oltp.sql

PROMPT === [2/13] DDL & PL/SQL: Auditoría y Registro de Errores del ETL ===
@@../plsql/pkg_auditoria.sql

PROMPT === [3/13] DDL: Área Intermedia de Staging ===
@@../ddl/02_staging_tables.sql

PROMPT === [4/13] DDL: Data Warehouse en Modelo Estrella (Kimball) ===
@@../ddl/03_dw_star_schema.sql

PROMPT === [5/13] PL/SQL: Motor de Calidad de Datos (12 Reglas R01-R12) ===
@@../plsql/pkg_calidad_datos.sql

PROMPT === [6/13] DDL & PL/SQL: Facturación Electrónica JSON + Firma SHA-256 ===
@@../ddl/04_facturas_json.sql

PROMPT === [7/13] DDL: 5 Vistas Materializadas para Power BI ===
@@../ddl/05_materialized_views.sql

PROMPT === [8/13] PL/SQL: Orquestador ETL Incremental (PKG_ETL_VENTAS) ===
@@../plsql/pkg_etl_ventas.sql

PROMPT === Verificación de objetos inválidos en OMNI_DW ===
SELECT OBJECT_TYPE, OBJECT_NAME FROM USER_OBJECTS WHERE STATUS <> 'VALID';

PROMPT === [9/13] Seguridad: Permisos SELECT hacia ROL_OMNI_LECTURA_BI ===
@@../security/03_grants_dw_to_bi_role.sql

PROMPT === [10/13] Ejecución Completa del Pipeline ETL ===
BEGIN
  PKG_ETL_VENTAS.PR_EJECUTAR_ETL;
END;
/

PROMPT === [11/13] Batería de 40 Pruebas de Integración y Seguridad QA ===
@@../tests/01_qa_integration_40_tests.sql

PROMPT === [12/13] Conciliación Matemática Cero-Diferencias ===
@@../tests/02_reconciliation_checks.sql

PROMPT === [13/13] Validación de Volumen Histórico de 9 Meses ===
@@../tests/04_historical_validation.sql

SPOOL OFF
PROMPT =====================================================================
PROMPT Capa OMNI_DW desplegada, cargada y validada (40/40 pruebas QA).
PROMPT Siguiente paso: conectarse como OMNI_BI y ejecutar 03_verify_bi_readonly.sql
PROMPT =====================================================================
