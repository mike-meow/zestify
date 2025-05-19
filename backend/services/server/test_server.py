import pytest
from fastapi.testclient import TestClient
from datetime import datetime
import ipaddress

from .main import app, verify_local_network, HealthResponse
from fastapi import Request, HTTPException

# Create test client
client = TestClient(app)

def test_health_check():
    """Test the health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["server_name"] == "Zestify Health AI Local Server"
    assert "timestamp" in data
    # Verify timestamp is in ISO format
    datetime.fromisoformat(data["timestamp"])

def test_root():
    """Test the root endpoint."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Zestify Health AI Server"
    assert data["version"] == "0.1.0"
    assert data["status"] == "running"
    assert "timestamp" in data
    # Verify timestamp is in ISO format
    datetime.fromisoformat(data["timestamp"])
    
    # Check endpoints list
    assert "endpoints" in data
    endpoints = data["endpoints"]
    assert len(endpoints) == 8  # Verify all endpoints are listed
    
    # Check specific endpoints exist
    endpoint_paths = [e["path"] for e in endpoints]
    assert "/health" in endpoint_paths
    assert "/users" in endpoint_paths
    assert "/biometrics" in endpoint_paths
    assert "/workouts" in endpoint_paths
    assert "/workouts/batch" in endpoint_paths
    assert "/activities" in endpoint_paths
    assert "/sleep" in endpoint_paths
    assert "/nutrition" in endpoint_paths

@pytest.mark.asyncio
async def test_verify_local_network():
    """Test the local network verification dependency."""
    
    # Test localhost
    mock_request = Request({"type": "http", "client": ("127.0.0.1", 1234)})
    result = await verify_local_network(mock_request)
    assert result is True
    
    # Test local IPv6
    mock_request = Request({"type": "http", "client": ("::1", 1234)})
    result = await verify_local_network(mock_request)
    assert result is True
    
    # Test private network IP
    mock_request = Request({"type": "http", "client": ("192.168.1.100", 1234)})
    result = await verify_local_network(mock_request)
    assert result is True
    
    # Test public IP (should raise HTTPException)
    mock_request = Request({"type": "http", "client": ("8.8.8.8", 1234)})
    with pytest.raises(HTTPException) as exc_info:
        await verify_local_network(mock_request)
    assert exc_info.value.status_code == 403
    assert "Access denied" in exc_info.value.detail
    
    # Test invalid IP
    mock_request = Request({"type": "http", "client": ("invalid-ip", 1234)})
    with pytest.raises(HTTPException) as exc_info:
        await verify_local_network(mock_request)
    assert exc_info.value.status_code == 400
    assert "Invalid IP address" in exc_info.value.detail

def test_cors_headers():
    """Test that CORS headers are properly set."""
    response = client.get(
        "/health", 
        headers={"Origin": "http://localhost:3000"}
    )
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "*"
    assert response.headers["access-control-allow-credentials"] == "true"
    
    # Test preflight request
    response = client.options(
        "/health",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "Content-Type"
        }
    )
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "*"
    assert response.headers["access-control-allow-credentials"] == "true"
    assert "GET" in response.headers["access-control-allow-methods"]
    assert "Content-Type" in response.headers["access-control-allow-headers"]