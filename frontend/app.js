const API = "/api";
const $ = (id) => document.getElementById(id);
let currentFlights = [];
let selectedFlight = null;
let lastBooking = null;

function money(value) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(Number(value || 0));
}
function time(value) {
  const d = new Date(String(value).replace(" ", "T"));
  return Number.isNaN(d.getTime()) ? value : d.toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit", hour12: true });
}
function day(value) {
  const d = new Date(String(value).replace(" ", "T"));
  return Number.isNaN(d.getTime()) ? value : d.toLocaleDateString("en-IN", { day: "2-digit", month: "short" });
}
function showToast(message) {
  const toast = $("toast");
  toast.textContent = message;
  toast.classList.add("show");
  setTimeout(() => toast.classList.remove("show"), 3000);
}
async function api(path, options = {}) {
  const response = await fetch(API + path, {
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
    ...options
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || "Request failed");
  return data;
}
function setStatus(ok, text) {
  $("api-status").textContent = text;
  $("api-status").style.color = ok ? "#14866d" : "#c44c4c";
}
function flightCard(f) {
  const soldOut = Number(f.available_seats) <= 0;
  return `<article class="flight-card">
    <div class="airline-block"><div class="airline-name">${escapeHtml(f.airline_name)}</div><div class="flight-no">${escapeHtml(f.flight_no)} · ${escapeHtml(f.aircraft_model || "")}</div></div>
    <div class="route-times">
      <div class="time-block"><strong>${time(f.departure_time)}</strong><small>${escapeHtml(f.departure_code)} · ${day(f.departure_time)}</small></div>
      <div class="route-track"><span>${duration(f.departure_time, f.arrival_time)}</span><div class="line"></div><span>Direct</span></div>
      <div class="time-block"><strong>${time(f.arrival_time)}</strong><small>${escapeHtml(f.arrival_code)} · ${day(f.arrival_time)}</small></div>
    </div>
    <div class="fare"><strong>${money(f.base_fare)}</strong><small>${f.available_seats} seats available</small></div>
    <button class="book-button" data-book="${f.flight_id}" ${soldOut ? "disabled" : ""}>${soldOut ? "Sold out" : "Book flight ↗"}</button>
  </article>`;
}
function duration(start, end) {
  const mins = Math.max(0, Math.round((new Date(String(end).replace(" ", "T")) - new Date(String(start).replace(" ", "T"))) / 60000));
  return `${Math.floor(mins / 60)}h ${mins % 60}m`;
}
function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, c => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[c]));
}
function bindBookButtons(container) {
  container.querySelectorAll("[data-book]").forEach(button => button.addEventListener("click", () => {
    selectedFlight = currentFlights.find(f => Number(f.flight_id) === Number(button.dataset.book));
    if (!selectedFlight) return;
    $("selected-flight-id").value = selectedFlight.flight_id;
    $("selected-flight").innerHTML = `<b>${escapeHtml(selectedFlight.airline_name)} · ${escapeHtml(selectedFlight.flight_no)}</b><br>${escapeHtml(selectedFlight.departure_city)} (${escapeHtml(selectedFlight.departure_code)}) → ${escapeHtml(selectedFlight.arrival_city)} (${escapeHtml(selectedFlight.arrival_code)})<br>${day(selectedFlight.departure_time)} · ${time(selectedFlight.departure_time)} · ${money(selectedFlight.base_fare)}`;
    $("booking-error").textContent = "";
    $("booking-dialog").showModal();
  }));
}
async function loadFlights(query = "", target = "preview-flights", limit = 3) {
  const container = $(target);
  container.innerHTML = '<div class="loading">Loading flight schedule…</div>';
  try {
    currentFlights = await api("/flights" + query);
    const list = target === "preview-flights" ? currentFlights.slice(0, limit) : currentFlights;
    $("result-count").textContent = `${currentFlights.length} flight${currentFlights.length === 1 ? "" : "s"} found`;
    container.innerHTML = list.length ? list.map(flightCard).join("") : '<div class="empty-state">No flights match this search. Try another route or date.</div>';
    bindBookButtons(container);
  } catch (err) {
    container.innerHTML = `<div class="empty-state">Could not load flights: ${escapeHtml(err.message)}<br><br>Make sure MySQL and the Flask API are running.</div>`;
    setStatus(false, "API unavailable");
  }
}
async function loadStats() {
  try {
    const s = await api("/stats");
    $("stat-flights").textContent = s.active_flights;
    $("stat-passengers").textContent = s.passengers;
    $("stat-bookings").textContent = s.confirmed_bookings;
    $("stat-revenue").textContent = money(s.revenue);
    setStatus(true, "API connected");
  } catch {
    setStatus(false, "Start backend to connect");
  }
}
async function loadAirports() {
  try {
    const airports = await api("/airports");
    ["origin", "destination"].forEach(id => {
      const select = $(id);
      airports.forEach(a => {
        const option = document.createElement("option");
        option.value = a.airport_code;
        option.textContent = `${a.city} (${a.airport_code})`;
        select.appendChild(option);
      });
    });
  } catch {}
}
async function loadBookings() {
  const body = $("booking-rows");
  body.innerHTML = '<tr><td colspan="7" class="loading">Loading bookings…</td></tr>';
  try {
    const rows = await api("/bookings");
    body.innerHTML = rows.length ? rows.map(b => `<tr>
      <td><strong>#${b.booking_id}</strong><br><span style="color:#9aa4b4">${escapeHtml(b.payment_status)}</span></td>
      <td><strong>${escapeHtml(b.full_name)}</strong></td>
      <td><strong>${escapeHtml(b.flight_no)}</strong><br>${escapeHtml(b.departure_code)} → ${escapeHtml(b.arrival_code)}<br><span style="color:#9aa4b4">${day(b.departure_time)}</span></td>
      <td>${escapeHtml(b.seat_no)}<br><span style="color:#9aa4b4">${escapeHtml(b.travel_class)}</span></td>
      <td><strong>${money(b.fare)}</strong></td>
      <td><span class="pill ${b.booking_status.toLowerCase()}">${escapeHtml(b.booking_status)}</span></td>
      <td>${b.ticket_no ? escapeHtml(b.ticket_no) : "—"}</td>
    </tr>`).join("") : '<tr><td colspan="7" class="empty-state">No bookings yet.</td></tr>';
  } catch (err) {
    body.innerHTML = `<tr><td colspan="7" class="empty-state">${escapeHtml(err.message)}</td></tr>`;
  }
}
function navigate(view) {
  document.querySelectorAll(".view").forEach(el => el.classList.add("hidden"));
  $(view + "-view").classList.remove("hidden");
  document.querySelectorAll(".nav-item").forEach(el => el.classList.toggle("active", el.dataset.view === view));
  const titles = { overview: "Good afternoon", flights: "Find your next flight", bookings: "Bookings & tickets" };
  $("page-title").innerHTML = `${titles[view]}<span class="title-dot">.</span>`;
  if (view === "flights") loadFlights("", "flight-results", 100);
  if (view === "bookings") loadBookings();
}
document.querySelectorAll(".nav-item").forEach(button => button.addEventListener("click", () => navigate(button.dataset.view)));
$("hero-search").addEventListener("click", () => navigate("flights"));
$("all-flights").addEventListener("click", () => navigate("flights"));
$("search-form").addEventListener("submit", async event => {
  event.preventDefault();
  const params = new URLSearchParams();
  if ($("origin").value) params.set("origin", $("origin").value);
  if ($("destination").value) params.set("destination", $("destination").value);
  if ($("travel-date").value) params.set("date", $("travel-date").value);
  await loadFlights("?" + params.toString(), "flight-results", 100);
});
$("close-dialog").addEventListener("click", () => $("booking-dialog").close());
$("close-payment").addEventListener("click", () => $("payment-dialog").close());

