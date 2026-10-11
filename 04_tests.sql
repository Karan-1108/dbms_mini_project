-- =====================================================================
-- Script 4 : TEST CASES  (run right after 03_seed.sql on a fresh schema)
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 160
SET PAGESIZE 50
SET VERIFY OFF
SET FEEDBACK OFF

PROMPT
PROMPT ===== SECTION A : FUNCTIONS =====
DECLARE
  v VARCHAR2(1);
  n NUMBER;
BEGIN
  v := fn_is_donor_eligible(13);
  DBMS_OUTPUT.PUT_LINE('TC01 fn_is_donor_eligible(13) = ' || v || '  expected Y  -> ' ||
                       CASE WHEN v = 'Y' THEN 'PASS' ELSE 'FAIL' END);
  v := fn_is_donor_eligible(1);
  DBMS_OUTPUT.PUT_LINE('TC02 fn_is_donor_eligible(1)  = ' || v || '  expected N  -> ' ||
                       CASE WHEN v = 'N' THEN 'PASS' ELSE 'FAIL' END);
  n := fn_stock_count('O+', 'RBC');
  DBMS_OUTPUT.PUT_LINE('TC03 fn_stock_count(O+, RBC)  = ' || n || '  expected 2  -> ' ||
                       CASE WHEN n = 2 THEN 'PASS' ELSE 'FAIL' END);
END;
/

PROMPT
PROMPT ===== SECTION B : PROCEDURE + TRIGGER =====
DECLARE
  v_unit NUMBER;
  v_days NUMBER;
BEGIN
  proc_register_donation(14, 'RBC', 350, v_unit);
  SELECT expiry_date - collected_on INTO v_days FROM blood_unit WHERE unit_id = v_unit;
  DBMS_OUTPUT.PUT_LINE('TC04 donation recorded, unit #' || v_unit || ', shelf life ' || v_days ||
                       ' days  expected 42  -> ' || CASE WHEN v_days = 42 THEN 'PASS' ELSE 'FAIL' END);
END;
/
DECLARE
  v_unit NUMBER;
