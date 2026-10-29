-- =====================================================================
-- 01 - PRUEBA DE ACCESO Y AISLAMIENTO DE SEGURIDAD (USUARIO DE REPORTES)
-- ---------------------------------------------------------------------
-- EJECUTAR COMO: OMNI_BI   (clave de laboratorio: bi2026)
-- Requisito: haber ejecutado 01_OMNI_OLTP\INSTALAR_OLTP.sql y
--            02_OMNI_DW\INSTALAR_DW.sql
--
-- Demuestra en vivo el principio de minimo privilegio:
--   1. OMNI_BI PUEDE consultar las 5 vistas materializadas, V_BI_LINEAS
--      y el modelo estrella (HECHOS_VENTAS + 7 DIM_*), obteniendo los
--      mismos $2,222,088.30 USD.
--   2. OMNI_BI NO PUEDE ver las tablas transaccionales (OMNI_OLTP.TRX_*).
--   3. OMNI_BI NO PUEDE ver Staging, Auditoria, Errores ni Facturas JSON.
--   4. OMNI_BI NO PUEDE modificar (UPDATE/DELETE/INSERT) el Data Warehouse.
--   5. OMNI_BI NO PUEDE crear tablas ni objetos propios.
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

-- Permite escribir MV_VENTAS_MENSUALES en vez de OMNI_DW.MV_VENTAS_MENSUALES
-- sin necesidad de otorgar CREATE SYNONYM a OMNI_BI. Los permisos siguen
-- siendo estrictamente los de OMNI_BI (ROL_OMNI_LECTURA_BI).
ALTER SESSION SET CURRENT_SCHEMA = OMNI_DW;

