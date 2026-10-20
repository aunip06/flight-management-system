# Flight Management System — deployment-ready starter

This project can be deployed without installing a MySQL server locally. The intended setup is a hosted MySQL database and a Flask web service on Railway. The Flask service also serves the frontend, so only one app URL is needed.

## Before deploying

- This is an educational demo, not a production airline booking platform.
- The SQL file begins by dropping and recreating `flight_management`. Review that line before running it against any existing database.
- Use demo data only. Do not enter real passport or payment information.
- Payments are simulated, not processed by a real payment gateway.
- Hosting may incur charges; check Railway's current plan and usage before enabling paid resources.

## 1. Push to GitHub

Create a GitHub repository and upload the contents of this folder. Keep `backend/` and `frontend/` at the repository root. Do not upload passwords, `.env` files, or database credentials.

## 2. Create hosted MySQL on Railway

1. Sign in at https://railway.com/ and create a project.
2. Add a MySQL database service using Railway's MySQL template.
3. Wait until it is running.
4. In the MySQL service's Variables/Connect area, find its host, port, username, password, and database name. Keep these secret.

## 3. Import the SQL schema

You do not need to install a MySQL *server*. You do need a SQL client to run the schema against the hosted database. For example, MySQL Workbench is a client application, not the database server.

1. Enable TCP Proxy/Public Networking for the Railway MySQL service only if connecting from your computer.
2. Connect your SQL client using the external host and port plus the supplied username/password.
3. Open `backend/flight_management.sql` and execute it.
4. Confirm that the tables, view, function, procedures, triggers, and sample rows were created.

**Caution:** The SQL script starts with `DROP DATABASE IF EXISTS flight_management;` and recreates it. Do not run it if that would overwrite data you need to keep. If your database provider restricts `CREATE DATABASE`, the script must be adjusted to use the database it provisioned for you.

## 4. Deploy the Flask app

1. In the same Railway project, choose New → GitHub Repo and select your repository.
2. Set the service's Root Directory to `/` (repository root), not `/backend`.
3. Set the Build Command to:

   `pip install -r backend/requirements.txt`

4. Set the Start Command to:

   `gunicorn --chdir backend app:app --bind 0.0.0.0:$PORT`

5. Add environment variables to the app service using the values from your MySQL service:

   - `DB_HOST` = MySQL service's internal host (usually the Railway private hostname, or the value Railway shows for internal connection)
   - `DB_PORT` = MySQL internal port, usually `3306`
   - `DB_USER` = MySQL username
   - `DB_PASSWORD` = MySQL password
   - `DB_NAME` = `flight_management` if you imported the provided SQL unchanged

   Keep the app and database in the same Railway project so the private host can be reached. Use the internal host, not the public TCP proxy, for app-to-database traffic.

6. Deploy the service and open its generated public domain.

## 5. Test

- Open `/api/health` on your app domain. It should return `ok: true` and a MySQL version.
- Open the homepage and check the dashboard and flight search.
- Try passenger registration and booking with demo data.
- Confirm duplicate active seat bookings are rejected.

If `/api/health` fails, check the Railway app logs and verify `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, and `DB_NAME`. Never paste database passwords into GitHub or public chats.
