import os
import psycopg2
from flask import Flask, jsonify, request

app = Flask(__name__)

def get_db_conn():
    return psycopg2.connect(
        host=os.environ["PGHOST"],
        port=os.environ.get("PGPORT", "5432"),
        dbname=os.environ["PGDATABASE"],
        user=os.environ["PGUSER"],
        password=os.environ["PGPASSWORD"],
    )

def init_db():
    conn = get_db_conn()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS vehicles (
            vid SERIAL PRIMARY KEY,
            vin VARCHAR(17) NOT NULL,
            make VARCHAR(64) NOT NULL,
            model VARCHAR(64) NOT NULL,
            depot VARCHAR(128),
            status VARCHAR(32) DEFAULT 'available'
        )
    """)
    cur.execute("SELECT COUNT(*) FROM vehicles")
    if cur.fetchone()[0] == 0:
        cur.executemany(
            "INSERT INTO vehicles (vin, make, model, depot, status) VALUES (%s,%s,%s,%s,%s)",
            [
                ("1HGCG5655WA042367", "Honda", "Accord", "Depot North", "available"),
                ("5YJSA1E26MF123456", "Tesla", "Model S", "Depot East", "in-transit"),
                ("WBAJB0C51JB084210", "BMW", "530i", "Depot North", "maintenance"),
            ],
        )
    conn.commit()
    cur.close()
    conn.close()

@app.route("/api/v1/status")
def health():
    try:
        conn = get_db_conn()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        return jsonify({"status": "healthy", "service": "fleet-tracker"}), 200
    except Exception as e:
        return jsonify({"status": "degraded", "error": str(e)}), 503

@app.route("/api/v1/vehicles")
def list_vehicles():
    conn = get_db_conn()
    cur = conn.cursor()
    cur.execute("SELECT vid, vin, make, model, depot, status FROM vehicles ORDER BY vid")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([
        {"vid": r[0], "vin": r[1], "make": r[2], "model": r[3], "depot": r[4], "status": r[5]}
        for r in rows
    ])

@app.route("/api/v1/vehicles/<int:vid>")
def get_vehicle(vid):
    conn = get_db_conn()
    cur = conn.cursor()
    cur.execute("SELECT vid, vin, make, model, depot, status FROM vehicles WHERE vid = %s", (vid,))
    r = cur.fetchone()
    cur.close()
    conn.close()
    if r is None:
        return jsonify({"error": "not found"}), 404
    return jsonify({"vid": r[0], "vin": r[1], "make": r[2], "model": r[3], "depot": r[4], "status": r[5]})

@app.route("/api/v1/vehicles", methods=["POST"])
def create_vehicle():
    data = request.get_json()
    conn = get_db_conn()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO vehicles (vin, make, model, depot, status) VALUES (%s,%s,%s,%s,%s) RETURNING vid",
        (data["vin"], data["make"], data["model"], data.get("depot"), data.get("status", "available")),
    )
    new_id = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({"vid": new_id}), 201

with app.app_context():
    init_db()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("LISTEN_PORT", "7600")))
