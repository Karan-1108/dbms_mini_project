-- =====================================================================
-- Script 2 : PL/SQL - Functions, Procedures, Packages, Triggers, Cursors
-- =====================================================================
SET SERVEROUTPUT ON;

CREATE OR REPLACE FUNCTION fn_is_donor_eligible (
  p_donor_id IN NUMBER,
  p_on_date  IN DATE DEFAULT SYSDATE
) RETURN VARCHAR2 IS
  v_dob   donor.dob%TYPE;
  v_last  donor.last_donation_date%TYPE;
  v_age   NUMBER;
BEGIN
  SELECT dob, last_donation_date INTO v_dob, v_last
  FROM donor WHERE donor_id = p_donor_id;

  v_age := TRUNC(MONTHS_BETWEEN(p_on_date, v_dob) / 12);
  IF v_age < 18 OR v_age > 65 THEN
    RETURN 'N';
  END IF;
  IF v_last IS NOT NULL AND (p_on_date - v_last) < 90 THEN
    RETURN 'N';
  END IF;
  RETURN 'Y';
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN 'N';
END fn_is_donor_eligible;
/

CREATE OR REPLACE FUNCTION fn_stock_count (
  p_group     IN VARCHAR2,
  p_component IN VARCHAR2 DEFAULT NULL
) RETURN NUMBER IS
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM blood_unit u JOIN donor d ON d.donor_id = u.donor_id
  WHERE d.blood_group = p_group
    AND u.status = 'AVAILABLE'
    AND u.expiry_date >= TRUNC(SYSDATE)
    AND (p_component IS NULL OR u.component_code = p_component);
  RETURN v_count;
END fn_stock_count;
/

CREATE OR REPLACE PROCEDURE proc_register_donation (
  p_donor_id  IN  NUMBER,
  p_component IN  VARCHAR2,
  p_volume_ml IN  NUMBER DEFAULT 350,
  p_unit_id   OUT NUMBER
) IS
BEGIN
  INSERT INTO blood_unit (donor_id, component_code, volume_ml)
  VALUES (p_donor_id, p_component, p_volume_ml)
  RETURNING unit_id INTO p_unit_id;

  UPDATE donor SET last_donation_date = TRUNC(SYSDATE)
  WHERE donor_id = p_donor_id;

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END proc_register_donation;
/

CREATE OR REPLACE PACKAGE pkg_ledger AS
  PROCEDURE append (p_table   IN VARCHAR2,
                    p_op      IN VARCHAR2,
                    p_key     IN VARCHAR2,
                    p_details IN VARCHAR2);

  FUNCTION compute_hash (p_prev    IN VARCHAR2,
                         p_table   IN VARCHAR2,
                         p_op      IN VARCHAR2,
                         p_key     IN VARCHAR2,
                         p_details IN VARCHAR2,
                         p_ts      IN VARCHAR2) RETURN VARCHAR2;

  FUNCTION verify_chain RETURN NUMBER;
END pkg_ledger;
/

CREATE OR REPLACE PACKAGE BODY pkg_ledger AS
  c_genesis CONSTANT VARCHAR2(64) := RPAD('0', 64, '0');

  FUNCTION compute_hash (p_prev IN VARCHAR2, p_table IN VARCHAR2, p_op IN VARCHAR2,
                         p_key  IN VARCHAR2, p_details IN VARCHAR2, p_ts IN VARCHAR2)
  RETURN VARCHAR2 IS
    v_hash VARCHAR2(64);
  BEGIN
    SELECT RAWTOHEX(STANDARD_HASH(
             p_prev||'|'||p_table||'|'||p_op||'|'||p_key||'|'||p_details||'|'||p_ts,
             'SHA256'))
      INTO v_hash
      FROM dual;
    RETURN v_hash;
  END compute_hash;

  PROCEDURE append (p_table IN VARCHAR2, p_op IN VARCHAR2,
                    p_key   IN VARCHAR2, p_details IN VARCHAR2) IS
    v_prev VARCHAR2(64);
    v_ts   VARCHAR2(30);
  BEGIN
    LOCK TABLE audit_ledger IN EXCLUSIVE MODE;
    BEGIN
      SELECT row_hash INTO v_prev
      FROM audit_ledger
      WHERE log_id = (SELECT MAX(log_id) FROM audit_ledger);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN v_prev := c_genesis;
    END;

    v_ts := TO_CHAR(SYSTIMESTAMP, 'YYYYMMDD"T"HH24MISSFF6');

    INSERT INTO audit_ledger
      (table_name, operation, record_key, details, changed_by, changed_at, prev_hash, row_hash)
    VALUES
      (p_table, p_op, p_key, p_details, SYS_CONTEXT('USERENV','SESSION_USER'), v_ts, v_prev,
       compute_hash(v_prev, p_table, p_op, p_key, p_details, v_ts));
  END append;

  FUNCTION verify_chain RETURN NUMBER IS
    v_expected_prev VARCHAR2(64) := c_genesis;
    CURSOR c_log IS SELECT * FROM audit_ledger ORDER BY log_id;
  BEGIN
    FOR r IN c_log LOOP
      IF r.prev_hash <> v_expected_prev
         OR r.row_hash <> compute_hash(r.prev_hash, r.table_name, r.operation,
                                       r.record_key, r.details, r.changed_at) THEN
        RETURN r.log_id;
      END IF;
      v_expected_prev := r.row_hash;
    END LOOP;
    RETURN 0;
  END verify_chain;