BEGIN
  proc_register_donation(1, 'RBC', 350, v_unit);
  DBMS_OUTPUT.PUT_LINE('TC05 ineligible donor accepted  -> FAIL');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('TC05 ineligible donor rejected: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('     expected ORA-20002  -> ' || CASE WHEN SQLCODE = -20002 THEN 'PASS' ELSE 'FAIL' END);
END;
/
DECLARE
  v_unit NUMBER;
BEGIN
  proc_register_donation(14, 'RBC', 350, v_unit);
  DBMS_OUTPUT.PUT_LINE('TC06 second donation same day accepted  -> FAIL');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('TC06 second donation rejected: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('     expected ORA-20002  -> ' || CASE WHEN SQLCODE = -20002 THEN 'PASS' ELSE 'FAIL' END);
END;
/
DECLARE
  v_unit NUMBER;
BEGIN
  proc_register_donation(13, 'XYZ', 350, v_unit);
  DBMS_OUTPUT.PUT_LINE('TC07 unknown component accepted  -> FAIL');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('TC07 unknown component rejected: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('     expected ORA-20003  -> ' || CASE WHEN SQLCODE = -20003 THEN 'PASS' ELSE 'FAIL' END);
END;
/

PROMPT
PROMPT ===== SECTION C : TRIGGER + CONSTRAINTS =====
BEGIN
  INSERT INTO donor (full_name, dob, gender, blood_group, phone, city)
  VALUES ('Test Minor', ADD_MONTHS(TRUNC(SYSDATE), -12 * 16), 'M', 'A+', '9876500099', 'Vellore');
  DBMS_OUTPUT.PUT_LINE('TC08 under-age donor accepted  -> FAIL');
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('TC08 under-age donor rejected: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('     expected ORA-20001  -> ' || CASE WHEN SQLCODE = -20001 THEN 'PASS' ELSE 'FAIL' END);
END;
/
BEGIN
  INSERT INTO donor (full_name, dob, gender, blood_group, phone, city)
  VALUES ('Test BadGroup', DATE '1995-05-05', 'F', 'Z+', '9876500098', 'Vellore');
  DBMS_OUTPUT.PUT_LINE('TC09 invalid blood group accepted  -> FAIL');
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('TC09 invalid blood group rejected: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('     expected ORA-02290  -> ' || CASE WHEN SQLCODE = -2290 THEN 'PASS' ELSE 'FAIL' END);
END;
/
BEGIN
  INSERT INTO donor (full_name, dob, gender, blood_group, phone, city)
  VALUES ('Test Duplicate', DATE '1995-05-05', 'F', 'A+', '9876500001', 'Vellore');
  DBMS_OUTPUT.PUT_LINE('TC10 duplicate phone accepted  -> FAIL');
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('TC10 duplicate phone rejected: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('     expected ORA-00001  -> ' || CASE WHEN SQLCODE = -1 THEN 'PASS' ELSE 'FAIL' END);
END;
/

PROMPT
PROMPT ===== SECTION D : PACKAGE pkg_bloodbank =====
DECLARE
  n NUMBER;
BEGIN
  pkg_bloodbank.expire_units(n);
  DBMS_OUTPUT.PUT_LINE('TC11 units marked EXPIRED = ' || n || '  expected >= 2  -> ' ||
                       CASE WHEN n >= 2 THEN 'PASS' ELSE 'FAIL' END);
END;
/
DECLARE
  n NUMBER;
  s VARCHAR2(10);
BEGIN
  pkg_bloodbank.fulfill_request(1, n);
  SELECT status INTO s FROM blood_request WHERE request_id = 1;
  DBMS_OUTPUT.PUT_LINE('TC12 request 1: issued ' || n || ', status ' || s || '  expected 2 / FULFILLED  -> ' ||
                       CASE WHEN n = 2 AND s = 'FULFILLED' THEN 'PASS' ELSE 'FAIL' END);
END;
/
DECLARE
  n NUMBER;
  s VARCHAR2(10);
  g VARCHAR2(3);
BEGIN
  pkg_bloodbank.fulfill_request(2, n);
  SELECT r.status, d.blood_group INTO s, g
    FROM blood_request r
    JOIN issue_record i ON i.request_id = r.request_id
    JOIN blood_unit u   ON u.unit_id = i.unit_id
    JOIN donor d        ON d.donor_id = u.donor_id
   WHERE r.request_id = 2;
  DBMS_OUTPUT.PUT_LINE('TC13 request 2: issued ' || n || ' unit of group ' || g || ', status ' || s ||
                       '  expected compatible group (not AB+)  -> ' ||
                       CASE WHEN n = 1 AND s = 'FULFILLED' AND g <> 'AB+' THEN 'PASS' ELSE 'FAIL' END);
END;
/
DECLARE
  n NUMBER;
  s VARCHAR2(10);
BEGIN
  pkg_bloodbank.fulfill_request(3, n);
  SELECT status INTO s FROM blood_request WHERE request_id = 3;
  DBMS_OUTPUT.PUT_LINE('TC14 request 3: issued ' || n || ' of 3, status ' || s || '  expected 1 / PARTIAL  -> ' ||
                       CASE WHEN n = 1 AND s = 'PARTIAL' THEN 'PASS' ELSE 'FAIL' END);
END;
/
DECLARE
  n NUMBER;
BEGIN
  pkg_bloodbank.fulfill_request(1, n);
  DBMS_OUTPUT.PUT_LINE('TC15 re-fulfilling request 1 accepted  -> FAIL');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('TC15 re-fulfil rejected: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('     expected ORA-20020  -> ' || CASE WHEN SQLCODE = -20020 THEN 'PASS' ELSE 'FAIL' END);
END;
/
DECLARE
  n NUMBER;
BEGIN
  pkg_bloodbank.fulfill_request(999, n);
  DBMS_OUTPUT.PUT_LINE('TC16 unknown request accepted  -> FAIL');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('TC16 unknown request rejected: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('     expected ORA-20021  -> ' || CASE WHEN SQLCODE = -20021 THEN 'PASS' ELSE 'FAIL' END);
END;
/

PROMPT
PROMPT ===== SECTION E : ISSUED UNITS AND STOCK =====
COLUMN hospital_name FORMAT A22
COLUMN patient_name  FORMAT A12
COLUMN issued_unit   FORMAT 9999
COLUMN unit_group    FORMAT A5
SELECT r.request_id, h.hospital_name, r.patient_name, r.blood_group AS needed, r.urgency, r.status,
       i.unit_id AS issued_unit, d.blood_group AS unit_group
  FROM blood_request r
  JOIN hospital h ON h.hospital_id = r.hospital_id
  LEFT JOIN issue_record i ON i.request_id = r.request_id
  LEFT JOIN blood_unit u ON u.unit_id = i.unit_id
  LEFT JOIN donor d ON d.donor_id = u.donor_id
 ORDER BY r.request_id, i.unit_id;

EXEC pkg_bloodbank.stock_report;

PROMPT
PROMPT ===== SECTION F : HASH-CHAINED AUDIT LEDGER =====
DECLARE
  bad NUMBER;
BEGIN
  bad := pkg_ledger.verify_chain;
  DBMS_OUTPUT.PUT_LINE('TC17 verify_chain = ' || bad || '  expected 0  -> ' ||
                       CASE WHEN bad = 0 THEN 'PASS' ELSE 'FAIL' END);
END;
/
BEGIN
  UPDATE audit_ledger SET details = 'hacked' WHERE log_id = 1;
  DBMS_OUTPUT.PUT_LINE('TC18 ledger update accepted  -> FAIL');
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('TC18 ledger update rejected: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('     expected ORA-20010  -> ' || CASE WHEN SQLCODE = -20010 THEN 'PASS' ELSE 'FAIL' END);
END;
/

PROMPT
PROMPT TC19 : tampering with row 3
COLUMN orig NEW_VALUE v_orig NOPRINT
SELECT details AS orig FROM audit_ledger WHERE log_id = 3;
ALTER TRIGGER trg_ledger_immutable DISABLE;
UPDATE audit_ledger SET details = 'donor=3;comp=WHOLE;expiry=2030-01-01' WHERE log_id = 3;
COMMIT;
ALTER TRIGGER trg_ledger_immutable ENABLE;
SELECT pkg_ledger.verify_chain AS first_bad_row,
       CASE WHEN pkg_ledger.verify_chain = 3 THEN 'PASS - tampering detected at row 3' ELSE 'FAIL' END AS tc19_result
  FROM dual;

PROMPT
PROMPT TC20 : restore, chain verifies again
ALTER TRIGGER trg_ledger_immutable DISABLE;
UPDATE audit_ledger SET details = '&v_orig' WHERE log_id = 3;
COMMIT;
ALTER TRIGGER trg_ledger_immutable ENABLE;
SELECT pkg_ledger.verify_chain AS first_bad_row,
       CASE WHEN pkg_ledger.verify_chain = 0 THEN 'PASS - chain intact again' ELSE 'FAIL' END AS tc20_result
  FROM dual;

PROMPT
PROMPT ===== END OF TESTS =====
SET FEEDBACK ON