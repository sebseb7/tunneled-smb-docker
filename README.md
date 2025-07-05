# Tunneled SMB Docker

A minimal Docker image that creates an SSH tunnel to a remote site and forwards SMB traffic through it, allowing Windows machines to connect to remote SMB shares via the tunnel.

## Features

- 🔧 **SSH Tunnel**: Establishes secure SSH tunnel to remote site
- 🗂️ **SMB Forwarding**: Tunnels SMB traffic through the SSH connection
- 🔌 **Privileged Port**: Shares connection on privileged port 445 for Windows compatibility
- 🔄 **Auto-Recovery**: Automatically restarts failed connections
- 📦 **Minimal**: Based on Alpine Linux for small image size

## Quick Start

### Prerequisites

- Docker installed (Docker Desktop for Windows recommended)
- SSH private key for accessing the remote server
- Remote server with SSH access and SMB shares

### Windows Setup Guide

#### 1. Create SSH Keys on Windows

**Option A: Using Built-in OpenSSH (Windows 10/11)**

Open PowerShell as Administrator and run:

```powershell
# Navigate to your project directory
cd C:\path\to\your\project

# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ssh-key

# When prompted:
# - Press Enter for no passphrase (easier for automation)
# - Or enter a secure passphrase (more secure)
```

**Option B: Using Ed25519 (Modern, Recommended)**

```powershell
ssh-keygen -t ed25519 -C "your_email@example.com" -f ssh-key
```

**Option C: Using Git Bash (if Git for Windows is installed)**

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ssh-key
```

This creates two files:
- `ssh-key` (private key - keep this secret!)
- `ssh-key.pub` (public key - copy this to your server)

#### 2. Copy Public Key to Your Server

Display the public key content:

```powershell
Get-Content ssh-key.pub
```

Copy the output and add it to your server's `~/.ssh/authorized_keys` file:

```bash
# On your server
echo "your-public-key-content-here" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

#### 3. Test SSH Connection

```powershell
ssh -i ssh-key your_username@your.server.com
```

#### 4. Configure Environment

```powershell
# Copy example environment file
copy .env.example .env

# Edit with your settings
notepad .env
```

Update the `.env` file with your server details:

```
SSH_HOST=your.server.com
SSH_USER=your_username
REMOTE_SMB_HOST=localhost
REMOTE_SMB_PORT=445
```

#### 5. Run with Docker Desktop

**Using Docker Compose (Recommended):**

```powershell
# Build and start the container
docker-compose up -d

# Check logs
docker-compose logs -f

# Stop the container
docker-compose down
```

**Using Docker Run:**

```powershell
docker run -d `
  --name smb-tunnel `
  -p 445:445 `
  -v "${PWD}/ssh-key:/home/tunneluser/.ssh/id_rsa:ro" `
  -e SSH_HOST=your.server.com `
  -e SSH_USER=your_username `
  -e REMOTE_SMB_HOST=localhost `
  tunneled-smb-docker:latest
```

#### 6. Connect from Windows

Once the container is running, you can connect to SMB shares:

**Using File Explorer:**
1. Open File Explorer
2. In the address bar, type: `\\localhost\share_name`
3. Enter your SMB credentials when prompted

**Using Command Prompt:**
```cmd
# Map network drive
net use Z: \\localhost\share_name /user:domain\username

# List mapped drives
net use

# Disconnect drive
net use Z: /delete
```

**Using PowerShell:**
```powershell
# Map network drive
New-PSDrive -Name "Z" -PSProvider FileSystem -Root "\\localhost\share_name" -Credential (Get-Credential)

# Access files
Get-ChildItem Z:\
```

### Windows-Specific Considerations

- **Port 445 Conflict**: Windows uses port 445 for its own SMB service. If you get a port conflict:
  - Use a different port: `-p 4445:445` and connect to `\\localhost:4445\share_name`
  - Or stop the Windows SMB service temporarily (not recommended)

- **Firewall**: Windows Defender Firewall may block connections. Add an exception for Docker Desktop or the specific port.

- **File Paths**: Use forward slashes in Docker volume mounts, even on Windows:
  ```powershell
  -v "C:/Users/username/ssh-key:/home/tunneluser/.ssh/id_rsa:ro"
  ```

### Basic Usage

```bash
# Pull the image
docker pull ghcr.io/sebseb7/tunneled-smb-docker:latest

# Run with required environment variables
docker run -d \
  --name smb-tunnel \
  -p 445:445 \
  -v /path/to/your/ssh/key:/home/tunneluser/.ssh/id_rsa:ro \
  -e SSH_HOST=your.remote.server.com \
  -e SSH_USER=your_username \
  -e REMOTE_SMB_HOST=target.smb.server \
  ghcr.io/sebseb7/tunneled-smb-docker:latest
```

### Using Docker Compose

Create a `docker-compose.yml` file:

```yaml
version: '3.8'

services:
  smb-tunnel:
    image: ghcr.io/sebseb7/tunneled-smb-docker:latest
    container_name: smb-tunnel
    ports:
      - "445:445"
    volumes:
      - ./ssh-key:/home/tunneluser/.ssh/id_rsa:ro
    environment:
      - SSH_HOST=your.remote.server.com
      - SSH_USER=your_username
      - REMOTE_SMB_HOST=target.smb.server
      - REMOTE_SMB_PORT=445
    restart: unless-stopped
