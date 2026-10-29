-- =====================================================================
-- 02 - DATOS DE PRUEBA OLTP (validos)              Responsable: Manuel
-- ---------------------------------------------------------------------
-- * Los IDs NO se escriben a mano: se buscan por codigo/nombre, asi el
--   script funciona aunque los IDENTITY no empiecen en 1.
-- * Las ventas se generan con semilla fija (DBMS_RANDOM.SEED), por lo
--   que cada ejecucion produce exactamente los mismos datos.
-- * Cubre: POS/WEB/MOB, USD/EUR/GTQ, ventas con y sin promocion,
--   varios productos por transaccion, distintas fechas y horas.
-- * Se evitan tildes en los datos para no depender de NLS_LANG.
-- Reglas usadas para calcular importes (decision punto 6):
--   subtotal_linea = cantidad * precio_unitario - descuento
--   impuesto       = ROUND(subtotal_linea * 0.13, 2)
--   TOTAL cabecera = SUM(subtotal_linea + impuesto)
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON

-- Paises ---------------------------------------------------------------
INSERT INTO TRX_PAISES (CODIGO_PAIS, NOMBRE_PAIS, MONEDA_OFICIAL) VALUES ('GT','Guatemala','GTQ');
INSERT INTO TRX_PAISES (CODIGO_PAIS, NOMBRE_PAIS, MONEDA_OFICIAL) VALUES ('SV','El Salvador','USD');
INSERT INTO TRX_PAISES (CODIGO_PAIS, NOMBRE_PAIS, MONEDA_OFICIAL) VALUES ('ES','Espana','EUR');
INSERT INTO TRX_PAISES (CODIGO_PAIS, NOMBRE_PAIS, MONEDA_OFICIAL) VALUES ('US','Estados Unidos','USD');
INSERT INTO TRX_PAISES (CODIGO_PAIS, NOMBRE_PAIS, MONEDA_OFICIAL) VALUES ('JP','Japon','JPY');
INSERT INTO TRX_PAISES (CODIGO_PAIS, NOMBRE_PAIS, MONEDA_OFICIAL) VALUES ('KR','Corea del Sur','KRW');
INSERT INTO TRX_PAISES (CODIGO_PAIS, NOMBRE_PAIS, MONEDA_OFICIAL) VALUES ('CN','China','CNY');
INSERT INTO TRX_PAISES (CODIGO_PAIS, NOMBRE_PAIS, MONEDA_OFICIAL) VALUES ('CH','Suiza','CHF');

-- Canales --------------------------------------------------------------
INSERT INTO TRX_CANALES (CODIGO_CANAL, NOMBRE_CANAL, DESCRIPCION) VALUES ('POS','Punto de Venta','Ventas en tienda fisica');
INSERT INTO TRX_CANALES (CODIGO_CANAL, NOMBRE_CANAL, DESCRIPCION) VALUES ('WEB','Plataforma Web','Ventas en el sitio oficial');
INSERT INTO TRX_CANALES (CODIGO_CANAL, NOMBRE_CANAL, DESCRIPCION) VALUES ('MOB','Aplicacion Movil','Ventas en la app iOS/Android');

-- Estados de venta -----------------------------------------------------
INSERT INTO TRX_ESTADOS_VENTA (NOMBRE_ESTADO, DESCRIPCION) VALUES ('Pendiente','Venta creada sin pago confirmado');
INSERT INTO TRX_ESTADOS_VENTA (NOMBRE_ESTADO, DESCRIPCION) VALUES ('Pagada','Pago confirmado, pendiente de factura');
INSERT INTO TRX_ESTADOS_VENTA (NOMBRE_ESTADO, DESCRIPCION) VALUES ('Facturada','Transaccion completada y emitida legalmente');
INSERT INTO TRX_ESTADOS_VENTA (NOMBRE_ESTADO, DESCRIPCION) VALUES ('Anulada','Venta anulada, no se reporta');

-- Metodos de pago ------------------------------------------------------
INSERT INTO TRX_METODOS_PAGO (NOMBRE_METODO, DESCRIPCION) VALUES ('Efectivo','Pago en caja');
INSERT INTO TRX_METODOS_PAGO (NOMBRE_METODO, DESCRIPCION) VALUES ('Tarjeta de Credito','Visa / Mastercard / Amex');
INSERT INTO TRX_METODOS_PAGO (NOMBRE_METODO, DESCRIPCION) VALUES ('Tarjeta de Debito','Debito bancario');
INSERT INTO TRX_METODOS_PAGO (NOMBRE_METODO, DESCRIPCION) VALUES ('Transferencia','Transferencia bancaria');
INSERT INTO TRX_METODOS_PAGO (NOMBRE_METODO, DESCRIPCION) VALUES ('Billetera Digital','PayPal / Apple Pay / Google Pay');

-- Categorias (jerarquia) -----------------------------------------------
INSERT INTO TRX_CATEGORIAS_PRODUCTO (NOMBRE_CATEGORIA, DESCRIPCION) VALUES ('Tecnologia','Categoria raiz');
INSERT INTO TRX_CATEGORIAS_PRODUCTO (ID_CATEGORIA_PADRE, NOMBRE_CATEGORIA, DESCRIPCION)
  SELECT ID_CATEGORIA, 'Audio', 'Audifonos y bocinas' FROM TRX_CATEGORIAS_PRODUCTO WHERE NOMBRE_CATEGORIA = 'Tecnologia';
