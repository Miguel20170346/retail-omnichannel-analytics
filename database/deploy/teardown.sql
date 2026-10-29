-- =====================================================================
-- 99 - DESINSTALAR (borra TODOS los objetos del proyecto del esquema)
-- Usar solo en el entorno de pruebas para reinstalar desde cero.
-- =====================================================================
SET SERVEROUTPUT ON
BEGIN
  FOR o IN (SELECT OBJECT_NAME, OBJECT_TYPE FROM USER_OBJECTS
             WHERE OBJECT_TYPE IN ('MATERIALIZED VIEW','PACKAGE','PROCEDURE','FUNCTION')
             ORDER BY DECODE(OBJECT_TYPE, 'MATERIALIZED VIEW', 1, 2)) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP ' || o.OBJECT_TYPE || ' ' || o.OBJECT_NAME;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
  FOR t IN (SELECT TABLE_NAME FROM USER_TABLES
             WHERE REGEXP_LIKE(TABLE_NAME, '^(TRX_|STG_|DIM_|HECHOS_|AUDITORIA_|ERRORES_|FACTURAS_|QA_)')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.TABLE_NAME || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Objetos del proyecto eliminados');
END;
/
