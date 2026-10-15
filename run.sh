#!/bin/bash
set -e

# ── Project Configuration ────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_DIR="$PROJECT_DIR/frontend"

BACKEND_PORT=8000
FRONTEND_PORT=5173
FRONTEND_PATH="/powergrid-hollowtube/"

BACKEND_PID=""
FRONTEND_PID=""

# ── Automatically Detect Network IP ──────────────────────────────────
get_network_ip() {
    # Prefer the LAN IP selected by the default network route.
    local IP
    IP=$(ip -4 route get 1.1.1.1 2>/dev/null |
        awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}')

    # Fall back to the first active, non-loopback IPv4 address.
    if [ -z "$IP" ]; then
        IP=$(ip -o -4 addr show up scope global |
            awk 'NR==1 {split($4,a,"/"); print a[1]}')
    fi

    echo "$IP"
}

# ── Cleanup ───────────────────────────────────────────────────────────
cleanup() {
    echo ""
    echo "Stopping application..."

    [ -z "$BACKEND_PID" ] || kill "$BACKEND_PID" 2>/dev/null || true
    [ -z "$FRONTEND_PID" ] || kill "$FRONTEND_PID" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

# ── Kill Existing Processes ───────────────────────────────────────────
for PORT in "$BACKEND_PORT" "$FRONTEND_PORT"; do
    PID=$(lsof -ti tcp:"$PORT" 2>/dev/null || true)

    if [ -n "$PID" ]; then
        echo "$PID" | xargs -r kill -9 2>/dev/null || true
        echo "Released port $PORT"
    fi
done

# ── Backend Dependencies ──────────────────────────────────────────────
cd "$BACKEND_DIR"

echo "Checking backend dependencies..."

if [ ! -d node_modules ] || \
   [ ! -f node_modules/.pkg_hash ] || \
   ! md5sum -c node_modules/.pkg_hash --status 2>/dev/null; then

    npm install
    md5sum package.json > node_modules/.pkg_hash
fi

# ── Start Node.js Backend ──────────────────────────────────────────────
echo "Starting backend..."

npm run dev -- --host 0.0.0.0 &
BACKEND_PID=$!

# ── Wait for Backend ──────────────────────────────────────────────────
echo "Waiting for backend..."

BACKEND_READY=0

for i in $(seq 1 60); do
    if curl -fsS "http://127.0.0.1:${BACKEND_PORT}/health" >/dev/null 2>&1; then
        BACKEND_READY=1
        break
    fi

    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
        echo "ERROR: Backend stopped unexpectedly."
        exit 1
    fi

    sleep 1
done

if [ "$BACKEND_READY" -ne 1 ]; then
    echo "ERROR: Backend did not become ready within 60 seconds."
    exit 1
fi

echo "Backend is ready."

# ── Frontend Dependencies ──────────────────────────────────────────────
cd "$FRONTEND_DIR"

echo "Checking frontend dependencies..."

if [ ! -d node_modules ] || \
   [ ! -f node_modules/.pkg_hash ] || \
   ! md5sum -c node_modules/.pkg_hash --status 2>/dev/null; then

    npm install
    md5sum package.json > node_modules/.pkg_hash
fi

# ── Start Frontend on All Interfaces ───────────────────────────────────
echo "Starting Vite frontend on 0.0.0.0..."

npm run dev -- --host 0.0.0.0 &
FRONTEND_PID=$!

# ── Wait for Frontend ──────────────────────────────────────────────────
echo "Waiting for frontend..."

FRONTEND_READY=0

for i in $(seq 1 60); do
    if curl -fsS "http://127.0.0.1:${FRONTEND_PORT}${FRONTEND_PATH}" >/dev/null 2>&1; then
        FRONTEND_READY=1
        break
    fi

    if ! kill -0 "$FRONTEND_PID" 2>/dev/null; then
        echo "ERROR: Frontend stopped unexpectedly."
        exit 1
    fi

    sleep 1
done

if [ "$FRONTEND_READY" -ne 1 ]; then
    echo "ERROR: Frontend did not become ready within 60 seconds."
    exit 1
fi

echo "Frontend is ready."

# ── Detect Network IP Automatically ───────────────────────────────────
NETWORK_IP=$(get_network_ip)

if [ -z "$NETWORK_IP" ]; then
    echo "ERROR: Unable to detect a network IP address."
    exit 1
fi

KIOSK_URL="http://${NETWORK_IP}:${FRONTEND_PORT}${FRONTEND_PATH}"

# ── Display Network URLs ───────────────────────────────────────────────
echo ""
echo "============================================================"
echo " APPLICATION STARTED"
echo "============================================================"
echo "Detected Network IP: $NETWORK_IP"
echo ""
echo "Kiosk URL:  $KIOSK_URL"
echo "Frontend:   http://${NETWORK_IP}:${FRONTEND_PORT}${FRONTEND_PATH}"
echo "Backend:    http://${NETWORK_IP}:${BACKEND_PORT}"
echo ""
echo "Available IPv4 network addresses:"

ip -o -4 addr show up scope global |
    awk '{split($4,a,"/"); print "http://" a[1] ":5173/powergrid-hollowtube/"}'

echo "============================================================"
echo ""

# ── Open Browser Using Network IP ──────────────────────────────────────
echo "Opening kiosk browser at $KIOSK_URL"

if command -v chromium-browser >/dev/null 2>&1; then
    chromium-browser --kiosk --noerrdialogs --disable-infobars \
        --no-first-run --start-fullscreen "$KIOSK_URL" || true

elif command -v chromium >/dev/null 2>&1; then
    chromium --kiosk --noerrdialogs --disable-infobars \
        --no-first-run --start-fullscreen "$KIOSK_URL" || true

elif command -v google-chrome >/dev/null 2>&1; then
    google-chrome --kiosk --noerrdialogs --disable-infobars \
        --no-first-run --start-fullscreen "$KIOSK_URL" || true

else
    xdg-open "$KIOSK_URL" || true
fi

# ── Keep Services Running ──────────────────────────────────────────────
wait "$BACKEND_PID" "$FRONTEND_PID"