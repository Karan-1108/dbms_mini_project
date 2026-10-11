-- =====================================================================
-- Script 3 : SEED DATA
-- =====================================================================

INSERT INTO component_type VALUES ('WHOLE',     'Whole Blood',      35);
INSERT INTO component_type VALUES ('RBC',       'Red Blood Cells',  42);
INSERT INTO component_type VALUES ('PLASMA',    'Fresh Plasma',    365);
INSERT INTO component_type VALUES ('PLATELETS', 'Platelets',         5);

INSERT INTO blood_compat VALUES ('O-','O-');
INSERT INTO blood_compat VALUES ('O-','O+');
INSERT INTO blood_compat VALUES ('O-','A-');
INSERT INTO blood_compat VALUES ('O-','A+');
INSERT INTO blood_compat VALUES ('O-','B-');
INSERT INTO blood_compat VALUES ('O-','B+');
INSERT INTO blood_compat VALUES ('O-','AB-');
INSERT INTO blood_compat VALUES ('O-','AB+');
INSERT INTO blood_compat VALUES ('O+','O+');
INSERT INTO blood_compat VALUES ('O+','A+');
INSERT INTO blood_compat VALUES ('O+','B+');
INSERT INTO blood_compat VALUES ('O+','AB+');
INSERT INTO blood_compat VALUES ('A-','A-');
INSERT INTO blood_compat VALUES ('A-','A+');
INSERT INTO blood_compat VALUES ('A-','AB-');
INSERT INTO blood_compat VALUES ('A-','AB+');
INSERT INTO blood_compat VALUES ('A+','A+');
INSERT INTO blood_compat VALUES ('A+','AB+');
INSERT INTO blood_compat VALUES ('B-','B-');
INSERT INTO blood_compat VALUES ('B-','B+');
INSERT INTO blood_compat VALUES ('B-','AB-');
INSERT INTO blood_compat VALUES ('B-','AB+');
INSERT INTO blood_compat VALUES ('B+','B+');
INSERT INTO blood_compat VALUES ('B+','AB+');
INSERT INTO blood_compat VALUES ('AB-','AB-');
INSERT INTO blood_compat VALUES ('AB-','AB+');
INSERT INTO blood_compat VALUES ('AB+','AB+');

INSERT INTO hospital (hospital_name, city, phone) VALUES ('CMC Vellore',            'Vellore', '0416-2281000');
INSERT INTO hospital (hospital_name, city, phone) VALUES ('Narayani Hospital',      'Vellore', '0416-2700500');
INSERT INTO hospital (hospital_name, city, phone) VALUES ('Apollo Hospitals',       'Chennai', '044-28290200');
INSERT INTO hospital (hospital_name, city, phone) VALUES ('Government Hospital',    'Katpadi', '0416-2240100');

INSERT INTO donor (full_name, dob, gender, blood_group, phone, city) VALUES ('Arjun Mehta',     DATE '1999-03-14','M','O-', '9876500001','Vellore');
INSERT INTO donor (full_name, dob, gender, blood_group, phone, city) VALUES ('Priya Nair',      DATE '2000-07-21','F','A+', '9876500002','Chennai');
INSERT INTO donor (full_name, dob, gender, blood_group, phone, city) VALUES ('Rahul Verma',     DATE '1998-11-02','M','B+', '9876500003','Vellore');
INSERT INTO donor (full_name, dob, gender, blood_group, phone, city) VALUES ('Sneha Iyer',      DATE '2001-01-30','F','O+', '9876500004','Katpadi');
INSERT INTO donor (full_name, dob, gender, blood_group, phone, city) VALUES ('Mohammed Faisal', DATE '1997-05-18','M','AB+','9876500005','Vellore');
INSERT INTO donor (full_name, dob, gender, blood_group, phone, city) VALUES ('Divya Krishnan',  DATE '2002-09-09','F','A-', '9876500006','Chennai');
INSERT INTO donor (full_name, dob, gender, blood_group, phone, city) VALUES ('Karthik Raj',     DATE '1996-12-25','M','B-', '9876500007','Vellore');
INSERT INTO donor (full_name, dob, gender, blood_group, phone, city) VALUES ('Ananya Das',      DATE '2000-04-04','F','AB-','9876500008','Katpadi');
INSERT INTO donor (full_name, dob, gender, blood_group, phone, city) VALUES ('Vikram Singh',    DATE '1995-08-12','M','O+', '9876500009','Vellore');
INSERT INTO donor (full_name, dob, gender, blood_group, phone, city) VALUES ('Lakshmi Menon',   DATE '1999-06-27','F','A+', '9876500010','Chennai');
INSERT INTO donor (full_name, dob, gender, blood_group, phone, city) VALUES ('Sanjay Kumar',    DATE '1994-02-16','M','O-', '9876500011','Vellore');
INSERT INTO donor (full_name, dob, gender, blood_group, phone, city) VALUES ('Meera Joshi',     DATE '2001-10-05','F','B+', '9876500012','Katpadi');
INSERT INTO donor (full_name, dob, gender, blood_group, phone, city) VALUES ('Rohit Sharma',    DATE '1998-09-19','M','O+', '9876500013','Vellore');
INSERT INTO donor (full_name, dob, gender, blood_group, phone, city) VALUES ('Pooja Reddy',     DATE '2000-12-01','F','A+', '9876500014','Chennai');

