-- =====================================================================
-- 03 - CASOS DE ERROR CONTROLADOS              Responsables: Eduardo/Mario
-- ---------------------------------------------------------------------
-- Transacciones que SI cumplen las restricciones del OLTP pero violan
-- reglas de negocio. Sirven para demostrar que la capa de calidad las
-- detecta, las registra en ERRORES_ETL_VENTAS y (si son criticas) no
-- las deja pasar al Data Warehouse.
--
--  Caso  Regla  Severidad    Que se simula
--  E1    R04    CRITICO      Venta EUR en una fecha sin tasa de cambio
--  E2    R09    CRITICO      Total de cabecera no cuadra con el detalle
--  E3    R07    CRITICO      Promocion aplicada fuera de su vigencia
--  E4    R07    CRITICO      Promocion de otro producto
--  E5    R06    CRITICO      Precio fuera de vigencia (producto descontinuado)
--  E6    R08    CRITICO      Descuento mayor que el importe de la linea
--  E7    R12    ADVERTENCIA  Cliente con zona de otro pais (se carga)
--  E8    R11    ADVERTENCIA  Impuesto distinto al 13% (se carga)
-- Los errores que el OLTP impide por constraint (cantidad negativa,
-- moneda invalida, duplicados, nulos) se prueban inyectandolos en
-- Staging desde 14_PRUEBAS_INTEGRACION_QA.sql.
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON

-- Cliente con geografia inconsistente (departamento GT, zona SV) para E7
INSERT INTO TRX_CLIENTES (NOMBRE, EMAIL, TELEFONO, ID_PAIS, ID_DEPARTAMENTO, ID_ZONA, DIRECCION, SEGMENTO)
SELECT 'Cliente Geo Inconsistente', 'geo.inconsistente@email.com', '+502 5555-9999',
       p.ID_PAIS, d.ID_DEPARTAMENTO, z.ID_ZONA, 'Direccion de prueba', 'Regular'
FROM TRX_PAISES p
JOIN TRX_DEPARTAMENTOS d ON d.CODIGO_DEPARTAMENTO = 'GT-GU'
JOIN TRX_ZONAS z         ON z.CODIGO_ZONA = 'SV-ESC'
WHERE p.CODIGO_PAIS = 'GT';

DECLARE
  v_canal   NUMBER; v_cli NUMBER; v_cli_geo NUMBER; v_emp NUMBER; v_met NUMBER; v_est NUMBER;
  v_trx     NUMBER;

  FUNCTION prod (p_nombre VARCHAR2) RETURN NUMBER IS v NUMBER;
  BEGIN SELECT ID_PRODUCTO INTO v FROM TRX_PRODUCTOS WHERE NOMBRE_PRODUCTO = p_nombre; RETURN v; END;

  FUNCTION promo (p_producto VARCHAR2) RETURN NUMBER IS v NUMBER;
  BEGIN
    SELECT pr.ID_PROMOCION INTO v FROM TRX_PROMOCIONES pr
      JOIN TRX_PRODUCTOS p ON p.ID_PRODUCTO = pr.ID_PRODUCTO
     WHERE p.NOMBRE_PRODUCTO = p_producto AND ROWNUM = 1;
    RETURN v;
  END;

  FUNCTION venta (p_fecha TIMESTAMP, p_moneda VARCHAR2, p_total NUMBER, p_cliente NUMBER) RETURN NUMBER IS v NUMBER;
  BEGIN
    INSERT INTO TRX_VENTAS (FECHA_TRANSACCION, ID_CANAL, ID_CLIENTE, ID_EMPLEADO, ID_METODO_PAGO, ID_ESTADO_VENTA, MONEDA_ORIGEN, TOTAL)
    VALUES (p_fecha, v_canal, p_cliente, v_emp, v_met, v_est, p_moneda, p_total)
    RETURNING ID_TRANSACCION INTO v;
    RETURN v;
  END;

  PROCEDURE linea (p_trx NUMBER, p_prod NUMBER, p_promo NUMBER, p_cant NUMBER, p_precio NUMBER, p_desc NUMBER, p_imp NUMBER) IS
  BEGIN
    INSERT INTO TRX_DETALLE (ID_TRANSACCION, ID_PRODUCTO, ID_PROMOCION, CANTIDAD, PRECIO_UNITARIO, DESCUENTO, IMPUESTO)
    VALUES (p_trx, p_prod, p_promo, p_cant, p_precio, p_desc, p_imp);
  END;
