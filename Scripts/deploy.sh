#!/bin/bash
#
# This script manages the deployment of the GestureControlPro servers.
# It can start, stop, and check the status of the Python server.

set -e

LOG_DIR="logs"
PYTHON_LOG="$LOG_DIR/python_server.log"
PYTHON_PID_FILE="/tmp/python_server.pid"

# Create log directory if it doesn't exist
mkdir -p $LOG_DIR

start_python() {
    if [ -f "$PYTHON_PID_FILE" ]; then
        echo "Python server is already running."
        return
    fi
    echo "Starting Python server..."
    (cd Server/Python && python gesture_server.py > "$OLDPWD/$PYTHON_LOG" 2>&1 & echo $! > "$OLDPWD/$PYTHON_PID_FILE")
    echo "Python server started. Log: $PYTHON_LOG"
}

stop_python() {
    if [ ! -f "$PYTHON_PID_FILE" ]; then
        echo "Python server is not running."
        return
    fi
    echo "Stopping Python server..."
    kill $(cat "$PYTHON_PID_FILE")
    rm "$PYTHON_PID_FILE"
    echo "Python server stopped."
}

status() {
    echo "--- Server Status ---"
    if [ -f "$PYTHON_PID_FILE" ]; then
        echo "Python server is RUNNING (PID: $(cat $PYTHON_PID_FILE))"
    else
        echo "Python server is STOPPED"
    fi
    echo "---------------------"
}


usage() {
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
}

case "$1" in
    start)
        start_python
        ;;
    stop)
        stop_python
        ;;
    restart)
        stop_python
        sleep 2
        start_python
        ;;
    status)
        status
        ;;
    *)
        usage
        ;;
esac

exit 0
