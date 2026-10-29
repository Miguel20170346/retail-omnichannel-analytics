-- =====================================================================
-- 09 - PERMISOS DEL DATA WAREHOUSE HACIA EL ROL DE BI
-- ---------------------------------------------------------------------
-- EJECUTAR COMO: OMNI_DW   (despues de crear vistas y ETL)
--
-- Se otorga SELECT al ROL (ROL_OMNI_LECTURA_BI), no al usuario: asi un
-- nuevo analista solo necesita recibir el rol.
--
-- SE EXPONE (datos de negocio ya validados):
--   * Las 5 vistas materializadas MV_*  (lo que usa Power BI)
--   * V_BI_LINEAS                       (detalle por linea, exportacion CSV)
--   * HECHOS_VENTAS y las 7 DIM_*       (modelo estrella para analisis libre)
--
-- NO SE EXPONE (internos de ingenieria de datos):
--   * STG_*                  datos crudos, pueden contener errores
--   * AUDITORIA_ / ERRORES_  operacion del ETL
--   * FACTURAS_JSON          documentos con datos personales del cliente
--   * QA_RESULTADOS          evidencia de pruebas
--   * V_BI_PROMOCIONES       lee una tabla del OLTP; exponerla obligaria a
--                            dar GRANT ... WITH GRANT OPTION desde el OLTP.
--                            Power BI usa MV_PROMOCIONES_USADAS en su lugar.
-- =====================================================================

-- Capa semantica para Power BI
GRANT SELECT ON MV_VENTAS_MENSUALES       TO ROL_OMNI_LECTURA_BI;
GRANT SELECT ON MV_TOP_PRODUCTOS          TO ROL_OMNI_LECTURA_BI;
GRANT SELECT ON MV_FRECUENCIA_CLIENTES    TO ROL_OMNI_LECTURA_BI;
GRANT SELECT ON MV_UTILIDAD_POR_CATEGORIA TO ROL_OMNI_LECTURA_BI;
GRANT SELECT ON MV_PROMOCIONES_USADAS     TO ROL_OMNI_LECTURA_BI;
GRANT SELECT ON V_BI_LINEAS               TO ROL_OMNI_LECTURA_BI;

-- Modelo estrella
GRANT SELECT ON HECHOS_VENTAS   TO ROL_OMNI_LECTURA_BI;
GRANT SELECT ON DIM_FECHA       TO ROL_OMNI_LECTURA_BI;
GRANT SELECT ON DIM_CLIENTE     TO ROL_OMNI_LECTURA_BI;
GRANT SELECT ON DIM_PRODUCTO    TO ROL_OMNI_LECTURA_BI;
GRANT SELECT ON DIM_CANAL       TO ROL_OMNI_LECTURA_BI;
GRANT SELECT ON DIM_EMPLEADO    TO ROL_OMNI_LECTURA_BI;
GRANT SELECT ON DIM_PROMOCION   TO ROL_OMNI_LECTURA_BI;
GRANT SELECT ON DIM_METODO_PAGO TO ROL_OMNI_LECTURA_BI;

-- Evidencia: lo que OMNI_DW otorgo al rol (compatible con ejecucion directa o via SYS)
SET SERVEROUTPUT ON
DECLARE
  v_rc      SYS_REFCURSOR;
  v_grantee VARCHAR2(128);
  v_tabla   VARCHAR2(128);
  v_priv    VARCHAR2(40);
  v_total   NUMBER := 0;
BEGIN
  IF SYS_CONTEXT('USERENV', 'ISDBA') = 'TRUE' THEN
    OPEN v_rc FOR
      'SELECT GRANTEE, TABLE_NAME, PRIVILEGE FROM DBA_TAB_PRIVS
        WHERE OWNER = ''OMNI_DW'' AND GRANTEE = ''ROL_OMNI_LECTURA_BI''
        ORDER BY TABLE_NAME';
  ELSE
    OPEN v_rc FOR
      SELECT GRANTEE, TABLE_NAME, PRIVILEGE FROM USER_TAB_PRIVS
       WHERE OWNER = 'OMNI_DW' AND GRANTEE = 'ROL_OMNI_LECTURA_BI'
       ORDER BY TABLE_NAME;
  END IF;
  LOOP
    FETCH v_rc INTO v_grantee, v_tabla, v_priv;
    EXIT WHEN v_rc%NOTFOUND;
    v_total := v_total + 1;
  END LOOP;
  CLOSE v_rc;
  DBMS_OUTPUT.PUT_LINE('Permisos verificados OMNI_DW -> ROL_OMNI_LECTURA_BI: ' || v_total || ' de 14');
END;
/

PROMPT 09 - 14 permisos SELECT otorgados a ROL_OMNI_LECTURA_BI
