-- =====================================================================
-- 01 - SINONIMOS PRIVADOS HACIA EL OLTP
-- ---------------------------------------------------------------------
-- EJECUTAR COMO: OMNI_DW   (despues de 01_OMNI_OLTP\INSTALAR_OLTP.sql)
--
-- Un sinonimo es un "alias": cuando el ETL escribe TRX_VENTAS, Oracle
-- lo traduce a OMNI_OLTP.TRX_VENTAS.
--
-- Por que se usa el MISMO nombre que en el OLTP:
--   * El codigo del ETL, calidad, facturas y vistas NO se modifica.
--     Es exactamente el mismo codigo que ya dio 36/36 en un solo esquema,
--     por eso los resultados deben ser identicos.
--   * El prefijo TRX_ ya indica que el objeto es transaccional.
--   * Si manana el OLTP se mueve a otro esquema (o a otra base por
--     DB LINK), solo se recrean estos sinonimos: el ETL no se toca.
--
-- Un sinonimo NO da permisos: si OMNI_OLTP no hubiera otorgado SELECT,
-- consultar TRX_VENTAS fallaria con ORA-00942 / ORA-01031.
-- =====================================================================

-- 17 tablas transaccionales (solo lectura, segun 06_PERMISOS_HACIA_DW)
CREATE OR REPLACE SYNONYM TRX_PAISES              FOR OMNI_OLTP.TRX_PAISES;
CREATE OR REPLACE SYNONYM TRX_CANALES             FOR OMNI_OLTP.TRX_CANALES;
CREATE OR REPLACE SYNONYM TRX_ESTADOS_VENTA       FOR OMNI_OLTP.TRX_ESTADOS_VENTA;
CREATE OR REPLACE SYNONYM TRX_METODOS_PAGO        FOR OMNI_OLTP.TRX_METODOS_PAGO;
CREATE OR REPLACE SYNONYM TRX_CATEGORIAS_PRODUCTO FOR OMNI_OLTP.TRX_CATEGORIAS_PRODUCTO;
CREATE OR REPLACE SYNONYM TRX_MONEDAS             FOR OMNI_OLTP.TRX_MONEDAS;
CREATE OR REPLACE SYNONYM TRX_DEPARTAMENTOS       FOR OMNI_OLTP.TRX_DEPARTAMENTOS;
CREATE OR REPLACE SYNONYM TRX_ZONAS               FOR OMNI_OLTP.TRX_ZONAS;
CREATE OR REPLACE SYNONYM TRX_MARCAS              FOR OMNI_OLTP.TRX_MARCAS;
CREATE OR REPLACE SYNONYM TRX_PROVEEDORES         FOR OMNI_OLTP.TRX_PROVEEDORES;
CREATE OR REPLACE SYNONYM TRX_SUCURSALES          FOR OMNI_OLTP.TRX_SUCURSALES;
CREATE OR REPLACE SYNONYM TRX_CLIENTES            FOR OMNI_OLTP.TRX_CLIENTES;
CREATE OR REPLACE SYNONYM TRX_PRODUCTOS           FOR OMNI_OLTP.TRX_PRODUCTOS;
CREATE OR REPLACE SYNONYM TRX_EMPLEADOS           FOR OMNI_OLTP.TRX_EMPLEADOS;
CREATE OR REPLACE SYNONYM TRX_PROMOCIONES         FOR OMNI_OLTP.TRX_PROMOCIONES;
CREATE OR REPLACE SYNONYM TRX_VENTAS              FOR OMNI_OLTP.TRX_VENTAS;
CREATE OR REPLACE SYNONYM TRX_DETALLE             FOR OMNI_OLTP.TRX_DETALLE;

-- Logica de negocio del OLTP (solo ejecucion)
CREATE OR REPLACE SYNONYM PKG_DIVISAS             FOR OMNI_OLTP.PKG_DIVISAS;
CREATE OR REPLACE SYNONYM FN_CODIGO_TRANSACCION   FOR OMNI_OLTP.FN_CODIGO_TRANSACCION;

-- Verificacion: cada sinonimo debe poder leerse (si falta un GRANT, falla aqui)
DECLARE
  v_n NUMBER;
BEGIN
  FOR s IN (SELECT SYNONYM_NAME FROM USER_SYNONYMS
             WHERE TABLE_OWNER = 'OMNI_OLTP' AND SYNONYM_NAME LIKE 'TRX\_%' ESCAPE '\'
             ORDER BY SYNONYM_NAME) LOOP
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || s.SYNONYM_NAME INTO v_n;
    DBMS_OUTPUT.PUT_LINE(RPAD(s.SYNONYM_NAME, 26) || v_n || ' filas');
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Tasa EUR 2026-09-10 via PKG_DIVISAS: '
                       || PKG_DIVISAS.FN_OBTENER_TASA('EUR', DATE '2026-09-10'));
END;
/

PROMPT 01 - 19 sinonimos creados hacia OMNI_OLTP (17 tablas + 2 objetos PL/SQL)
