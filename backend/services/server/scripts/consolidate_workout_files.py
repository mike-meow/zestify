#!/usr/bin/env python3
"""
Script to consolidate workout files.
This script will:
1. Find all users with both workouts.json and workout_memory.json files
2. Consolidate the data into a single workout_memory.json file following the template
3. Optionally remove the workouts.json file
"""

import json
import os
import sys
import logging
from pathlib import Path
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def load_json_file(file_path):
    """Load JSON data from a file."""
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        logger.error(f"Error loading {file_path}: {e}")
        return None

def save_json_file(file_path, data):
    """Save JSON data to a file."""
    try:
        with open(file_path, 'w') as f:
            json.dump(data, f, indent=2)
        return True
    except Exception as e:
        logger.error(f"Error saving {file_path}: {e}")
        return False

def consolidate_workout_files(data_dir, user_id=None, remove_workouts_file=False):
    """
    Consolidate workout files for a user or all users.
    
    Args:
        data_dir: Path to the data directory
        user_id: Optional user ID to process only one user
        remove_workouts_file: Whether to remove the workouts.json file after consolidation
    """
    data_path = Path(data_dir)
    
    # Get list of users to process
    if user_id:
        user_dirs = [data_path / user_id]
    else:
        user_dirs = [d for d in data_path.iterdir() if d.is_dir()]
    
    for user_dir in user_dirs:
        user_id = user_dir.name
        workouts_file = user_dir / "workouts.json"
        workout_memory_file = user_dir / "workout_memory.json"
        
        # Check if both files exist
        if not workouts_file.exists():
            logger.info(f"User {user_id} has no workouts.json file, skipping")
            continue
            
        # Load workouts data
        workouts_data = load_json_file(workouts_file)
        if workouts_data is None:
            logger.error(f"Failed to load workouts data for user {user_id}")
            continue
        
        # Create or load workout memory
        if workout_memory_file.exists():
            workout_memory = load_json_file(workout_memory_file)
            if workout_memory is None:
                logger.error(f"Failed to load workout memory for user {user_id}")
                continue
        else:
            # Create new workout memory from template
            now = datetime.now().isoformat()
            workout_memory = {
                "metadata": {
                    "user_id": user_id,
                    "created_at": now,
                    "last_updated": now,
                    "version": "1.0"
                },
                "workout_memory": {
                    "last_updated": now,
                    "recent_workouts": [],
                    "workout_patterns": {
                        "frequency": {
                            "weekly_average": 0,
                            "most_active_days": [],
                            "consistency_score": 0
                        },
                        "preferred_times": {
                            "morning": 0,
                            "afternoon": 0,
                            "evening": 0
                        },
                        "performance_trends": {}
                    }
                }
            }
        
        # Update workout memory with workouts data
        # First, create a set of existing workout IDs to avoid duplicates
        existing_workout_ids = set()
        if "workout_memory" in workout_memory and "recent_workouts" in workout_memory["workout_memory"]:
            for workout in workout_memory["workout_memory"]["recent_workouts"]:
                if "id" in workout:
                    existing_workout_ids.add(workout["id"])
        
        # Add new workouts
        now = datetime.now().isoformat()
        new_workouts = []
        for workout in workouts_data:
            if "id" in workout and workout["id"] not in existing_workout_ids:
                new_workouts.append(workout)
                existing_workout_ids.add(workout["id"])
        
        # Update workout memory
        if "workout_memory" not in workout_memory:
            workout_memory["workout_memory"] = {}
        
        if "recent_workouts" not in workout_memory["workout_memory"]:
            workout_memory["workout_memory"]["recent_workouts"] = []
        
        workout_memory["workout_memory"]["recent_workouts"] = new_workouts + workout_memory["workout_memory"]["recent_workouts"]
        workout_memory["workout_memory"]["last_updated"] = now
        workout_memory["metadata"]["last_updated"] = now
        
        # Save updated workout memory
        if save_json_file(workout_memory_file, workout_memory):
            logger.info(f"Successfully updated workout memory for user {user_id}")
            
            # Remove workouts file if requested
            if remove_workouts_file:
                try:
                    workouts_file.unlink()
                    logger.info(f"Removed workouts.json for user {user_id}")
                except Exception as e:
                    logger.error(f"Error removing workouts.json for user {user_id}: {e}")
        else:
            logger.error(f"Failed to save workout memory for user {user_id}")

def main():
    """Main function."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Consolidate workout files")
    parser.add_argument("--data-dir", required=True, help="Path to the data directory")
    parser.add_argument("--user-id", help="Process only this user ID")
    parser.add_argument("--remove-workouts-file", action="store_true", help="Remove workouts.json after consolidation")
    
    args = parser.parse_args()
    
    consolidate_workout_files(args.data_dir, args.user_id, args.remove_workouts_file)

if __name__ == "__main__":
    main()
