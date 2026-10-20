-- ============================================================
-- FLIGHT MANAGEMENT SYSTEM - DBMS MINI PROJECT
-- MySQL 8.0+
-- DDL, sample data, constraints, indexes, view, function,
-- stored procedures and triggers.
-- ============================================================

DROP DATABASE IF EXISTS flight_management;
CREATE DATABASE flight_management CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE flight_management;

-- 1. MASTER TABLES

CREATE TABLE airlines (
    airline_id INT AUTO_INCREMENT PRIMARY KEY,
    airline_name VARCHAR(100) NOT NULL,
    country VARCHAR(80) NOT NULL,
    contact_no VARCHAR(20),
    email VARCHAR(120) UNIQUE
) ENGINE=InnoDB;

CREATE TABLE airports (
    airport_id INT AUTO_INCREMENT PRIMARY KEY,
    airport_code CHAR(3) NOT NULL UNIQUE,
    airport_name VARCHAR(120) NOT NULL,
    city VARCHAR(80) NOT NULL,
    country VARCHAR(80) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE aircraft (
    aircraft_id INT AUTO_INCREMENT PRIMARY KEY,
    registration_no VARCHAR(20) NOT NULL UNIQUE,
    model VARCHAR(80) NOT NULL,
    manufacturer VARCHAR(80) NOT NULL,
    capacity INT NOT NULL,
    CONSTRAINT chk_aircraft_capacity CHECK (capacity > 0)
) ENGINE=InnoDB;

CREATE TABLE flights (
    flight_id INT AUTO_INCREMENT PRIMARY KEY,
    flight_no VARCHAR(15) NOT NULL,
    airline_id INT NOT NULL,
    aircraft_id INT NOT NULL,
    departure_airport_id INT NOT NULL,
    arrival_airport_id INT NOT NULL,
    departure_time DATETIME NOT NULL,
    arrival_time DATETIME NOT NULL,
    flight_status ENUM('SCHEDULED','DELAYED','CANCELLED','COMPLETED') NOT NULL DEFAULT 'SCHEDULED',
    base_fare DECIMAL(10,2) NOT NULL,
    CONSTRAINT uq_flight_departure UNIQUE (flight_no, departure_time),
    CONSTRAINT chk_flight_route CHECK (departure_airport_id <> arrival_airport_id),
    CONSTRAINT chk_flight_times CHECK (arrival_time > departure_time),
    CONSTRAINT chk_flight_fare CHECK (base_fare >= 0),
    CONSTRAINT fk_flight_airline FOREIGN KEY (airline_id) REFERENCES airlines(airline_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_flight_aircraft FOREIGN KEY (aircraft_id) REFERENCES aircraft(aircraft_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_flight_departure FOREIGN KEY (departure_airport_id) REFERENCES airports(airport_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_flight_arrival FOREIGN KEY (arrival_airport_id) REFERENCES airports(airport_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_flight_route_time (departure_airport_id, arrival_airport_id, departure_time),
    INDEX idx_flight_status (flight_status)
) ENGINE=InnoDB;

CREATE TABLE passengers (
    passenger_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    date_of_birth DATE NOT NULL,
    gender ENUM('FEMALE','MALE','OTHER','PREFER_NOT_TO_SAY') NOT NULL DEFAULT 'PREFER_NOT_TO_SAY',
    phone VARCHAR(20),
    email VARCHAR(120) UNIQUE,
    passport_no VARCHAR(30) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE bookings (
    booking_id INT AUTO_INCREMENT PRIMARY KEY,
    passenger_id INT NOT NULL,
    flight_id INT NOT NULL,
    booking_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    seat_no VARCHAR(5) NOT NULL,
    travel_class ENUM('ECONOMY','BUSINESS','FIRST') NOT NULL DEFAULT 'ECONOMY',
    fare DECIMAL(10,2) NOT NULL,
    booking_status ENUM('PENDING','CONFIRMED','CANCELLED') NOT NULL DEFAULT 'PENDING',
    active_seat VARCHAR(5) GENERATED ALWAYS AS
        (CASE WHEN booking_status IN ('PENDING','CONFIRMED') THEN seat_no ELSE NULL END) STORED,
    CONSTRAINT fk_booking_passenger FOREIGN KEY (passenger_id) REFERENCES passengers(passenger_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_booking_flight FOREIGN KEY (flight_id) REFERENCES flights(flight_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_booking_fare CHECK (fare >= 0),
    CONSTRAINT uq_active_seat UNIQUE (flight_id, active_seat),
    INDEX idx_booking_passenger (passenger_id),
    INDEX idx_booking_flight_status (flight_id, booking_status)
) ENGINE=InnoDB;

CREATE TABLE tickets (
    ticket_id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL UNIQUE,
    ticket_no VARCHAR(30) NOT NULL UNIQUE,
    issue_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    seat_no VARCHAR(5) NOT NULL,
    ticket_status ENUM('ISSUED','CANCELLED','USED') NOT NULL DEFAULT 'ISSUED',
    CONSTRAINT fk_ticket_booking FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL,
    payment_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    amount DECIMAL(10,2) NOT NULL,
    payment_method ENUM('CARD','UPI','NET_BANKING','CASH','OTHER') NOT NULL,
    transaction_no VARCHAR(60) NOT NULL UNIQUE,
    payment_status ENUM('PENDING','SUCCESS','FAILED','REFUNDED') NOT NULL DEFAULT 'PENDING',
    CONSTRAINT fk_payment_booking FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_payment_amount CHECK (amount >= 0),
    INDEX idx_payment_booking_status (booking_id, payment_status)
) ENGINE=InnoDB;

-- 2. SAMPLE DATA

INSERT INTO airlines (airline_name, country, contact_no, email) VALUES
('Air India','India','1800-180-1407','support@airindia.example'),
('IndiGo','India','0124-617-3838','support@indigo.example'),
('Emirates','United Arab Emirates','800-777-3999','support@emirates.example');

INSERT INTO airports (airport_code, airport_name, city, country) VALUES
('PNQ','Pune Airport','Pune','India'),
('BOM','Chhatrapati Shivaji Maharaj International Airport','Mumbai','India'),
('DEL','Indira Gandhi International Airport','Delhi','India'),
('BLR','Kempegowda International Airport','Bengaluru','India'),
('DXB','Dubai International Airport','Dubai','United Arab Emirates');

INSERT INTO aircraft (registration_no, model, manufacturer, capacity) VALUES
('VT-ABC','A320neo','Airbus',180),
('VT-DEF','Boeing 737-800','Boeing',189),
('VT-GHI','A350-900','Airbus',300);

INSERT INTO flights
(flight_no, airline_id, aircraft_id, departure_airport_id, arrival_airport_id,
 departure_time, arrival_time, flight_status, base_fare) VALUES
('AI101',1,1,1,3,'2026-11-05 08:00:00','2026-11-05 10:10:00','SCHEDULED',5200.00),
('6E204',2,2,1,2,'2026-11-06 12:30:00','2026-11-06 13:35:00','SCHEDULED',2800.00),
('AI405',1,1,2,4,'2026-11-07 09:00:00','2026-11-07 10:45:00','SCHEDULED',4100.00),
('EK501',3,3,3,5,'2026-11-08 22:00:00','2026-11-09 02:30:00','SCHEDULED',18500.00),
('6E310',2,2,4,1,'2026-11-09 17:00:00','2026-11-09 18:35:00','SCHEDULED',3600.00);

INSERT INTO passengers (full_name,date_of_birth,gender,phone,email,passport_no) VALUES
('Aarav Mehta','2004-03-14','MALE','9876500101','aarav.demo@example.com','PDEMO1001'),
('Diya Sharma','2003-07-21','FEMALE','9876500102','diya.demo@example.com','PDEMO1002'),
('Kabir Joshi','2002-11-02','MALE','9876500103','kabir.demo@example.com','PDEMO1003');

INSERT INTO bookings (passenger_id,flight_id,seat_no,travel_class,fare,booking_status) VALUES
(1,1,'12A','ECONOMY',5200.00,'CONFIRMED'),
(2,2,'08C','ECONOMY',2800.00,'CONFIRMED'),
(3,3,'03A','BUSINESS',8200.00,'PENDING');

INSERT INTO tickets (booking_id,ticket_no,seat_no,ticket_status) VALUES
(1,'TKT-DEMO-10001','12A','ISSUED'),
(2,'TKT-DEMO-10002','08C','ISSUED');

INSERT INTO payments (booking_id,amount,payment_method,transaction_no,payment_status) VALUES
(1,5200.00,'UPI','TXN-DEMO-10001','SUCCESS'),
(2,2800.00,'CARD','TXN-DEMO-10002','SUCCESS'),
(3,8200.00,'NET_BANKING','TXN-DEMO-10003','PENDING');

-- 3. TRIGGERS: prevent booking on cancelled/completed flights
DELIMITER $$

CREATE TRIGGER trg_booking_before_insert
BEFORE INSERT ON bookings
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    SELECT flight_status INTO v_status
    FROM flights WHERE flight_id = NEW.flight_id;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Flight does not exist';
    ELSEIF v_status IN ('CANCELLED','COMPLETED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot book a cancelled or completed flight';
    END IF;
END$$

CREATE TRIGGER trg_booking_before_update
BEFORE UPDATE ON bookings
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    SELECT flight_status INTO v_status
    FROM flights WHERE flight_id = NEW.flight_id;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Flight does not exist';
    ELSEIF v_status IN ('CANCELLED','COMPLETED') AND NEW.booking_status IN ('PENDING','CONFIRMED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot activate booking for a cancelled or completed flight';
    END IF;
END$$

DELIMITER ;

-- 4. REPORTING VIEW
CREATE OR REPLACE VIEW vw_flight_schedule AS
SELECT f.flight_id, f.flight_no, al.airline_name,
       dep.airport_code AS departure_code, dep.city AS departure_city,
       arr.airport_code AS arrival_code, arr.city AS arrival_city,
       f.departure_time, f.arrival_time, f.flight_status,
       ac.model AS aircraft_model, ac.capacity, f.base_fare
FROM flights f
JOIN airlines al ON f.airline_id = al.airline_id
JOIN airports dep ON f.departure_airport_id = dep.airport_id
JOIN airports arr ON f.arrival_airport_id = arr.airport_id
JOIN aircraft ac ON f.aircraft_id = ac.aircraft_id;

-- 5. USER-DEFINED FUNCTION
DELIMITER $$
CREATE FUNCTION fn_available_seats(p_flight_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_capacity INT DEFAULT NULL;
    DECLARE v_booked INT DEFAULT 0;
    SELECT ac.capacity INTO v_capacity
    FROM flights f JOIN aircraft ac ON f.aircraft_id = ac.aircraft_id
    WHERE f.flight_id = p_flight_id;
    IF v_capacity IS NULL THEN
        RETURN NULL;
    END IF;
    SELECT COUNT(*) INTO v_booked
    FROM bookings
    WHERE flight_id = p_flight_id AND booking_status IN ('PENDING','CONFIRMED');
    RETURN GREATEST(v_capacity - v_booked, 0);
END$$
DELIMITER ;

-- 6. STORED PROCEDURE: issue a ticket only for confirmed booking
DELIMITER $$
CREATE PROCEDURE sp_issue_ticket(IN p_booking_id INT, IN p_ticket_no VARCHAR(30))
BEGIN
    DECLARE v_status VARCHAR(20) DEFAULT NULL;
    DECLARE v_seat VARCHAR(5) DEFAULT NULL;
    SELECT booking_status, seat_no INTO v_status, v_seat
    FROM bookings WHERE booking_id = p_booking_id;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking does not exist';
    ELSEIF v_status <> 'CONFIRMED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only confirmed bookings can receive tickets';
    ELSE
        INSERT INTO tickets (booking_id,ticket_no,seat_no,ticket_status)
        VALUES (p_booking_id,p_ticket_no,v_seat,'ISSUED');
    END IF;
END$$
DELIMITER ;

-- 7. STORED PROCEDURE: confirm booking after successful payment
DELIMITER $$
CREATE PROCEDURE sp_confirm_booking(IN p_booking_id INT)
BEGIN
    DECLARE v_payment_count INT DEFAULT 0;
    DECLARE v_booking_status VARCHAR(20) DEFAULT NULL;
    SELECT booking_status INTO v_booking_status
    FROM bookings WHERE booking_id = p_booking_id;
    IF v_booking_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking does not exist';
    ELSEIF v_booking_status = 'CANCELLED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cancelled booking cannot be confirmed';
    ELSE
        SELECT COUNT(*) INTO v_payment_count
        FROM payments WHERE booking_id = p_booking_id AND payment_status = 'SUCCESS';
        IF v_payment_count = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Successful payment is required';
        ELSE
            UPDATE bookings SET booking_status = 'CONFIRMED' WHERE booking_id = p_booking_id;
        END IF;
    END IF;
END$$
DELIMITER ;

-- 8. EXAMPLE QUERIES

-- Q1. Full flight schedule
SELECT * FROM vw_flight_schedule ORDER BY departure_time;

-- Q2. Search flights between two airports
SELECT * FROM vw_flight_schedule
WHERE departure_code = 'PNQ' AND arrival_code = 'DEL'
ORDER BY departure_time;

-- Q3. Passenger booking history
SELECT p.full_name, f.flight_no, b.seat_no, b.travel_class, b.fare, b.booking_status
FROM bookings b
JOIN passengers p ON b.passenger_id = p.passenger_id
JOIN flights f ON b.flight_id = f.flight_id
ORDER BY b.booking_date DESC;

-- Q4. Revenue by airline (successful payments)
SELECT al.airline_name, SUM(pay.amount) AS total_revenue
FROM payments pay
JOIN bookings b ON pay.booking_id = b.booking_id
JOIN flights f ON b.flight_id = f.flight_id
JOIN airlines al ON f.airline_id = al.airline_id
WHERE pay.payment_status = 'SUCCESS'
GROUP BY al.airline_id, al.airline_name
ORDER BY total_revenue DESC;

-- Q5. Flights with more than one booking
SELECT f.flight_no, COUNT(b.booking_id) AS active_bookings
FROM flights f JOIN bookings b ON f.flight_id = b.flight_id
WHERE b.booking_status IN ('PENDING','CONFIRMED')
GROUP BY f.flight_id, f.flight_no
HAVING COUNT(b.booking_id) > 1;

-- Q6. Available seats for each flight
SELECT flight_id, flight_no, fn_available_seats(flight_id) AS available_seats
FROM flights ORDER BY departure_time;

-- Q7. Passengers with no bookings
SELECT p.passenger_id, p.full_name
FROM passengers p
WHERE NOT EXISTS (SELECT 1 FROM bookings b WHERE b.passenger_id = p.passenger_id);

-- Q8. Bookings with payment status
SELECT b.booking_id, p.full_name, f.flight_no, b.fare,
       COALESCE(pay.payment_status,'NO PAYMENT') AS payment_status
FROM bookings b
JOIN passengers p ON b.passenger_id = p.passenger_id
JOIN flights f ON b.flight_id = f.flight_id
LEFT JOIN payments pay ON b.booking_id = pay.booking_id
ORDER BY b.booking_id;

-- Q9. Airlines with fares above average
SELECT al.airline_name, AVG(f.base_fare) AS average_fare
FROM airlines al JOIN flights f ON al.airline_id = f.airline_id
GROUP BY al.airline_id, al.airline_name
HAVING AVG(f.base_fare) > (SELECT AVG(base_fare) FROM flights);

-- Q10. Flight booking summary
SELECT f.flight_no,
       COUNT(b.booking_id) AS total_bookings,
       SUM(CASE WHEN b.booking_status = 'CONFIRMED' THEN 1 ELSE 0 END) AS confirmed_bookings,
       SUM(CASE WHEN b.booking_status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_bookings
FROM flights f LEFT JOIN bookings b ON f.flight_id = b.flight_id
GROUP BY f.flight_id, f.flight_no
ORDER BY f.flight_no;

-- 9. OPTIONAL DCL (run with an account permitted to CREATE USER / GRANT)
CREATE USER IF NOT EXISTS 'flight_viewer'@'localhost' IDENTIFIED BY 'Viewer@123';
GRANT SELECT ON flight_management.* TO 'flight_viewer'@'localhost';
FLUSH PRIVILEGES;

-- END OF PROJECT
