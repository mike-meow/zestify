#!/usr/bin/env python3
"""
Extract a subset of health data from raw JSON files.

This script extracts:
1. Workout data from the last 7-30 days
2. Related heart rate & route data for each workout
3. Biometric data (weight) for a longer period
4. Sleep data
5. Other relevant health metrics

The extracted data is saved to an example_user directory.
"""

import json
import os
import datetime
from pathlib import Path
import shutil
from typing import Dict, List, Any, Optional

# Configuration
DAYS_TO_EXTRACT = 30  # Extract data from the last 30 days
SOURCE_DIR = "frontend/health_ai_app/health_ai/example_data/Documents/health_data"
TARGET_DIR = "backend/services/example_user"
CURRENT_DATE = datetime.datetime.now()

def ensure_target_dir():
    """Create the target directory if it doesn't exist."""
    os.makedirs(TARGET_DIR, exist_ok=True)

def parse_date(date_str: str) -> datetime.datetime:
    """Parse date string to datetime object."""
    try:
        return datetime.datetime.fromisoformat(date_str.replace('Z', '+00:00'))
    except ValueError:
        # Handle any parsing errors
        print(f"Warning: Could not parse date: {date_str}")
        return CURRENT_DATE  # Return current date as fallback

def is_within_days(date_str: str, days: int) -> bool:
    """Check if a date is within the specified number of days from now."""
    if not date_str:
        return False

    date = parse_date(date_str)
    delta = CURRENT_DATE - date
    return delta.days <= days

def extract_workouts() -> Dict[str, Any]:
    """Extract workout data from the last DAYS_TO_EXTRACT days."""
    try:
        with open(os.path.join(SOURCE_DIR, "workout_history.json"), "r") as f:
            workout_data = json.load(f)

        # Filter workouts by date
        recent_workouts = []
        for workout in workout_data.get("workouts", []):
            if is_within_days(workout.get("startTime"), DAYS_TO_EXTRACT):
                recent_workouts.append(workout)

        # Create a new workout history with only recent workouts
        filtered_data = {
            "workouts": recent_workouts,
            "userId": workout_data.get("userId", "example_user"),
            "lastSyncTime": workout_data.get("lastSyncTime", CURRENT_DATE.isoformat())
        }

        return filtered_data
    except Exception as e:
        print(f"Error extracting workout data: {e}")
        return {"workouts": [], "userId": "example_user", "lastSyncTime": CURRENT_DATE.isoformat()}

def extract_heart_rate_data(workout_ids: List[str]) -> List[Dict[str, Any]]:
    """Extract heart rate data related to the specified workouts."""
    try:
        with open(os.path.join(SOURCE_DIR, "heart_rate_data.json"), "r") as f:
            heart_rate_data = json.load(f)

        # Filter heart rate data by workout IDs and date
        filtered_data = []
        for entry in heart_rate_data:
            if (entry.get("sourceId") in workout_ids or
                is_within_days(entry.get("timestamp"), DAYS_TO_EXTRACT)):
                filtered_data.append(entry)

        return filtered_data
    except Exception as e:
        print(f"Error extracting heart rate data: {e}")
        return []

def extract_route_data(workout_ids: List[str]) -> Dict[str, List[Dict[str, Any]]]:
    """Extract route data for the specified workouts."""
    route_data = {}

    for workout_id in workout_ids:
        route_file = f"raw_route_{workout_id}.json"
        try:
            with open(os.path.join(SOURCE_DIR, route_file), "r") as f:
                route = json.load(f)
                route_data[workout_id] = route
        except FileNotFoundError:
            # Route data might not exist for all workouts
            continue
        except Exception as e:
            print(f"Error extracting route data for {workout_id}: {e}")

    return route_data

def extract_weight_data() -> List[Dict[str, Any]]:
    """Extract weight data for a longer period."""
    try:
        with open(os.path.join(SOURCE_DIR, "weight_data.json"), "r") as f:
            weight_data = json.load(f)

        # Weight data is typically small, so we can include more history
        return weight_data
    except Exception as e:
        print(f"Error extracting weight data: {e}")
        return []

