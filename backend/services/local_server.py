#!/usr/bin/env python3

import os
import json
import logging
import ipaddress
import datetime
from pathlib import Path
from typing import Dict, Any, Optional, List, Union

import uvicorn
from fastapi import FastAPI, HTTPException, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

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

# Set up paths
REPO_ROOT = Path(__file__).parent.parent.parent
DATA_DIR = REPO_ROOT / "data"

# Create data directory if it doesn't exist
os.makedirs(DATA_DIR, exist_ok=True)

# Models
class HealthResponse(BaseModel):
    status: str = "ok"
    timestamp: str = Field(default_factory=lambda: datetime.datetime.now().isoformat())
    server_name: str = "Zestify Health AI Local Server"

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
async def health_check(local: bool = Depends(verify_local_network)):
    """Health check endpoint to verify the server is running."""
    return HealthResponse()

@app.get("/")
async def root(local: bool = Depends(verify_local_network)):
    """Root endpoint with server information."""
    return {
        "name": "Zestify Health AI Local Server",
        "version": "0.1.0",
        "status": "running",
        "timestamp": datetime.datetime.now().isoformat(),
        "endpoints": [
            {"path": "/health", "method": "GET", "description": "Health check endpoint"},
        ]
    }

def start_server(host: str = "0.0.0.0", port: int = 8000, log_level: str = "info"):
    """Start the FastAPI server."""
    logger.info(f"Starting server at http://{host}:{port}")
    
    # Get local IP for user to connect from iPhone
    import socket
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Doesn't need to be reachable
        s.connect(('10.255.255.255', 1))
        local_ip = s.getsockname()[0]
    except Exception:
        local_ip = '127.0.0.1'
    finally:
        s.close()
    
    logger.info(f"Connect from your iPhone using: http://{local_ip}:{port}")
    
    # Start server
    uvicorn.run(
        "backend.services.local_server:app",
        host=host,
        port=port,
        log_level=log_level,
        reload=True  # Enable auto-reload for development
    )

if __name__ == "__main__":
    start_server()
