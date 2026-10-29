-- =====================================================================
-- DESPLIEGUE MAESTRO DE UN SOLO CLIC (ARQUITECTURA DE 3 ESQUEMAS)
-- ---------------------------------------------------------------------
-- EJECUTAR COMO: SYS (AS SYSDBA) conectado a localhost:1521/freepdb1
-- En SQL Developer: abrir con la conexión "dba" (SYS) y presionar F5.
-- Cambia automáticamente de sesión (SYS -> OMNI_OLTP -> OMNI_DW -> OMNI_BI).
-- =====================================================================
SET ECHO OFF
SET VERIFY OFF
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SPOOL deploy_all_multischema.log

PROMPT =====================================================================
PROMPT [FASE 0/3] SYS: Creando 2 Tablespaces, Rol RBAC y 3 Usuarios OMNI_*
PROMPT =====================================================================
BEGIN
  IF SYS_CONTEXT('USERENV', 'CON_NAME') = 'CDB$ROOT' THEN
    RAISE_APPLICATION_ERROR(-20000, 'Conéctese al servicio freepdb1 (no a CDB$ROOT).');
  END IF;
END;
/

@@00_init_schemas_and_roles.sql

PROMPT =====================================================================
PROMPT [FASE 1/3] Conectando automáticamente como OMNI_OLTP...
PROMPT =====================================================================
CONNECT OMNI_OLTP/oltp2026@//localhost:1521/freepdb1
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
  IF USER <> 'OMNI_OLTP' THEN
    RAISE_APPLICATION_ERROR(-20001, 'Falló el cambio de sesión a OMNI_OLTP. Usuario actual: ' || USER);
  END IF;
END;
/

@@../ddl/01_oltp_tables.sql
SET FEEDBACK OFF
@@../dml/01_seed_catalog_and_september.sql
@@../dml/02_seed_history_jan_aug.sql
SET FEEDBACK ON
@@../dml/03_controlled_error_cases.sql
@@../plsql/pkg_divisas.sql
@@../security/01_grants_oltp_to_dw.sql

SELECT OBJECT_TYPE, OBJECT_NAME FROM USER_OBJECTS WHERE STATUS <> 'VALID';

PROMPT =====================================================================
PROMPT [FASE 2/3] Conectando automáticamente como OMNI_DW...
PROMPT =====================================================================
CONNECT OMNI_DW/dw2026@//localhost:1521/freepdb1
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
  IF USER <> 'OMNI_DW' THEN
    RAISE_APPLICATION_ERROR(-20002, 'Falló el cambio de sesión a OMNI_DW. Usuario actual: ' || USER);
  END IF;
END;
/

@@../security/02_synonyms_dw_to_oltp.sql
@@../plsql/pkg_auditoria.sql
@@../ddl/02_staging_tables.sql
@@../ddl/03_dw_star_schema.sql
@@../plsql/pkg_calidad_datos.sql
@@../ddl/04_facturas_json.sql
@@../ddl/05_materialized_views.sql
@@../plsql/pkg_etl_ventas.sql
SELECT OBJECT_TYPE, OBJECT_NAME FROM USER_OBJECTS WHERE STATUS <> 'VALID';

@@../security/03_grants_dw_to_bi_role.sql

BEGIN
  PKG_ETL_VENTAS.PR_EJECUTAR_ETL;
END;
/

@@../tests/01_qa_integration_40_tests.sql
@@../tests/02_reconciliation_checks.sql
@@../tests/04_historical_validation.sql

PROMPT =====================================================================
PROMPT [FASE 3/3] Conectando automáticamente como OMNI_BI (Solo Lectura)...
PROMPT =====================================================================
CONNECT OMNI_BI/bi2026@//localhost:1521/freepdb1
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
  IF USER <> 'OMNI_BI' THEN
    RAISE_APPLICATION_ERROR(-20003, 'Falló el cambio de sesión a OMNI_BI. Usuario actual: ' || USER);
  END IF;
END;
/

@@../tests/07_bi_security_audit.sql

SELECT COUNT(DISTINCT CODIGO_TRANSACCION) AS TRANSACCIONES,
       COUNT(*) AS LINEAS_HECHOS,
       SUM(MONTO_NETO_USD) AS VENTA_NETA_USD,
       SUM(TOTAL_LINEA_USD) AS VENTA_TOTAL_USD,
       SUM(COSTO_TOTAL_USD) AS COSTO_USD,
       SUM(MARGEN_BRUTO_USD) AS UTILIDAD_USD
  FROM V_BI_LINEAS;

SPOOL OFF
PROMPT =====================================================================
PROMPT ¡DESPLIEGUE MULTI-ESQUEMA COMPLETADO DE UN SOLO GOLPE (40/40 QA + 8/8 BI)!
PROMPT =====================================================================
