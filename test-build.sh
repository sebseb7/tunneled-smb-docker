#!/bin/bash

echo "Building Docker image..."
docker build -t tunneled-smb-docker:test .

if [ $? -eq 0 ]; then
    echo "✅ Docker image built successfully"
    
    echo "Testing image help output..."
    docker run --rm tunneled-smb-docker:test 2>&1 | head -10
    
    echo "Cleaning up test image..."
    docker rmi tunneled-smb-docker:test
    
    echo "✅ Build test completed successfully"
else
    echo "❌ Docker build failed"
    exit 1
fi 