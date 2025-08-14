#!/bin/bash
#
# This script manages the deployment of the GestureControlPro servers.
# It can start, stop, and check the status of the Node.js and Python servers.

set -e

LOG_DIR="logs"
NODE_LOG="$LOG_DIR/node_server.log"
PYTHON_LOG="$LOG_DIR/python_server.log"
NODE_PID_FILE="/tmp/node_server.pid"
PYTHON_PID_FILE="/tmp/python_server.pid"

# Create log directory if it doesn't exist
mkdir -p $LOG_DIR

start_node() {
    if [ -f "$NODE_PID_FILE" ]; then
        echo "Node.js server is already running."
        return
    fi
    echo "Starting Node.js server..."
    (cd Server/Node.js && npm start > "$OLDPWD/$NODE_LOG" 2>&1 & echo $! > "$OLDPWD/$NODE_PID_FILE")
    echo "Node.js server started. Log: $NODE_LOG"
}

start_python() {
    if [ -f "$PYTHON_PID_FILE" ]; then
        echo "Python server is already running."
        return
    fi
    echo "Starting Python server..."
    (cd Server/Python && python gesture_server.py > "$OLDPWD/$PYTHON_LOG" 2>&1 & echo $! > "$OLDPWD/$PYTHON_PID_FILE")
    echo "Python server started. Log: $PYTHON_LOG"
}

stop_node() {
    if [ ! -f "$NODE_PID_FILE" ]; then
        echo "Node.js server is not running."
        return
    fi
    echo "Stopping Node.js server..."
    kill $(cat "$NODE_PID_FILE")
    rm "$NODE_PID_FILE"
    echo "Node.js server stopped."
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
    if [ -f "$NODE_PID_FILE" ]; then
        echo "Node.js server is RUNNING (PID: $(cat $NODE_PID_FILE))"
    else
        echo "Node.js server is STOPPED"
    fi
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
        start_node
        start_python
        ;;
    stop)
        stop_node
        stop_python
        ;;
    restart)
        stop_node
        stop_python
        sleep 2
        start_node
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