INSERT INTO blood_unit (donor_id, component_code, collected_on) VALUES (1,  'RBC',       TRUNC(SYSDATE) - 5);
INSERT INTO blood_unit (donor_id, component_code, collected_on) VALUES (2,  'RBC',       TRUNC(SYSDATE) - 10);
INSERT INTO blood_unit (donor_id, component_code, collected_on) VALUES (3,  'WHOLE',     TRUNC(SYSDATE) - 20);
INSERT INTO blood_unit (donor_id, component_code, collected_on) VALUES (4,  'RBC',       TRUNC(SYSDATE) - 3);
INSERT INTO blood_unit (donor_id, component_code, collected_on) VALUES (5,  'PLASMA',    TRUNC(SYSDATE) - 30);
INSERT INTO blood_unit (donor_id, component_code, collected_on) VALUES (6,  'RBC',       TRUNC(SYSDATE) - 12);
INSERT INTO blood_unit (donor_id, component_code, collected_on) VALUES (7,  'WHOLE',     TRUNC(SYSDATE) - 8);
INSERT INTO blood_unit (donor_id, component_code, collected_on) VALUES (8,  'PLASMA',    TRUNC(SYSDATE) - 2);
INSERT INTO blood_unit (donor_id, component_code, collected_on) VALUES (9,  'RBC',       TRUNC(SYSDATE) - 25);
INSERT INTO blood_unit (donor_id, component_code, collected_on) VALUES (10, 'PLATELETS', TRUNC(SYSDATE) - 8);
INSERT INTO blood_unit (donor_id, component_code, collected_on) VALUES (11, 'RBC',       TRUNC(SYSDATE) - 100);
INSERT INTO blood_unit (donor_id, component_code, collected_on) VALUES (12, 'PLATELETS', TRUNC(SYSDATE) - 1);

UPDATE donor d
   SET last_donation_date = (SELECT MAX(collected_on) FROM blood_unit u WHERE u.donor_id = d.donor_id);

INSERT INTO blood_request (hospital_id, patient_name, blood_group, component_code, units_needed, urgency)
VALUES (1, 'Ramesh K',   'A+',  'RBC', 2, 'NORMAL');
INSERT INTO blood_request (hospital_id, patient_name, blood_group, component_code, units_needed, urgency)
VALUES (2, 'Fatima B',   'AB+', 'RBC', 1, 'CRITICAL');
INSERT INTO blood_request (hospital_id, patient_name, blood_group, component_code, units_needed, urgency)
VALUES (3, 'Suresh P',   'O-',  'RBC', 3, 'NORMAL');

COMMIT;

SELECT 'donors' AS tbl, COUNT(*) AS n FROM donor;
SELECT 'blood_unit' AS tbl, COUNT(*) AS n FROM blood_unit;
SELECT 'blood_compat' AS tbl, COUNT(*) AS n FROM blood_compat;
SELECT 'blood_request' AS tbl, COUNT(*) AS n FROM blood_request;
SELECT 'audit_ledger' AS tbl, COUNT(*) AS n FROM audit_ledger;

SELECT pkg_ledger.verify_chain AS first_bad_row FROM dual;