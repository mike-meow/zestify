# Request Logging and Replay

This document explains how to use the request logging and replay features of the Zestify Health AI server.

## Request Logging

The server can log all incoming requests to a file for later replay. This is useful for testing and development without needing to redeploy the client.

### Enabling Request Logging

To enable request logging, start the server with the `--log-requests` flag:

```bash
zestify server --log-requests
```

By default, requests will be logged to `request_log.jsonl` in the current directory. You can specify a different log file with the `--log-file` option:

```bash
zestify server --log-requests --log-file logs/my_requests.jsonl
```

### Log File Format

Each request is logged as a single JSON object per line (JSONL format). Each log entry contains:

- `timestamp`: The time the request was received
- `method`: The HTTP method (GET, POST, etc.)
- `url`: The full URL of the request
- `path`: The path component of the URL
- `query_params`: Any query parameters as a dictionary
- `body`: The request body (for POST, PUT, PATCH requests)

Example log entry:

```json
{"timestamp": "2023-04-15T12:34:56.789012", "method": "POST", "url": "http://localhost:8000/users/123/health-data", "path": "/users/123/health-data", "query_params": {}, "body": {"metrics": {"WEIGHT": {"value": "70.5", "unit": "KILOGRAM", "date": "2023-04-15T12:00:00.000", "source": "Apple Health"}}}}
```

## Replaying Requests

The `zestify replay-requests` command can be used to replay requests from a log file.

### Usage

```bash
zestify replay-requests [LOG_FILE] [options]
```

Options:
- `--base-url`: The base URL of the server (default: http://localhost:8000)
- `--delay`: Delay between requests in seconds (default: 0.0)

Example:

```bash
zestify replay-requests request_log.jsonl --base-url http://192.168.1.100:8000 --delay 0.5
```

### Example Workflow

1. Start the server with request logging enabled:
   ```bash
   zestify server --log-requests
   ```

2. Use the client app to interact with the server. All requests will be logged.

3. Stop the server when you're done collecting requests.

4. Make changes to the server code as needed.

5. Start the server again (without logging):
   ```bash
   zestify server
   ```

6. Replay the logged requests:
   ```bash
   zestify replay-requests request_log.jsonl
   ```

This allows you to test server changes without needing to redeploy the client app.
