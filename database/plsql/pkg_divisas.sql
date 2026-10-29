-- =====================================================================
-- 04 - MODULO DE CONVERSION DE DIVISAS                Responsable: Bryan
-- ---------------------------------------------------------------------
-- Regla comun: TASA_USD = cuantos USD vale 1 unidad de la moneda origen.
--   USD = monto_origen * TASA_USD
-- Se busca la tasa EXACTA de la fecha (sin hora) de la transaccion.
-- Si no existe tasa valida -> la transaccion se rechaza (no se inventa
-- ni se usa la del dia anterior). Ver regla R04 en 08_CALIDAD_DATOS.
-- =====================================================================
SET DEFINE OFF

CREATE OR REPLACE PACKAGE PKG_DIVISAS AS
  -- Error lanzado cuando no hay tasa (codigo propio del proyecto)
  e_sin_tasa EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_sin_tasa, -20010);

  -- Devuelve la tasa USD o NULL si no existe / moneda no soportada
  FUNCTION FN_OBTENER_TASA (p_moneda VARCHAR2, p_fecha DATE) RETURN NUMBER;

  -- Convierte a USD. Lanza ORA-20010 si no hay tasa.
  FUNCTION FN_CONVERTIR_USD (p_monto NUMBER, p_moneda VARCHAR2, p_fecha DATE) RETURN NUMBER;

  -- Conversion entre cualquier par USD/EUR/GTQ (pasando por USD).
  FUNCTION FN_CONVERTIR (p_monto NUMBER, p_moneda_origen VARCHAR2,
                         p_moneda_destino VARCHAR2, p_fecha DATE) RETURN NUMBER;

  -- 'S' si existe tasa valida, 'N' si no (util en SQL y en calidad)
  FUNCTION FN_TIENE_TASA (p_moneda VARCHAR2, p_fecha DATE) RETURN VARCHAR2;
END PKG_DIVISAS;
/

CREATE OR REPLACE PACKAGE BODY PKG_DIVISAS AS

  FUNCTION FN_OBTENER_TASA (p_moneda VARCHAR2, p_fecha DATE) RETURN NUMBER IS
    v_tasa NUMBER;
  BEGIN
    IF p_moneda IS NULL OR p_fecha IS NULL THEN
      RETURN NULL;
    END IF;
    IF p_moneda = 'USD' THEN
      -- USD tambien debe existir en la tabla para mantener trazabilidad,
      -- pero si falta se asume 1 (es la moneda base).
      BEGIN
        SELECT TASA_USD INTO v_tasa FROM TRX_MONEDAS
         WHERE MONEDA_ORIGEN = 'USD' AND FECHA = TRUNC(p_fecha) AND ACTIVO = 'S';
      EXCEPTION WHEN NO_DATA_FOUND THEN v_tasa := 1;
      END;
      RETURN v_tasa;
    END IF;

    SELECT TASA_USD INTO v_tasa
      FROM TRX_MONEDAS
     WHERE MONEDA_ORIGEN = UPPER(p_moneda)
       AND FECHA = TRUNC(p_fecha)
       AND ACTIVO = 'S'
       AND TASA_USD > 0;
    RETURN v_tasa;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
  END FN_OBTENER_TASA;

  FUNCTION FN_CONVERTIR_USD (p_monto NUMBER, p_moneda VARCHAR2, p_fecha DATE) RETURN NUMBER IS
    v_tasa NUMBER := FN_OBTENER_TASA(p_moneda, p_fecha);
  BEGIN
    IF v_tasa IS NULL THEN
      RAISE_APPLICATION_ERROR(-20010,
        'Sin tasa valida para ' || p_moneda || ' en ' || TO_CHAR(p_fecha, 'YYYY-MM-DD'));
    END IF;
    RETURN ROUND(p_monto * v_tasa, 2);
  END FN_CONVERTIR_USD;

  FUNCTION FN_CONVERTIR (p_monto NUMBER, p_moneda_origen VARCHAR2,
                         p_moneda_destino VARCHAR2, p_fecha DATE) RETURN NUMBER IS
    v_tasa_origen  NUMBER := FN_OBTENER_TASA(p_moneda_origen, p_fecha);
    v_tasa_destino NUMBER := FN_OBTENER_TASA(p_moneda_destino, p_fecha);
  BEGIN
    IF v_tasa_origen IS NULL OR v_tasa_destino IS NULL THEN
      RAISE_APPLICATION_ERROR(-20010,
        'Sin tasa valida para ' || p_moneda_origen || '/' || p_moneda_destino
        || ' en ' || TO_CHAR(p_fecha, 'YYYY-MM-DD'));
    END IF;
    RETURN ROUND(p_monto * v_tasa_origen / v_tasa_destino, 2);
  END FN_CONVERTIR;

  FUNCTION FN_TIENE_TASA (p_moneda VARCHAR2, p_fecha DATE) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN FN_OBTENER_TASA(p_moneda, p_fecha) IS NULL THEN 'N' ELSE 'S' END;
  END FN_TIENE_TASA;

END PKG_DIVISAS;
/

-- Identificador de negocio TX-{CANAL}-{YYYYMMDD}-{SEQ} (decision punto 1)
-- SEQ = ID_TRANSACCION con 6 digitos. Se calcula, no se almacena en OLTP.
CREATE OR REPLACE FUNCTION FN_CODIGO_TRANSACCION (
  p_codigo_canal VARCHAR2, p_fecha TIMESTAMP, p_id_transaccion NUMBER
) RETURN VARCHAR2 DETERMINISTIC IS
BEGIN
  RETURN 'TX-' || p_codigo_canal || '-' || TO_CHAR(p_fecha, 'YYYYMMDD')
         || '-' || LPAD(TO_CHAR(p_id_transaccion), 6, '0');
END;
/

PROMPT 04 - Modulo de divisas y codigo de transaccion creados