def extract_sleep_data() -> Dict[str, List[Dict[str, Any]]]:
    """Extract sleep data from the last DAYS_TO_EXTRACT days."""
    sleep_categories = [
        "sleep_asleep_data.json",
        "sleep_awake_data.json",
        "sleep_deep_data.json",
        "sleep_in_bed_data.json",
        "sleep_rem_data.json"
    ]

    sleep_data = {}

    for category in sleep_categories:
        try:
            with open(os.path.join(SOURCE_DIR, category), "r") as f:
                data = json.load(f)

            # Filter by date
            filtered_data = []
            for entry in data if isinstance(data, list) else []:
                if is_within_days(entry.get("timestamp"), DAYS_TO_EXTRACT):
                    filtered_data.append(entry)

            sleep_data[category.replace(".json", "")] = filtered_data
        except Exception as e:
            print(f"Error extracting sleep data from {category}: {e}")
            sleep_data[category.replace(".json", "")] = []

    return sleep_data

def extract_additional_metrics() -> Dict[str, List[Dict[str, Any]]]:
    """Extract additional health metrics from the last DAYS_TO_EXTRACT days."""
    metrics = [
        "active_energy_burned_data.json",
        "steps_data.json",
        "distance_walking_running_data.json",
        "flights_climbed_data.json",
        "resting_heart_rate_data.json",
        "water_data.json",
        "dietary_energy_consumed_data.json"
    ]

    additional_data = {}

    for metric in metrics:
        try:
            with open(os.path.join(SOURCE_DIR, metric), "r") as f:
                data = json.load(f)

            # Filter by date
            filtered_data = []
            for entry in data if isinstance(data, list) else []:
                if is_within_days(entry.get("timestamp"), DAYS_TO_EXTRACT):
                    filtered_data.append(entry)

            # Limit the number of entries to keep file sizes manageable
            if len(filtered_data) > 1000:
                filtered_data = filtered_data[:1000]

            additional_data[metric.replace(".json", "")] = filtered_data
        except Exception as e:
            print(f"Error extracting data from {metric}: {e}")
            additional_data[metric.replace(".json", "")] = []

    return additional_data

def combine_workout_data(workouts: Dict[str, Any], heart_rate: List[Dict[str, Any]],
                         routes: Dict[str, List[Dict[str, Any]]]) -> Dict[str, Any]:
    """Combine workout data with related heart rate and route data."""
    workout_ids = [workout.get("id") for workout in workouts.get("workouts", [])]

    # Create a mapping of workout IDs to heart rate data
    workout_heart_rates = {}
    for entry in heart_rate:
        workout_id = entry.get("sourceId")
        if workout_id in workout_ids:
            if workout_id not in workout_heart_rates:
                workout_heart_rates[workout_id] = []
            workout_heart_rates[workout_id].append(entry)

    # Add heart rate and route data to each workout
    for workout in workouts.get("workouts", []):
        workout_id = workout.get("id")
        workout["heartRateData"] = workout_heart_rates.get(workout_id, [])
        workout["routeData"] = routes.get(workout_id, [])

    return workouts

def save_data(data: Any, filename: str):
    """Save data to a JSON file in the target directory."""
    filepath = os.path.join(TARGET_DIR, filename)
    with open(filepath, "w") as f:
        json.dump(data, f, indent=2)
    print(f"Saved {filename}")

def main():
    """Main function to extract and save health data."""
    print("Extracting health data...")
    ensure_target_dir()

    # Extract workout data
    workouts = extract_workouts()
    workout_ids = [workout.get("id") for workout in workouts.get("workouts", [])]

    # Extract related data
    heart_rate_data = extract_heart_rate_data(workout_ids)
    route_data = extract_route_data(workout_ids)
    weight_data = extract_weight_data()
    sleep_data = extract_sleep_data()
    additional_metrics = extract_additional_metrics()

    # Combine workout data with heart rate and route data
    combined_workouts = combine_workout_data(workouts, heart_rate_data, route_data)

    # Save extracted data
    save_data(combined_workouts, "workout_data.json")
    save_data(heart_rate_data, "heart_rate_data.json")
    save_data(weight_data, "weight_data.json")
    save_data(sleep_data, "sleep_data.json")
    save_data(additional_metrics, "additional_metrics.json")

    print("Data extraction complete!")

if __name__ == "__main__":
    main()
