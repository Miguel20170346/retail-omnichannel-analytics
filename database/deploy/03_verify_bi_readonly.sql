-- =====================================================================
-- 03 - AUDITORÍA DE SEGURIDAD Y CONSULTAS KPI (ESQUEMA OMNI_BI)
-- ---------------------------------------------------------------------
-- EJECUTAR COMO: OMNI_BI   (localhost:1521/FREEPDB1)
-- Requisito previo: 02_deploy_dw.sql (como OMNI_DW)
-- =====================================================================
SET ECHO OFF
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SPOOL deploy_03_bi_readonly.log

PROMPT === [1/2] Auditoría Automática de Mínimo Privilegio (8 Controles) ===
@@../tests/07_bi_security_audit.sql

PROMPT === [2/2] Consultas Gerenciales de KPIs desde Cuenta de Solo Lectura ===
@@../tests/03_kpi_business_queries.sql

SPOOL OFF
PROMPT =====================================================================
PROMPT Verificación de OMNI_BI completada al 100% (8/8 controles de seguridad).
PROMPT =====================================================================
