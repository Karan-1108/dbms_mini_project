# Blood Bank & Emergency Matching System

A mini project for **BCSE302P – Database Systems Laboratory**, Fall Semester 2026-27, Vellore Institute of Technology, Vellore.

**Author:** Karan Singh (24BCI0287)

---

## Overview

The system manages the complete lifecycle of blood donations — donor registration, unit collection, storage, request handling, and emergency allocation — on **Oracle Database 21c Express Edition**, with a **Python Flask** front-end.

A distinctive feature is a **tamper-evident audit ledger**: every write to the `blood_unit` or `issue_record` tables appends a row to `audit_ledger` whose `row_hash` includes the SHA-256 of the previous row's hash. Any direct modification to historical rows breaks the chain, which the application surfaces live.

## Features

- Normalized schema in **BCNF** with eight relations
- PL/SQL: 2 functions, 1 procedure, 2 packages, 4 triggers, explicit & implicit cursors
- **First-Expired-First-Out** emergency matching with compatible-group fallback for critical requests
- Row-level triggers enforcing donor age (18–65) and 90-day donation cooldown
- **Hash-chained audit ledger** with live integrity verification
- Six-page Flask UI: Dashboard, Stock (heat grid), Requests, Donors, Best Unit, Audit Ledger
- Twenty automated test cases with 100% pass rate

## Stack

| Layer | Technology |
|-------|-----------|
| Database | Oracle Database 21c XE (21.3.0.0.0), pluggable DB `XEPDB1` |
| Query tool | SQL*Plus 21.0 |
| Backend | Python 3.12, Flask 3.0.3, python-oracledb 2.4.1 |
| Front-end | Jinja2 templates with responsive CSS |

## Setup

### 1. Database

Create an Oracle user and run the SQL scripts in order:

```sql
ALTER SESSION SET CONTAINER = XEPDB1;
CREATE USER bloodbank IDENTIFIED BY <password>;
GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE TRIGGER, UNLIMITED TABLESPACE TO bloodbank;