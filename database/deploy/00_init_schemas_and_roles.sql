-- =====================================================================
-- 00 - ARQUITECTURA MULTI-ESQUEMA: TABLESPACES, USUARIOS Y ROL
-- ---------------------------------------------------------------------
-- EJECUTAR COMO: SYS (AS SYSDBA) o SYSTEM, conectado al PDB FREEPDB1.
--
-- Crea 3 esquemas con responsabilidades separadas:
--   OMNI_OLTP  -> dueno de los datos transaccionales (17 tablas TRX_*)
--   OMNI_DW    -> dueno del Staging, Data Warehouse, ETL y vistas
--   OMNI_BI    -> cuenta de solo lectura para Power BI / reportes
--
-- Principio de minimo privilegio:
--   * Cada esquema recibe SOLO los privilegios que necesita.
--   * OMNI_BI no puede crear objetos ni ocupar espacio (sin cuota).
--   * Los permisos entre esquemas (SELECT, EXECUTE) los otorga el DUENO
--     de cada objeto en sus propios scripts, no el administrador.
--
-- Se usan nombres OMNI_* (y no RETAIL_OLTP) para NO tocar la instalacion
-- original de un solo esquema, que sigue funcionando en RETAIL_OLTP.
--
-- Las claves son valores de LABORATORIO: cambielas fuera de pruebas.
-- =====================================================================
SET DEFINE ON
SET VERIFY OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

-- Carpeta de datafiles (la misma que usa el script original 00)
DEFINE RUTA_DATAFILES = '/opt/oracle/oradata/FREE/FREEPDB1'
DEFINE CLAVE_OLTP     = 'oltp2026'
DEFINE CLAVE_DW       = 'dw2026'
DEFINE CLAVE_BI       = 'bi2026'

-- ---------------------------------------------------------------------
-- 1. Tablespaces separados: el historico del DW no compite por espacio
--    con las ventas transaccionales.
-- ---------------------------------------------------------------------
CREATE TABLESPACE TS_OMNI_OLTP
  DATAFILE '&RUTA_DATAFILES/ts_omni_oltp01.dbf'
  SIZE 200M AUTOEXTEND ON NEXT 50M MAXSIZE 2G
  SEGMENT SPACE MANAGEMENT AUTO;

CREATE TABLESPACE TS_OMNI_DW
  DATAFILE '&RUTA_DATAFILES/ts_omni_dw01.dbf'
  SIZE 300M AUTOEXTEND ON NEXT 100M MAXSIZE 4G
  SEGMENT SPACE MANAGEMENT AUTO;

-- ---------------------------------------------------------------------
-- 2. OMNI_OLTP: solo puede crear tablas y codigo PL/SQL.
--    No necesita vistas, sinonimos, vistas materializadas ni jobs.
-- ---------------------------------------------------------------------
CREATE USER OMNI_OLTP IDENTIFIED BY "&CLAVE_OLTP"
  DEFAULT TABLESPACE TS_OMNI_OLTP
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON TS_OMNI_OLTP;

GRANT CREATE SESSION    TO OMNI_OLTP;
GRANT CREATE TABLE      TO OMNI_OLTP;
GRANT CREATE SEQUENCE   TO OMNI_OLTP;
GRANT CREATE PROCEDURE  TO OMNI_OLTP;

-- ---------------------------------------------------------------------
-- 3. OMNI_DW: capas analiticas. Necesita sinonimos (para leer el OLTP
--    sin cambiar el codigo), vistas materializadas y jobs (ETL nocturno).
--    Su cuota es SOLO en TS_OMNI_DW: no puede escribir en el tablespace
--    transaccional.
-- ---------------------------------------------------------------------
CREATE USER OMNI_DW IDENTIFIED BY "&CLAVE_DW"
  DEFAULT TABLESPACE TS_OMNI_DW
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON TS_OMNI_DW;

GRANT CREATE SESSION            TO OMNI_DW;
GRANT CREATE TABLE              TO OMNI_DW;
GRANT CREATE VIEW               TO OMNI_DW;
GRANT CREATE SEQUENCE           TO OMNI_DW;
GRANT CREATE PROCEDURE          TO OMNI_DW;
GRANT CREATE SYNONYM            TO OMNI_DW;
GRANT CREATE MATERIALIZED VIEW  TO OMNI_DW;
GRANT CREATE JOB                TO OMNI_DW;

-- ---------------------------------------------------------------------
-- 4. Rol de lectura para BI. El rol agrupa los permisos: si manana hay
--    otro usuario de reportes, se le otorga el rol y listo.
--    (OMNI_DW le dara SELECT sobre sus vistas en 09_PERMISOS_HACIA_BI.sql)
-- ---------------------------------------------------------------------
CREATE ROLE ROL_OMNI_LECTURA_BI;

-- ---------------------------------------------------------------------
-- 5. OMNI_BI: solo puede conectarse. Sin cuota = no puede guardar nada.
-- ---------------------------------------------------------------------
CREATE USER OMNI_BI IDENTIFIED BY "&CLAVE_BI"
  DEFAULT TABLESPACE TS_OMNI_DW
  TEMPORARY TABLESPACE TEMP;

GRANT CREATE SESSION       TO OMNI_BI;
GRANT ROL_OMNI_LECTURA_BI  TO OMNI_BI;

-- ---------------------------------------------------------------------
-- 6. Resumen de lo creado
-- ---------------------------------------------------------------------
COLUMN USERNAME FORMAT A12
COLUMN DEFAULT_TABLESPACE FORMAT A15
SELECT USERNAME, DEFAULT_TABLESPACE, ACCOUNT_STATUS
  FROM DBA_USERS WHERE USERNAME LIKE 'OMNI\_%' ESCAPE '\' ORDER BY USERNAME;

COLUMN GRANTEE FORMAT A12
COLUMN PRIVILEGE FORMAT A28
SELECT GRANTEE, PRIVILEGE FROM DBA_SYS_PRIVS
 WHERE GRANTEE LIKE 'OMNI\_%' ESCAPE '\' ORDER BY GRANTEE, PRIVILEGE;

PROMPT =====================================================================
PROMPT Esquemas OMNI_OLTP, OMNI_DW y OMNI_BI creados.
PROMPT Siguiente paso: conectarse como OMNI_OLTP y ejecutar 01_deploy_oltp.sql
PROMPT =====================================================================
