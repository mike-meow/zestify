# Zestify Health AI Local Server

This is a minimal local server for the Zestify Health AI app. It allows your iPhone app to connect to your laptop over your local WiFi network.

## Features

- Simple FastAPI server that runs on your laptop
- Health check endpoint to verify connectivity
- User creation endpoint
- Health data upload endpoint
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

### Create User

```
POST /users
```

Creates a new user and returns a user ID.

Example response:
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "created_at": "2023-04-10T21:30:00Z"
}
```

### Upload Health Data

```
POST /users/{user_id}/health-data
```

Uploads health data for a user. The request body should contain the health data from Apple HealthKit.

Example response:
```json
{
  "status": "success",
  "message": "Health data received and saved",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2023-04-10T21:30:00Z"
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

## Testing with curl

You can test the server using curl commands:

```bash
# Health check
curl http://localhost:8000/health

# Create a user
curl -X POST http://localhost:8000/users

# Upload health data (example)
curl -X POST http://localhost:8000/users/550e8400-e29b-41d4-a716-446655440000/health-data \
  -H "Content-Type: application/json" \
  -d '{"workouts": [{"type": "running", "date": "2023-04-10", "duration": 1800}]}'
```

## Next Steps

According to the todo.md file, the next steps are:

1. Look at all data types in the app and refine our memory if necessary
2. Process the health data from Apple HealthKit and update the memory files
3. Save the processed data to disk on the server
