#!/bin/bash
echo "Testing GemiServer.app bundle..."
echo "================================"

# Launch the server
./dist/GemiServer.app/Contents/MacOS/GemiServer &
SERVER_PID=$!

# Wait for server to start
echo "Waiting for server to start..."
sleep 10

# Test health endpoint
echo "Testing health endpoint..."
curl -s http://127.0.0.1:11435/api/health | jq . || echo "Health check failed"

# Kill the server
echo "Stopping server..."
kill $SERVER_PID 2>/dev/null

echo "Test complete!"
