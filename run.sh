#!/bin/bash
set -Ee

# ── Project Configuration ────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_DIR="$PROJECT_DIR/frontend"

BACKEND_PORT=5010
FRONTEND_PORT=5177

BACKEND_HEALTH_PATH="/iocl-cube/api/health"
FRONTEND_PATH="/iocl-cube/kiosk"

BACKEND_PID=""
FRONTEND_PID=""
CLEANING_UP=0

# ── Automatically Detect Network IP ──────────────────────────────────
get_network_ip() {
    local IP=""

    if command -v ip >/dev/null 2>&1; then
        IP=$(ip -4 route get 1.1.1.1 2>/dev/null |
            awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}')

        if [ -z "$IP" ]; then
            IP=$(ip -o -4 addr show up scope global 2>/dev/null |
                awk 'NR==1 {split($4,a,"/"); print a[1]}')
        fi
    fi

    echo "$IP"
}

# ── Cleanup ───────────────────────────────────────────────────────────
cleanup() {
    [ "$CLEANING_UP" -eq 1 ] && return
    CLEANING_UP=1

    trap - EXIT INT TERM

    echo ""
    echo "Stopping application..."

    for PID in "$FRONTEND_PID" "$BACKEND_PID"; do
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            kill "$PID" 2>/dev/null || true
        fi
    done

    # Give the processes a moment to exit gracefully.
    sleep 1

    for PID in "$FRONTEND_PID" "$BACKEND_PID"; do
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            kill -TERM "$PID" 2>/dev/null || true
        fi
    done

    echo "Application stopped."
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ── Validate Project Directories ──────────────────────────────────────
if [ ! -d "$BACKEND_DIR" ]; then
    echo "ERROR: Backend directory not found: $BACKEND_DIR"
    exit 1
fi

if [ ! -d "$FRONTEND_DIR" ]; then
    echo "ERROR: Frontend directory not found: $FRONTEND_DIR"
    exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
    echo "ERROR: npm is not installed or not in PATH."
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is required."
    exit 1
fi

# ── Release Existing Application Ports ────────────────────────────────
for PORT in "$BACKEND_PORT" "$FRONTEND_PORT"; do
    if command -v lsof >/dev/null 2>&1; then
        PIDS=$(lsof -ti "tcp:$PORT" 2>/dev/null || true)

        if [ -n "$PIDS" ]; then
            echo "Releasing port $PORT..."

            while IFS= read -r PID; do
                [ -z "$PID" ] && continue
                kill "$PID" 2>/dev/null || true
            done <<< "$PIDS"

            # Wait briefly for the port to be released.
            for _ in $(seq 1 5); do
                if ! lsof -ti "tcp:$PORT" >/dev/null 2>&1; then
                    break
                fi
                sleep 1
            done

            PIDS=$(lsof -ti "tcp:$PORT" 2>/dev/null || true)
            if [ -n "$PIDS" ]; then
                echo "ERROR: Port $PORT is still occupied."
                echo "Stop the existing process and run this script again."
                exit 1
            fi
        fi
    else
        echo "WARNING: lsof is unavailable; cannot automatically check port $PORT."
    fi
done

# ── Install Dependencies When Necessary ───────────────────────────────
install_dependencies() {
    local DIR="$1"
    local NAME="$2"

    echo "Checking $NAME dependencies..."

    if [ ! -d "$DIR/node_modules" ] ||
       [ ! -f "$DIR/package-lock.json" ] ||
       [ ! -f "$DIR/node_modules/.pkg_hash" ] ||
       ! (cd "$DIR" && md5sum -c node_modules/.pkg_hash --status 2>/dev/null); then

        echo "Installing $NAME dependencies..."

        (
            cd "$DIR"
            npm install
        )

        # Record package.json and package-lock.json so changes trigger reinstall.
        (
            cd "$DIR"
            md5sum package.json package-lock.json > node_modules/.pkg_hash
        )
    fi
}

install_dependencies "$BACKEND_DIR" "backend"
install_dependencies "$FRONTEND_DIR" "frontend"

# ── Start Backend ─────────────────────────────────────────────────────
echo ""
echo "Starting backend on port $BACKEND_PORT..."

(
    cd "$BACKEND_DIR"
    exec npm run dev -- --host 0.0.0.0
) &
BACKEND_PID=$!

# ── Wait for Backend Health Check ─────────────────────────────────────
echo "Waiting for backend health check..."

BACKEND_READY=0

for _ in $(seq 1 60); do
    if curl -fsS \
        "http://127.0.0.1:${BACKEND_PORT}${BACKEND_HEALTH_PATH}" \
        >/dev/null 2>&1; then
        BACKEND_READY=1
        break
    fi

    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
        echo "ERROR: Backend process stopped unexpectedly."
        exit 1
    fi

    sleep 1
done

if [ "$BACKEND_READY" -ne 1 ]; then
    echo "ERROR: Backend did not become ready within 60 seconds."
    echo "Check this URL:"
    echo "http://127.0.0.1:${BACKEND_PORT}${BACKEND_HEALTH_PATH}"
    exit 1
fi

echo "Backend is ready."

# ── Start Frontend ────────────────────────────────────────────────────
echo ""
echo "Starting Vite frontend on port $FRONTEND_PORT..."

(
    cd "$FRONTEND_DIR"
    exec npm run dev -- --host 0.0.0.0 --port "$FRONTEND_PORT" --strictPort
) &
FRONTEND_PID=$!

# ── Wait for Frontend ─────────────────────────────────────────────────
echo "Waiting for frontend..."

FRONTEND_READY=0

for _ in $(seq 1 60); do
    if curl -fsS \
        "http://127.0.0.1:${FRONTEND_PORT}${FRONTEND_PATH}" \
        >/dev/null 2>&1; then
        FRONTEND_READY=1
        break
    fi

    if ! kill -0 "$FRONTEND_PID" 2>/dev/null; then
        echo "ERROR: Frontend process stopped unexpectedly."
        exit 1
    fi

    sleep 1
done

if [ "$FRONTEND_READY" -ne 1 ]; then
    echo "ERROR: Frontend did not become ready within 60 seconds."
    echo "Check the frontend port and route:"
    echo "http://127.0.0.1:${FRONTEND_PORT}${FRONTEND_PATH}"
    exit 1
fi

echo "Frontend is ready."

# ── Detect Network IP ─────────────────────────────────────────────────
NETWORK_IP="$(get_network_ip)"

if [ -z "$NETWORK_IP" ]; then
    echo "WARNING: Unable to detect network IP automatically."
    NETWORK_IP="127.0.0.1"
fi

KIOSK_URL="http://${NETWORK_IP}:${FRONTEND_PORT}${FRONTEND_PATH}"

# ── Display Application URLs ──────────────────────────────────────────
echo ""
echo "============================================================"
echo " APPLICATION STARTED SUCCESSFULLY"
echo "============================================================"
echo "Network IP: $NETWORK_IP"
echo ""
echo "Kiosk URL:  $KIOSK_URL"
echo "Frontend:   http://${NETWORK_IP}:${FRONTEND_PORT}${FRONTEND_PATH}"
echo "Backend:    http://${NETWORK_IP}:${BACKEND_PORT}"
echo "Health:     http://${NETWORK_IP}:${BACKEND_PORT}${BACKEND_HEALTH_PATH}"
echo ""
echo "Available IPv4 network addresses:"

if command -v ip >/dev/null 2>&1; then
    ip -o -4 addr show up scope global 2>/dev/null |
        awk '{split($4,a,"/"); print "http://" a[1] ":5177/iocl-cube/"}'
fi

echo "============================================================"
echo ""

# ── Open Kiosk Browser ────────────────────────────────────────────────
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
    echo "WARNING: Chromium/Chrome not found."
    echo "Open this URL manually: $KIOSK_URL"
fi

# ── Keep Both Services Running ────────────────────────────────────────
echo "Backend and frontend are running."
echo "Press Ctrl+C to stop both services."

# Exit if either service exits; cleanup will stop the other.
while true; do
    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
        echo "ERROR: Backend process exited."
        exit 1
    fi

    if ! kill -0 "$FRONTEND_PID" 2>/dev/null; then
        echo "ERROR: Frontend process exited."
        exit 1
    fi

    sleep 2
done