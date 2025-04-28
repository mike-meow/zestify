# Zestify Health AI Local Server

This is a minimal local server for the Zestify Health AI app. It allows your iPhone app to connect to your laptop over your local WiFi network.

## Features

- Simple FastAPI server that runs on your laptop
- Health check endpoint to verify connectivity
- Local network access only (security feature)
- Automatic IP detection for easy connection

## Getting Started

### Prerequisites

Make sure you have the required dependencies installed:

```bash
uv pip install fastapi uvicorn
```

### Running the Server

Start the server using the Zestify CLI:

```bash
zestify server
```

This will start the server on all network interfaces (0.0.0.0) on port 8000.

### Options

You can customize the server with these options:

```bash
# Change the port
zestify server --port 9000

# Change the host
zestify server --host 127.0.0.1

# Change the log level
zestify server --log-level debug
```

### Connecting from Your iPhone

When the server starts, it will display your local IP address. Use this address in your iPhone app to connect to the server:

```
Starting Zestify Health AI server at http://0.0.0.0:8000
Connect from your iPhone using: http://192.168.1.100:8000
```

## API Endpoints

### Health Check

```
GET /health
```

Returns a simple health check response to verify the server is running.

Example response:
```json
{
  "status": "ok",
  "timestamp": "2023-04-10T21:30:00Z",
  "server_name": "Zestify Health AI Local Server"
}
```

## Security

This server is designed to only accept connections from your local network. Connections from external IP addresses will be rejected with a 403 Forbidden error.

## Troubleshooting

If you can't connect from your iPhone:

1. Make sure your iPhone is on the same WiFi network as your laptop
2. Check if any firewall is blocking the connection
3. Try using a different port with `--port`
4. Verify the server is running with `curl http://localhost:8000/health`
