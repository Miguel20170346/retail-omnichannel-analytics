-- =====================================================================
-- 14 - PRUEBAS DE INTEGRACION DE PUNTA A PUNTA        Responsable: Mario
-- ---------------------------------------------------------------------
-- Ejecutar DESPUES de 12_EJECUTAR_ETL.sql. Cada prueba deja una fila en
-- QA_RESULTADOS con PASA / FALLA: es la evidencia para el acta.
-- Cubre: OLTP, datos de prueba, staging, calidad, divisas, DW,
-- conciliacion de totales, idempotencia, JSON + firma, MVs, auditoria.
-- ---------------------------------------------------------------------
-- VERSION MULTI-ESQUEMA. EJECUTAR COMO: OMNI_DW
-- Cambios respecto a la version de un solo esquema:
--   T01  cuenta las tablas TRX_ en ALL_TABLES del duenio OMNI_OLTP
--        (ya no estan en USER_TABLES de quien ejecuta).
--   T28  ya no modifica TRX_VENTAS: OMNI_DW no tiene UPDATE sobre el
--        OLTP (y eso es justamente lo que se quiere). Ahora prueba que
--        (a) si el total cambiara, la firma recalculada seria distinta y
--        (b) si se altera la firma guardada, FN_VERIFICAR_FIRMA lo detecta.
--   T37-T40  NUEVAS pruebas de seguridad (minimo privilegio).
-- Total: 40 pruebas.
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 220
SET PAGESIZE 200

CREATE TABLE IF NOT EXISTS QA_RESULTADOS (
  ID_PRUEBA    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  CORRIDA      NUMBER        NOT NULL,
  FECHA        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CASO         VARCHAR2(10)  NOT NULL,
  AREA         VARCHAR2(30)  NOT NULL,
  DESCRIPCION  VARCHAR2(300) NOT NULL,
  RESULTADO    VARCHAR2(5)   NOT NULL,
  DETALLE      VARCHAR2(1000)
);

-- Funcion con derechos del dueno (OMNI_DW): garantiza que la prueba T38 se
-- ejecute siempre con los privilegios exactos de OMNI_DW, incluso si el
-- instalador de 1 clic corre desde SYS con CURRENT_SCHEMA = OMNI_DW.
CREATE OR REPLACE FUNCTION FN_QA_INTENTAR_DML (p_sql VARCHAR2)
RETURN NUMBER AUTHID DEFINER IS
BEGIN
  EXECUTE IMMEDIATE p_sql;
  RETURN 0;
EXCEPTION
  WHEN OTHERS THEN RETURN SQLCODE;
END;
/

