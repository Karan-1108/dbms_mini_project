-- =====================================================================
-- Script 1 : SCHEMA - tables, constraints, indexes
-- =====================================================================

CREATE TABLE component_type (
  component_code   VARCHAR2(10)  PRIMARY KEY,
  description      VARCHAR2(40)  NOT NULL,
  shelf_life_days  NUMBER(4)     NOT NULL CHECK (shelf_life_days > 0)
);

CREATE TABLE blood_compat (
  donor_group      VARCHAR2(3) NOT NULL,
  recipient_group  VARCHAR2(3) NOT NULL,
  CONSTRAINT pk_blood_compat PRIMARY KEY (donor_group, recipient_group),
  CONSTRAINT ck_bc_donor CHECK (donor_group     IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  CONSTRAINT ck_bc_recip CHECK (recipient_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-'))
);

CREATE TABLE donor (
  donor_id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name           VARCHAR2(60) NOT NULL,
  dob                 DATE         NOT NULL,
  gender              CHAR(1)      NOT NULL CHECK (gender IN ('M','F','O')),
  blood_group         VARCHAR2(3)  NOT NULL
                      CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  phone               VARCHAR2(10) NOT NULL UNIQUE
                      CHECK (REGEXP_LIKE(phone, '^[6-9][0-9]{9}$')),
  city                VARCHAR2(40),
  last_donation_date  DATE,
  registered_on       DATE DEFAULT SYSDATE NOT NULL
);

CREATE TABLE hospital (
  hospital_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  hospital_name  VARCHAR2(80) NOT NULL,
  city           VARCHAR2(40),
  phone          VARCHAR2(15)
);

CREATE TABLE blood_unit (
  unit_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  donor_id        NUMBER       NOT NULL REFERENCES donor(donor_id),
  component_code  VARCHAR2(10) NOT NULL REFERENCES component_type(component_code),
  volume_ml       NUMBER(4)    DEFAULT 350 NOT NULL CHECK (volume_ml BETWEEN 50 AND 500),
  collected_on    DATE         DEFAULT TRUNC(SYSDATE) NOT NULL,
  expiry_date     DATE,
  status          VARCHAR2(10) DEFAULT 'AVAILABLE' NOT NULL
                  CHECK (status IN ('AVAILABLE','ISSUED','EXPIRED')),
  CONSTRAINT ck_unit_dates CHECK (expiry_date > collected_on)
);

CREATE TABLE blood_request (
  request_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  hospital_id     NUMBER       NOT NULL REFERENCES hospital(hospital_id),
  patient_name    VARCHAR2(60) NOT NULL,
  blood_group     VARCHAR2(3)  NOT NULL
                  CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  component_code  VARCHAR2(10) NOT NULL REFERENCES component_type(component_code),
  units_needed    NUMBER(2)    NOT NULL CHECK (units_needed BETWEEN 1 AND 10),
  urgency         VARCHAR2(8)  DEFAULT 'NORMAL' NOT NULL CHECK (urgency IN ('NORMAL','CRITICAL')),
  request_date    DATE         DEFAULT SYSDATE NOT NULL,
  status          VARCHAR2(10) DEFAULT 'PENDING' NOT NULL
                  CHECK (status IN ('PENDING','PARTIAL','FULFILLED'))
);

CREATE TABLE issue_record (
  issue_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  request_id  NUMBER NOT NULL REFERENCES blood_request(request_id),
  unit_id     NUMBER NOT NULL UNIQUE REFERENCES blood_unit(unit_id),
  issued_on   DATE DEFAULT SYSDATE NOT NULL
);

CREATE TABLE audit_ledger (
  log_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  table_name   VARCHAR2(30)  NOT NULL,
  operation    VARCHAR2(10)  NOT NULL,
  record_key   VARCHAR2(40)  NOT NULL,
  details      VARCHAR2(400),
  changed_by   VARCHAR2(30)  NOT NULL,
  changed_at   VARCHAR2(30)  NOT NULL,
  prev_hash    VARCHAR2(64)  NOT NULL,
  row_hash     VARCHAR2(64)  NOT NULL
);

CREATE INDEX idx_unit_match ON blood_unit (status, component_code, expiry_date);
CREATE INDEX idx_req_status ON blood_request (status, urgency);

PROMPT Schema created. Run 02_plsql.sql next.