INSERT INTO TRX_CATEGORIAS_PRODUCTO (ID_CATEGORIA_PADRE, NOMBRE_CATEGORIA, DESCRIPCION)
  SELECT ID_CATEGORIA, 'Computadoras', 'Laptops y equipos' FROM TRX_CATEGORIAS_PRODUCTO WHERE NOMBRE_CATEGORIA = 'Tecnologia';
INSERT INTO TRX_CATEGORIAS_PRODUCTO (ID_CATEGORIA_PADRE, NOMBRE_CATEGORIA, DESCRIPCION)
  SELECT ID_CATEGORIA, 'Smartphones', 'Telefonos inteligentes' FROM TRX_CATEGORIAS_PRODUCTO WHERE NOMBRE_CATEGORIA = 'Tecnologia';
INSERT INTO TRX_CATEGORIAS_PRODUCTO (ID_CATEGORIA_PADRE, NOMBRE_CATEGORIA, DESCRIPCION)
  SELECT ID_CATEGORIA, 'Accesorios', 'Perifericos y accesorios' FROM TRX_CATEGORIAS_PRODUCTO WHERE NOMBRE_CATEGORIA = 'Tecnologia';
INSERT INTO TRX_CATEGORIAS_PRODUCTO (ID_CATEGORIA_PADRE, NOMBRE_CATEGORIA, DESCRIPCION)
  SELECT ID_CATEGORIA, 'Gaming', 'Consolas y videojuegos' FROM TRX_CATEGORIAS_PRODUCTO WHERE NOMBRE_CATEGORIA = 'Tecnologia';
INSERT INTO TRX_CATEGORIAS_PRODUCTO (ID_CATEGORIA_PADRE, NOMBRE_CATEGORIA, DESCRIPCION)
  SELECT ID_CATEGORIA, 'Televisores', 'Smart TV' FROM TRX_CATEGORIAS_PRODUCTO WHERE NOMBRE_CATEGORIA = 'Tecnologia';
INSERT INTO TRX_CATEGORIAS_PRODUCTO (ID_CATEGORIA_PADRE, NOMBRE_CATEGORIA, DESCRIPCION)
  SELECT ID_CATEGORIA, 'Tablets', 'Tabletas' FROM TRX_CATEGORIAS_PRODUCTO WHERE NOMBRE_CATEGORIA = 'Tecnologia';

-- Tasas diarias: 2026-08-25 a 2026-10-10 (TASA_USD = USD por 1 unidad)
-- EUR ~ 1.08 USD y GTQ ~ 0.1295 USD, con una variacion diaria pequena.
INSERT INTO TRX_MONEDAS (FECHA, MONEDA_ORIGEN, TASA_USD, FUENTE_TIPO_CAMBIO)
  SELECT DATE '2026-08-25' + LEVEL - 1, 'USD', 1, 'Tasa base'
  FROM DUAL CONNECT BY LEVEL <= 47;
INSERT INTO TRX_MONEDAS (FECHA, MONEDA_ORIGEN, TASA_USD, FUENTE_TIPO_CAMBIO)
  SELECT DATE '2026-08-25' + LEVEL - 1, 'EUR', ROUND(1.08 + 0.006 * SIN(LEVEL / 3), 6), 'Banco Central Europeo'
  FROM DUAL CONNECT BY LEVEL <= 47;
INSERT INTO TRX_MONEDAS (FECHA, MONEDA_ORIGEN, TASA_USD, FUENTE_TIPO_CAMBIO)
  SELECT DATE '2026-08-25' + LEVEL - 1, 'GTQ', ROUND(0.1295 + 0.0004 * COS(LEVEL / 4), 6), 'Banco de Guatemala'
  FROM DUAL CONNECT BY LEVEL <= 47;

-- Departamentos ----------------------------------------------------------
INSERT INTO TRX_DEPARTAMENTOS (ID_PAIS, CODIGO_DEPARTAMENTO, NOMBRE_DEPARTAMENTO)
  SELECT ID_PAIS, 'GT-GU', 'Guatemala' FROM TRX_PAISES WHERE CODIGO_PAIS = 'GT';
INSERT INTO TRX_DEPARTAMENTOS (ID_PAIS, CODIGO_DEPARTAMENTO, NOMBRE_DEPARTAMENTO)
  SELECT ID_PAIS, 'GT-SA', 'Sacatepequez' FROM TRX_PAISES WHERE CODIGO_PAIS = 'GT';
INSERT INTO TRX_DEPARTAMENTOS (ID_PAIS, CODIGO_DEPARTAMENTO, NOMBRE_DEPARTAMENTO)
  SELECT ID_PAIS, 'GT-QZ', 'Quetzaltenango' FROM TRX_PAISES WHERE CODIGO_PAIS = 'GT';
INSERT INTO TRX_DEPARTAMENTOS (ID_PAIS, CODIGO_DEPARTAMENTO, NOMBRE_DEPARTAMENTO)
  SELECT ID_PAIS, 'SV-SS', 'San Salvador' FROM TRX_PAISES WHERE CODIGO_PAIS = 'SV';