END pkg_ledger;
/
SHOW ERRORS PACKAGE BODY pkg_ledger

CREATE OR REPLACE PACKAGE pkg_bloodbank AS
  PROCEDURE fulfill_request (p_request_id IN NUMBER, p_issued OUT NUMBER);
  PROCEDURE expire_units (p_count OUT NUMBER);
  PROCEDURE stock_report;
END pkg_bloodbank;
/

CREATE OR REPLACE PACKAGE BODY pkg_bloodbank AS

  PROCEDURE fulfill_request (p_request_id IN NUMBER, p_issued OUT NUMBER) IS
    v_req     blood_request%ROWTYPE;
    v_allow   VARCHAR2(1);
    v_already NUMBER;
    v_needed  NUMBER;
    v_total   NUMBER;

    CURSOR c_units (cp_group VARCHAR2, cp_comp VARCHAR2, cp_allow VARCHAR2) IS
      SELECT u.unit_id, d.blood_group, u.expiry_date
      FROM   blood_unit u JOIN donor d ON d.donor_id = u.donor_id
      WHERE  u.status = 'AVAILABLE'
        AND  u.component_code = cp_comp
        AND  u.expiry_date >= TRUNC(SYSDATE)
        AND (d.blood_group = cp_group
             OR (cp_allow = 'Y'
                 AND cp_comp IN ('RBC','WHOLE')
                 AND EXISTS (SELECT 1 FROM blood_compat bc
                             WHERE bc.donor_group = d.blood_group
                               AND bc.recipient_group = cp_group)))
      ORDER BY CASE WHEN d.blood_group = cp_group THEN 0 ELSE 1 END,
               u.expiry_date
      FOR UPDATE OF u.status;
  BEGIN
    SELECT * INTO v_req FROM blood_request
    WHERE request_id = p_request_id FOR UPDATE;

    IF v_req.status = 'FULFILLED' THEN
      RAISE_APPLICATION_ERROR(-20020, 'Request ' || p_request_id || ' is already fulfilled');
    END IF;

    v_allow := CASE WHEN v_req.urgency = 'CRITICAL' THEN 'Y' ELSE 'N' END;
    SELECT COUNT(*) INTO v_already FROM issue_record WHERE request_id = p_request_id;
    v_needed := v_req.units_needed - v_already;
    p_issued := 0;

    FOR r IN c_units(v_req.blood_group, v_req.component_code, v_allow) LOOP
      EXIT WHEN p_issued >= v_needed;
      UPDATE blood_unit SET status = 'ISSUED' WHERE CURRENT OF c_units;
      INSERT INTO issue_record (request_id, unit_id) VALUES (p_request_id, r.unit_id);
      p_issued := p_issued + 1;
    END LOOP;

    v_total := v_already + p_issued;
    UPDATE blood_request
       SET status = CASE WHEN v_total >= units_needed THEN 'FULFILLED'
                         WHEN v_total > 0             THEN 'PARTIAL'
                         ELSE 'PENDING' END
     WHERE request_id = p_request_id;
    COMMIT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      ROLLBACK;
      RAISE_APPLICATION_ERROR(-20021, 'Request ' || p_request_id || ' not found');
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END fulfill_request;

  PROCEDURE expire_units (p_count OUT NUMBER) IS
  BEGIN
    UPDATE blood_unit SET status = 'EXPIRED'
    WHERE status = 'AVAILABLE' AND expiry_date < TRUNC(SYSDATE);
    p_count := SQL%ROWCOUNT;
    COMMIT;
  END expire_units;

  PROCEDURE stock_report IS
    CURSOR c_stock IS
      SELECT d.blood_group, u.component_code, COUNT(*) AS qty
      FROM   blood_unit u JOIN donor d ON d.donor_id = u.donor_id
      WHERE  u.status = 'AVAILABLE' AND u.expiry_date >= TRUNC(SYSDATE)
      GROUP  BY d.blood_group, u.component_code
      ORDER  BY d.blood_group, u.component_code;
  BEGIN
    DBMS_OUTPUT.PUT_LINE(RPAD('GROUP',8) || RPAD('COMPONENT',12) || 'UNITS');
    FOR r IN c_stock LOOP
      DBMS_OUTPUT.PUT_LINE(RPAD(r.blood_group,8) || RPAD(r.component_code,12) || r.qty);
    END LOOP;
  END stock_report;