BEGIN
  SELECT ID_CANAL INTO v_canal FROM TRX_CANALES WHERE CODIGO_CANAL = 'WEB';
  SELECT ID_CLIENTE INTO v_cli FROM TRX_CLIENTES WHERE EMAIL = 'laura.restrepo@email.com';
  SELECT ID_CLIENTE INTO v_cli_geo FROM TRX_CLIENTES WHERE EMAIL = 'geo.inconsistente@email.com';
  SELECT ID_EMPLEADO INTO v_emp FROM TRX_EMPLEADOS WHERE EMAIL = 'operador.web@retail.com';
  SELECT ID_METODO_PAGO INTO v_met FROM TRX_METODOS_PAGO WHERE NOMBRE_METODO = 'Tarjeta de Credito';
  SELECT ID_ESTADO_VENTA INTO v_est FROM TRX_ESTADOS_VENTA WHERE NOMBRE_ESTADO = 'Facturada';

  -- E1: EUR el 2025-12-31 (no hay tasa para esa fecha). 1 x 324.07 + 13%
  v_trx := venta(TIMESTAMP '2025-12-31 10:00:00', 'EUR', 366.20, v_cli);
  linea(v_trx, prod('Audifonos Sony WH-1000XM5'), NULL, 1, 324.07, 0, 42.13);

  -- E2: total declarado 100 USD de mas (correcto = 111.87)
  v_trx := venta(TIMESTAMP '2026-09-18 11:30:00', 'USD', 211.87, v_cli);
  linea(v_trx, prod('Mouse Logitech MX Master 3S'), NULL, 1, 99.00, 0, 12.87);

  -- E3: promo de audifonos (vence 2026-09-15) aplicada el 2026-09-25
  v_trx := venta(TIMESTAMP '2026-09-25 16:45:00', 'USD', 339.00, v_cli);
  linea(v_trx, prod('Audifonos Sony WH-1000XM5'), promo('Audifonos Sony WH-1000XM5'), 1, 350.00, 50.00, 39.00);

  -- E4: promocion del iPhone aplicada a una laptop HP (vigente en fecha, producto equivocado)
  v_trx := venta(TIMESTAMP '2026-09-15 09:10:00', 'USD', 691.56, v_cli);
  linea(v_trx, prod('Laptop HP Pavilion 15'), promo('iPhone 16 128GB'), 1, 680.00, 68.00, 79.56);

  -- E5: tablet descontinuada (precio vigente solo hasta 2026-08-31) vendida el 2026-09-20
  v_trx := venta(TIMESTAMP '2026-09-20 13:00:00', 'USD', 507.37, v_cli);
  linea(v_trx, prod('Tablet Samsung Galaxy Tab S9 FE'), NULL, 1, 449.00, 0, 58.37);

  -- E6: descuento (80) mayor que la linea (60). Total = 0 para no romper CHECK >= 0
  v_trx := venta(TIMESTAMP '2026-09-22 18:20:00', 'USD', 0, v_cli);
  linea(v_trx, prod('Bocina Sony SRS-XB100'), NULL, 1, 60.00, 80.00, 0);

  -- E7: cliente con geografia inconsistente (ADVERTENCIA: se carga igual)
  v_trx := venta(TIMESTAMP '2026-09-23 12:00:00', 'USD', 123.17, v_cli_geo);
  linea(v_trx, prod('Teclado Logitech MX Keys'), NULL, 1, 109.00, 0, 14.17);

  -- E8: impuesto al 5% en vez de 13% (ADVERTENCIA: se carga igual; total cuadra con lo registrado)
  v_trx := venta(TIMESTAMP '2026-09-24 15:30:00', 'USD', 63.00, v_cli);
  linea(v_trx, prod('Bocina Sony SRS-XB100'), NULL, 1, 60.00, 0, 3.00);

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Casos de error controlados insertados: 8');
END;
/

PROMPT 03 - Casos de error controlados insertados
