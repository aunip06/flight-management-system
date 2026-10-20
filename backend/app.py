import os
import uuid
from datetime import date
from flask import Flask, jsonify, request
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error

app = Flask(__name__, static_folder=os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "frontend")), static_url_path="")
CORS(app)

def get_connection():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "flight_management"),
        autocommit=False,
    )

def fetch_all(sql, params=()):
    conn = get_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(sql, params)
        rows = cur.fetchall()
        cur.close()
        return rows
    finally:
        conn.close()

@app.get("/")
def home():
    return app.send_static_file("index.html")

@app.get("/api/health")
def health():
    try:
        rows = fetch_all("SELECT DATABASE() AS database_name, VERSION() AS mysql_version")
        return jsonify({"ok": True, **rows[0]})
    except Error as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500

@app.get("/api/flights")
def flights():
    origin = request.args.get("origin", "").strip().upper()
    destination = request.args.get("destination", "").strip().upper()
    travel_date = request.args.get("date", "").strip()
    sql = """
        SELECT v.*,
               fn_available_seats(v.flight_id) AS available_seats
        FROM vw_flight_schedule v
        WHERE v.flight_status IN ('SCHEDULED','DELAYED')
    """
    params = []
    if origin:
        sql += " AND v.departure_code = %s"
        params.append(origin)
    if destination:
        sql += " AND v.arrival_code = %s"
        params.append(destination)
    if travel_date:
        try:
            date.fromisoformat(travel_date)
        except ValueError:
            return jsonify({"error": "Date must be YYYY-MM-DD"}), 400
        sql += " AND DATE(v.departure_time) = %s"
        params.append(travel_date)
    sql += " ORDER BY v.departure_time LIMIT 100"
    try:
        return jsonify(fetch_all(sql, tuple(params)))
    except Error as exc:
        return jsonify({"error": str(exc)}), 500

@app.get("/api/airports")
def airports():
    try:
        return jsonify(fetch_all(
            "SELECT airport_code, airport_name, city, country FROM airports ORDER BY city"
        ))
    except Error as exc:
        return jsonify({"error": str(exc)}), 500