INSERT INTO TRX_DEPARTAMENTOS (ID_PAIS, CODIGO_DEPARTAMENTO, NOMBRE_DEPARTAMENTO)
  SELECT ID_PAIS, 'SV-LI', 'La Libertad' FROM TRX_PAISES WHERE CODIGO_PAIS = 'SV';
INSERT INTO TRX_DEPARTAMENTOS (ID_PAIS, CODIGO_DEPARTAMENTO, NOMBRE_DEPARTAMENTO)
  SELECT ID_PAIS, 'ES-MD', 'Madrid' FROM TRX_PAISES WHERE CODIGO_PAIS = 'ES';
INSERT INTO TRX_DEPARTAMENTOS (ID_PAIS, CODIGO_DEPARTAMENTO, NOMBRE_DEPARTAMENTO)
  SELECT ID_PAIS, 'ES-B', 'Barcelona' FROM TRX_PAISES WHERE CODIGO_PAIS = 'ES';

-- Zonas -----------------------------------------------------------------
INSERT INTO TRX_ZONAS (ID_PAIS, CODIGO_ZONA, NOMBRE_ZONA) SELECT ID_PAIS, 'GT-Z10', 'Zona Viva 10'      FROM TRX_PAISES WHERE CODIGO_PAIS = 'GT';
INSERT INTO TRX_ZONAS (ID_PAIS, CODIGO_ZONA, NOMBRE_ZONA) SELECT ID_PAIS, 'GT-Z01', 'Centro Historico'  FROM TRX_PAISES WHERE CODIGO_PAIS = 'GT';
INSERT INTO TRX_ZONAS (ID_PAIS, CODIGO_ZONA, NOMBRE_ZONA) SELECT ID_PAIS, 'GT-ANT', 'Antigua Centro'    FROM TRX_PAISES WHERE CODIGO_PAIS = 'GT';
INSERT INTO TRX_ZONAS (ID_PAIS, CODIGO_ZONA, NOMBRE_ZONA) SELECT ID_PAIS, 'GT-XEL', 'Xela Centro'       FROM TRX_PAISES WHERE CODIGO_PAIS = 'GT';
INSERT INTO TRX_ZONAS (ID_PAIS, CODIGO_ZONA, NOMBRE_ZONA) SELECT ID_PAIS, 'SV-ESC', 'Colonia Escalon'   FROM TRX_PAISES WHERE CODIGO_PAIS = 'SV';
INSERT INTO TRX_ZONAS (ID_PAIS, CODIGO_ZONA, NOMBRE_ZONA) SELECT ID_PAIS, 'SV-STA', 'Santa Tecla'       FROM TRX_PAISES WHERE CODIGO_PAIS = 'SV';
INSERT INTO TRX_ZONAS (ID_PAIS, CODIGO_ZONA, NOMBRE_ZONA) SELECT ID_PAIS, 'ES-SAL', 'Barrio Salamanca'  FROM TRX_PAISES WHERE CODIGO_PAIS = 'ES';
INSERT INTO TRX_ZONAS (ID_PAIS, CODIGO_ZONA, NOMBRE_ZONA) SELECT ID_PAIS, 'ES-EIX', 'Eixample'          FROM TRX_PAISES WHERE CODIGO_PAIS = 'ES';

-- Marcas ----------------------------------------------------------------
INSERT INTO TRX_MARCAS (NOMBRE_MARCA, ID_PAIS_ORIGEN, SITIO_WEB) SELECT 'Sony',     ID_PAIS, 'https://www.sony.com'     FROM TRX_PAISES WHERE CODIGO_PAIS = 'JP';
INSERT INTO TRX_MARCAS (NOMBRE_MARCA, ID_PAIS_ORIGEN, SITIO_WEB) SELECT 'Nintendo', ID_PAIS, 'https://www.nintendo.com' FROM TRX_PAISES WHERE CODIGO_PAIS = 'JP';
INSERT INTO TRX_MARCAS (NOMBRE_MARCA, ID_PAIS_ORIGEN, SITIO_WEB) SELECT 'Samsung',  ID_PAIS, 'https://www.samsung.com'  FROM TRX_PAISES WHERE CODIGO_PAIS = 'KR';
INSERT INTO TRX_MARCAS (NOMBRE_MARCA, ID_PAIS_ORIGEN, SITIO_WEB) SELECT 'Apple',    ID_PAIS, 'https://www.apple.com'    FROM TRX_PAISES WHERE CODIGO_PAIS = 'US';
INSERT INTO TRX_MARCAS (NOMBRE_MARCA, ID_PAIS_ORIGEN, SITIO_WEB) SELECT 'HP',       ID_PAIS, 'https://www.hp.com'       FROM TRX_PAISES WHERE CODIGO_PAIS = 'US';
INSERT INTO TRX_MARCAS (NOMBRE_MARCA, ID_PAIS_ORIGEN, SITIO_WEB) SELECT 'Lenovo',   ID_PAIS, 'https://www.lenovo.com'   FROM TRX_PAISES WHERE CODIGO_PAIS = 'CN';
INSERT INTO TRX_MARCAS (NOMBRE_MARCA, ID_PAIS_ORIGEN, SITIO_WEB) SELECT 'Xiaomi',   ID_PAIS, 'https://www.mi.com'       FROM TRX_PAISES WHERE CODIGO_PAIS = 'CN';
INSERT INTO TRX_MARCAS (NOMBRE_MARCA, ID_PAIS_ORIGEN, SITIO_WEB) SELECT 'Logitech', ID_PAIS, 'https://www.logitech.com' FROM TRX_PAISES WHERE CODIGO_PAIS = 'CH';

