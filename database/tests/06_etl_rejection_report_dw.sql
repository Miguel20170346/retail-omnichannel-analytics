-- =====================================================================
-- 14 - REPORTE DE RECHAZOS DE CALIDAD (uso interno de ingenieria de datos)
-- ---------------------------------------------------------------------
-- EJECUTAR COMO: OMNI_DW
-- En la version de un solo esquema esta consulta estaba dentro de
-- 13_CONSULTAS_KPIS.sql. Aqui se separa porque ERRORES_ETL_VENTAS es un
-- objeto interno y OMNI_BI no tiene acceso a el (minimo privilegio).
-- =====================================================================
SET DEFINE OFF

PROMPT === Rechazos por promocion invalida (regla R07) ===
SELECT ID_EJECUCION, ID_TRANSACCION_OLTP, ID_DETALLE_OLTP, CODIGO_REGLA,
       SEVERIDAD, DESCRIPCION, ESTADO_ERROR
  FROM ERRORES_ETL_VENTAS
 WHERE CODIGO_REGLA = 'R07';

PROMPT === Resumen de errores abiertos por regla ===
SELECT CODIGO_REGLA, SEVERIDAD, COUNT(*) AS CASOS
  FROM ERRORES_ETL_VENTAS
 WHERE ESTADO_ERROR = 'ABIERTO'
 GROUP BY CODIGO_REGLA, SEVERIDAD
 ORDER BY CODIGO_REGLA;
