-- =====================================================================
-- 06 - PERMISOS DEL OLTP HACIA EL DATA WAREHOUSE
-- ---------------------------------------------------------------------
-- EJECUTAR COMO: OMNI_OLTP  (el DUENO de los datos decide quien los lee)
--
-- OMNI_DW recibe:
--   * SELECT     sobre las 17 tablas -> puede LEER para el ETL.
--   * REFERENCES sobre TRX_VENTAS    -> FACTURAS_JSON (en el DW) puede
--                                       tener una FK hacia la venta real.
--   * EXECUTE    sobre PKG_DIVISAS y FN_CODIGO_TRANSACCION -> usa la
--                logica oficial de conversion sin poder modificarla.
--
-- OMNI_DW NO recibe INSERT, UPDATE ni DELETE: aunque el ETL tenga un
-- error, es imposible que altere o borre ventas del sistema transaccional.
--
-- Los permisos se otorgan directo al usuario (no por rol) porque el
-- codigo PL/SQL de OMNI_DW los necesita, y PL/SQL ignora los roles.
-- =====================================================================

-- Lectura de las 17 tablas transaccionales
GRANT SELECT ON TRX_PAISES              TO OMNI_DW;
GRANT SELECT ON TRX_CANALES             TO OMNI_DW;
GRANT SELECT ON TRX_ESTADOS_VENTA       TO OMNI_DW;
GRANT SELECT ON TRX_METODOS_PAGO        TO OMNI_DW;
GRANT SELECT ON TRX_CATEGORIAS_PRODUCTO TO OMNI_DW;
GRANT SELECT ON TRX_MONEDAS             TO OMNI_DW;
GRANT SELECT ON TRX_DEPARTAMENTOS       TO OMNI_DW;
GRANT SELECT ON TRX_ZONAS               TO OMNI_DW;
GRANT SELECT ON TRX_MARCAS              TO OMNI_DW;
GRANT SELECT ON TRX_PROVEEDORES         TO OMNI_DW;
GRANT SELECT ON TRX_SUCURSALES          TO OMNI_DW;
GRANT SELECT ON TRX_CLIENTES            TO OMNI_DW;
GRANT SELECT ON TRX_PRODUCTOS           TO OMNI_DW;
GRANT SELECT ON TRX_EMPLEADOS           TO OMNI_DW;
GRANT SELECT ON TRX_PROMOCIONES         TO OMNI_DW;
GRANT SELECT ON TRX_VENTAS              TO OMNI_DW;
GRANT SELECT ON TRX_DETALLE             TO OMNI_DW;

-- Integridad referencial de las facturas hacia la venta original
GRANT REFERENCES ON TRX_VENTAS TO OMNI_DW;

-- Logica de negocio compartida (solo ejecucion, no modificacion)
GRANT EXECUTE ON PKG_DIVISAS           TO OMNI_DW;
GRANT EXECUTE ON FN_CODIGO_TRANSACCION TO OMNI_DW;

-- Evidencia: lo que OMNI_OLTP otorgo
COLUMN GRANTEE FORMAT A10
COLUMN TABLE_NAME FORMAT A25
COLUMN PRIVILEGE FORMAT A12
SELECT GRANTEE, TABLE_NAME, PRIVILEGE
  FROM ALL_TAB_PRIVS
 WHERE TABLE_SCHEMA = 'OMNI_OLTP' AND GRANTEE = 'OMNI_DW'
 ORDER BY PRIVILEGE, TABLE_NAME;

PROMPT 06 - Permisos de solo lectura otorgados a OMNI_DW (17 SELECT + 1 REFERENCES + 2 EXECUTE)
