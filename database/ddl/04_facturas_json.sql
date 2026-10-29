-- =====================================================================
-- 09 - FACTURA ELECTRONICA JSON                      Responsable: Celina
-- ---------------------------------------------------------------------
-- Version corregida de Generacion_FacturaJSON.sql. Cambios:
--  1. RETURNING CLOB: sin esto JSON_OBJECT devuelve VARCHAR2(4000) y una
--     factura con muchos productos falla (ORA-40478).
--  2. FORMAT JSON en el arreglo de productos: garantiza que se inserte
--     como arreglo y no como texto escapado.
--  3. Conversion a USD con PKG_DIVISAS (modulo de Bryan) en lugar del
--     JOIN directo a TRX_MONEDAS.
--  4. Solo se facturan transacciones que pasaron calidad y estan en el
--     DW. Las ventas sin tasa ya no "desaparecen" en silencio: quedan
--     registradas en ERRORES_ETL_VENTAS por la regla R04.
--  5. Carga INCREMENTAL (no TRUNCATE): conserva la fecha de generacion
--     original de cada factura.
--  6. fecha_emision en UTC real (las ventas se registran en hora de
--     Guatemala, UTC-06:00); antes se le ponia "Z" a una hora local.
--  7. Firma SHA256 incluye el codigo de transaccion (antes dos ventas
--     del mismo cliente, dia, canal y monto tenian la misma firma) y el
--     formato del monto soporta valores grandes.
-- =====================================================================
SET DEFINE OFF

CREATE TABLE FACTURAS_JSON (
  CODIGO_FACTURA_NEGOCIO  VARCHAR2(100) NOT NULL,   -- TX-CANAL-YYYYMMDD-SEQ
  ID_TRANSACCION_FK       NUMBER        NOT NULL,
  FECHA_GENERACION        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  FIRMA_SHA256            VARCHAR2(64)  NOT NULL,
  FACTURA_DOC             CLOB          NOT NULL,
  CONSTRAINT PK_FACTURAS_JSON PRIMARY KEY (CODIGO_FACTURA_NEGOCIO),
  CONSTRAINT UQ_FACTURAS_JSON_TRX UNIQUE (ID_TRANSACCION_FK),
  CONSTRAINT FK_FACTURAS_JSON_TRX FOREIGN KEY (ID_TRANSACCION_FK) REFERENCES TRX_VENTAS (ID_TRANSACCION),
  CONSTRAINT CK_FACTURAS_JSON_VALIDO CHECK (FACTURA_DOC IS JSON)
);

-- Cadena canonica que se firma (se usa tambien para verificar)
CREATE OR REPLACE FUNCTION FN_CADENA_FIRMA (
  p_codigo VARCHAR2, p_canal VARCHAR2, p_fecha TIMESTAMP,
  p_monto_usd NUMBER, p_moneda VARCHAR2, p_id_cliente NUMBER
) RETURN VARCHAR2 DETERMINISTIC IS
BEGIN
  RETURN p_codigo || '|' || p_canal || '|' || TO_CHAR(p_fecha, 'YYYY-MM-DD') || '|'
      || TO_CHAR(p_monto_usd, 'FM999999999999990.00') || '|' || p_moneda || '|' || p_id_cliente;
END;
/

