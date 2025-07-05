#!/bin/bash

# Configuration via environment variables
SSH_HOST=${SSH_HOST:-""}
SSH_PORT=${SSH_PORT:-22}
SSH_USER=${SSH_USER:-""}
SSH_KEY_PATH=${SSH_KEY_PATH:-"/home/tunneluser/.ssh/id_rsa"}
REMOTE_SMB_HOST=${REMOTE_SMB_HOST:-"localhost"}
REMOTE_SMB_PORT=${REMOTE_SMB_PORT:-445}
LOCAL_SMB_PORT=${LOCAL_SMB_PORT:-445}
SSH_OPTIONS=${SSH_OPTIONS:-"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60"}

# Validation
if [ -z "$SSH_HOST" ] || [ -z "$SSH_USER" ]; then
    echo "ERROR: SSH_HOST and SSH_USER environment variables are required"
    echo "Usage:"
    echo "  SSH_HOST=your.ssh.host"
    echo "  SSH_USER=your_username"
    echo "  SSH_KEY_PATH=/path/to/private/key (optional, defaults to /home/tunneluser/.ssh/id_rsa)"
    echo "  REMOTE_SMB_HOST=target.smb.host (optional, defaults to localhost)"
    echo "  REMOTE_SMB_PORT=445 (optional)"
    echo "  LOCAL_SMB_PORT=445 (optional)"
    exit 1
fi

# Check if SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "ERROR: SSH key not found at $SSH_KEY_PATH"
    echo "Please mount your SSH private key to $SSH_KEY_PATH"
    exit 1
fi

# Set correct permissions for SSH key
chmod 600 "$SSH_KEY_PATH"
chown tunneluser:tunneluser "$SSH_KEY_PATH"

echo "Starting SSH tunnel..."
echo "SSH Host: $SSH_HOST:$SSH_PORT"
echo "SSH User: $SSH_USER"
echo "Remote SMB: $REMOTE_SMB_HOST:$REMOTE_SMB_PORT"
echo "Local SMB Port: $LOCAL_SMB_PORT"

# Function to cleanup on exit
cleanup() {
    echo "Shutting down..."
    pkill -f "ssh.*$SSH_HOST"
    pkill -f "socat.*$LOCAL_SMB_PORT"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Start SSH tunnel in the background
# Forward local port to remote SMB through SSH tunnel
su - tunneluser -c "ssh $SSH_OPTIONS -i $SSH_KEY_PATH -L 0.0.0.0:8445:$REMOTE_SMB_HOST:$REMOTE_SMB_PORT -N $SSH_USER@$SSH_HOST -p $SSH_PORT" &
SSH_PID=$!

# Wait for SSH tunnel to establish
echo "Waiting for SSH tunnel to establish..."
sleep 5

# Check if SSH tunnel is running
if ! kill -0 $SSH_PID 2>/dev/null; then
    echo "ERROR: SSH tunnel failed to start"
    exit 1
fi

echo "SSH tunnel established successfully"

# Start socat to forward privileged port 445 to the tunneled connection
echo "Starting SMB port forwarding on port $LOCAL_SMB_PORT..."
socat TCP-LISTEN:$LOCAL_SMB_PORT,fork,reuseaddr TCP:localhost:8445 &
SOCAT_PID=$!

# Wait for socat to start
sleep 2

# Check if socat is running
if ! kill -0 $SOCAT_PID 2>/dev/null; then
    echo "ERROR: SMB port forwarding failed to start"
    kill $SSH_PID 2>/dev/null
    exit 1
fi

echo "SMB forwarding active on port $LOCAL_SMB_PORT"
echo "You can now connect to this container's IP on port $LOCAL_SMB_PORT"

# Keep the container running and monitor processes
while true; do
    # Check if SSH tunnel is still running
    if ! kill -0 $SSH_PID 2>/dev/null; then
        echo "ERROR: SSH tunnel died, restarting..."
        su - tunneluser -c "ssh $SSH_OPTIONS -i $SSH_KEY_PATH -L 0.0.0.0:8445:$REMOTE_SMB_HOST:$REMOTE_SMB_PORT -N $SSH_USER@$SSH_HOST -p $SSH_PORT" &
        SSH_PID=$!
        sleep 5
    fi
    
    # Check if socat is still running
    if ! kill -0 $SOCAT_PID 2>/dev/null; then
        echo "ERROR: SMB forwarding died, restarting..."
        socat TCP-LISTEN:$LOCAL_SMB_PORT,fork,reuseaddr TCP:localhost:8445 &
        SOCAT_PID=$!
        sleep 2
    fi
    
    sleep 30
done 