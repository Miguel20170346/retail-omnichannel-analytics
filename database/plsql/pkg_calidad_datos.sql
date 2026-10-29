-- =====================================================================
-- 08 - CALIDAD DE DATOS                            Responsable: Eduardo
-- ---------------------------------------------------------------------
-- Valida STG_VENTAS antes de cargar al DW. Cada regla inserta en
-- ERRORES_ETL_VENTAS las filas que la incumplen.
--   CRITICO     -> la TRANSACCION COMPLETA se rechaza (no pasa al DW),
--                  para que el total del DW siempre cuadre con el OLTP.
--   ADVERTENCIA -> se registra, pero la transaccion se carga.
--
--  Regla  Severidad    Descripcion
--  R01    CRITICO      Linea duplicada (en el lote o ya cargada al DW)
--  R02    CRITICO      Referencia inexistente (cliente, producto, empleado,
--                      canal, metodo de pago, promocion)
--  R03    CRITICO      Moneda no soportada (solo USD, EUR, GTQ)
--  R04    CRITICO      Sin tasa de cambio valida para la fecha
--  R05    CRITICO      Cantidad nula, cero, negativa o con decimales
--  R06    CRITICO      Precio negativo o fuera de vigencia del producto
--  R07    CRITICO      Promocion de otro producto, inactiva o fuera de vigencia
--  R08    CRITICO      Descuento/impuesto negativo o descuento > importe
--  R09    CRITICO      Total de cabecera distinto a la suma del detalle
--  R10    CRITICO      Campo obligatorio vacio
--  R11    ADVERTENCIA  Impuesto distinto al 13% de (cantidad*precio - descuento)
--  R12    ADVERTENCIA  Departamento o zona del cliente de otro pais
-- =====================================================================
SET DEFINE OFF

CREATE OR REPLACE PACKAGE PKG_CALIDAD AS
  c_tolerancia CONSTANT NUMBER := 0.01;   -- 1 centavo
  c_iva        CONSTANT NUMBER := 0.13;
  PROCEDURE PR_VALIDAR (p_id_ejecucion NUMBER);
END PKG_CALIDAD;
/

