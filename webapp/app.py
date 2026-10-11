"""
BCSE302P Mini Project : Blood Bank & Emergency Matching System
Flask front-end for the Oracle 21c XE database.

Run:
    python app.py
Then open http://127.0.0.1:5000
"""
import os
from flask import Flask, render_template, request, redirect, url_for, flash, session
from dotenv import load_dotenv
import oracledb

# Load .env file if present (do NOT commit .env to git)
load_dotenv()

app = Flask(__name__)
app.secret_key = os.environ.get("BB_SECRET", "bloodbank-mini-project-2026")

# ------------------------------------------------------------------
# Database connection settings - read from environment variables
# with safe local defaults. Change these in a .env file.
# ------------------------------------------------------------------
DB_USER     = os.environ.get("BB_USER", "bloodbank")
DB_PASSWORD = os.environ.get("BB_PASS", "CHANGE_ME_IN_ENV")
DB_DSN      = os.environ.get("BB_DSN",  "localhost:1521/XEPDB1")


def get_connection():
    """Return a fresh connection to the Oracle database."""
    return oracledb.connect(user=DB_USER, password=DB_PASSWORD, dsn=DB_DSN)


def query(sql, params=None, fetch=True):
    """Run a SELECT and return rows as dicts (or [] if none)."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params or {})
            if not fetch:
                conn.commit()
                return []
            cols = [c[0].lower() for c in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]


def execute(sql, params=None):
    """Run INSERT/UPDATE/DELETE and commit. Returns rowcount."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params or {})
            rc = cur.rowcount
            conn.commit()
            return rc


@app.errorhandler(oracledb.DatabaseError)
def handle_db_error(e):
    return render_template(
        "error.html",
        error=str(e).splitlines()[0] if str(e) else "Database error"
    ), 500


# ------------------------------------------------------------------
# Routes
# ------------------------------------------------------------------
@app.route("/")
def dashboard():
    stock_total = query("""
        SELECT COUNT(*) AS n FROM blood_unit
        WHERE status = 'AVAILABLE' AND expiry_date >= TRUNC(SYSDATE)
    """)[0]['n']

    pending = query("""
        SELECT COUNT(*) AS n FROM blood_request WHERE status = 'PENDING'
    """)[0]['n']

    donors_n = query("SELECT COUNT(*) AS n FROM donor")[0]['n']

    chain = query("SELECT pkg_ledger.verify_chain AS bad FROM dual")[0]['bad']

    recent = query("""
        SELECT u.unit_id, d.blood_group, u.component_code, u.expiry_date, u.status
        FROM blood_unit u JOIN donor d ON d.donor_id = u.donor_id
        ORDER BY u.unit_id DESC FETCH FIRST 8 ROWS ONLY
    """)

    return render_template("dashboard.html",
                           stock_total=stock_total,
                           pending=pending,
                           donors_n=donors_n,
                           chain=chain,
                           recent=recent)


@app.route("/stock")
def stock():
    rows = query("""
        SELECT d.blood_group, u.component_code, COUNT(*) AS qty,
               MIN(u.expiry_date) AS earliest
        FROM blood_unit u JOIN donor d ON d.donor_id = u.donor_id
        WHERE u.status = 'AVAILABLE' AND u.expiry_date >= TRUNC(SYSDATE)
        GROUP BY d.blood_group, u.component_code
        ORDER BY d.blood_group, u.component_code
    """)
    return render_template("stock.html", rows=rows)


@app.route("/requests")
def requests_list():
    rows = query("""
        SELECT r.request_id, h.hospital_name, r.patient_name, r.blood_group,
               r.component_code, r.units_needed, r.urgency, r.status,
               NVL((SELECT COUNT(*) FROM issue_record i WHERE i.request_id = r.request_id), 0) AS issued
        FROM blood_request r JOIN hospital h ON h.hospital_id = r.hospital_id
        ORDER BY r.request_id
    """)
    return render_template("requests.html", rows=rows)


@app.route("/requests/fulfill/<int:rid>", methods=["POST"])
def fulfill(rid):
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                issued = cur.var(int)
                cur.callproc("pkg_bloodbank.fulfill_request", [rid, issued])
                conn.commit()
                n = issued.getvalue()
        flash(f"Request #{rid}: issued {n} unit(s).", "success")
    except oracledb.DatabaseError as e:
        err = str(e).splitlines()[0]
        flash(f"Request #{rid} failed: {err}", "error")
    return redirect(url_for("requests_list"))


@app.route("/donors")
def donors():
    donors_list = query("""
        SELECT donor_id, full_name, blood_group, city, last_donation_date,
               fn_is_donor_eligible(donor_id) AS eligible
        FROM donor ORDER BY donor_id
    """)
    return render_template("donors.html", donors=donors_list)