-- Proveedores -----------------------------------------------------------
INSERT INTO TRX_PROVEEDORES (NOMBRE_PROVEEDOR, ID_PAIS, NOMBRE_CONTACTO, TELEFONO, CORREO_ELECTRONICO)
  SELECT 'Distribuidora Tech SA', ID_PAIS, 'Carlos Perez', '+502 2222-1000', 'ventas@distech.gt' FROM TRX_PAISES WHERE CODIGO_PAIS = 'GT';
INSERT INTO TRX_PROVEEDORES (NOMBRE_PROVEEDOR, ID_PAIS, NOMBRE_CONTACTO, TELEFONO, CORREO_ELECTRONICO)
  SELECT 'Importadora Digital SV', ID_PAIS, 'Ana Martinez', '+503 2250-3000', 'compras@impdigital.sv' FROM TRX_PAISES WHERE CODIGO_PAIS = 'SV';
INSERT INTO TRX_PROVEEDORES (NOMBRE_PROVEEDOR, ID_PAIS, NOMBRE_CONTACTO, TELEFONO, CORREO_ELECTRONICO)
  SELECT 'EuroTech Supply SL', ID_PAIS, 'Jordi Puig', '+34 910 000 000', 'info@eurotech.es' FROM TRX_PAISES WHERE CODIGO_PAIS = 'ES';

-- Sucursales ------------------------------------------------------------
INSERT INTO TRX_SUCURSALES (ID_DEPARTAMENTO, CODIGO_SUCURSAL, NOMBRE_SUCURSAL, DIRECCION, FECHA_APERTURA)
  SELECT ID_DEPARTAMENTO, 'SUC-GT-OAK', 'Tienda Oakland Mall', 'Diagonal 6, Zona 10', DATE '2022-03-01' FROM TRX_DEPARTAMENTOS WHERE CODIGO_DEPARTAMENTO = 'GT-GU';
INSERT INTO TRX_SUCURSALES (ID_DEPARTAMENTO, CODIGO_SUCURSAL, NOMBRE_SUCURSAL, DIRECCION, FECHA_APERTURA)
  SELECT ID_DEPARTAMENTO, 'SUC-GT-XEL', 'Tienda Interplaza Xela', 'Calzada Las Americas', DATE '2023-06-15' FROM TRX_DEPARTAMENTOS WHERE CODIGO_DEPARTAMENTO = 'GT-QZ';
INSERT INTO TRX_SUCURSALES (ID_DEPARTAMENTO, CODIGO_SUCURSAL, NOMBRE_SUCURSAL, DIRECCION, FECHA_APERTURA)
  SELECT ID_DEPARTAMENTO, 'SUC-SV-MUL', 'Tienda Multiplaza', 'Antiguo Cuscatlan', DATE '2023-01-10' FROM TRX_DEPARTAMENTOS WHERE CODIGO_DEPARTAMENTO = 'SV-LI';
INSERT INTO TRX_SUCURSALES (ID_DEPARTAMENTO, CODIGO_SUCURSAL, NOMBRE_SUCURSAL, DIRECCION, FECHA_APERTURA)
  SELECT ID_DEPARTAMENTO, 'SUC-ES-MAD', 'Tienda Gran Via', 'Gran Via 30', DATE '2024-02-01' FROM TRX_DEPARTAMENTOS WHERE CODIGO_DEPARTAMENTO = 'ES-MD';
INSERT INTO TRX_SUCURSALES (ID_DEPARTAMENTO, CODIGO_SUCURSAL, NOMBRE_SUCURSAL, DIRECCION, FECHA_APERTURA)
  SELECT ID_DEPARTAMENTO, 'SUC-VIRT', 'Bodega Central Online', 'Zona 12', DATE '2022-01-01' FROM TRX_DEPARTAMENTOS WHERE CODIGO_DEPARTAMENTO = 'GT-GU';

