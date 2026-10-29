-- =====================================================================
-- 99 - ELIMINAR EL LABORATORIO MULTI-ESQUEMA (reinicio limpio)
-- ---------------------------------------------------------------------
-- EJECUTAR COMO: SYS (AS SYSDBA) o SYSTEM, conectado al PDB FREEPDB1.
-- Borra SOLO los objetos OMNI_*. La instalacion original en RETAIL_OLTP
-- no se toca.
-- ATENCION: antes de ejecutar, desconecte las sesiones de OMNI_OLTP,
-- OMNI_DW y OMNI_BI en SQL Developer (si no, DROP USER falla con ORA-01940).
-- =====================================================================
WHENEVER SQLERROR CONTINUE

-- Orden inverso a la creacion: primero quien consume, al final el dueno
DROP USER OMNI_BI   CASCADE;
DROP USER OMNI_DW   CASCADE;
DROP USER OMNI_OLTP CASCADE;
DROP ROLE ROL_OMNI_LECTURA_BI;

DROP TABLESPACE TS_OMNI_DW   INCLUDING CONTENTS AND DATAFILES;
DROP TABLESPACE TS_OMNI_OLTP INCLUDING CONTENTS AND DATAFILES;

PROMPT Esquemas y tablespaces OMNI_* eliminados. Puede volver a ejecutar 00_init_schemas_and_roles.sql
