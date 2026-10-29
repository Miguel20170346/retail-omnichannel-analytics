-- =====================================================================
-- DESPLIEGUE MAESTRO DE UN SOLO CLIC (ARQUITECTURA DE 3 ESQUEMAS)
-- ---------------------------------------------------------------------
-- EJECUTAR COMO: SYS (AS SYSDBA) conectado a localhost:1521/freepdb1
-- En SQL Developer: abrir con la conexión "dba" (SYS) y presionar F5.
--
-- Usa ALTER SESSION SET CURRENT_SCHEMA + funciones AUTHID DEFINER para
-- desplegar y auditar los 3 esquemas (OMNI_OLTP, OMNI_DW, OMNI_BI) en
-- una sola corrida continua compatible con SQL Developer clásico.
-- No toca ni interfiere con instalaciones previas de RETAIL_OLTP.
-- =====================================================================
SET ECHO OFF
SET VERIFY OFF
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SPOOL deploy_all_multischema.log

PROMPT =====================================================================
PROMPT [FASE 0/3] SYS: Preparando 2 Tablespaces, Rol RBAC y 3 Usuarios OMNI_*
PROMPT =====================================================================
DECLARE
  v_pdb VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CON_NAME');
BEGIN
  IF v_pdb = 'CDB$ROOT' THEN
    RAISE_APPLICATION_ERROR(-20000, 'Conéctese al servicio freepdb1 (no a CDB$ROOT).');
  END IF;
  IF USER <> 'SYS' AND SYS_CONTEXT('USERENV', 'ISDBA') <> 'TRUE' THEN
    RAISE_APPLICATION_ERROR(-20001, 'Ejecute este instalador con conexión SYS AS SYSDBA.');
  END IF;

  FOR u IN (SELECT USERNAME FROM DBA_USERS
             WHERE USERNAME IN ('OMNI_BI', 'OMNI_DW', 'OMNI_OLTP')
             ORDER BY DECODE(USERNAME, 'OMNI_BI', 1, 'OMNI_DW', 2, 3)) LOOP
    EXECUTE IMMEDIATE 'DROP USER ' || u.USERNAME || ' CASCADE';
  END LOOP;

  FOR r IN (SELECT ROLE FROM DBA_ROLES WHERE ROLE = 'ROL_OMNI_LECTURA_BI') LOOP
    EXECUTE IMMEDIATE 'DROP ROLE ' || r.ROLE;
  END LOOP;

  FOR ts IN (SELECT TABLESPACE_NAME FROM DBA_TABLESPACES
              WHERE TABLESPACE_NAME IN ('TS_OMNI_DW', 'TS_OMNI_OLTP')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLESPACE ' || ts.TABLESPACE_NAME || ' INCLUDING CONTENTS AND DATAFILES';
  END LOOP;
END;
/

@@00_init_schemas_and_roles.sql
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

PROMPT =====================================================================
PROMPT [FASE 1/3] Desplegando Capa Transaccional en esquema OMNI_OLTP...
PROMPT =====================================================================
ALTER SESSION SET CURRENT_SCHEMA = OMNI_OLTP;

@@../ddl/01_oltp_tables.sql
SET FEEDBACK OFF
@@../dml/01_seed_catalog_and_september.sql
@@../dml/02_seed_history_jan_aug.sql
SET FEEDBACK ON
@@../dml/03_controlled_error_cases.sql
@@../plsql/pkg_divisas.sql
@@../security/01_grants_oltp_to_dw.sql

SELECT OWNER, OBJECT_TYPE, OBJECT_NAME
  FROM ALL_OBJECTS
 WHERE OWNER = 'OMNI_OLTP' AND STATUS <> 'VALID';

PROMPT =====================================================================
PROMPT [FASE 2/3] Desplegando Data Warehouse y ETL en esquema OMNI_DW...
PROMPT =====================================================================
ALTER SESSION SET CURRENT_SCHEMA = OMNI_DW;

@@../security/02_synonyms_dw_to_oltp.sql
@@../plsql/pkg_auditoria.sql
@@../ddl/02_staging_tables.sql
@@../ddl/03_dw_star_schema.sql
@@../plsql/pkg_calidad_datos.sql
@@../ddl/04_facturas_json.sql
@@../ddl/05_materialized_views.sql
@@../plsql/pkg_etl_ventas.sql

SELECT OWNER, OBJECT_TYPE, OBJECT_NAME
  FROM ALL_OBJECTS
 WHERE OWNER = 'OMNI_DW' AND STATUS <> 'VALID';

@@../security/03_grants_dw_to_bi_role.sql

BEGIN
  PKG_ETL_VENTAS.PR_EJECUTAR_ETL;
END;
/

@@../tests/01_qa_integration_40_tests.sql
@@../tests/02_reconciliation_checks.sql
@@../tests/04_historical_validation.sql

PROMPT =====================================================================
PROMPT [FASE 3/3] Auditando permisos efectivos y aislamiento de OMNI_BI...
PROMPT =====================================================================
DECLARE
  v_ok    NUMBER := 0;
  v_tot   NUMBER := 0;
  v_n1    NUMBER;
  v_n2    NUMBER;
  v_monto NUMBER;

  PROCEDURE chk_bi (p_cod VARCHAR2, p_desc VARCHAR2, p_cond BOOLEAN, p_det VARCHAR2) IS
  BEGIN
    v_tot := v_tot + 1;
    IF p_cond THEN
      v_ok := v_ok + 1;
      DBMS_OUTPUT.PUT_LINE('[PASA]  ' || p_cod || ' - ' || p_desc || ' (' || p_det || ')');
    ELSE
      DBMS_OUTPUT.PUT_LINE('[FALLA] ' || p_cod || ' - ' || p_desc || ' (' || p_det || ')');
    END IF;
  END;
BEGIN
  SELECT COUNT(*) INTO v_n1 FROM DBA_ROLE_PRIVS
   WHERE GRANTEE = 'OMNI_BI' AND GRANTED_ROLE = 'ROL_OMNI_LECTURA_BI';
  SELECT COUNT(*) INTO v_n2 FROM DBA_TAB_PRIVS
   WHERE GRANTEE = 'ROL_OMNI_LECTURA_BI' AND OWNER = 'OMNI_DW' AND PRIVILEGE = 'SELECT'
     AND TABLE_NAME IN ('MV_VENTAS_MENSUALES','MV_TOP_PRODUCTOS','MV_FRECUENCIA_CLIENTES',
                        'MV_UTILIDAD_POR_CATEGORIA','MV_PROMOCIONES_USADAS','V_BI_LINEAS');
  SELECT NVL(SUM(TOTAL_LINEA_USD), 0) INTO v_monto FROM OMNI_DW.V_BI_LINEAS;
  chk_bi('B01', 'OMNI_BI recibe ROL_OMNI_LECTURA_BI con lectura a las 5 MVs + V_BI_LINEAS',
         v_n1 = 1 AND v_n2 = 6 AND v_monto = 2222088.30,
         'vistas_bi=' || v_n2 || ', total_usd=' || TO_CHAR(v_monto, 'FM9,999,990.00'));

  SELECT COUNT(*) INTO v_n1 FROM DBA_TAB_PRIVS
   WHERE GRANTEE = 'ROL_OMNI_LECTURA_BI' AND OWNER = 'OMNI_DW' AND PRIVILEGE = 'SELECT'
     AND (TABLE_NAME = 'HECHOS_VENTAS' OR TABLE_NAME LIKE 'DIM\_%' ESCAPE '\');
  chk_bi('B02', 'OMNI_BI tiene SELECT sobre el Modelo Estrella (HECHOS_VENTAS + 7 DIM_*)',
         v_n1 = 8, 'tablas_estrella=' || v_n1);

  SELECT COUNT(*) INTO v_n1 FROM DBA_TAB_PRIVS
   WHERE GRANTEE IN ('OMNI_BI', 'ROL_OMNI_LECTURA_BI') AND OWNER = 'OMNI_OLTP';
  chk_bi('B03', 'OMNI_BI tiene 0 permisos sobre el esquema transaccional OMNI_OLTP',
         v_n1 = 0, 'permisos_oltp=' || v_n1);

  SELECT COUNT(*) INTO v_n1 FROM DBA_TAB_PRIVS
   WHERE GRANTEE IN ('OMNI_BI', 'ROL_OMNI_LECTURA_BI') AND TABLE_NAME LIKE 'STG\_%' ESCAPE '\';
  chk_bi('B04', 'OMNI_BI tiene 0 permisos sobre el area de Staging (STG_*)',
         v_n1 = 0, 'permisos_stg=' || v_n1);

  SELECT COUNT(*) INTO v_n1 FROM DBA_TAB_PRIVS
   WHERE GRANTEE IN ('OMNI_BI', 'ROL_OMNI_LECTURA_BI') AND TABLE_NAME = 'FACTURAS_JSON';
  chk_bi('B05', 'OMNI_BI tiene 0 permisos sobre FACTURAS_JSON (datos sensibles)',
         v_n1 = 0, 'permisos_json=' || v_n1);

  SELECT COUNT(*) INTO v_n1 FROM DBA_TAB_PRIVS
   WHERE GRANTEE IN ('OMNI_BI', 'ROL_OMNI_LECTURA_BI')
     AND TABLE_NAME IN ('AUDITORIA_ETL_VENTAS', 'ERRORES_ETL_VENTAS');
  chk_bi('B06', 'OMNI_BI tiene 0 permisos sobre AUDITORIA_ETL_VENTAS y ERRORES_ETL_VENTAS',
         v_n1 = 0, 'permisos_logs=' || v_n1);

  SELECT COUNT(*) INTO v_n1 FROM DBA_TAB_PRIVS
   WHERE GRANTEE IN ('OMNI_BI', 'ROL_OMNI_LECTURA_BI') AND PRIVILEGE <> 'SELECT';
  chk_bi('B07', 'OMNI_BI tiene 0 permisos de escritura (INSERT/UPDATE/DELETE) en la BD',
         v_n1 = 0, 'permisos_escritura=' || v_n1);

  SELECT COUNT(*) INTO v_n1 FROM DBA_SYS_PRIVS
   WHERE GRANTEE IN ('OMNI_BI', 'ROL_OMNI_LECTURA_BI') AND PRIVILEGE <> 'CREATE SESSION';
  SELECT COUNT(*) INTO v_n2 FROM DBA_TS_QUOTAS WHERE USERNAME = 'OMNI_BI' AND MAX_BYTES <> 0;
  chk_bi('B08', 'OMNI_BI solo posee CREATE SESSION y 0 MB de cuota en tablespaces',
         v_n1 = 0 AND v_n2 = 0, 'privs_extra=' || v_n1 || ', cuotas=' || v_n2);

  DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------');
  DBMS_OUTPUT.PUT_LINE('AUDITORIA OMNI_BI: ' || v_ok || ' de ' || v_tot || ' controles de seguridad PASAN');
  DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------');

  IF v_ok <> v_tot THEN
    RAISE_APPLICATION_ERROR(-20090, 'Falló auditoría de seguridad de OMNI_BI');
  END IF;
END;
/

SELECT COUNT(DISTINCT CODIGO_TRANSACCION) AS TRANSACCIONES,
       COUNT(*) AS LINEAS_HECHOS,
       SUM(MONTO_NETO_USD) AS VENTA_NETA_USD,
       SUM(TOTAL_LINEA_USD) AS VENTA_TOTAL_USD,
       SUM(COSTO_TOTAL_USD) AS COSTO_USD,
       SUM(MARGEN_BRUTO_USD) AS UTILIDAD_USD
  FROM OMNI_DW.V_BI_LINEAS;

ALTER SESSION SET CURRENT_SCHEMA = SYS;
SPOOL OFF
PROMPT =====================================================================
PROMPT ¡DESPLIEGUE MULTI-ESQUEMA COMPLETADO DE UN SOLO GOLPE (40/40 QA + 8/8 BI)!
PROMPT =====================================================================