-- Clientes (pais, departamento y zona coherentes) -------------------------
INSERT INTO TRX_CLIENTES (NOMBRE, EMAIL, TELEFONO, ID_PAIS, ID_DEPARTAMENTO, ID_ZONA, DIRECCION, SEGMENTO, FECHA_REGISTRO)
WITH c (NOMBRE, EMAIL, TELEFONO, PAIS, DEP, ZONA, DIRECCION, SEGMENTO, FREG) AS (
  SELECT 'Laura Restrepo',   'laura.restrepo@email.com', '+502 5555-1234', 'GT','GT-GU','GT-Z10','Av. Las Americas 12',  'Premium',     DATE '2024-05-10' FROM DUAL UNION ALL
  SELECT 'Jorge Castillo',   'jorge.castillo@email.com', '+502 5555-2201', 'GT','GT-GU','GT-Z01','6a Avenida 8-20',     'Regular',     DATE '2025-01-15' FROM DUAL UNION ALL
  SELECT 'Maria Lopez',      'maria.lopez@email.com',    '+502 5555-3302', 'GT','GT-SA','GT-ANT','Calle del Arco 4',    'Premium',     DATE '2023-11-02' FROM DUAL UNION ALL
  SELECT 'Kevin Ajanel',     'kevin.ajanel@email.com',   '+502 5555-4403', 'GT','GT-QZ','GT-XEL','14 Avenida 3-15',     'Nuevo',       DATE '2026-08-01' FROM DUAL UNION ALL
  SELECT 'Sofia Hernandez',  'sofia.hdz@email.com',      '+503 7000-1111', 'SV','SV-SS','SV-ESC','Paseo General Escalon','Premium',    DATE '2024-02-20' FROM DUAL UNION ALL
  SELECT 'Carlos Mejia',     'carlos.mejia@email.com',   '+503 7000-2222', 'SV','SV-LI','SV-STA','Calle Chiltiupan 5',  'Regular',     DATE '2025-06-11' FROM DUAL UNION ALL
  SELECT 'Tecnologias Rivas','compras@trivas.com.sv',    '+503 2200-3333', 'SV','SV-SS','SV-ESC','Blvd. del Hipodromo', 'Corporativo', DATE '2023-09-30' FROM DUAL UNION ALL
  SELECT 'Lucia Fernandez',  'lucia.fdz@email.es',       '+34 600 111 222','ES','ES-MD','ES-SAL','Calle Serrano 45',    'Premium',     DATE '2024-10-05' FROM DUAL UNION ALL
  SELECT 'Pablo Garcia',     'pablo.garcia@email.es',    '+34 600 333 444','ES','ES-B', 'ES-EIX','Carrer de Mallorca 9','Regular',     DATE '2025-03-18' FROM DUAL UNION ALL
  SELECT 'Elena Ruiz',       'elena.ruiz@email.es',      '+34 600 555 666','ES','ES-MD','ES-SAL','Calle Goya 12',       'Nuevo',       DATE '2026-07-22' FROM DUAL UNION ALL
  SELECT 'Andrea Morales',   'andrea.morales@email.com', '+502 5555-5504', 'GT','GT-GU','GT-Z10','Blvd. Los Proceres',  'Corporativo', DATE '2023-04-04' FROM DUAL UNION ALL
  SELECT 'Diego Ramirez',    'diego.ramirez@email.com',  '+503 7000-4444', 'SV','SV-LI','SV-STA','Residencial Lomas',   'Nuevo',       DATE '2026-08-15' FROM DUAL
)
SELECT c.NOMBRE, c.EMAIL, c.TELEFONO, p.ID_PAIS, d.ID_DEPARTAMENTO, z.ID_ZONA, c.DIRECCION, c.SEGMENTO, c.FREG
FROM c
JOIN TRX_PAISES p        ON p.CODIGO_PAIS = c.PAIS
JOIN TRX_DEPARTAMENTOS d ON d.CODIGO_DEPARTAMENTO = c.DEP AND d.ID_PAIS = p.ID_PAIS
JOIN TRX_ZONAS z         ON z.CODIGO_ZONA = c.ZONA AND z.ID_PAIS = p.ID_PAIS;

-- Productos (precio y costo en USD) -------------------------------------
INSERT INTO TRX_PRODUCTOS (NOMBRE_PRODUCTO, ID_CATEGORIA, ID_MARCA, ID_PROVEEDOR, PRECIO_BASE, COSTO_UNITARIO_USD, FECHA_INICIO_PRECIO, FECHA_FIN_PRECIO)
WITH p (NOMBRE, CAT, MARCA, PROV, PRECIO, COSTO, INI, FIN) AS (
  SELECT 'Audifonos Sony WH-1000XM5',     'Audio',        'Sony',     'Distribuidora Tech SA',   350.00, 230.00, DATE '2026-01-01', CAST(NULL AS DATE) FROM DUAL UNION ALL
  SELECT 'Bocina Sony SRS-XB100',         'Audio',        'Sony',     'Distribuidora Tech SA',    60.00,  35.00, DATE '2026-01-01', NULL FROM DUAL UNION ALL
  SELECT 'Laptop Lenovo IdeaPad 5',       'Computadoras', 'Lenovo',   'Importadora Digital SV',  750.00, 560.00, DATE '2026-01-01', NULL FROM DUAL UNION ALL
  SELECT 'Laptop HP Pavilion 15',         'Computadoras', 'HP',       'Importadora Digital SV',  680.00, 500.00, DATE '2026-01-01', NULL FROM DUAL UNION ALL
  SELECT 'MacBook Air M3 13',             'Computadoras', 'Apple',    'EuroTech Supply SL',     1299.00, 980.00, DATE '2026-01-01', NULL FROM DUAL UNION ALL
  SELECT 'iPhone 16 128GB',               'Smartphones',  'Apple',    'EuroTech Supply SL',      999.00, 760.00, DATE '2026-01-01', NULL FROM DUAL UNION ALL
  SELECT 'Samsung Galaxy S25',            'Smartphones',  'Samsung',  'Importadora Digital SV',  899.00, 650.00, DATE '2026-01-01', NULL FROM DUAL UNION ALL
  SELECT 'Xiaomi Redmi Note 14',          'Smartphones',  'Xiaomi',   'Distribuidora Tech SA',   249.00, 170.00, DATE '2026-01-01', NULL FROM DUAL UNION ALL
  SELECT 'Mouse Logitech MX Master 3S',   'Accesorios',   'Logitech', 'Distribuidora Tech SA',    99.00,  55.00, DATE '2026-01-01', NULL FROM DUAL UNION ALL
  SELECT 'Teclado Logitech MX Keys',      'Accesorios',   'Logitech', 'Distribuidora Tech SA',   109.00,  62.00, DATE '2026-01-01', NULL FROM DUAL UNION ALL
  SELECT 'Nintendo Switch OLED',          'Gaming',       'Nintendo', 'Importadora Digital SV',  349.00, 270.00, DATE '2026-01-01', NULL FROM DUAL UNION ALL
  SELECT 'Smart TV Samsung 55 Crystal',   'Televisores',  'Samsung',  'EuroTech Supply SL',      599.00, 430.00, DATE '2026-01-01', NULL FROM DUAL UNION ALL
  -- Producto descontinuado: su precio vencio el 31/08. Solo lo usa el script 03 (caso de error).
  SELECT 'Tablet Samsung Galaxy Tab S9 FE','Tablets',     'Samsung',  'Importadora Digital SV',  449.00, 330.00, DATE '2026-01-01', DATE '2026-08-31' FROM DUAL
)
SELECT p.NOMBRE, c.ID_CATEGORIA, m.ID_MARCA, v.ID_PROVEEDOR, p.PRECIO, p.COSTO, p.INI, p.FIN
FROM p
JOIN TRX_CATEGORIAS_PRODUCTO c ON c.NOMBRE_CATEGORIA = p.CAT
JOIN TRX_MARCAS m              ON m.NOMBRE_MARCA = p.MARCA
JOIN TRX_PROVEEDORES v         ON v.NOMBRE_PROVEEDOR = p.PROV;