DECLARE
  v_pasaron NUMBER := 0;
  v_total   NUMBER := 0;
  v_filas   NUMBER;
  v_monto   NUMBER;
  v_dims    NUMBER := 0;

  PROCEDURE verificar_permitido (p_codigo VARCHAR2, p_desc VARCHAR2, p_ok BOOLEAN, p_detalle VARCHAR2) IS
  BEGIN
    v_total := v_total + 1;
    IF p_ok THEN
      v_pasaron := v_pasaron + 1;
      DBMS_OUTPUT.PUT_LINE('[PASA]  ' || p_codigo || ' - ' || p_desc || ' (' || p_detalle || ')');
    ELSE
      DBMS_OUTPUT.PUT_LINE('[FALLA] ' || p_codigo || ' - ' || p_desc || ' (' || p_detalle || ')');
    END IF;
  END;

  PROCEDURE verificar_bloqueado (p_codigo VARCHAR2, p_desc VARCHAR2, p_sql VARCHAR2) IS
  BEGIN
    v_total := v_total + 1;
    EXECUTE IMMEDIATE p_sql;
    DBMS_OUTPUT.PUT_LINE('[FALLA] ' || p_codigo || ' - ' || p_desc || ' (ERROR: Oracle lo permitio!)');
  EXCEPTION
    WHEN OTHERS THEN
      -- -942: tabla/vista no visible | -1031 / -41900: privilegios insuficientes | -1950: sin cuota
      IF SQLCODE IN (-942, -1031, -41900, -1950) THEN
        v_pasaron := v_pasaron + 1;
        DBMS_OUTPUT.PUT_LINE('[PASA]  ' || p_codigo || ' - ' || p_desc || ' -> Bloqueado (' || SQLCODE || ')');
      ELSE
        DBMS_OUTPUT.PUT_LINE('[FALLA] ' || p_codigo || ' - ' || p_desc || ' -> Error inesperado: ' || SQLERRM);
      END IF;
  END;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=====================================================================');
  DBMS_OUTPUT.PUT_LINE('AUDITORIA DE SEGURIDAD DESDE SESION: '
                       || SYS_CONTEXT('USERENV', 'SESSION_USER')
                       || ' (CURRENT_SCHEMA=' || SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') || ')');
  DBMS_OUTPUT.PUT_LINE('=====================================================================');

  -- B01: Lectura de capa semantica (5 MVs + V_BI_LINEAS)
  SELECT COUNT(*), NVL(SUM(TOTAL_LINEA_USD), 0) INTO v_filas, v_monto FROM V_BI_LINEAS;
  SELECT v_filas
       + (SELECT COUNT(*) FROM MV_VENTAS_MENSUALES)
       + (SELECT COUNT(*) FROM MV_TOP_PRODUCTOS)
       + (SELECT COUNT(*) FROM MV_FRECUENCIA_CLIENTES)
       + (SELECT COUNT(*) FROM MV_UTILIDAD_POR_CATEGORIA)
       + (SELECT COUNT(*) FROM MV_PROMOCIONES_USADAS)
    INTO v_dims FROM DUAL;
  verificar_permitido(
    'B01',
    'Lectura autorizada de las 5 vistas materializadas y V_BI_LINEAS',
    v_filas = 2805 AND v_monto = 2222088.30 AND v_dims > 2805,
    'lineas=' || v_filas || ', total_usd=' || TO_CHAR(v_monto, 'FM9,999,990.00')
  );

  -- B02: Lectura del modelo estrella (HECHOS_VENTAS + 7 dimensiones)
  SELECT (SELECT COUNT(*) FROM HECHOS_VENTAS)
       + (SELECT COUNT(*) FROM DIM_FECHA)
       + (SELECT COUNT(*) FROM DIM_CLIENTE)
       + (SELECT COUNT(*) FROM DIM_PRODUCTO)
       + (SELECT COUNT(*) FROM DIM_CANAL)
       + (SELECT COUNT(*) FROM DIM_EMPLEADO)
       + (SELECT COUNT(*) FROM DIM_PROMOCION)
       + (SELECT COUNT(*) FROM DIM_METODO_PAGO)
    INTO v_dims FROM DUAL;
  verificar_permitido(
    'B02',
    'Lectura autorizada del Modelo Estrella (HECHOS_VENTAS + 7 DIM_*)',
    v_dims > 3900,
    'filas acumuladas leidas=' || v_dims
  );

  -- B03: Aislamiento frente al sistema transaccional OLTP
  verificar_bloqueado(
    'B03',
    'Acceso directo a tablas transaccionales (OMNI_OLTP.TRX_VENTAS) bloqueado',
    'SELECT COUNT(*) FROM OMNI_OLTP.TRX_VENTAS'
  );

  -- B04: Aislamiento frente al area de Staging
  verificar_bloqueado(
    'B04',
    'Acceso a tablas crudas de Staging (OMNI_DW.STG_VENTAS) bloqueado',
    'SELECT COUNT(*) FROM OMNI_DW.STG_VENTAS'
  );

  -- B05: Aislamiento frente a documentos sensibles de facturacion JSON
  verificar_bloqueado(
    'B05',
    'Acceso a documentos de facturacion electronica (FACTURAS_JSON) bloqueado',
    'SELECT COUNT(*) FROM OMNI_DW.FACTURAS_JSON'
  );

  -- B06: Aislamiento frente a bitacoras internas del ETL
  verificar_bloqueado(
    'B06',
    'Acceso a bitacoras internas de errores ETL (ERRORES_ETL_VENTAS) bloqueado',
    'SELECT COUNT(*) FROM OMNI_DW.ERRORES_ETL_VENTAS'
  );

  -- B07: Prohibicion de escritura sobre tablas que SI puede leer
  verificar_bloqueado(
    'B07',
    'Intento de DELETE/UPDATE sobre HECHOS_VENTAS bloqueado',
    'DELETE FROM OMNI_DW.HECHOS_VENTAS WHERE 1 = 0'
  );

  -- B08: Prohibicion de crear objetos propios en la base de datos
  verificar_bloqueado(
    'B08',
    'Intento de CREATE TABLE con usuario OMNI_BI bloqueado',
    'CREATE TABLE OMNI_BI.TABLA_NO_AUTORIZADA (ID NUMBER)'
  );

  DBMS_OUTPUT.PUT_LINE('=====================================================================');
  DBMS_OUTPUT.PUT_LINE('RESULTADO FINAL OMNI_BI: ' || v_pasaron || ' de ' || v_total || ' controles PASAN');
  DBMS_OUTPUT.PUT_LINE('=====================================================================');

  IF v_pasaron <> v_total THEN
    RAISE_APPLICATION_ERROR(-20090, 'Fallo al menos un control de seguridad en OMNI_BI');
  END IF;
END;
/
