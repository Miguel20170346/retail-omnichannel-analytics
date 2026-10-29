-- =====================================================================
-- PLATAFORMA ANALITICA OMNICANAL PARA RETAIL
-- 00 - Tablespace, usuario propietario y privilegios
-- ---------------------------------------------------------------------
-- EJECUTAR COMO ADMINISTRADOR (SYSDBA) DENTRO DEL PDB (FREEPDB1).
-- =====================================================================
SET DEFINE ON
SET VERIFY OFF
WHENEVER SQLERROR CONTINUE

DEFINE RUTA_DATAFILE = '/opt/oracle/oradata/FREE/FREEPDB1/ts_retail_omnicanal_oltp01.dbf'
DEFINE CLAVE_USUARIO = 'oracle'

CREATE TABLESPACE TS_RETAIL_OMNICANAL_OLTP
  DATAFILE '&RUTA_DATAFILE'
  SIZE 500M AUTOEXTEND ON NEXT 100M MAXSIZE UNLIMITED
  SEGMENT SPACE MANAGEMENT AUTO;

CREATE USER RETAIL_OLTP IDENTIFIED BY "&CLAVE_USUARIO"
  DEFAULT TABLESPACE TS_RETAIL_OMNICANAL_OLTP
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON TS_RETAIL_OMNICANAL_OLTP;

GRANT CREATE SESSION            TO RETAIL_OLTP;
GRANT CREATE TABLE              TO RETAIL_OLTP;
GRANT CREATE VIEW               TO RETAIL_OLTP;
GRANT CREATE SEQUENCE           TO RETAIL_OLTP;
GRANT CREATE TRIGGER            TO RETAIL_OLTP;
GRANT CREATE PROCEDURE          TO RETAIL_OLTP;
GRANT CREATE SYNONYM            TO RETAIL_OLTP;
GRANT CREATE MATERIALIZED VIEW  TO RETAIL_OLTP;
GRANT CREATE JOB                TO RETAIL_OLTP;

PROMPT =====================================================================
PROMPT Usuario RETAIL_OLTP listo (clave: oracle).
PROMPT Conectese como RETAIL_OLTP y ejecute INSTALAR_TODO_DESDE_CERO.sql
PROMPT =====================================================================