-- Empleados (WEB/MOB usan operadores virtuales de SUC-VIRT) --------------
INSERT INTO TRX_EMPLEADOS (NOMBRE, EMAIL, CARGO, ID_SUCURSAL, FECHA_CONTRATACION)
WITH e (NOMBRE, EMAIL, CARGO, SUC, FCON) AS (
  SELECT 'Pedro Lopez',      'pedro.lopez@retail.com',      'Vendedor',          'SUC-GT-OAK', DATE '2022-03-01' FROM DUAL UNION ALL
  SELECT 'Ana Gomez',        'ana.gomez@retail.com',        'Supervisora',       'SUC-GT-OAK', DATE '2022-04-15' FROM DUAL UNION ALL
  SELECT 'Luis Tzoc',        'luis.tzoc@retail.com',        'Vendedor',          'SUC-GT-XEL', DATE '2023-06-15' FROM DUAL UNION ALL
  SELECT 'Rosa Quezada',     'rosa.quezada@retail.com',     'Vendedora',         'SUC-SV-MUL', DATE '2023-01-10' FROM DUAL UNION ALL
  SELECT 'Mario Alvarado',   'mario.alvarado@retail.com',   'Vendedor',          'SUC-SV-MUL', DATE '2024-07-01' FROM DUAL UNION ALL
  SELECT 'Marta Sanchez',    'marta.sanchez@retail.com',    'Vendedora',         'SUC-ES-MAD', DATE '2024-02-01' FROM DUAL UNION ALL
  SELECT 'Operador Web',     'operador.web@retail.com',     'Operador Virtual',  'SUC-VIRT',   DATE '2022-01-01' FROM DUAL UNION ALL
  SELECT 'Operador App',     'operador.app@retail.com',     'Operador Virtual',  'SUC-VIRT',   DATE '2022-01-01' FROM DUAL
)
SELECT e.NOMBRE, e.EMAIL, e.CARGO, s.ID_SUCURSAL, e.FCON
FROM e JOIN TRX_SUCURSALES s ON s.CODIGO_SUCURSAL = e.SUC;

-- Promociones (MONTO = USD por unidad; PORCENTAJE = % sobre el precio) --
INSERT INTO TRX_PROMOCIONES (ID_PRODUCTO, TIPO, VALOR, FECHA_INICIO, FECHA_FIN, DESCRIPCION)
WITH pr (PROD, TIPO, VALOR, INI, FIN, DESCR) AS (
  SELECT 'Audifonos Sony WH-1000XM5', 'MONTO',      50, DATE '2026-09-01', DATE '2026-09-15', 'Promo lanzamiento audio' FROM DUAL UNION ALL
  SELECT 'iPhone 16 128GB',           'PORCENTAJE', 10, DATE '2026-09-10', DATE '2026-09-20', 'Semana Apple'            FROM DUAL UNION ALL
  SELECT 'Nintendo Switch OLED',      'MONTO',      30, DATE '2026-09-15', DATE '2026-09-30', 'Gaming fest'             FROM DUAL UNION ALL
  SELECT 'Laptop Lenovo IdeaPad 5',   'PORCENTAJE',  5, DATE '2026-09-01', DATE '2026-09-30', 'Regreso a clases'        FROM DUAL UNION ALL
  SELECT 'Smart TV Samsung 55 Crystal','PORCENTAJE',15, DATE '2026-09-12', DATE '2026-09-16', 'Fiestas patrias'         FROM DUAL
)
SELECT p.ID_PRODUCTO, pr.TIPO, pr.VALOR, pr.INI, pr.FIN, pr.DESCR
FROM pr JOIN TRX_PRODUCTOS p ON p.NOMBRE_PRODUCTO = pr.PROD;

COMMIT;

