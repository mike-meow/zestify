#!/usr/bin/env python3
"""
Script to replay API requests and verify data files match templates.
"""

import os
import json
import requests
import argparse
from pathlib import Path
from datetime import datetime, timedelta

# Default server URL
DEFAULT_SERVER_URL = "http://localhost:8009"

# User ID to use for testing
USER_ID = "0e9efacd-717f-4342-b20a-60f8f92fadba"

# Sample data for testing
SAMPLE_BIOMETRICS = {
    "user_id": USER_ID,
    "body_composition": {
        "weight": {
            "value": 75.5,
            "unit": "kg",
            "timestamp": datetime.now().isoformat(),
            "source": "Apple Health"
        },
        "bmi": {
            "value": 24.2,
            "unit": "kg/m²",
            "timestamp": datetime.now().isoformat(),
            "source": "Apple Health"
        },
        "body_fat_percentage": {
            "value": 18.5,
            "unit": "%",
            "timestamp": datetime.now().isoformat(),
            "source": "Apple Health"
        }
    },
    "vital_signs": {
        "resting_heart_rate": {
            "value": 65,
            "unit": "bpm",
            "timestamp": datetime.now().isoformat(),
            "source": "Apple Health"
        },
        "blood_pressure_systolic": {
            "value": 120,
            "unit": "mmHg",
            "timestamp": datetime.now().isoformat(),
            "source": "Apple Health"
        },
        "blood_pressure_diastolic": {
            "value": 80,
            "unit": "mmHg",
            "timestamp": datetime.now().isoformat(),
            "source": "Apple Health"
        }
    }
}

SAMPLE_WORKOUT = {
    "user_id": USER_ID,
    "workouts": [
        {
            "id": "workout-123",
            "workout_type": "Running",
            "start_date": (datetime.now() - timedelta(days=1)).isoformat(),
            "end_date": (datetime.now() - timedelta(days=1) + timedelta(hours=1)).isoformat(),
            "duration_seconds": 3600,
            "active_energy_burned": 450,
            "active_energy_burned_unit": "kcal",
            "distance": 8.0,
            "distance_unit": "km",
            "source": "Apple Health"
        }
    ]
}

SAMPLE_ACTIVITY = {
    "user_id": USER_ID,
    "activities": [
        {
            "date": datetime.now().date().isoformat(),
            "steps": 10000,
            "distance": 7.5,
            "distance_unit": "km",
            "floors_climbed": 15,
            "active_energy_burned": 350,
            "active_energy_burned_unit": "kcal",
            "exercise_minutes": 45,
            "source": "Apple Health"
        }
    ]
}

def replay_biometrics(server_url):
    """Replay biometrics API request."""
    print("Replaying biometrics API request...")
    response = requests.post(
        f"{server_url}/biometrics",
        json=SAMPLE_BIOMETRICS
    )
    print(f"Status code: {response.status_code}")
    print(f"Response: {response.json()}")
    return response.status_code == 200

def replay_workouts(server_url):
    """Replay workouts API request."""
    print("Replaying workouts API request...")
    response = requests.post(
        f"{server_url}/workouts/batch",
        json=SAMPLE_WORKOUT
    )
    print(f"Status code: {response.status_code}")
    print(f"Response: {response.json()}")
    return response.status_code == 200

def replay_activities(server_url):
    """Replay activities API request."""
    print("Replaying activities API request...")
    response = requests.post(
        f"{server_url}/activities",
        json=SAMPLE_ACTIVITY
    )
    print(f"Status code: {response.status_code}")
    print(f"Response: {response.json()}")
    return response.status_code == 200

def check_data_files():
    """Check data files to ensure they match templates."""
    print("\nChecking data files...")
    data_dir = Path("data") / USER_ID
    
    # List all files in the data directory
    files = list(data_dir.glob("*.json"))
    print(f"Found {len(files)} files in {data_dir}:")
    for file in files:
        print(f"  - {file.name}")
    
    # Expected files based on templates
    expected_files = [
        "biometrics.json",
        "workout_memory.json",
        "workouts.json",
        "activities.json",
        "user_info.json"
    ]
    
    # Check if all expected files exist
    missing_files = [f for f in expected_files if not (data_dir / f).exists()]
    if missing_files:
        print(f"Missing expected files: {missing_files}")
    
    # Check for unexpected files
    unexpected_files = [f.name for f in files if f.name not in expected_files]
    if unexpected_files:
        print(f"Unexpected files found: {unexpected_files}")
        print("These files should be removed as they don't match any template.")
    
    # Check biometrics.json structure
    biometrics_file = data_dir / "biometrics.json"
    if biometrics_file.exists():
        with open(biometrics_file, 'r') as f:
            biometrics_data = json.load(f)
        
        # Check if it has the expected structure
        if "body_composition" in biometrics_data and "vital_signs" in biometrics_data:
            print("biometrics.json has the correct structure.")
        else:
            print("biometrics.json does not have the expected structure.")
            print(f"Keys found: {list(biometrics_data.keys())}")
    
    return not missing_files and not unexpected_files

def main():
    """Main function to replay API requests and check data files."""
    parser = argparse.ArgumentParser(description="Replay API requests and verify data files.")
    parser.add_argument("--server", default=DEFAULT_SERVER_URL, help="Server URL")
    args = parser.parse_args()
    
    # Replay API requests
    success = True
    success = success and replay_biometrics(args.server)
    success = success and replay_workouts(args.server)
    success = success and replay_activities(args.server)
    
    # Check data files
    files_ok = check_data_files()
    
    if success and files_ok:
        print("\nAll API requests succeeded and data files match templates.")
    else:
        print("\nSome issues were found. Please check the output above.")

if __name__ == "__main__":
    main()
