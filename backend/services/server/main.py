#!/usr/bin/env python3
"""
Main entry point for the Zestify Health AI Server.
"""

import os
import json
import logging
import ipaddress
import datetime
import socket
from pathlib import Path
from typing import Dict, Any, Optional, List

import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from pydantic import BaseModel, Field

# Import handlers
try:
    # Try relative import first (for package usage)
    from .handlers import (
        user_router,
        biometrics_router,
        workout_router,
        activity_router,
        sleep_router,
        nutrition_router
    )
except ImportError:
    # Fall back to absolute import (for direct script usage)
    from handlers import (
        user_router,
        biometrics_router,
        workout_router,
        activity_router,
        sleep_router,
        nutrition_router
    )

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global variables for request logging
REQUEST_LOG_FILE = "request_log.jsonl"
LOG_REQUESTS = False

# Create FastAPI app
app = FastAPI(
    title="Zestify Health AI Local Server",
    description="Local server for Zestify Health AI app",
    version="0.1.0"
)

# Add CORS middleware to allow requests from the app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For development only
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request logging middleware
class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Middleware to log all requests to a file for replay"""

    async def dispatch(self, request: Request, call_next):
        # Only log if enabled
        if not LOG_REQUESTS:
            return await call_next(request)

        # Get request details
        timestamp = datetime.datetime.now().isoformat()
        method = request.method
        url = str(request.url)
        path = request.url.path

        # Get request body
        body = None
        if method in ["POST", "PUT", "PATCH"]:
            # Save the request body
            body_bytes = await request.body()
            if body_bytes:
                try:
                    # Try to parse as JSON
                    body = json.loads(body_bytes)
                except json.JSONDecodeError:
                    # If not JSON, store as string
                    body = body_bytes.decode()

        # Get query parameters
        query_params = {}
        for key, value in request.query_params.items():
            query_params[key] = value

        # Create log entry
        log_entry = {
            "timestamp": timestamp,
            "method": method,
            "url": url,
            "path": path,
            "query_params": query_params,
            "body": body
        }

        # Write to log file
        with open(REQUEST_LOG_FILE, "a") as f:
            f.write(json.dumps(log_entry) + "\n")

        # Continue processing the request
        response = await call_next(request)
        return response

# Set up paths
REPO_ROOT = Path(__file__).parent.parent.parent.parent
DATA_DIR = REPO_ROOT / "data"

# Memory adapters are now handled in the handler modules

# Create data directory if it doesn't exist
os.makedirs(DATA_DIR, exist_ok=True)

# Models
class HealthResponse(BaseModel):
    status: str = "ok"
    timestamp: str = Field(default_factory=lambda: datetime.datetime.now().isoformat())
    server_name: str = "Zestify Health AI Local Server"

class UserCreateResponse(BaseModel):
    user_id: str
    created_at: str

class BiometricsData(BaseModel):
    heart_rate: Optional[Dict[str, Any]] = None
    sleep: Optional[Dict[str, Any]] = None
    activity: Optional[Dict[str, Any]] = None
    body_composition: Optional[Dict[str, Any]] = None
    blood_pressure: Optional[Dict[str, Any]] = None
    blood_glucose: Optional[Dict[str, Any]] = None
    oxygen_saturation: Optional[Dict[str, Any]] = None

class BiometricsUploadResponse(BaseModel):
    status: str
    message: str
    user_id: str
    timestamp: str
    metrics_received: List[str]

# Dependency to check if request is from local network
async def verify_local_network(request: Request):
    client_host = request.client.host if request.client else None

    # Always allow localhost
    if client_host in ["127.0.0.1", "::1", "localhost"]:
        return True

    # Check if IP is in private network ranges
    try:
        ip = ipaddress.ip_address(client_host)
        if ip.is_private:
            return True
        else:
            logger.warning(f"Rejected connection from non-local IP: {client_host}")
            raise HTTPException(status_code=403, detail="Access denied: Server only accessible from local network")
    except ValueError:
        logger.error(f"Invalid IP address: {client_host}")
        raise HTTPException(status_code=400, detail="Invalid IP address")

# Routes
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint to verify the server is running."""
    return HealthResponse()

@app.get("/")
async def root():
    """Root endpoint with server information."""
    return {
        "name": "Zestify Health AI Server",
        "version": "0.1.0",
        "status": "running",
        "timestamp": datetime.datetime.now().isoformat(),
        "endpoints": [
            {"path": "/health", "method": "GET", "description": "Health check endpoint"},
            {"path": "/users", "method": "POST", "description": "Create a new user"},
            {"path": "/biometrics", "method": "POST", "description": "Upload biometrics data"},
            {"path": "/workouts", "method": "POST", "description": "Upload a single workout"},
            {"path": "/workouts/batch", "method": "POST", "description": "Upload multiple workouts"},
            {"path": "/activities", "method": "POST", "description": "Upload daily activity data"},
            {"path": "/sleep", "method": "POST", "description": "Upload sleep data"},
            {"path": "/nutrition", "method": "POST", "description": "Upload nutrition data"},
        ]
    }

# Include routers
app.include_router(user_router)
app.include_router(biometrics_router)
app.include_router(workout_router)
app.include_router(activity_router)
app.include_router(sleep_router)
app.include_router(nutrition_router)







def get_local_ip():
    """Get the local IP address."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Doesn't need to be reachable
        s.connect(('10.255.255.255', 1))
        local_ip = s.getsockname()[0]
    except Exception:
        local_ip = '127.0.0.1'
    finally:
        s.close()
    return local_ip

def start_server(host: str = "0.0.0.0", port: int = 8000, log_level: str = "info", log_requests: bool = False, log_file: str = "request_log.jsonl"):
    """Start the FastAPI server."""
    global LOG_REQUESTS, REQUEST_LOG_FILE

    # Set request logging options
    LOG_REQUESTS = log_requests
    REQUEST_LOG_FILE = log_file

    # Add request logging middleware if enabled
    if LOG_REQUESTS:
        # Create directory for log file if it doesn't exist
        log_dir = os.path.dirname(REQUEST_LOG_FILE)
        if log_dir and not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)

        # Create empty log file
        open(REQUEST_LOG_FILE, "w").close()

        # Add middleware
        app.add_middleware(RequestLoggingMiddleware)
        logger.info(f"Request logging enabled. Logging to {REQUEST_LOG_FILE}")

    logger.info(f"Starting server at http://{host}:{port}")

    # Get local IP for user to connect from iPhone
    local_ip = get_local_ip()
    logger.info(f"Connect from your iPhone using: http://{local_ip}:{port}")

    # Start server
    # Get the app directly
    uvicorn.run(
        app,
        host=host,
        port=port,
        log_level=log_level,
        reload=False  # Disable auto-reload when running directly
    )



if __name__ == "__main__":
    start_server()
