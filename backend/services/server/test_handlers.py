import pytest
from fastapi.testclient import TestClient
from datetime import datetime, timedelta
import json
import shutil
from pathlib import Path
import os

from .main import app
from .handlers.base_handler import BaseHandler

# Create test client
client = TestClient(app)

# Test data directory
TEST_DATA_DIR = Path("test_data")

@pytest.fixture(autouse=True)
def setup_teardown():
    """Setup and teardown for tests."""
    # Setup: Create test data directory
    TEST_DATA_DIR.mkdir(exist_ok=True)
    
    # Set the data directory for BaseHandler
    BaseHandler.DATA_DIR = TEST_DATA_DIR
    
    yield
    
    # Teardown: Remove test data directory
    shutil.rmtree(TEST_DATA_DIR)

# ==================== User Handler Tests ====================

def test_create_user_success():
    """Test successful user creation."""
    user_data = {
        "user_id": "test_user_1",
        "name": "Test User",
        "email": "test@example.com"
    }
    
    response = client.post("/users", json=user_data)
    assert response.status_code == 200
    
    data = response.json()
    assert data["status"] == "success"
    assert data["message"] == "User created successfully"
    assert data["user_id"] == user_data["user_id"]
    assert "created_at" in data
    
    # Verify user directory and profile were created
    user_dir = TEST_DATA_DIR / user_data["user_id"]
    assert user_dir.exists()
    
    profile_file = user_dir / "profile.json"
    assert profile_file.exists()
    
    with open(profile_file) as f:
        profile = json.load(f)
        assert profile["user_id"] == user_data["user_id"]
        assert profile["name"] == user_data["name"]
        assert profile["email"] == user_data["email"]

def test_create_user_minimal():
    """Test user creation with minimal data."""
    user_data = {
        "user_id": "test_user_2"
    }
    
    response = client.post("/users", json=user_data)
    assert response.status_code == 200
    
    data = response.json()
    assert data["user_id"] == user_data["user_id"]
    
    # Verify profile has empty strings for optional fields
    profile_file = TEST_DATA_DIR / user_data["user_id"] / "profile.json"
    with open(profile_file) as f:
        profile = json.load(f)
        assert profile["name"] == ""
        assert profile["email"] == ""

def test_create_user_duplicate():
    """Test creating a user that already exists."""
    user_data = {
        "user_id": "test_user_3",
        "name": "Original Name"
    }
    
    # Create user first time
    response = client.post("/users", json=user_data)
    assert response.status_code == 200
    
    # Try to create same user with different name
    user_data["name"] = "New Name"
    response = client.post("/users", json=user_data)
    assert response.status_code == 200  # Should succeed but update profile
    
    # Verify profile was updated
    profile_file = TEST_DATA_DIR / user_data["user_id"] / "profile.json"
    with open(profile_file) as f:
        profile = json.load(f)
        assert profile["name"] == "New Name"

# ==================== Biometrics Handler Tests ====================

def test_upload_biometrics_new_user():
    """Test uploading biometrics for a new user."""
    user_id = "test_bio_user_1"
    
    # Create test biometrics data
    biometrics_data = {
        "user_id": user_id,
        "data": {
            "body_composition": {
                "weight_readings": [
                    {
                        "value": 70.5,
                        "unit": "kg",
                        "date": datetime.now().isoformat(),
                        "source": "test"
                    }
                ],
                "bmi_readings": [
                    {
                        "value": 22.1,
                        "unit": "kg/m2",
                        "date": datetime.now().isoformat(),
                        "source": "test"
                    }
                ]
            },
            "resting_heart_rate_readings": [
                {
                    "value": 65,
                    "unit": "bpm",
                    "date": datetime.now().isoformat(),
                    "source": "test"
                }
            ]
        }
    }
    
    response = client.post("/biometrics", json=biometrics_data)
    assert response.status_code == 200
    
    data = response.json()
    assert data["status"] == "success"
    assert data["user_id"] == user_id
    assert set(data["metrics_received"]) == {"body.weight", "body.bmi", "vitals.rhr"}
    
    # Verify biometrics file was created
    biometrics_file = TEST_DATA_DIR / user_id / "biometrics.json"
    assert biometrics_file.exists()
    
    with open(biometrics_file) as f:
        saved_data = json.load(f)
        assert len(saved_data["body_composition"]["weight_readings"]) == 1
        assert len(saved_data["body_composition"]["bmi_readings"]) == 1
        assert len(saved_data["resting_heart_rate_readings"]) == 1