-- Ventas: 150 transacciones entre 2026-09-01 y 2026-09-30 ---------------
DECLARE
  TYPE t_num IS TABLE OF NUMBER;
  v_clientes   t_num;
  v_productos  t_num;
  v_pos_gt     t_num; v_pos_sv t_num; v_pos_es t_num;
  v_op_web     NUMBER; v_op_app NUMBER;
  v_canal_pos  NUMBER; v_canal_web NUMBER; v_canal_mob NUMBER;
  v_metodos    t_num;
  v_est_fact   NUMBER; v_est_pag NUMBER; v_est_anu NUMBER;

  v_id_trx     NUMBER;
  v_fecha      TIMESTAMP;
  v_dia        DATE;
  v_canal      NUMBER;
  v_cod_canal  VARCHAR2(3);
  v_cliente    NUMBER;
  v_pais_cli   VARCHAR2(2);
  v_moneda     VARCHAR2(3);
  v_tasa       NUMBER;
  v_empleado   NUMBER;
  v_metodo     NUMBER;
  v_estado     NUMBER;
  v_lineas     PLS_INTEGER;
  v_prod       NUMBER;
  v_usados     VARCHAR2(400);
  v_precio_usd NUMBER;
  v_precio     NUMBER;
  v_cant       PLS_INTEGER;
  v_promo      NUMBER;
  v_tipo_promo VARCHAR2(50);
  v_val_promo  NUMBER;
  v_desc       NUMBER;
  v_imp        NUMBER;
  v_total      NUMBER;

  FUNCTION pick (p_lista t_num) RETURN NUMBER IS
  BEGIN
    RETURN p_lista(TRUNC(DBMS_RANDOM.VALUE(1, p_lista.COUNT + 1)));
  END;