@app.post("/api/passengers")
def create_passenger():
    data = request.get_json(silent=True) or {}
    required = ["full_name", "date_of_birth", "passport_no"]
    missing = [key for key in required if not str(data.get(key, "")).strip()]
    if missing:
        return jsonify({"error": "Required fields: " + ", ".join(missing)}), 400
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO passengers (full_name,date_of_birth,gender,phone,email,passport_no)
            VALUES (%s,%s,%s,%s,%s,%s)
        """, (
            data["full_name"].strip(), data["date_of_birth"],
            data.get("gender", "PREFER_NOT_TO_SAY"),
            data.get("phone") or None, data.get("email") or None,
            data["passport_no"].strip().upper()
        ))
        passenger_id = cur.lastrowid
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"passenger_id": passenger_id, "message": "Passenger registered"}), 201
    except Error as exc:
        try: conn.rollback(); conn.close()
        except Exception: pass
        return jsonify({"error": "Could not register passenger. Email or passport may already exist.", "details": str(exc)}), 400

@app.post("/api/bookings")
def create_booking():
    data = request.get_json(silent=True) or {}
    required = ["passenger_id", "flight_id", "seat_no", "travel_class"]
    missing = [key for key in required if data.get(key) in (None, "")]
    if missing:
        return jsonify({"error": "Required fields: " + ", ".join(missing)}), 400

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        conn.start_transaction()

        # Serialise capacity checks for the same flight.
        cur.execute("""
            SELECT f.flight_id, f.flight_status, f.base_fare, a.capacity
            FROM flights f JOIN aircraft a ON f.aircraft_id = a.aircraft_id
            WHERE f.flight_id = %s FOR UPDATE
        """, (int(data["flight_id"]),))
        flight = cur.fetchone()
        if not flight:
            conn.rollback()
            return jsonify({"error": "Flight not found"}), 404
        if flight["flight_status"] not in ("SCHEDULED", "DELAYED"):
            conn.rollback()
            return jsonify({"error": "This flight is not available for booking"}), 400

        cur.execute("""
            SELECT COUNT(*) AS booked
            FROM bookings
            WHERE flight_id = %s AND booking_status IN ('PENDING','CONFIRMED')
        """, (int(data["flight_id"]),))
        booked = cur.fetchone()["booked"]
        if booked >= flight["capacity"]:
            conn.rollback()
            return jsonify({"error": "This flight has reached aircraft capacity"}), 409

        cur.execute("""
            INSERT INTO bookings
            (passenger_id,flight_id,seat_no,travel_class,fare,booking_status)
            VALUES (%s,%s,%s,%s,%s,'PENDING')
        """, (
            int(data["passenger_id"]), int(data["flight_id"]),
            str(data["seat_no"]).strip().upper(),
            data["travel_class"],
            float(data.get("fare", flight["base_fare"]))
        ))
        booking_id = cur.lastrowid
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({
            "booking_id": booking_id,
            "booking_status": "PENDING",
            "message": "Seat held. Add a simulated payment to confirm the booking."
        }), 201
    except Error as exc:
        if conn:
            try: conn.rollback(); conn.close()
            except Exception: pass
        message = str(exc)
        if "uq_active_seat" in message or "Duplicate entry" in message:
            return jsonify({"error": "That seat is already reserved on this flight."}), 409
        return jsonify({"error": "Booking failed. Check passenger, flight and input values.", "details": message}), 400

@app.post("/api/payments")
def create_payment():
    data = request.get_json(silent=True) or {}
    required = ["booking_id", "payment_method"]
    missing = [key for key in required if data.get(key) in (None, "")]
    if missing:
        return jsonify({"error": "Required fields: " + ", ".join(missing)}), 400
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        conn.start_transaction()
        cur.execute("""
            SELECT booking_id, fare, booking_status
            FROM bookings WHERE booking_id = %s FOR UPDATE
        """, (int(data["booking_id"]),))
        booking = cur.fetchone()
        if not booking:
            conn.rollback()
            return jsonify({"error": "Booking not found"}), 404
        if booking["booking_status"] == "CANCELLED":
            conn.rollback()
            return jsonify({"error": "Cannot pay for a cancelled booking"}), 400

        transaction_no = "DEMO-" + uuid.uuid4().hex[:12].upper()
        cur.execute("""
            INSERT INTO payments (booking_id,amount,payment_method,transaction_no,payment_status)
            VALUES (%s,%s,%s,%s,'SUCCESS')
        """, (booking["booking_id"], booking["fare"], data["payment_method"], transaction_no))
        payment_id = cur.lastrowid
        cur.execute("UPDATE bookings SET booking_status='CONFIRMED' WHERE booking_id=%s",
                    (booking["booking_id"],))
        ticket_no = "TKT-" + uuid.uuid4().hex[:10].upper()
        cur.execute("""
            INSERT INTO tickets (booking_id,ticket_no,seat_no,ticket_status)
            SELECT booking_id,%s,seat_no,'ISSUED'
            FROM bookings WHERE booking_id=%s
            ON DUPLICATE KEY UPDATE ticket_no=VALUES(ticket_no), seat_no=VALUES(seat_no), ticket_status='ISSUED'
        """, (ticket_no, booking["booking_id"]))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({
            "payment_id": payment_id,
            "transaction_no": transaction_no,
            "ticket_no": ticket_no,
            "booking_status": "CONFIRMED",
            "payment_status": "SUCCESS",
            "message": "Demo payment recorded and ticket issued."
        }), 201
    except Error as exc:
        if conn:
            try: conn.rollback(); conn.close()
            except Exception: pass
        return jsonify({"error": "Payment/confirmation failed", "details": str(exc)}), 400

@app.get("/api/bookings")
def list_bookings():
    try:
        return jsonify(fetch_all("""
            SELECT b.booking_id, p.full_name, f.flight_no,
                   v.departure_code, v.arrival_code, v.departure_time,
                   b.seat_no, b.travel_class, b.fare, b.booking_status,
                   t.ticket_no, COALESCE(pay.payment_status,'NO PAYMENT') AS payment_status
            FROM bookings b
            JOIN passengers p ON b.passenger_id=p.passenger_id
            JOIN flights f ON b.flight_id=f.flight_id
            JOIN vw_flight_schedule v ON b.flight_id=v.flight_id
            LEFT JOIN tickets t ON b.booking_id=t.booking_id
            LEFT JOIN payments pay ON b.booking_id=pay.booking_id
            ORDER BY b.booking_date DESC LIMIT 100
        """))
    except Error as exc:
        return jsonify({"error": str(exc)}), 500

@app.get("/api/stats")
def stats():
    try:
        rows = fetch_all("""
            SELECT
              (SELECT COUNT(*) FROM flights WHERE flight_status IN ('SCHEDULED','DELAYED')) AS active_flights,
              (SELECT COUNT(*) FROM passengers) AS passengers,
              (SELECT COUNT(*) FROM bookings WHERE booking_status='CONFIRMED') AS confirmed_bookings,
              (SELECT COALESCE(SUM(amount),0) FROM payments WHERE payment_status='SUCCESS') AS revenue
        """)
        return jsonify(rows[0])
    except Error as exc:
        return jsonify({"error": str(exc)}), 500

@app.errorhandler(404)
def not_found(_):
    return jsonify({"error": "Endpoint not found"}), 404

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")), debug=False)