```

Then run:
```bash
docker-compose up -d
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SSH_HOST` | *required* | SSH server hostname or IP |
| `SSH_USER` | *required* | SSH username |
| `SSH_PORT` | `22` | SSH server port |
| `SSH_KEY_PATH` | `/home/tunneluser/.ssh/id_rsa` | Path to SSH private key inside container |
| `REMOTE_SMB_HOST` | `localhost` | SMB server hostname (as seen from SSH server) |
| `REMOTE_SMB_PORT` | `445` | SMB server port |
| `LOCAL_SMB_PORT` | `445` | Local port to expose SMB on |
| `SSH_OPTIONS` | `-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60` | Additional SSH options |

## Windows Usage

After starting the container, you can connect from Windows using:

```cmd
# Map network drive
net use Z: \\DOCKER_HOST_IP\share_name /user:domain\username

# Or use File Explorer
\\DOCKER_HOST_IP\share_name
```

Where `DOCKER_HOST_IP` is the IP address of your Docker host.

## Examples

### Connect to SMB share on the same server as SSH
```bash
docker run -d \
  --name smb-tunnel \
  -p 445:445 \
  -v ~/.ssh/id_rsa:/home/tunneluser/.ssh/id_rsa:ro \
  -e SSH_HOST=myserver.com \
  -e SSH_USER=myuser \
  ghcr.io/sebseb7/tunneled-smb-docker:latest
```

### Connect to SMB share on different server via SSH tunnel
```bash
docker run -d \
  --name smb-tunnel \
  -p 445:445 \
  -v ~/.ssh/id_rsa:/home/tunneluser/.ssh/id_rsa:ro \
  -e SSH_HOST=jumphost.com \
  -e SSH_USER=jumpuser \
  -e REMOTE_SMB_HOST=fileserver.internal \
  -e REMOTE_SMB_PORT=445 \
  ghcr.io/sebseb7/tunneled-smb-docker:latest
```

### Custom SSH port and options
```bash
docker run -d \
  --name smb-tunnel \
  -p 445:445 \
  -v ~/.ssh/id_rsa:/home/tunneluser/.ssh/id_rsa:ro \
  -e SSH_HOST=myserver.com \
  -e SSH_PORT=2222 \
  -e SSH_USER=myuser \
  -e SSH_OPTIONS="-o StrictHostKeyChecking=yes -o ServerAliveInterval=30" \
  ghcr.io/sebseb7/tunneled-smb-docker:latest
```

## Building Locally

```bash
# Clone the repository
git clone https://github.com/sebseb7/tunneled-smb-docker.git
cd tunneled-smb-docker

# Build the image
docker build -t tunneled-smb-docker .

# Run locally
docker run -d \
  --name smb-tunnel \
  -p 445:445 \
  -v /path/to/ssh/key:/home/tunneluser/.ssh/id_rsa:ro \
  -e SSH_HOST=your.server.com \
  -e SSH_USER=your_username \
  tunneled-smb-docker
```

## Troubleshooting

### Check container logs
```bash
docker logs smb-tunnel
```

### Test SSH connection
```bash
# Test SSH connection manually
ssh -i /path/to/key your_username@your.server.com

# Test from within container
docker exec -it smb-tunnel su - tunneluser -c "ssh -i ~/.ssh/id_rsa your_username@your.server.com"
```

### Common Issues

1. **SSH key permissions**: Make sure your SSH key has correct permissions (600)
2. **SSH host key verification**: The container disables host key checking by default
3. **Port conflicts**: Make sure port 445 is not already in use on the host
4. **Firewall**: Ensure Docker host allows connections on port 445

### Windows-Specific Troubleshooting

#### Port 445 Already in Use
Windows runs its own SMB service on port 445. If you get this error:
```
Error starting userland proxy: listen tcp 0.0.0.0:445: bind: Only one usage of each socket address
```

**Solution 1: Use a different port**
```powershell
# Use port 4445 instead
docker run -d -p 4445:445 ...
# Connect using: \\localhost:4445\share_name
```

**Solution 2: Disable Windows SMB temporarily (Advanced)**
```powershell
# Stop SMB services (requires admin)
Stop-Service -Name "LanmanServer" -Force
Stop-Service -Name "LanmanWorkstation" -Force

# After testing, restart them
Start-Service -Name "LanmanWorkstation"
Start-Service -Name "LanmanServer"
```

#### Windows Firewall Blocking Connections
```powershell
# Allow Docker Desktop through firewall
New-NetFirewallRule -DisplayName "Docker SMB Tunnel" -Direction Inbound -Protocol TCP -LocalPort 445 -Action Allow

# Or allow specific application
New-NetFirewallRule -DisplayName "Docker Desktop" -Direction Inbound -Program "C:\Program Files\Docker\Docker\Docker Desktop.exe" -Action Allow
```

#### SSH Key File Permissions on Windows
```powershell
# Set correct permissions on SSH key
icacls ssh-key /inheritance:r /grant:r "%username%:R"
```

#### Docker Desktop Not Running
```powershell
# Check if Docker Desktop is running
docker version

# Start Docker Desktop if not running
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
```

#### Container Can't Connect to Host Network
If using `localhost` in your environment variables doesn't work:
```powershell
# Use host.docker.internal instead
-e REMOTE_SMB_HOST=host.docker.internal
```

#### Test SSH Connection from Windows
```powershell
# Test SSH connection before running container
ssh -i ssh-key -o StrictHostKeyChecking=no your_username@your.server.com "echo 'SSH connection successful'"
```

#### Check Container Logs
```powershell
# View container logs
docker logs smb-tunnel

# Follow logs in real-time
docker logs -f smb-tunnel
```

## Security Considerations

- The container runs SSH with `StrictHostKeyChecking=no` by default for convenience
- SSH private keys are mounted as read-only volumes
- Consider using SSH certificates or proper host key verification for production use
- Run the container with appropriate network isolation

## License

MIT License - see LICENSE file for details.