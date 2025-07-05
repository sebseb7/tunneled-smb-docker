# Windows Setup Script for Tunneled SMB Docker
# Run this script in PowerShell as Administrator

Write-Host "🚀 Setting up Tunneled SMB Docker for Windows..." -ForegroundColor Cyan

# Check if Docker is installed
try {
    $dockerVersion = docker --version
    Write-Host "✅ Docker found: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker not found. Please install Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Check if SSH is available
try {
    ssh -V
    Write-Host "✅ SSH client available" -ForegroundColor Green
} catch {
    Write-Host "❌ SSH not found. Please enable OpenSSH client in Windows Features." -ForegroundColor Red
    exit 1
}

# Generate SSH key if it doesn't exist
if (-not (Test-Path "ssh-key")) {
    Write-Host "🔑 Creating SSH key..." -ForegroundColor Yellow
    $email = Read-Host "Enter your email address"
    ssh-keygen -t ed25519 -C "$email" -f ssh-key
    Write-Host "✅ SSH key created successfully" -ForegroundColor Green
} else {
    Write-Host "✅ SSH key already exists" -ForegroundColor Green
}

# Display public key
Write-Host "📋 Your public key (copy this to your server):" -ForegroundColor Yellow
Get-Content ssh-key.pub
Write-Host ""

# Create environment file
if (-not (Test-Path ".env")) {
    Write-Host "⚙️  Creating environment file..." -ForegroundColor Yellow
    Copy-Item .env.example .env
    Write-Host "✅ Environment file created. Please edit .env with your settings." -ForegroundColor Green
} else {
    Write-Host "✅ Environment file already exists" -ForegroundColor Green
}

# Check for port conflicts
$port445InUse = Get-NetTCPConnection -LocalPort 445 -ErrorAction SilentlyContinue
if ($port445InUse) {
    Write-Host "⚠️  Port 445 is already in use by Windows SMB service." -ForegroundColor Yellow
    Write-Host "   Consider using a different port (e.g., 4445) in docker-compose.yml" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 Setup complete! Next steps:" -ForegroundColor Green
Write-Host "1. Copy the public key above to your server's ~/.ssh/authorized_keys file"
Write-Host "2. Edit .env file with your server details"
Write-Host "3. Test SSH connection: ssh -i ssh-key your_username@your_server"
Write-Host "4. Run: docker-compose up -d"
Write-Host "" 