def test_upload_biometrics_merge():
    """Test merging new biometrics with existing data."""
    user_id = "test_bio_user_2"
    
    # Create initial biometrics
    initial_time = datetime.now() - timedelta(days=1)
    initial_data = {
        "user_id": user_id,
        "data": {
            "body_composition": {
                "weight_readings": [
                    {
                        "value": 70.5,
                        "unit": "kg",
                        "date": initial_time.isoformat(),
                        "source": "test"
                    }
                ]
            }
        }
    }
    
    response = client.post("/biometrics", json=initial_data)
    assert response.status_code == 200
    
    # Upload new biometrics
    new_time = datetime.now()
    new_data = {
        "user_id": user_id,
        "data": {
            "body_composition": {
                "weight_readings": [
                    {
                        "value": 70.0,
                        "unit": "kg",
                        "date": new_time.isoformat(),
                        "source": "test"
                    }
                ]
            }
        }
    }
    
    response = client.post("/biometrics", json=new_data)
    assert response.status_code == 200
    
    # Verify data was merged
    biometrics_file = TEST_DATA_DIR / user_id / "biometrics.json"
    with open(biometrics_file) as f:
        saved_data = json.load(f)
        weight_readings = saved_data["body_composition"]["weight_readings"]
        assert len(weight_readings) == 2
        # Verify readings are sorted by date (newest first)
        assert weight_readings[0]["date"] == new_time.isoformat()
        assert weight_readings[1]["date"] == initial_time.isoformat()

def test_upload_biometrics_duplicate_timestamps():
    """Test handling of duplicate timestamps in biometrics data."""
    user_id = "test_bio_user_3"
    timestamp = datetime.now().isoformat()
    
    # Upload initial data
    initial_data = {
        "user_id": user_id,
        "data": {
            "resting_heart_rate_readings": [
                {
                    "value": 65,
                    "unit": "bpm",
                    "date": timestamp,
                    "source": "test"
                }
            ]
        }
    }
    
    response = client.post("/biometrics", json=initial_data)
    assert response.status_code == 200
    
    # Upload data with same timestamp but different value
    new_data = {
        "user_id": user_id,
        "data": {
            "resting_heart_rate_readings": [
                {
                    "value": 70,
                    "unit": "bpm",
                    "date": timestamp,
                    "source": "test"
                }
            ]
        }
    }
    
    response = client.post("/biometrics", json=new_data)
    assert response.status_code == 200
    
    # Verify only the latest value was kept
    biometrics_file = TEST_DATA_DIR / user_id / "biometrics.json"
    with open(biometrics_file) as f:
        saved_data = json.load(f)
        readings = saved_data["resting_heart_rate_readings"]
        assert len(readings) == 1
        assert readings[0]["value"] == 70  # Latest value should be kept

def test_upload_biometrics_invalid_user():
    """Test uploading biometrics with invalid user format."""
    data = {
        "user_id": "",  # Invalid empty user ID
        "data": {
            "resting_heart_rate_readings": [
                {
                    "value": 65,
                    "unit": "bpm",
                    "date": datetime.now().isoformat(),
                    "source": "test"
                }
            ]
        }
    }
    
    response = client.post("/biometrics", json=data)
    assert response.status_code == 422  # Validation error