CREATE OR REPLACE PACKAGE BODY PKG_CALIDAD AS

  PROCEDURE PR_VALIDAR (p_id_ejecucion NUMBER) IS
  BEGIN
    -- 0. Preparacion: tasa, codigo de negocio y hash de cada fila --------
    UPDATE STG_VENTAS s
       SET TASA_USD = PKG_DIVISAS.FN_OBTENER_TASA(s.MONEDA_ORIGEN, CAST(s.FECHA_TRANSACCION AS DATE)),
           CODIGO_TRANSACCION = CASE WHEN s.CODIGO_CANAL IS NOT NULL AND s.FECHA_TRANSACCION IS NOT NULL
                                          AND s.ID_TRANSACCION IS NOT NULL
                                     THEN FN_CODIGO_TRANSACCION(s.CODIGO_CANAL, s.FECHA_TRANSACCION, s.ID_TRANSACCION)
                                END,
           HASH_REGISTRO = LOWER(RAWTOHEX(STANDARD_HASH(
                              s.ID_TRANSACCION || '|' || s.ID_DETALLE || '|' ||
                              TO_CHAR(s.FECHA_TRANSACCION, 'YYYYMMDDHH24MISS') || '|' ||
                              s.CODIGO_CANAL || '|' || s.ID_CLIENTE || '|' || s.ID_EMPLEADO || '|' ||
                              s.ID_PRODUCTO || '|' || s.ID_PROMOCION || '|' || s.CANTIDAD || '|' ||
                              s.PRECIO_UNITARIO || '|' || s.DESCUENTO || '|' || s.IMPUESTO || '|' ||
                              s.MONEDA_ORIGEN || '|' || s.TOTAL_CABECERA, 'SHA256')))
     WHERE s.ID_EJECUCION = p_id_ejecucion;

    -- R10. Campos obligatorios --------------------------------------------
    INSERT INTO ERRORES_ETL_VENTAS (ID_EJECUCION, ID_TRANSACCION_OLTP, ID_DETALLE_OLTP, CODIGO_REGLA, SEVERIDAD, DESCRIPCION, VALOR_DETECTADO, HASH_REGISTRO)
    SELECT p_id_ejecucion, s.ID_TRANSACCION, s.ID_DETALLE, 'R10', 'CRITICO',
           'Campo obligatorio vacio',
           RTRIM(
             CASE WHEN s.ID_TRANSACCION     IS NULL THEN 'ID_TRANSACCION,' END ||
             CASE WHEN s.ID_DETALLE         IS NULL THEN 'ID_DETALLE,' END ||
             CASE WHEN s.FECHA_TRANSACCION  IS NULL THEN 'FECHA_TRANSACCION,' END ||
             CASE WHEN s.CODIGO_CANAL       IS NULL THEN 'CODIGO_CANAL,' END ||
             CASE WHEN s.ID_CLIENTE         IS NULL THEN 'ID_CLIENTE,' END ||
             CASE WHEN s.ID_EMPLEADO        IS NULL THEN 'ID_EMPLEADO,' END ||
             CASE WHEN s.NOMBRE_METODO_PAGO IS NULL THEN 'METODO_PAGO,' END ||
             CASE WHEN s.MONEDA_ORIGEN      IS NULL THEN 'MONEDA_ORIGEN,' END ||
             CASE WHEN s.TOTAL_CABECERA     IS NULL THEN 'TOTAL,' END ||
             CASE WHEN s.ID_PRODUCTO        IS NULL THEN 'ID_PRODUCTO,' END ||
             CASE WHEN s.CANTIDAD           IS NULL THEN 'CANTIDAD,' END ||
             CASE WHEN s.PRECIO_UNITARIO    IS NULL THEN 'PRECIO_UNITARIO,' END ||
             CASE WHEN s.DESCUENTO          IS NULL THEN 'DESCUENTO,' END ||
             CASE WHEN s.IMPUESTO           IS NULL THEN 'IMPUESTO,' END, ','),
           s.HASH_REGISTRO
      FROM STG_VENTAS s
     WHERE s.ID_EJECUCION = p_id_ejecucion
       AND (s.ID_TRANSACCION IS NULL OR s.ID_DETALLE IS NULL OR s.FECHA_TRANSACCION IS NULL
            OR s.CODIGO_CANAL IS NULL OR s.ID_CLIENTE IS NULL OR s.ID_EMPLEADO IS NULL
            OR s.NOMBRE_METODO_PAGO IS NULL OR s.MONEDA_ORIGEN IS NULL OR s.TOTAL_CABECERA IS NULL
            OR s.ID_PRODUCTO IS NULL OR s.CANTIDAD IS NULL OR s.PRECIO_UNITARIO IS NULL
            OR s.DESCUENTO IS NULL OR s.IMPUESTO IS NULL);

    -- R01. Duplicados (segunda aparicion en el lote o ya existente en DW) ---
    INSERT INTO ERRORES_ETL_VENTAS (ID_EJECUCION, ID_TRANSACCION_OLTP, ID_DETALLE_OLTP, CODIGO_REGLA, SEVERIDAD, DESCRIPCION, VALOR_DETECTADO, HASH_REGISTRO)
    SELECT p_id_ejecucion, d.ID_TRANSACCION, d.ID_DETALLE, 'R01', 'CRITICO',
           d.motivo, 'ID_DETALLE=' || d.ID_DETALLE, d.HASH_REGISTRO
      FROM (SELECT s.*,
                   ROW_NUMBER() OVER (PARTITION BY s.ID_DETALLE ORDER BY ROWID) AS rn,
                   CASE WHEN EXISTS (SELECT 1 FROM HECHOS_VENTAS h WHERE h.ID_DETALLE_OLTP = s.ID_DETALLE)
                        THEN 'Linea ya cargada en el Data Warehouse'
                        ELSE 'Linea duplicada dentro del lote' END AS motivo
              FROM STG_VENTAS s
             WHERE s.ID_EJECUCION = p_id_ejecucion AND s.ID_DETALLE IS NOT NULL) d
     WHERE d.rn > 1
        OR EXISTS (SELECT 1 FROM HECHOS_VENTAS h WHERE h.ID_DETALLE_OLTP = d.ID_DETALLE);

    -- R02. Integridad referencial -----------------------------------------
    INSERT INTO ERRORES_ETL_VENTAS (ID_EJECUCION, ID_TRANSACCION_OLTP, ID_DETALLE_OLTP, CODIGO_REGLA, SEVERIDAD, DESCRIPCION, VALOR_DETECTADO, HASH_REGISTRO)
    SELECT p_id_ejecucion, s.ID_TRANSACCION, s.ID_DETALLE, 'R02', 'CRITICO', x.descr, x.valor, s.HASH_REGISTRO
      FROM STG_VENTAS s
      CROSS APPLY (
        SELECT 'Cliente inexistente' descr, 'ID_CLIENTE=' || s.ID_CLIENTE valor FROM DUAL
         WHERE s.ID_CLIENTE IS NOT NULL AND NOT EXISTS (SELECT 1 FROM STG_CLIENTES c WHERE c.ID_CLIENTE = s.ID_CLIENTE)
        UNION ALL
        SELECT 'Producto inexistente', 'ID_PRODUCTO=' || s.ID_PRODUCTO FROM DUAL
         WHERE s.ID_PRODUCTO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM STG_PRODUCTOS p WHERE p.ID_PRODUCTO = s.ID_PRODUCTO)
        UNION ALL
        SELECT 'Empleado inexistente', 'ID_EMPLEADO=' || s.ID_EMPLEADO FROM DUAL
         WHERE s.ID_EMPLEADO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM STG_EMPLEADOS e WHERE e.ID_EMPLEADO = s.ID_EMPLEADO)
        UNION ALL
        SELECT 'Canal inexistente', 'CANAL=' || s.CODIGO_CANAL FROM DUAL
         WHERE s.CODIGO_CANAL IS NOT NULL AND NOT EXISTS (SELECT 1 FROM TRX_CANALES c WHERE c.CODIGO_CANAL = s.CODIGO_CANAL)
        UNION ALL
        SELECT 'Metodo de pago inexistente', 'METODO=' || s.NOMBRE_METODO_PAGO FROM DUAL
         WHERE s.NOMBRE_METODO_PAGO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM TRX_METODOS_PAGO m WHERE m.NOMBRE_METODO = s.NOMBRE_METODO_PAGO)
        UNION ALL
        SELECT 'Promocion inexistente', 'ID_PROMOCION=' || s.ID_PROMOCION FROM DUAL
         WHERE s.ID_PROMOCION IS NOT NULL AND NOT EXISTS (SELECT 1 FROM STG_PROMOCIONES pr WHERE pr.ID_PROMOCION = s.ID_PROMOCION)
      ) x
     WHERE s.ID_EJECUCION = p_id_ejecucion;

    -- R03. Moneda soportada ------------------------------------------------
    INSERT INTO ERRORES_ETL_VENTAS (ID_EJECUCION, ID_TRANSACCION_OLTP, ID_DETALLE_OLTP, CODIGO_REGLA, SEVERIDAD, DESCRIPCION, VALOR_DETECTADO, HASH_REGISTRO)
    SELECT p_id_ejecucion, s.ID_TRANSACCION, s.ID_DETALLE, 'R03', 'CRITICO',
           'Moneda no soportada', 'MONEDA=' || s.MONEDA_ORIGEN, s.HASH_REGISTRO
      FROM STG_VENTAS s
     WHERE s.ID_EJECUCION = p_id_ejecucion
       AND s.MONEDA_ORIGEN IS NOT NULL AND s.MONEDA_ORIGEN NOT IN ('USD','EUR','GTQ');

    -- R04. Tasa de cambio para la fecha ------------------------------------
    INSERT INTO ERRORES_ETL_VENTAS (ID_EJECUCION, ID_TRANSACCION_OLTP, ID_DETALLE_OLTP, CODIGO_REGLA, SEVERIDAD, DESCRIPCION, VALOR_DETECTADO, HASH_REGISTRO)
    SELECT p_id_ejecucion, s.ID_TRANSACCION, s.ID_DETALLE, 'R04', 'CRITICO',
           'Sin tasa de cambio valida para la fecha',
           s.MONEDA_ORIGEN || ' ' || TO_CHAR(s.FECHA_TRANSACCION, 'YYYY-MM-DD'), s.HASH_REGISTRO
      FROM STG_VENTAS s
     WHERE s.ID_EJECUCION = p_id_ejecucion
       AND s.MONEDA_ORIGEN IN ('USD','EUR','GTQ') AND s.FECHA_TRANSACCION IS NOT NULL
       AND s.TASA_USD IS NULL;

    -- R05. Cantidad ---------------------------------------------------------
    INSERT INTO ERRORES_ETL_VENTAS (ID_EJECUCION, ID_TRANSACCION_OLTP, ID_DETALLE_OLTP, CODIGO_REGLA, SEVERIDAD, DESCRIPCION, VALOR_DETECTADO, HASH_REGISTRO)
    SELECT p_id_ejecucion, s.ID_TRANSACCION, s.ID_DETALLE, 'R05', 'CRITICO',
           'Cantidad invalida (debe ser entero mayor que cero)', 'CANTIDAD=' || s.CANTIDAD, s.HASH_REGISTRO
      FROM STG_VENTAS s
     WHERE s.ID_EJECUCION = p_id_ejecucion
       AND s.CANTIDAD IS NOT NULL AND (s.CANTIDAD <= 0 OR s.CANTIDAD <> TRUNC(s.CANTIDAD));

    -- R06. Precio negativo o fuera de vigencia ------------------------------
    INSERT INTO ERRORES_ETL_VENTAS (ID_EJECUCION, ID_TRANSACCION_OLTP, ID_DETALLE_OLTP, CODIGO_REGLA, SEVERIDAD, DESCRIPCION, VALOR_DETECTADO, HASH_REGISTRO)
    SELECT p_id_ejecucion, s.ID_TRANSACCION, s.ID_DETALLE, 'R06', 'CRITICO',
           CASE WHEN s.PRECIO_UNITARIO < 0 THEN 'Precio unitario negativo'
                ELSE 'Precio fuera de vigencia temporal del producto' END,
           'PRECIO=' || s.PRECIO_UNITARIO || ' FECHA=' || TO_CHAR(s.FECHA_TRANSACCION, 'YYYY-MM-DD')
             || ' VIGENCIA=' || TO_CHAR(p.FECHA_INICIO, 'YYYY-MM-DD') || '..' || NVL(TO_CHAR(p.FECHA_FIN, 'YYYY-MM-DD'), 'abierta'),
           s.HASH_REGISTRO
      FROM STG_VENTAS s
      LEFT JOIN STG_PRODUCTOS p ON p.ID_PRODUCTO = s.ID_PRODUCTO
     WHERE s.ID_EJECUCION = p_id_ejecucion
       AND (s.PRECIO_UNITARIO < 0
            OR (p.ID_PRODUCTO IS NOT NULL AND s.FECHA_TRANSACCION IS NOT NULL
                AND (TRUNC(s.FECHA_TRANSACCION) < NVL(p.FECHA_INICIO, DATE '1900-01-01')
                     OR TRUNC(s.FECHA_TRANSACCION) > NVL(p.FECHA_FIN, DATE '9999-12-31'))));

    -- R07. Promocion valida para el producto y la fecha --------------------
    INSERT INTO ERRORES_ETL_VENTAS (ID_EJECUCION, ID_TRANSACCION_OLTP, ID_DETALLE_OLTP, CODIGO_REGLA, SEVERIDAD, DESCRIPCION, VALOR_DETECTADO, HASH_REGISTRO)
    SELECT p_id_ejecucion, s.ID_TRANSACCION, s.ID_DETALLE, 'R07', 'CRITICO',
           CASE WHEN pr.ID_PRODUCTO <> s.ID_PRODUCTO THEN 'Promocion pertenece a otro producto'
                WHEN pr.ACTIVO <> 'S'                THEN 'Promocion inactiva'
                ELSE 'Promocion fuera de vigencia' END,
           'ID_PROMOCION=' || pr.ID_PROMOCION || ' FECHA=' || TO_CHAR(s.FECHA_TRANSACCION, 'YYYY-MM-DD')
             || ' VIGENCIA=' || TO_CHAR(pr.FECHA_INICIO, 'YYYY-MM-DD') || '..' || TO_CHAR(pr.FECHA_FIN, 'YYYY-MM-DD'),
           s.HASH_REGISTRO
      FROM STG_VENTAS s
      JOIN STG_PROMOCIONES pr ON pr.ID_PROMOCION = s.ID_PROMOCION
     WHERE s.ID_EJECUCION = p_id_ejecucion
       AND (pr.ID_PRODUCTO <> s.ID_PRODUCTO
            OR pr.ACTIVO <> 'S'
            OR TRUNC(s.FECHA_TRANSACCION) NOT BETWEEN pr.FECHA_INICIO AND pr.FECHA_FIN);

    -- R08. Descuento / impuesto ---------------------------------------------
    INSERT INTO ERRORES_ETL_VENTAS (ID_EJECUCION, ID_TRANSACCION_OLTP, ID_DETALLE_OLTP, CODIGO_REGLA, SEVERIDAD, DESCRIPCION, VALOR_DETECTADO, HASH_REGISTRO)
    SELECT p_id_ejecucion, s.ID_TRANSACCION, s.ID_DETALLE, 'R08', 'CRITICO',
           CASE WHEN s.DESCUENTO < 0 OR s.IMPUESTO < 0 THEN 'Descuento o impuesto negativo'
                ELSE 'Descuento mayor que el importe de la linea' END,
           'IMPORTE=' || (s.CANTIDAD * s.PRECIO_UNITARIO) || ' DESCUENTO=' || s.DESCUENTO || ' IMPUESTO=' || s.IMPUESTO,
           s.HASH_REGISTRO
      FROM STG_VENTAS s
     WHERE s.ID_EJECUCION = p_id_ejecucion
       AND (s.DESCUENTO < 0 OR s.IMPUESTO < 0 OR s.DESCUENTO > s.CANTIDAD * s.PRECIO_UNITARIO);

    -- R09. Total de cabecera = suma del detalle (una fila por transaccion) --
    INSERT INTO ERRORES_ETL_VENTAS (ID_EJECUCION, ID_TRANSACCION_OLTP, ID_DETALLE_OLTP, CODIGO_REGLA, SEVERIDAD, DESCRIPCION, VALOR_DETECTADO)
    SELECT p_id_ejecucion, t.ID_TRANSACCION, NULL, 'R09', 'CRITICO',
           'Total de cabecera no coincide con la suma del detalle',
           'DECLARADO=' || t.total_decl || ' CALCULADO=' || t.total_calc
      FROM (SELECT s.ID_TRANSACCION,
                   MAX(s.TOTAL_CABECERA) AS total_decl,
                   SUM(s.CANTIDAD * s.PRECIO_UNITARIO - s.DESCUENTO + s.IMPUESTO) AS total_calc
              FROM STG_VENTAS s
             WHERE s.ID_EJECUCION = p_id_ejecucion AND s.ID_TRANSACCION IS NOT NULL
             GROUP BY s.ID_TRANSACCION) t
     WHERE t.total_decl IS NOT NULL AND t.total_calc IS NOT NULL
       AND ABS(t.total_decl - t.total_calc) > c_tolerancia;

    -- R11. Impuesto 13% (advertencia) ---------------------------------------
    INSERT INTO ERRORES_ETL_VENTAS (ID_EJECUCION, ID_TRANSACCION_OLTP, ID_DETALLE_OLTP, CODIGO_REGLA, SEVERIDAD, DESCRIPCION, VALOR_DETECTADO, HASH_REGISTRO)
    SELECT p_id_ejecucion, s.ID_TRANSACCION, s.ID_DETALLE, 'R11', 'ADVERTENCIA',
           'Impuesto distinto al 13% de la base (cantidad*precio - descuento)',
           'REGISTRADO=' || s.IMPUESTO || ' ESPERADO=' || ROUND((s.CANTIDAD * s.PRECIO_UNITARIO - s.DESCUENTO) * c_iva, 2),
           s.HASH_REGISTRO
      FROM STG_VENTAS s
     WHERE s.ID_EJECUCION = p_id_ejecucion
       AND s.IMPUESTO >= 0 AND s.DESCUENTO >= 0 AND s.DESCUENTO <= s.CANTIDAD * s.PRECIO_UNITARIO
       AND ABS(s.IMPUESTO - ROUND((s.CANTIDAD * s.PRECIO_UNITARIO - s.DESCUENTO) * c_iva, 2)) > c_tolerancia;

    -- R12. Coherencia geografica del cliente (advertencia, 1 por transaccion)
    INSERT INTO ERRORES_ETL_VENTAS (ID_EJECUCION, ID_TRANSACCION_OLTP, ID_DETALLE_OLTP, CODIGO_REGLA, SEVERIDAD, DESCRIPCION, VALOR_DETECTADO)
    SELECT DISTINCT p_id_ejecucion, s.ID_TRANSACCION, CAST(NULL AS NUMBER), 'R12', 'ADVERTENCIA',
           'Departamento o zona del cliente pertenece a otro pais',
           'ID_CLIENTE=' || c.ID_CLIENTE || ' PAIS=' || c.ID_PAIS || ' PAIS_DEP=' || c.PAIS_DEPARTAMENTO || ' PAIS_ZONA=' || c.PAIS_ZONA
      FROM STG_VENTAS s
      JOIN STG_CLIENTES c ON c.ID_CLIENTE = s.ID_CLIENTE
     WHERE s.ID_EJECUCION = p_id_ejecucion
       AND (c.PAIS_DEPARTAMENTO <> c.ID_PAIS OR c.PAIS_ZONA <> c.ID_PAIS);

    -- Resultado: si una linea tiene error CRITICO se rechaza toda la transaccion
    UPDATE STG_VENTAS s
       SET s.ESTADO_VALIDACION =
             CASE WHEN s.ID_TRANSACCION IS NULL THEN 'RECHAZADO'
                  WHEN EXISTS (SELECT 1 FROM ERRORES_ETL_VENTAS e
                                WHERE e.ID_EJECUCION = p_id_ejecucion
                                  AND e.ID_TRANSACCION_OLTP = s.ID_TRANSACCION
                                  AND e.SEVERIDAD = 'CRITICO')
                  THEN 'RECHAZADO'
                  ELSE 'VALIDO' END
     WHERE s.ID_EJECUCION = p_id_ejecucion;
  END PR_VALIDAR;

END PKG_CALIDAD;
/

PROMPT 08 - Reglas de calidad creadas