CREATE OR REPLACE PROCEDURE PR_GENERAR_FACTURAS_JSON (p_generadas OUT NUMBER) AS
BEGIN
  INSERT INTO FACTURAS_JSON (CODIGO_FACTURA_NEGOCIO, ID_TRANSACCION_FK, FIRMA_SHA256, FACTURA_DOC)
  WITH base AS (
    SELECT v.ID_TRANSACCION, v.FECHA_TRANSACCION, v.MONEDA_ORIGEN, v.TOTAL, v.ID_CLIENTE,
           cn.CODIGO_CANAL,
           c.NOMBRE AS NOMBRE_CLIENTE, c.SEGMENTO, z.NOMBRE_ZONA,
           e.ID_EMPLEADO, e.NOMBRE AS NOMBRE_EMPLEADO, s.NOMBRE_SUCURSAL,
           mp.NOMBRE_METODO,
           FN_CODIGO_TRANSACCION(cn.CODIGO_CANAL, v.FECHA_TRANSACCION, v.ID_TRANSACCION) AS CODIGO,
           PKG_DIVISAS.FN_OBTENER_TASA(v.MONEDA_ORIGEN, CAST(v.FECHA_TRANSACCION AS DATE)) AS TASA
      FROM TRX_VENTAS v
      JOIN TRX_CLIENTES c      ON c.ID_CLIENTE = v.ID_CLIENTE
      JOIN TRX_ZONAS z         ON z.ID_ZONA = c.ID_ZONA
      JOIN TRX_CANALES cn      ON cn.ID_CANAL = v.ID_CANAL
      JOIN TRX_EMPLEADOS e     ON e.ID_EMPLEADO = v.ID_EMPLEADO
      JOIN TRX_SUCURSALES s    ON s.ID_SUCURSAL = e.ID_SUCURSAL
      JOIN TRX_METODOS_PAGO mp ON mp.ID_METODO_PAGO = v.ID_METODO_PAGO
     WHERE EXISTS (SELECT 1 FROM HECHOS_VENTAS h WHERE h.ID_TRANSACCION_OLTP = v.ID_TRANSACCION)
       AND NOT EXISTS (SELECT 1 FROM FACTURAS_JSON f WHERE f.ID_TRANSACCION_FK = v.ID_TRANSACCION)
  ),
  firmada AS (
    SELECT b.*,
           ROUND(b.TOTAL * b.TASA, 2) AS TOTAL_USD,
           LOWER(RAWTOHEX(STANDARD_HASH(
             FN_CADENA_FIRMA(b.CODIGO, b.CODIGO_CANAL, b.FECHA_TRANSACCION,
                             ROUND(b.TOTAL * b.TASA, 2), b.MONEDA_ORIGEN, b.ID_CLIENTE), 'SHA256'))) AS FIRMA
      FROM base b
  )
  SELECT f.CODIGO,
         f.ID_TRANSACCION,
         f.FIRMA,
         JSON_OBJECT(
           'id_transaccion'  VALUE f.CODIGO,
           'fecha_emision'   VALUE TO_CHAR(SYS_EXTRACT_UTC(FROM_TZ(f.FECHA_TRANSACCION, '-06:00')),
                                           'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'cliente'         VALUE JSON_OBJECT(
                                     'id_cliente' VALUE f.ID_CLIENTE,
                                     'nombre'     VALUE f.NOMBRE_CLIENTE,
                                     'segmento'   VALUE f.SEGMENTO,
                                     'zona'       VALUE f.NOMBRE_ZONA),
           'productos'       VALUE (SELECT JSON_ARRAYAGG(
                                             JSON_OBJECT(
                                               'id_producto'        VALUE d.ID_PRODUCTO,
                                               'nombre_producto'    VALUE p.NOMBRE_PRODUCTO,
                                               'cantidad'           VALUE d.CANTIDAD,
                                               'precio_unitario'    VALUE d.PRECIO_UNITARIO,
                                               'descuento_aplicado' VALUE d.DESCUENTO,
                                               'id_promocion'       VALUE d.ID_PROMOCION,
                                               'impuesto'           VALUE d.IMPUESTO,
                                               'subtotal'           VALUE (d.CANTIDAD * d.PRECIO_UNITARIO - d.DESCUENTO)
                                               ABSENT ON NULL)
                                             ORDER BY d.ID_DETALLE
                                             RETURNING CLOB)
                                      FROM TRX_DETALLE d
                                      JOIN TRX_PRODUCTOS p ON p.ID_PRODUCTO = d.ID_PRODUCTO
                                     WHERE d.ID_TRANSACCION = f.ID_TRANSACCION) FORMAT JSON,
           'moneda_origen'   VALUE f.MONEDA_ORIGEN,
           'tasa_usd'        VALUE f.TASA,
           'monto_total_usd' VALUE f.TOTAL_USD,
           'impuestos'       VALUE JSON_OBJECT(
                                     'tipo_impuesto'        VALUE 'IVA',
                                     'tasa'                 VALUE 0.13,
                                     'monto_impuesto_total' VALUE (SELECT NVL(SUM(d2.IMPUESTO), 0)
                                                                     FROM TRX_DETALLE d2
                                                                    WHERE d2.ID_TRANSACCION = f.ID_TRANSACCION)),
           'total_final'     VALUE ROUND(f.TOTAL, 2),
           'metodo_pago'     VALUE f.NOMBRE_METODO,
           'canal_origen'    VALUE f.CODIGO_CANAL,
           'empleado'        VALUE JSON_OBJECT(
                                     'id_empleado' VALUE f.ID_EMPLEADO,
                                     'nombre'      VALUE f.NOMBRE_EMPLEADO,
                                     'sucursal'    VALUE f.NOMBRE_SUCURSAL),
           'firma_digital'   VALUE f.FIRMA
           RETURNING CLOB)
    FROM firmada f
   WHERE f.TASA IS NOT NULL;

  p_generadas := SQL%ROWCOUNT;
END PR_GENERAR_FACTURAS_JSON;
/

-- Verificacion: recalcula la firma desde el OLTP y la compara.
-- Devuelve 'VALIDA' o 'ALTERADA'.
CREATE OR REPLACE FUNCTION FN_VERIFICAR_FIRMA (p_codigo VARCHAR2) RETURN VARCHAR2 IS
  v_firma_guardada VARCHAR2(64);
  v_firma_json     VARCHAR2(64);
  v_firma_calc     VARCHAR2(64);
BEGIN
  SELECT f.FIRMA_SHA256,
         JSON_VALUE(f.FACTURA_DOC, '$.firma_digital'),
         LOWER(RAWTOHEX(STANDARD_HASH(
           FN_CADENA_FIRMA(f.CODIGO_FACTURA_NEGOCIO, cn.CODIGO_CANAL, v.FECHA_TRANSACCION,
                           ROUND(v.TOTAL * PKG_DIVISAS.FN_OBTENER_TASA(v.MONEDA_ORIGEN, CAST(v.FECHA_TRANSACCION AS DATE)), 2),
                           v.MONEDA_ORIGEN, v.ID_CLIENTE), 'SHA256')))
    INTO v_firma_guardada, v_firma_json, v_firma_calc
    FROM FACTURAS_JSON f
    JOIN TRX_VENTAS v   ON v.ID_TRANSACCION = f.ID_TRANSACCION_FK
    JOIN TRX_CANALES cn ON cn.ID_CANAL = v.ID_CANAL
   WHERE f.CODIGO_FACTURA_NEGOCIO = p_codigo;

  RETURN CASE WHEN v_firma_guardada = v_firma_calc AND v_firma_json = v_firma_calc
              THEN 'VALIDA' ELSE 'ALTERADA' END;
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN 'NO_EXISTE';
END FN_VERIFICAR_FIRMA;
/

PROMPT 09 - Factura JSON creada
