-- =====================================================================
-- 01 - DESPLIEGUE DE LA CAPA TRANSACCIONAL (ESQUEMA OMNI_OLTP)
-- ---------------------------------------------------------------------
-- EJECUTAR COMO: OMNI_OLTP   (localhost:1521/FREEPDB1)
-- Requisito previo: 00_init_schemas_and_roles.sql (como SYS)
-- =====================================================================
SET ECHO OFF
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SPOOL deploy_01_oltp.log

PROMPT === [1/6] DDL: 17 Tablas Transaccionales Normalizadas (3NF) ===
@@../ddl/01_oltp_tables.sql

PROMPT === [2/6] DML: Catálogos y Ventas Base de Septiembre ===
@@../dml/01_seed_catalog_and_september.sql

PROMPT === [3/6] DML: Histórico de Ventas Enero - Agosto (9 Meses) ===
@@../dml/02_seed_history_jan_aug.sql

PROMPT === [4/6] DML: 8 Casos de Error Controlados para Pruebas de Calidad ===
@@../dml/03_controlled_error_cases.sql

PROMPT === [5/6] PL/SQL: Motor de Conversión de Divisas (PKG_DIVISAS) ===
@@../plsql/pkg_divisas.sql

PROMPT === [6/6] Seguridad: Permisos de Solo Lectura hacia OMNI_DW ===
@@../security/01_grants_oltp_to_dw.sql

PROMPT === Verificación de objetos inválidos en OMNI_OLTP ===
SELECT OBJECT_TYPE, OBJECT_NAME FROM USER_OBJECTS WHERE STATUS <> 'VALID';

SPOOL OFF
PROMPT =====================================================================
PROMPT Capa OMNI_OLTP desplegada al 100%.
PROMPT Siguiente paso: conectarse como OMNI_DW y ejecutar 02_deploy_dw.sql
PROMPT =====================================================================