DECLARE
  v_corrida NUMBER;
  v_n1 NUMBER; v_n2 NUMBER; v_n3 NUMBER; v_n4 NUMBER;
  v_txt VARCHAR2(1000);
  v_ok  BOOLEAN;
  v_qa_ejec NUMBER;

  PROCEDURE chk (p_caso VARCHAR2, p_area VARCHAR2, p_desc VARCHAR2, p_ok BOOLEAN, p_detalle VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO QA_RESULTADOS (CORRIDA, CASO, AREA, DESCRIPCION, RESULTADO, DETALLE)
    VALUES (v_corrida, p_caso, p_area, p_desc, CASE WHEN p_ok THEN 'PASA' ELSE 'FALLA' END, SUBSTR(p_detalle, 1, 1000));
    COMMIT;
  END;

  -- Transaccion del caso de error controlado identificada por su fecha/hora
  FUNCTION trx_caso (p_ts VARCHAR2) RETURN NUMBER IS v NUMBER;
  BEGIN
    SELECT MAX(ID_TRANSACCION) INTO v FROM TRX_VENTAS
     WHERE FECHA_TRANSACCION = TO_TIMESTAMP(p_ts, 'YYYY-MM-DD HH24:MI:SS');
    RETURN v;
  END;

  PROCEDURE chk_rechazo (p_caso VARCHAR2, p_ts VARCHAR2, p_regla VARCHAR2, p_desc VARCHAR2) IS
    v_trx NUMBER := trx_caso(p_ts);
    v_err NUMBER; v_dw NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_err FROM ERRORES_ETL_VENTAS
     WHERE ID_TRANSACCION_OLTP = v_trx AND CODIGO_REGLA = p_regla AND SEVERIDAD = 'CRITICO';
    SELECT COUNT(*) INTO v_dw FROM HECHOS_VENTAS WHERE ID_TRANSACCION_OLTP = v_trx;
    chk(p_caso, 'CALIDAD', p_desc, v_trx IS NOT NULL AND v_err > 0 AND v_dw = 0,
        'trx=' || v_trx || ' errores ' || p_regla || '=' || v_err || ' lineas en DW=' || v_dw);
  END;

  PROCEDURE chk_advertencia (p_caso VARCHAR2, p_ts VARCHAR2, p_regla VARCHAR2, p_desc VARCHAR2) IS
    v_trx NUMBER := trx_caso(p_ts);
    v_err NUMBER; v_dw NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_err FROM ERRORES_ETL_VENTAS
     WHERE ID_TRANSACCION_OLTP = v_trx AND CODIGO_REGLA = p_regla AND SEVERIDAD = 'ADVERTENCIA';
    SELECT COUNT(*) INTO v_dw FROM HECHOS_VENTAS WHERE ID_TRANSACCION_OLTP = v_trx;
    chk(p_caso, 'CALIDAD', p_desc, v_trx IS NOT NULL AND v_err > 0 AND v_dw > 0,
        'trx=' || v_trx || ' advertencias ' || p_regla || '=' || v_err || ' lineas en DW=' || v_dw);
  END;
BEGIN
  SELECT NVL(MAX(CORRIDA), 0) + 1 INTO v_corrida FROM QA_RESULTADOS;

  -- ---------------- OLTP y datos de prueba ----------------------------
  SELECT COUNT(*) INTO v_n1 FROM ALL_TABLES WHERE OWNER = 'OMNI_OLTP' AND TABLE_NAME LIKE 'TRX\_%' ESCAPE '\';
  chk('T01', 'OLTP', 'Existen las 17 tablas TRX_', v_n1 = 17, 'tablas=' || v_n1);

  SELECT COUNT(DISTINCT c.CODIGO_CANAL) INTO v_n1 FROM TRX_VENTAS v JOIN TRX_CANALES c ON c.ID_CANAL = v.ID_CANAL;
  SELECT COUNT(DISTINCT MONEDA_ORIGEN) INTO v_n2 FROM TRX_VENTAS;
  chk('T02', 'OLTP', 'Hay ventas en los 3 canales y las 3 monedas', v_n1 = 3 AND v_n2 = 3,
      'canales=' || v_n1 || ' monedas=' || v_n2);

  SELECT COUNT(*) INTO v_n1 FROM TRX_DETALLE WHERE ID_PROMOCION IS NOT NULL;
  SELECT COUNT(*) INTO v_n2 FROM TRX_DETALLE WHERE ID_PROMOCION IS NULL;
  SELECT COUNT(*) INTO v_n3 FROM (SELECT ID_TRANSACCION FROM TRX_DETALLE GROUP BY ID_TRANSACCION HAVING COUNT(*) > 1);
  chk('T03', 'OLTP', 'Hay lineas con y sin promocion y ventas multiproducto', v_n1 > 0 AND v_n2 > 0 AND v_n3 > 0,
      'con promo=' || v_n1 || ' sin promo=' || v_n2 || ' trx multiproducto=' || v_n3);

  SELECT COUNT(*) INTO v_n1 FROM (
    SELECT DISTINCT TRUNC(v.FECHA_TRANSACCION) f, v.MONEDA_ORIGEN m FROM TRX_VENTAS v
     WHERE NOT EXISTS (SELECT 1 FROM TRX_MONEDAS t WHERE t.FECHA = TRUNC(v.FECHA_TRANSACCION) AND t.MONEDA_ORIGEN = v.MONEDA_ORIGEN));
  chk('T04', 'DIVISAS', 'Solo el caso E1 usa una fecha/moneda sin tasa', v_n1 = 1, 'combinaciones sin tasa=' || v_n1);

  -- ---------------- Modulo de divisas ---------------------------------
  SELECT TASA_USD INTO v_n1 FROM TRX_MONEDAS WHERE FECHA = DATE '2026-09-10' AND MONEDA_ORIGEN = 'EUR';
  v_n2 := PKG_DIVISAS.FN_CONVERTIR_USD(100, 'EUR', DATE '2026-09-10');
  chk('T05', 'DIVISAS', '100 EUR se convierten con la tasa del dia', v_n2 = ROUND(100 * v_n1, 2),
      'tasa=' || v_n1 || ' resultado=' || v_n2);

  BEGIN
    v_n2 := PKG_DIVISAS.FN_CONVERTIR_USD(100, 'EUR', DATE '2020-01-01');
    v_ok := FALSE; v_txt := 'no lanzo error, devolvio ' || v_n2;
  EXCEPTION WHEN PKG_DIVISAS.e_sin_tasa THEN v_ok := TRUE; v_txt := SQLERRM;
  END;
  chk('T06', 'DIVISAS', 'Sin tasa valida la conversion se rechaza (ORA-20010)', v_ok, v_txt);

  v_n1 := PKG_DIVISAS.FN_CONVERTIR(1000, 'GTQ', 'EUR', DATE '2026-09-10');
  v_n2 := ROUND(1000 * PKG_DIVISAS.FN_OBTENER_TASA('GTQ', DATE '2026-09-10')
                / PKG_DIVISAS.FN_OBTENER_TASA('EUR', DATE '2026-09-10'), 2);
  chk('T07', 'DIVISAS', 'Conversion cruzada GTQ -> EUR pasa por USD', v_n1 = v_n2, '1000 GTQ = ' || v_n1 || ' EUR');

  -- ---------------- Casos de error controlados ------------------------
  chk_rechazo('T08', '2025-12-31 10:00:00', 'R04', 'E1 venta sin tasa se rechaza');
  chk_rechazo('T09', '2026-09-18 11:30:00', 'R09', 'E2 total de cabecera que no cuadra se rechaza');
  chk_rechazo('T10', '2026-09-25 16:45:00', 'R07', 'E3 promocion vencida se rechaza');
  chk_rechazo('T11', '2026-09-15 09:10:00', 'R07', 'E4 promocion de otro producto se rechaza');
  chk_rechazo('T12', '2026-09-20 13:00:00', 'R06', 'E5 precio fuera de vigencia se rechaza');
  chk_rechazo('T13', '2026-09-22 18:20:00', 'R08', 'E6 descuento mayor al importe se rechaza');
  chk_advertencia('T14', '2026-09-23 12:00:00', 'R12', 'E7 geografia inconsistente: advertencia y se carga');
  chk_advertencia('T15', '2026-09-24 15:30:00', 'R11', 'E8 impuesto distinto al 13%: advertencia y se carga');

  -- ---------------- Conciliacion OLTP vs DW ---------------------------
  SELECT COUNT(*) INTO v_n1 FROM TRX_VENTAS v JOIN TRX_ESTADOS_VENTA e ON e.ID_ESTADO_VENTA = v.ID_ESTADO_VENTA
   WHERE e.NOMBRE_ESTADO IN ('Pagada','Facturada') AND v.ACTIVO = 'S';
  SELECT COUNT(DISTINCT ID_TRANSACCION_OLTP) INTO v_n2 FROM HECHOS_VENTAS;
  SELECT COUNT(DISTINCT ID_TRANSACCION_OLTP) INTO v_n3 FROM ERRORES_ETL_VENTAS
   WHERE SEVERIDAD = 'CRITICO' AND ESTADO_ERROR = 'ABIERTO' AND ID_TRANSACCION_OLTP > 0;
  chk('T16', 'CONCILIACION', 'Transacciones elegibles OLTP = cargadas DW + rechazadas', v_n1 = v_n2 + v_n3,
      'OLTP=' || v_n1 || ' DW=' || v_n2 || ' rechazadas=' || v_n3);

  SELECT COUNT(*) INTO v_n1 FROM (
    SELECT h.ID_TRANSACCION_OLTP FROM HECHOS_VENTAS h JOIN TRX_VENTAS v ON v.ID_TRANSACCION = h.ID_TRANSACCION_OLTP
     GROUP BY h.ID_TRANSACCION_OLTP, v.TOTAL
    HAVING ABS(SUM(h.TOTAL_LINEA_ORIGEN) - v.TOTAL) > 0.01);
  chk('T17', 'CONCILIACION', 'Total por transaccion en moneda origen DW = OLTP', v_n1 = 0, 'diferencias=' || v_n1);

  SELECT COUNT(*), NVL(MAX(dif), 0) INTO v_n1, v_n2 FROM (
    SELECT ABS(SUM(h.TOTAL_LINEA_USD) - ROUND(v.TOTAL * MAX(h.TASA_USD), 2)) dif
      FROM HECHOS_VENTAS h JOIN TRX_VENTAS v ON v.ID_TRANSACCION = h.ID_TRANSACCION_OLTP
     GROUP BY h.ID_TRANSACCION_OLTP, v.TOTAL
    HAVING ABS(SUM(h.TOTAL_LINEA_USD) - ROUND(v.TOTAL * MAX(h.TASA_USD), 2)) > 0.05);
  chk('T18', 'CONCILIACION', 'Total USD por transaccion cuadra (redondeo <= 0.05)', v_n1 = 0,
      'fuera de tolerancia=' || v_n1 || ' max dif=' || v_n2);

  SELECT COUNT(*) INTO v_n1 FROM HECHOS_VENTAS h JOIN TRX_VENTAS v ON v.ID_TRANSACCION = h.ID_TRANSACCION_OLTP
    JOIN TRX_ESTADOS_VENTA e ON e.ID_ESTADO_VENTA = v.ID_ESTADO_VENTA
   WHERE e.NOMBRE_ESTADO NOT IN ('Pagada','Facturada');
  chk('T19', 'CONCILIACION', 'Ventas anuladas o pendientes no llegan al DW', v_n1 = 0, 'lineas indebidas=' || v_n1);

  SELECT COUNT(*) INTO v_n1 FROM HECHOS_VENTAS h
   WHERE EXISTS (SELECT 1 FROM ERRORES_ETL_VENTAS e WHERE e.ID_TRANSACCION_OLTP = h.ID_TRANSACCION_OLTP
                    AND e.SEVERIDAD = 'CRITICO' AND e.ESTADO_ERROR = 'ABIERTO');
  chk('T20', 'CALIDAD', 'Ningun registro con error critico esta en el DW', v_n1 = 0, 'lineas=' || v_n1);

  SELECT COUNT(*), COUNT(DISTINCT ID_DETALLE_OLTP) INTO v_n1, v_n2 FROM HECHOS_VENTAS;
  chk('T21', 'DW', 'Grano: una fila por linea de detalle, sin duplicados', v_n1 = v_n2 AND v_n1 > 0,
      'filas=' || v_n1 || ' lineas distintas=' || v_n2);

  SELECT COUNT(*) INTO v_n1 FROM HECHOS_VENTAS
   WHERE ABS(TOTAL_LINEA_USD - (MONTO_NETO_USD + IMPUESTO_USD)) > 0
      OR ABS(MONTO_NETO_USD - (MONTO_BRUTO_USD - DESCUENTO_USD)) > 0
      OR ABS(MARGEN_BRUTO_USD - (MONTO_NETO_USD - COSTO_TOTAL_USD)) > 0;
  chk('T22', 'DW', 'Medidas del hecho son internamente consistentes', v_n1 = 0, 'filas inconsistentes=' || v_n1);

  -- ---------------- Idempotencia (segunda corrida no duplica) ----------
  SELECT COUNT(*) INTO v_n1 FROM HECHOS_VENTAS;
  SELECT COUNT(*) INTO v_n3 FROM FACTURAS_JSON;
  PKG_ETL_VENTAS.PR_EJECUTAR_ETL;
  SELECT COUNT(*) INTO v_n2 FROM HECHOS_VENTAS;
  SELECT COUNT(*) INTO v_n4 FROM FACTURAS_JSON;
  chk('T23', 'ETL', 'Re-ejecutar el ETL no duplica hechos ni facturas', v_n1 = v_n2 AND v_n3 = v_n4,
      'hechos ' || v_n1 || '->' || v_n2 || ' facturas ' || v_n3 || '->' || v_n4);

  -- ---------------- Factura JSON ---------------------------------------
  SELECT COUNT(*) INTO v_n1 FROM FACTURAS_JSON;
  SELECT COUNT(DISTINCT ID_TRANSACCION_OLTP) INTO v_n2 FROM HECHOS_VENTAS;
  chk('T24', 'JSON', 'Una factura por cada transaccion cargada al DW', v_n1 = v_n2, 'facturas=' || v_n1 || ' trx DW=' || v_n2);

  SELECT COUNT(*) INTO v_n1 FROM FACTURAS_JSON f
   WHERE JSON_VALUE(f.FACTURA_DOC, '$.productos.size()' RETURNING NUMBER)
         <> (SELECT COUNT(*) FROM TRX_DETALLE d WHERE d.ID_TRANSACCION = f.ID_TRANSACCION_FK);
  chk('T25', 'JSON', 'El arreglo productos tiene una entrada por linea', v_n1 = 0, 'facturas con diferencia=' || v_n1);

  SELECT COUNT(*) INTO v_n1 FROM FACTURAS_JSON f JOIN TRX_VENTAS v ON v.ID_TRANSACCION = f.ID_TRANSACCION_FK
   WHERE JSON_VALUE(f.FACTURA_DOC, '$.monto_total_usd' RETURNING NUMBER)
         <> PKG_DIVISAS.FN_CONVERTIR_USD(v.TOTAL, v.MONEDA_ORIGEN, CAST(v.FECHA_TRANSACCION AS DATE))
      OR JSON_VALUE(f.FACTURA_DOC, '$.total_final' RETURNING NUMBER) <> v.TOTAL;
  chk('T26', 'JSON', 'monto_total_usd y total_final coinciden con OLTP + divisas', v_n1 = 0, 'diferencias=' || v_n1);

  SELECT COUNT(*) INTO v_n1 FROM FACTURAS_JSON WHERE FN_VERIFICAR_FIRMA(CODIGO_FACTURA_NEGOCIO) <> 'VALIDA';
  chk('T27', 'JSON', 'Todas las firmas SHA256 se verifican', v_n1 = 0, 'firmas invalidas=' || v_n1);

  SELECT MIN(CODIGO_FACTURA_NEGOCIO) INTO v_txt FROM FACTURAS_JSON;
  -- (a) Firma recalculada como si el total del OLTP hubiera subido 1 unidad
  SELECT CASE WHEN f.FIRMA_SHA256 <> LOWER(RAWTOHEX(STANDARD_HASH(
                     FN_CADENA_FIRMA(f.CODIGO_FACTURA_NEGOCIO, cn.CODIGO_CANAL, v.FECHA_TRANSACCION,
                                     ROUND((v.TOTAL + 1) * PKG_DIVISAS.FN_OBTENER_TASA(v.MONEDA_ORIGEN, CAST(v.FECHA_TRANSACCION AS DATE)), 2),
                                     v.MONEDA_ORIGEN, v.ID_CLIENTE), 'SHA256')))
              THEN 1 ELSE 0 END
    INTO v_n1
    FROM FACTURAS_JSON f
    JOIN TRX_VENTAS v   ON v.ID_TRANSACCION = f.ID_TRANSACCION_FK
    JOIN TRX_CANALES cn ON cn.ID_CANAL = v.ID_CANAL
   WHERE f.CODIGO_FACTURA_NEGOCIO = v_txt;
  -- (b) Se altera la firma guardada (tabla propia del DW) y se verifica
  SAVEPOINT sp_firma;
  UPDATE FACTURAS_JSON SET FIRMA_SHA256 = LPAD('0', 64, '0') WHERE CODIGO_FACTURA_NEGOCIO = v_txt;
  v_ok := v_n1 = 1 AND FN_VERIFICAR_FIRMA(v_txt) = 'ALTERADA';
  ROLLBACK TO sp_firma;
  chk('T28', 'JSON', 'Si se altera el total o la firma, la verificacion lo detecta', v_ok,
      'factura=' || v_txt || ' firma distinta con total+1=' || v_n1);

  SELECT COUNT(*) INTO v_n1 FROM FACTURAS_JSON
   WHERE NOT REGEXP_LIKE(CODIGO_FACTURA_NEGOCIO, '^TX-(POS|WEB|MOB)-[0-9]{8}-[0-9]{6}$');
  chk('T29', 'JSON', 'Codigo de negocio con formato TX-{CANAL}-{YYYYMMDD}-{SEQ}', v_n1 = 0, 'codigos invalidos=' || v_n1);

  -- ---------------- Vistas materializadas ------------------------------
  SELECT SUM(TOTAL_LINEA_USD), SUM(MARGEN_BRUTO_USD) INTO v_n1, v_n2 FROM HECHOS_VENTAS;
  SELECT SUM(VENTA_TOTAL_USD) INTO v_n3 FROM MV_VENTAS_MENSUALES;
  SELECT SUM(UTILIDAD_TOTAL_USD) INTO v_n4 FROM MV_UTILIDAD_POR_CATEGORIA;
  chk('T30', 'MV', 'MV diaria y MV margen cuadran con HECHOS_VENTAS', v_n1 = v_n3 AND v_n2 = v_n4,
      'venta hechos=' || v_n1 || ' mv=' || v_n3 || ' margen hechos=' || v_n2 || ' mv=' || v_n4);

  SELECT SUM(VENTA_TOTAL_USD) INTO v_n3 FROM MV_TOP_PRODUCTOS;
  SELECT SUM(VENTA_TOTAL_USD) INTO v_n4 FROM MV_FRECUENCIA_CLIENTES;
  chk('T31', 'MV', 'MV sucursal y MV clientes cuadran con HECHOS_VENTAS', v_n1 = v_n3 AND v_n1 = v_n4,
      'hechos=' || v_n1 || ' sucursal=' || v_n3 || ' clientes=' || v_n4);

  SELECT SUM(VENTA_NETA_USD) INTO v_n3 FROM MV_PROMOCIONES_USADAS;
  SELECT SUM(MONTO_NETO_USD) INTO v_n4 FROM HECHOS_VENTAS;
  chk('T32', 'MV', 'MV promociones cuadra con HECHOS_VENTAS', v_n3 = v_n4, 'hechos=' || v_n4 || ' mv=' || v_n3);

  SELECT COUNT(*) INTO v_n1 FROM ALL_MVIEWS WHERE OWNER = 'OMNI_DW' AND STALENESS NOT IN ('FRESH','UNKNOWN') AND MVIEW_NAME LIKE 'MV\_%' ESCAPE '\';
  chk('T33', 'MV', 'Las 5 MVs estan actualizadas', v_n1 = 0, 'desactualizadas=' || v_n1);

  -- ---------------- Auditoria -----------------------------------------
  SELECT COUNT(*) INTO v_n1 FROM AUDITORIA_ETL_VENTAS
   WHERE PROCESO = 'ETL_VENTAS' AND (FECHA_FIN IS NULL OR HASH_LOTE IS NULL OR DURACION_SEGUNDOS IS NULL
                                     OR ESTADO IN ('EN_PROCESO','FALLIDO'));
  chk('T34', 'AUDITORIA', 'Cada ejecucion ETL tiene fin, duracion, hash y estado final', v_n1 = 0, 'incompletas=' || v_n1);

  SELECT COUNT(*) INTO v_n1 FROM AUDITORIA_ETL_VENTAS
   WHERE PROCESO = 'ETL_VENTAS' AND REGISTROS_EXTRAIDOS <> REGISTROS_VALIDOS + REGISTROS_RECHAZADOS;
  chk('T35', 'AUDITORIA', 'Extraidos = validos + rechazados en cada ejecucion', v_n1 = 0, 'ejecuciones descuadradas=' || v_n1);

  -- ---------------- Inyeccion de datos sucios en Staging -------------
  -- Simula errores que el OLTP impide por constraint. Se usan IDs
  -- negativos para no mezclarse con datos reales.
  v_qa_ejec := PKG_AUDITORIA.FN_INICIAR('QA_INYECCION');
  INSERT INTO STG_VENTAS (ID_EJECUCION, ID_TRANSACCION, ID_DETALLE, FECHA_TRANSACCION, CODIGO_CANAL, ID_CLIENTE,
                          ID_EMPLEADO, NOMBRE_METODO_PAGO, NOMBRE_ESTADO, MONEDA_ORIGEN, TOTAL_CABECERA,
                          ID_PRODUCTO, ID_PROMOCION, CANTIDAD, PRECIO_UNITARIO, DESCUENTO, IMPUESTO)
  SELECT v_qa_ejec, -901, -9011, TIMESTAMP '2026-09-10 10:00:00', 'POS', (SELECT MIN(ID_CLIENTE) FROM STG_CLIENTES),
         (SELECT MIN(ID_EMPLEADO) FROM STG_EMPLEADOS), 'Efectivo', 'Facturada', 'USD', -56.5,
         (SELECT MIN(ID_PRODUCTO) FROM STG_PRODUCTOS), NULL, -1, 50, 0, -6.5 FROM DUAL           -- R05 cantidad negativa
  UNION ALL
  SELECT v_qa_ejec, -902, -9021, TIMESTAMP '2026-09-10 10:00:00', 'POS', (SELECT MIN(ID_CLIENTE) FROM STG_CLIENTES),
         (SELECT MIN(ID_EMPLEADO) FROM STG_EMPLEADOS), 'Efectivo', 'Facturada', 'MXN', 113,
         (SELECT MIN(ID_PRODUCTO) FROM STG_PRODUCTOS), NULL, 1, 100, 0, 13 FROM DUAL             -- R03 moneda invalida
  UNION ALL
  SELECT v_qa_ejec, -903, -9031, TIMESTAMP '2026-09-10 10:00:00', 'POS', 999999,
         (SELECT MIN(ID_EMPLEADO) FROM STG_EMPLEADOS), 'Efectivo', 'Facturada', 'USD', 113,
         (SELECT MIN(ID_PRODUCTO) FROM STG_PRODUCTOS), NULL, 1, 100, 0, 13 FROM DUAL             -- R02 cliente inexistente
  UNION ALL
  SELECT v_qa_ejec, -904, -9041, TIMESTAMP '2026-09-10 10:00:00', 'POS', (SELECT MIN(ID_CLIENTE) FROM STG_CLIENTES),
         (SELECT MIN(ID_EMPLEADO) FROM STG_EMPLEADOS), 'Efectivo', 'Facturada', 'USD', 113,
         (SELECT MIN(ID_PRODUCTO) FROM STG_PRODUCTOS), NULL, 1, 100, 0, 13 FROM DUAL             -- R01 duplicado (1/2)
  UNION ALL
  SELECT v_qa_ejec, -904, -9041, TIMESTAMP '2026-09-10 10:00:00', 'POS', (SELECT MIN(ID_CLIENTE) FROM STG_CLIENTES),
         (SELECT MIN(ID_EMPLEADO) FROM STG_EMPLEADOS), 'Efectivo', 'Facturada', 'USD', 113,
         (SELECT MIN(ID_PRODUCTO) FROM STG_PRODUCTOS), NULL, 1, 100, 0, 13 FROM DUAL             -- R01 duplicado (2/2)
  UNION ALL
  SELECT v_qa_ejec, -905, -9051, NULL, 'POS', (SELECT MIN(ID_CLIENTE) FROM STG_CLIENTES),
         NULL, 'Efectivo', 'Facturada', 'USD', 113,
         (SELECT MIN(ID_PRODUCTO) FROM STG_PRODUCTOS), NULL, 1, 100, 0, 13 FROM DUAL;            -- R10 obligatorios

  PKG_CALIDAD.PR_VALIDAR(v_qa_ejec);

  SELECT COUNT(DISTINCT CODIGO_REGLA) INTO v_n1 FROM ERRORES_ETL_VENTAS
   WHERE ID_EJECUCION = v_qa_ejec AND CODIGO_REGLA IN ('R01','R02','R03','R05','R10');
  SELECT COUNT(*) INTO v_n2 FROM STG_VENTAS WHERE ID_EJECUCION = v_qa_ejec AND ESTADO_VALIDACION <> 'RECHAZADO';
  SELECT LISTAGG(DISTINCT CODIGO_REGLA, ',') WITHIN GROUP (ORDER BY CODIGO_REGLA) INTO v_txt
    FROM ERRORES_ETL_VENTAS WHERE ID_EJECUCION = v_qa_ejec;
  chk('T36', 'CALIDAD', 'Staging sucio: duplicado, FK, moneda, cantidad y nulos se rechazan', v_n1 = 5 AND v_n2 = 0,
      'reglas detectadas=' || v_txt || ' filas no rechazadas=' || v_n2);

  -- limpieza de la inyeccion (la evidencia queda en ERRORES_ETL_VENTAS como DESCARTADO)
  DELETE FROM STG_VENTAS WHERE ID_EJECUCION = v_qa_ejec;
  UPDATE ERRORES_ETL_VENTAS SET ESTADO_ERROR = 'DESCARTADO' WHERE ID_EJECUCION = v_qa_ejec;
  UPDATE AUDITORIA_ETL_VENTAS SET ESTADO = 'CON_RECHAZOS', FECHA_FIN = SYSTIMESTAMP,
         MENSAJE = 'Prueba QA: inyeccion de datos sucios en staging'
   WHERE ID_EJECUCION = v_qa_ejec;
  COMMIT;

  -- ---------------- Seguridad multi-esquema (NUEVO) --------------------
  -- Si corre desde el instalador de 1 clic (SYS AS SYSDBA), ALL_TAB_PRIVS filtra
  -- por el usuario de login (SYS) y no por CURRENT_SCHEMA; por eso se consulta
  -- DBA_TAB_PRIVS dinamicamente. Si corre conectado como OMNI_DW, usa USER_TAB_PRIVS.
  IF SYS_CONTEXT('USERENV', 'ISDBA') = 'TRUE' THEN
    EXECUTE IMMEDIATE
      'SELECT COUNT(*) FROM DBA_TAB_PRIVS
        WHERE OWNER = ''OMNI_OLTP'' AND GRANTEE = ''OMNI_DW''
          AND PRIVILEGE = ''SELECT'' AND TABLE_NAME LIKE ''TRX\_%'' ESCAPE ''\'''
      INTO v_n1;
    EXECUTE IMMEDIATE
      'SELECT COUNT(*) FROM DBA_TAB_PRIVS
        WHERE OWNER = ''OMNI_OLTP'' AND GRANTEE = ''OMNI_DW''
          AND PRIVILEGE NOT IN (''SELECT'', ''REFERENCES'', ''EXECUTE'')'
      INTO v_n2;
  ELSE
    SELECT COUNT(*) INTO v_n1 FROM USER_TAB_PRIVS
     WHERE OWNER = 'OMNI_OLTP' AND GRANTEE = 'OMNI_DW'
       AND PRIVILEGE = 'SELECT' AND TABLE_NAME LIKE 'TRX\_%' ESCAPE '\';
    SELECT COUNT(*) INTO v_n2 FROM USER_TAB_PRIVS
     WHERE OWNER = 'OMNI_OLTP' AND GRANTEE = 'OMNI_DW'
       AND PRIVILEGE NOT IN ('SELECT', 'REFERENCES', 'EXECUTE');
  END IF;
  chk('T37', 'SEGURIDAD', 'OMNI_DW lee las 17 tablas del OLTP y no recibio permisos de escritura',
      v_n1 = 17 AND v_n2 = 0, 'SELECT=' || v_n1 || ' permisos de escritura=' || v_n2);

  -- Se intenta escribir en el OLTP usando el dominio real de privilegios de OMNI_DW
  -- (FN_QA_INTENTAR_DML es AUTHID DEFINER en OMNI_DW): Oracle debe bloquearlo (-1031 o -41900).
  v_n1 := 0; v_txt := NULL;
  FOR s IN (SELECT 'UPDATE OMNI_OLTP.TRX_VENTAS SET TOTAL = TOTAL WHERE 1 = 0' AS sql_txt FROM DUAL
            UNION ALL SELECT 'DELETE FROM OMNI_OLTP.TRX_DETALLE WHERE 1 = 0' FROM DUAL
            UNION ALL SELECT 'INSERT INTO OMNI_OLTP.TRX_CANALES (CODIGO_CANAL, NOMBRE_CANAL) SELECT ''X'', ''X'' FROM DUAL WHERE 1 = 0' FROM DUAL) LOOP
    v_n2 := FN_QA_INTENTAR_DML(s.sql_txt);
    IF v_n2 IN (-1031, -41900) THEN
      v_n1 := v_n1 + 1;
    ELSIF v_n2 = 0 THEN
      v_txt := v_txt || ' PERMITIDO: ' || SUBSTR(s.sql_txt, 1, 30);
    ELSE
      v_txt := SUBSTR(v_txt || ' cod=' || v_n2, 1, 900);
    END IF;
  END LOOP;
  chk('T38', 'SEGURIDAD', 'UPDATE, DELETE e INSERT del DW sobre el OLTP son rechazados por Oracle',
      v_n1 = 3, 'sentencias bloqueadas=' || v_n1 || ' de 3' || v_txt);

  IF SYS_CONTEXT('USERENV', 'ISDBA') = 'TRUE' THEN
    EXECUTE IMMEDIATE
      'SELECT COUNT(*), NVL(SUM(CASE WHEN PRIVILEGE <> ''SELECT'' THEN 1 ELSE 0 END), 0)
         FROM DBA_TAB_PRIVS
        WHERE OWNER = ''OMNI_DW'' AND GRANTEE = ''ROL_OMNI_LECTURA_BI'''
      INTO v_n1, v_n2;
    EXECUTE IMMEDIATE
      'SELECT COUNT(*) FROM DBA_TAB_PRIVS
        WHERE OWNER = ''OMNI_DW''
          AND REGEXP_LIKE(TABLE_NAME, ''^(STG_|AUDITORIA_|ERRORES_|FACTURAS_|QA_)'')'
      INTO v_n3;
  ELSE
    SELECT COUNT(*), NVL(SUM(CASE WHEN PRIVILEGE <> 'SELECT' THEN 1 ELSE 0 END), 0)
      INTO v_n1, v_n2
      FROM USER_TAB_PRIVS
     WHERE OWNER = 'OMNI_DW' AND GRANTEE = 'ROL_OMNI_LECTURA_BI';
    SELECT COUNT(*) INTO v_n3 FROM USER_TAB_PRIVS
     WHERE OWNER = 'OMNI_DW'
       AND REGEXP_LIKE(TABLE_NAME, '^(STG_|AUDITORIA_|ERRORES_|FACTURAS_|QA_)');
  END IF;
  chk('T39', 'SEGURIDAD', 'El rol de BI solo tiene SELECT sobre los 14 objetos analiticos',
      v_n1 = 14 AND v_n2 = 0, 'permisos=' || v_n1 || ' distintos de SELECT=' || v_n2);

  chk('T40', 'SEGURIDAD', 'Staging, auditoria, errores, facturas y QA no se exponen a nadie',
      v_n3 = 0, 'objetos internos expuestos=' || v_n3);

  -- ---------------- Resumen --------------------------------------------
  SELECT COUNT(*), SUM(CASE WHEN RESULTADO = 'PASA' THEN 1 ELSE 0 END) INTO v_n1, v_n2
    FROM QA_RESULTADOS WHERE CORRIDA = v_corrida;
  DBMS_OUTPUT.PUT_LINE('Corrida QA ' || v_corrida || ': ' || v_n2 || ' de ' || v_n1 || ' pruebas PASAN');
END;
/

COLUMN CASO FORMAT A5
COLUMN AREA FORMAT A12
COLUMN DESCRIPCION FORMAT A70
COLUMN RESULTADO FORMAT A6
COLUMN DETALLE FORMAT A80
SELECT CASO, AREA, DESCRIPCION, RESULTADO, DETALLE
  FROM QA_RESULTADOS
 WHERE CORRIDA = (SELECT MAX(CORRIDA) FROM QA_RESULTADOS)
 ORDER BY ID_PRUEBA;