@app.route("/donors/donate", methods=["POST"])
def donate():
    donor_id_raw = (request.form.get("donor_id") or "").strip()
    component = (request.form.get("component_code") or "").upper().strip()

    if not donor_id_raw.isdigit():
        flash("Donor ID must be a positive number.", "error")
        return redirect(url_for("donors"))

    donor_id = int(donor_id_raw)
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                unit_id = cur.var(int)
                cur.callproc("proc_register_donation",
                             [donor_id, component, 350, unit_id])
                conn.commit()
                u = unit_id.getvalue()
        flash(f"Donation recorded. New unit #{u}.", "success")
    except oracledb.DatabaseError as e:
        err = str(e).splitlines()[0]
        flash(f"Donation rejected: {err}", "error")
    return redirect(url_for("donors"))


@app.route("/best-unit", methods=["GET", "POST"])
def best_unit():
    result = None
    if request.method == "POST":
        group = request.form["blood_group"].upper().strip()
        component = request.form["component_code"].upper().strip()
        urgency = request.form.get("urgency", "NORMAL")
        allow_compat = "Y" if urgency == "CRITICAL" else "N"

        sql = """
            SELECT u.unit_id, d.blood_group, u.component_code,
                   u.expiry_date,
                   CASE WHEN d.blood_group = :grp THEN 0 ELSE 1 END AS rank_group
            FROM blood_unit u JOIN donor d ON d.donor_id = u.donor_id
            WHERE u.status = 'AVAILABLE'
              AND u.component_code = :comp
              AND u.expiry_date >= TRUNC(SYSDATE)
              AND (
                    d.blood_group = :grp
                    OR (
                        :allow = 'Y'
                        AND :comp IN ('RBC','WHOLE')
                        AND EXISTS (
                            SELECT 1 FROM blood_compat bc
                            WHERE bc.donor_group = d.blood_group
                              AND bc.recipient_group = :grp
                        )
                    )
                  )
            ORDER BY rank_group, u.expiry_date
        """
        rows = query(sql, {"grp": group, "comp": component, "allow": allow_compat})

        result = {
            "group": group,
            "component": component,
            "urgency": urgency,
            "rows": rows,
            "best": rows[0] if rows else None,
            "total": len(rows),
        }

    return render_template("best_unit.html", result=result)


@app.route("/ledger")
def ledger():
    rows = query("""
        SELECT log_id, table_name, operation, record_key, details,
               changed_by, changed_at, SUBSTR(row_hash,1,12) AS hash_prefix
        FROM audit_ledger ORDER BY log_id
    """)
    bad = query("SELECT pkg_ledger.verify_chain AS bad FROM dual")[0]['bad']
    return render_template("ledger.html", rows=rows, bad=bad)


@app.route("/ledger/tamper", methods=["POST"])
def tamper():
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                # Save the original row-3 text so restore() is deterministic
                cur.execute("SELECT details FROM audit_ledger WHERE log_id = 3")
                row = cur.fetchone()
                if row:
                    session['row3_orig'] = row[0]
                try:
                    cur.execute("ALTER TRIGGER trg_ledger_immutable DISABLE")
                    cur.execute("""
                        UPDATE audit_ledger
                        SET details = 'TAMPERED-BY-WEBAPP'
                        WHERE log_id = 3
                    """)
                    conn.commit()
                finally:
                    cur.execute("ALTER TRIGGER trg_ledger_immutable ENABLE")
                    conn.commit()
        flash("Row 3 has been tampered with. Now verify integrity.", "error")
    except oracledb.DatabaseError as e:
        flash(f"Tamper failed: {e}", "error")
    return redirect(url_for("ledger"))


@app.route("/ledger/restore", methods=["POST"])
def restore():
    original = session.get('row3_orig')
    if not original:
        flash("No saved original value. Re-run tamper first.", "error")
        return redirect(url_for("ledger"))
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                try:
                    cur.execute("ALTER TRIGGER trg_ledger_immutable DISABLE")
                    cur.execute(
                        "UPDATE audit_ledger SET details = :1 WHERE log_id = 3",
                        [original]
                    )
                    conn.commit()
                finally:
                    cur.execute("ALTER TRIGGER trg_ledger_immutable ENABLE")
                    conn.commit()
        flash("Row 3 restored. Chain should verify again.", "success")
    except oracledb.DatabaseError as e:
        flash(f"Restore failed: {e}", "error")
    return redirect(url_for("ledger"))


if __name__ == "__main__":
    app.run(debug=True, port=5000)