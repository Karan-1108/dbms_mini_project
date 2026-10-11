-- =====================================================================
-- Script 0 : RESET - drops all objects so scripts 01-03 can rerun cleanly
-- =====================================================================
SET SERVEROUTPUT ON
SET FEEDBACK OFF

BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN ('ISSUE_RECORD','BLOOD_REQUEST','BLOOD_UNIT',
                                 'HOSPITAL','DONOR','BLOOD_COMPAT',
                                 'COMPONENT_TYPE','AUDIT_LEDGER'))
  LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
END;
/

BEGIN
  FOR p IN (SELECT object_name, object_type FROM user_objects
            WHERE object_type IN ('PACKAGE','PACKAGE BODY','PROCEDURE','FUNCTION','TRIGGER')
              AND object_name IN ('PKG_BLOODBANK','PKG_LEDGER',
                                  'PROC_REGISTER_DONATION',
                                  'FN_STOCK_COUNT','FN_IS_DONOR_ELIGIBLE',
                                  'TRG_DONOR_RULES','TRG_UNIT_RULES',
                                  'TRG_UNIT_AUDIT','TRG_ISSUE_AUDIT',
                                  'TRG_LEDGER_IMMUTABLE'))
  LOOP
    EXECUTE IMMEDIATE 'DROP ' || p.object_type || ' ' || p.object_name;
  END LOOP;
END;
/

SET FEEDBACK ON
PROMPT Reset complete. Run 01_schema.sql next.