BEGIN
  DBMS_RANDOM.SEED(2026);

  SELECT ID_CLIENTE BULK COLLECT INTO v_clientes FROM TRX_CLIENTES ORDER BY ID_CLIENTE;
  -- El producto descontinuado (precio vencido) no participa en las ventas validas
  SELECT ID_PRODUCTO BULK COLLECT INTO v_productos FROM TRX_PRODUCTOS
   WHERE FECHA_FIN_PRECIO IS NULL ORDER BY ID_PRODUCTO;
  SELECT ID_METODO_PAGO BULK COLLECT INTO v_metodos FROM TRX_METODOS_PAGO ORDER BY ID_METODO_PAGO;

  SELECT e.ID_EMPLEADO BULK COLLECT INTO v_pos_gt FROM TRX_EMPLEADOS e JOIN TRX_SUCURSALES s ON s.ID_SUCURSAL = e.ID_SUCURSAL
   WHERE s.CODIGO_SUCURSAL IN ('SUC-GT-OAK','SUC-GT-XEL') ORDER BY 1;
  SELECT e.ID_EMPLEADO BULK COLLECT INTO v_pos_sv FROM TRX_EMPLEADOS e JOIN TRX_SUCURSALES s ON s.ID_SUCURSAL = e.ID_SUCURSAL
   WHERE s.CODIGO_SUCURSAL = 'SUC-SV-MUL' ORDER BY 1;
  SELECT e.ID_EMPLEADO BULK COLLECT INTO v_pos_es FROM TRX_EMPLEADOS e JOIN TRX_SUCURSALES s ON s.ID_SUCURSAL = e.ID_SUCURSAL
   WHERE s.CODIGO_SUCURSAL = 'SUC-ES-MAD' ORDER BY 1;
  SELECT ID_EMPLEADO INTO v_op_web FROM TRX_EMPLEADOS WHERE EMAIL = 'operador.web@retail.com';
  SELECT ID_EMPLEADO INTO v_op_app FROM TRX_EMPLEADOS WHERE EMAIL = 'operador.app@retail.com';

  SELECT ID_CANAL INTO v_canal_pos FROM TRX_CANALES WHERE CODIGO_CANAL = 'POS';
  SELECT ID_CANAL INTO v_canal_web FROM TRX_CANALES WHERE CODIGO_CANAL = 'WEB';
  SELECT ID_CANAL INTO v_canal_mob FROM TRX_CANALES WHERE CODIGO_CANAL = 'MOB';
  SELECT ID_ESTADO_VENTA INTO v_est_fact FROM TRX_ESTADOS_VENTA WHERE NOMBRE_ESTADO = 'Facturada';
  SELECT ID_ESTADO_VENTA INTO v_est_pag  FROM TRX_ESTADOS_VENTA WHERE NOMBRE_ESTADO = 'Pagada';
  SELECT ID_ESTADO_VENTA INTO v_est_anu  FROM TRX_ESTADOS_VENTA WHERE NOMBRE_ESTADO = 'Anulada';

  FOR i IN 1 .. 150 LOOP
    v_dia   := DATE '2026-09-01' + TRUNC(DBMS_RANDOM.VALUE(0, 30));
    v_fecha := CAST(v_dia AS TIMESTAMP)
               + NUMTODSINTERVAL(TRUNC(DBMS_RANDOM.VALUE(8, 21)), 'HOUR')
               + NUMTODSINTERVAL(TRUNC(DBMS_RANDOM.VALUE(0, 60)), 'MINUTE')
               + NUMTODSINTERVAL(TRUNC(DBMS_RANDOM.VALUE(0, 60)), 'SECOND');

    v_cliente := pick(v_clientes);
    SELECT p.CODIGO_PAIS INTO v_pais_cli
      FROM TRX_CLIENTES c JOIN TRX_PAISES p ON p.ID_PAIS = c.ID_PAIS
     WHERE c.ID_CLIENTE = v_cliente;

    -- Moneda segun pais del cliente (algunos clientes GT pagan en USD)
    v_moneda := CASE v_pais_cli
                  WHEN 'GT' THEN CASE WHEN DBMS_RANDOM.VALUE < 0.2 THEN 'USD' ELSE 'GTQ' END
                  WHEN 'ES' THEN 'EUR'
                  ELSE 'USD' END;
    SELECT TASA_USD INTO v_tasa FROM TRX_MONEDAS WHERE FECHA = v_dia AND MONEDA_ORIGEN = v_moneda;

    -- Canal y empleado
    CASE TRUNC(DBMS_RANDOM.VALUE(0, 3))
      WHEN 0 THEN v_canal := v_canal_pos; v_cod_canal := 'POS';
      WHEN 1 THEN v_canal := v_canal_web; v_cod_canal := 'WEB';
      ELSE        v_canal := v_canal_mob; v_cod_canal := 'MOB';
    END CASE;
    v_empleado := CASE
                    WHEN v_cod_canal = 'WEB' THEN v_op_web
                    WHEN v_cod_canal = 'MOB' THEN v_op_app
                    WHEN v_pais_cli = 'GT'   THEN pick(v_pos_gt)
                    WHEN v_pais_cli = 'SV'   THEN pick(v_pos_sv)
                    ELSE pick(v_pos_es) END;

    v_metodo := CASE WHEN v_cod_canal = 'POS' THEN pick(v_metodos)
                     ELSE v_metodos(TRUNC(DBMS_RANDOM.VALUE(2, v_metodos.COUNT + 1))) END; -- online sin efectivo
    v_estado := CASE WHEN DBMS_RANDOM.VALUE < 0.04 THEN v_est_anu
                     WHEN DBMS_RANDOM.VALUE < 0.15 THEN v_est_pag
                     ELSE v_est_fact END;

    INSERT INTO TRX_VENTAS (FECHA_TRANSACCION, ID_CANAL, ID_CLIENTE, ID_EMPLEADO, ID_METODO_PAGO, ID_ESTADO_VENTA, MONEDA_ORIGEN, TOTAL)
    VALUES (v_fecha, v_canal, v_cliente, v_empleado, v_metodo, v_estado, v_moneda, 0)
    RETURNING ID_TRANSACCION INTO v_id_trx;

    v_total  := 0;
    v_usados := ',';
    v_lineas := TRUNC(DBMS_RANDOM.VALUE(1, 5));     -- 1 a 4 productos distintos
    FOR l IN 1 .. v_lineas LOOP
      LOOP
        v_prod := pick(v_productos);
        EXIT WHEN INSTR(v_usados, ',' || v_prod || ',') = 0;
      END LOOP;
      v_usados := v_usados || v_prod || ',';

      SELECT PRECIO_BASE INTO v_precio_usd FROM TRX_PRODUCTOS WHERE ID_PRODUCTO = v_prod;
      v_precio := ROUND(v_precio_usd / v_tasa, 2);  -- precio en moneda de la venta
      v_cant   := CASE WHEN DBMS_RANDOM.VALUE < 0.75 THEN 1 ELSE TRUNC(DBMS_RANDOM.VALUE(2, 4)) END;

      -- Promocion vigente del producto (se aplica en el 80% de los casos)
      BEGIN
        SELECT ID_PROMOCION, TIPO, VALOR INTO v_promo, v_tipo_promo, v_val_promo
          FROM TRX_PROMOCIONES
         WHERE ID_PRODUCTO = v_prod AND ACTIVO = 'S'
           AND v_dia BETWEEN FECHA_INICIO AND FECHA_FIN
           AND ROWNUM = 1;
        IF DBMS_RANDOM.VALUE >= 0.8 THEN v_promo := NULL; END IF;
      EXCEPTION WHEN NO_DATA_FOUND THEN v_promo := NULL;
      END;

      IF v_promo IS NULL THEN
        v_desc := 0;
      ELSIF v_tipo_promo = 'PORCENTAJE' THEN
        v_desc := ROUND(v_cant * v_precio * v_val_promo / 100, 2);
      ELSE
        v_desc := ROUND(v_cant * v_val_promo / v_tasa, 2);   -- MONTO en USD convertido
      END IF;

      v_imp   := ROUND((v_cant * v_precio - v_desc) * 0.13, 2);
      v_total := v_total + (v_cant * v_precio - v_desc) + v_imp;

      INSERT INTO TRX_DETALLE (ID_TRANSACCION, ID_PRODUCTO, ID_PROMOCION, CANTIDAD, PRECIO_UNITARIO, DESCUENTO, IMPUESTO)
      VALUES (v_id_trx, v_prod, v_promo, v_cant, v_precio, v_desc, v_imp);
    END LOOP;

    UPDATE TRX_VENTAS SET TOTAL = v_total WHERE ID_TRANSACCION = v_id_trx;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Ventas validas generadas: 150');
END;
/

PROMPT 02 - Datos de prueba OLTP cargados