END pkg_bloodbank;
/
SHOW ERRORS PACKAGE BODY pkg_bloodbank

CREATE OR REPLACE TRIGGER trg_donor_rules
BEFORE INSERT OR UPDATE ON donor
FOR EACH ROW
BEGIN
  :NEW.blood_group := UPPER(TRIM(:NEW.blood_group));
  IF INSERTING OR UPDATING('DOB') THEN
    IF MONTHS_BETWEEN(SYSDATE, :NEW.dob) / 12 < 18
       OR MONTHS_BETWEEN(SYSDATE, :NEW.dob) / 12 > 65 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Donor must be between 18 and 65 years old');
    END IF;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_unit_rules
BEFORE INSERT ON blood_unit
FOR EACH ROW
DECLARE
  v_shelf component_type.shelf_life_days%TYPE;
BEGIN
  IF fn_is_donor_eligible(:NEW.donor_id, :NEW.collected_on) = 'N' THEN
    RAISE_APPLICATION_ERROR(-20002,
      'Donor ' || :NEW.donor_id || ' is not eligible to donate (age or <90 days since last donation)');
  END IF;

  SELECT shelf_life_days INTO v_shelf
  FROM component_type WHERE component_code = :NEW.component_code;

  :NEW.expiry_date := :NEW.collected_on + v_shelf;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20003, 'Unknown blood component: ' || :NEW.component_code);
END;
/

CREATE OR REPLACE TRIGGER trg_unit_audit
AFTER INSERT OR UPDATE OR DELETE ON blood_unit
FOR EACH ROW
BEGIN
  IF INSERTING THEN
    pkg_ledger.append('BLOOD_UNIT', 'INSERT', TO_CHAR(:NEW.unit_id),
      'donor=' || :NEW.donor_id || ';comp=' || :NEW.component_code ||
      ';expiry=' || TO_CHAR(:NEW.expiry_date, 'YYYY-MM-DD'));
  ELSIF UPDATING AND :OLD.status <> :NEW.status THEN
    pkg_ledger.append('BLOOD_UNIT', 'UPDATE', TO_CHAR(:NEW.unit_id),
      'status ' || :OLD.status || ' -> ' || :NEW.status);
  ELSIF DELETING THEN
    pkg_ledger.append('BLOOD_UNIT', 'DELETE', TO_CHAR(:OLD.unit_id), 'unit deleted');
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_issue_audit
AFTER INSERT ON issue_record
FOR EACH ROW
BEGIN
  pkg_ledger.append('ISSUE_RECORD', 'INSERT', TO_CHAR(:NEW.issue_id),
    'request=' || :NEW.request_id || ';unit=' || :NEW.unit_id);
END;
/

CREATE OR REPLACE TRIGGER trg_ledger_immutable
BEFORE UPDATE OR DELETE ON audit_ledger
BEGIN
  RAISE_APPLICATION_ERROR(-20010, 'audit_ledger is append-only');
END;
/

SHOW ERRORS;