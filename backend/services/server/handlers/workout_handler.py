"""
Workout API handler for Zestify Health AI Server.
"""

import uuid
import logging
from datetime import datetime
from typing import List, Dict, Any
from fastapi import APIRouter, HTTPException

try:
    # Try relative imports first (for package usage)
    from ..api_definitions import (
        WorkoutUploadRequest,
        WorkoutUploadResponse,
        WorkoutsUploadRequest,
        WorkoutsUploadResponse
    )
    from .base_handler import BaseHandler
except ImportError:
    # Fall back to absolute imports (for direct script usage)
    import sys
    import os
    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from api_definitions import (
        WorkoutUploadRequest,
        WorkoutUploadResponse,
        WorkoutsUploadRequest,
        WorkoutsUploadResponse
    )
    from handlers.base_handler import BaseHandler

# Configure logging
logger = logging.getLogger(__name__)

# Create router
router = APIRouter(tags=["Workouts"], prefix="/workouts")

@router.post("", response_model=WorkoutUploadResponse)
async def upload_workout(request: WorkoutUploadRequest) -> WorkoutUploadResponse:
    """Upload a single workout."""
    user_id = request.user_id
    workout = request.workout

    # Ensure user exists
    user_dir = BaseHandler.ensure_user_exists(user_id)

    # Generate workout ID if not provided
    if not workout.id:
        workout.id = str(uuid.uuid4())

    # Load existing workouts
    workouts_file = user_dir / "workouts.json"
    workouts = BaseHandler.load_json_file(workouts_file, default=[])

    # Check if workout already exists
    existing_ids = [w.get("id") for w in workouts if "id" in w]

    if workout.id in existing_ids:
        # Update existing workout
        for i, w in enumerate(workouts):
            if w.get("id") == workout.id:
                # Convert workout to dict and remove None values
                workout_dict = workout.dict(exclude_none=True)
                workouts[i] = workout_dict
                break
    else:
        # Add new workout
        # Convert workout to dict and remove None values
        workout_dict = workout.dict(exclude_none=True)
        workouts.append(workout_dict)

    # Save updated workouts
    BaseHandler.save_json_file(workouts_file, workouts)

    # Update workout memory
    await _update_workout_memory(user_id, workouts)

    logger.info(f"Saved workout for user {user_id} with ID: {workout.id}")

    return WorkoutUploadResponse(
        status="success",
        message="Workout saved successfully",
        user_id=user_id,
        workout_id=workout.id
    )

@router.post("/batch", response_model=WorkoutsUploadResponse)
async def upload_workouts(request: WorkoutsUploadRequest) -> WorkoutsUploadResponse:
    """Upload multiple workouts."""
    user_id = request.user_id
    workouts_to_add = request.workouts

    # Ensure user exists
    user_dir = BaseHandler.ensure_user_exists(user_id)

    # Load existing workouts
    workouts_file = user_dir / "workouts.json"
    existing_workouts = BaseHandler.load_json_file(workouts_file, default=[])

    # Create a map of existing workouts by ID
    existing_workout_map = {w.get("id", ""): w for w in existing_workouts if "id" in w}

    # Track workout IDs
    workout_ids = []

    # Process each workout
    for workout in workouts_to_add:
        # Generate workout ID if not provided
        if not workout.id:
            workout.id = str(uuid.uuid4())

        workout_ids.append(workout.id)

        # Convert workout to dict and remove None values
        workout_dict = workout.dict(exclude_none=True)

        if workout.id in existing_workout_map:
            # Update existing workout
            existing_workout_map[workout.id].update(workout_dict)
        else:
            # Add new workout
            existing_workouts.append(workout_dict)

    # Save updated workouts
    BaseHandler.save_json_file(workouts_file, existing_workouts)

    # Update workout memory
    await _update_workout_memory(user_id, existing_workouts)

    logger.info(f"Saved {len(workouts_to_add)} workouts for user {user_id}")

    return WorkoutsUploadResponse(
        status="success",
        message=f"Saved {len(workouts_to_add)} workouts successfully",
        user_id=user_id,
        workout_count=len(workouts_to_add),
        workout_ids=workout_ids
    )