$("booking-form").addEventListener("submit", async event => {
  event.preventDefault();
  const error = $("booking-error");
  error.textContent = "";
  const passenger = {
    full_name: $("passenger-name").value.trim(),
    date_of_birth: $("passenger-dob").value,
    gender: $("passenger-gender").value,
    phone: $("passenger-phone").value.trim(),
    email: $("passenger-email").value.trim(),
    passport_no: $("passenger-passport").value.trim()
  };
  try {
    const registered = await api("/passengers", { method: "POST", body: JSON.stringify(passenger) });
    const booking = await api("/bookings", { method: "POST", body: JSON.stringify({
      passenger_id: registered.passenger_id,
      flight_id: Number($("selected-flight-id").value),
      seat_no: $("seat-number").value.trim().toUpperCase(),
      travel_class: $("travel-class").value,
      fare: Number(selectedFlight.base_fare)
    })});
    lastBooking = booking;
    $("booking-dialog").close();
    $("payment-booking-id").value = booking.booking_id;
    $("payment-summary").innerHTML = `<b>Booking #${booking.booking_id}</b><br>${escapeHtml(selectedFlight.flight_no)} · Seat ${escapeHtml($("seat-number").value.toUpperCase())}<br>Amount due: <b>${money(selectedFlight.base_fare)}</b>`;
    $("payment-error").textContent = "";
    $("payment-dialog").showModal();
    showToast("Booking created. Complete demo checkout.");
  } catch (err) {
    error.textContent = err.message + (err.message.toLowerCase().includes("passport") ? " Use a new demo passport/ID value if this person is already registered." : "");
  }
});
$("payment-form").addEventListener("submit", async event => {
  event.preventDefault();
  $("payment-error").textContent = "";
  try {
    const result = await api("/payments", { method: "POST", body: JSON.stringify({
      booking_id: Number($("payment-booking-id").value),
      payment_method: $("payment-method").value
    })});
    $("payment-dialog").close();
    showToast(`Ticket issued: ${result.ticket_no}`);
    await Promise.all([loadStats(), loadFlights("", "preview-flights", 3)]);
    if (!$("bookings-view").classList.contains("hidden")) loadBookings();
    alert(`Booking confirmed!\nTicket: ${result.ticket_no}\nTransaction: ${result.transaction_no}\n\nThis is a simulated demo payment; no money was charged.`);
  } catch (err) {
    $("payment-error").textContent = err.message;
  }
});

$("today").textContent = new Date().toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short", year: "numeric" });
loadAirports();
loadStats();
loadFlights("", "preview-flights", 3);