async def _update_workout_memory(user_id: str, workouts: List[Dict[str, Any]]) -> bool:
    """Update workout memory from workouts data."""
    try:
        # Ensure user exists
        user_dir = BaseHandler.ensure_user_exists(user_id)

        # Create workout memory file path
        workout_memory_file = user_dir / "workout_memory.json"

        # Load existing workout memory or create new
        workout_memory = BaseHandler.load_json_file(workout_memory_file, default={
            "metadata": {
                "user_id": user_id,
                "created_at": datetime.now().isoformat(),
                "last_updated": datetime.now().isoformat(),
                "version": "1.0"
            },
            "workout_memory": {
                "last_updated": datetime.now().isoformat(),
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
        })

        # Sort workouts by date (newest first)
        sorted_workouts = sorted(
            workouts,
            key=lambda w: w.get("start_date", ""),
            reverse=True
        )

        # Take only the most recent 20 workouts
        recent_workouts = sorted_workouts[:20]

        # Update workout memory
        workout_memory["workout_memory"]["recent_workouts"] = recent_workouts

        # Update workout patterns if we have enough workouts
        if len(workouts) > 0:
            # Calculate weekly average (approximate)
            # Get unique workout dates
            workout_dates = set()
            for workout in workouts:
                if "start_date" in workout:
                    date_part = workout["start_date"].split("T")[0]  # Extract date part
                    workout_dates.add(date_part)

            # Count weeks (approximate)
            weeks = max(1, len(workout_dates) / 7)
            weekly_avg = round(len(workouts) / weeks, 1)

            # Count workouts by day of week
            days_of_week = {
                "Monday": 0, "Tuesday": 0, "Wednesday": 0,
                "Thursday": 0, "Friday": 0, "Saturday": 0, "Sunday": 0
            }

            for workout in workouts:
                if "start_date" in workout:
                    try:
                        date_obj = datetime.fromisoformat(
                            workout["start_date"].replace("Z", "+00:00")
                        )
                        day_name = date_obj.strftime("%A")
                        days_of_week[day_name] += 1
                    except (ValueError, TypeError):
                        pass

            # Find most active days
            most_active = sorted(days_of_week.items(), key=lambda x: x[1], reverse=True)
            most_active_days = [day for day, count in most_active if count > 0][:3]  # Top 3

            # Count workouts by time of day
            morning = 0  # 5am-12pm
            afternoon = 0  # 12pm-5pm
            evening = 0  # 5pm-10pm

            for workout in workouts:
                if "start_date" in workout:
                    try:
                        date_obj = datetime.fromisoformat(
                            workout["start_date"].replace("Z", "+00:00")
                        )
                        hour = date_obj.hour
                        if 5 <= hour < 12:
                            morning += 1
                        elif 12 <= hour < 17:
                            afternoon += 1
                        elif 17 <= hour < 22:
                            evening += 1
                    except (ValueError, TypeError):
                        pass

            total_time_classified = morning + afternoon + evening
            if total_time_classified > 0:
                morning_pct = round((morning / total_time_classified) * 100)
                afternoon_pct = round((afternoon / total_time_classified) * 100)
                evening_pct = round((evening / total_time_classified) * 100)
            else:
                morning_pct = afternoon_pct = evening_pct = 0

            # Update workout patterns
            workout_memory["workout_memory"]["workout_patterns"] = {
                "frequency": {
                    "weekly_average": weekly_avg,
                    "most_active_days": most_active_days,
                    "consistency_score": min(100, round(weekly_avg * 25))  # Simple scoring
                },
                "preferred_times": {
                    "morning": morning_pct,
                    "afternoon": afternoon_pct,
                    "evening": evening_pct
                },
                "performance_trends": {}
            }

        # Update timestamps
        workout_memory["workout_memory"]["last_updated"] = datetime.now().isoformat()
        workout_memory["metadata"]["last_updated"] = datetime.now().isoformat()

        # Save updated memory
        BaseHandler.save_json_file(workout_memory_file, workout_memory)

        return True
    except Exception as e:
        logger.error(f"Error updating workout memory: {str(e)}")
        return False
