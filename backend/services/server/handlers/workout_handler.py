"""
Workout API handler for Zestify Health AI Server.
"""

import uuid
import logging
from datetime import datetime
from typing import List, Dict, Any
from fastapi import APIRouter, HTTPException

# Import schemas and updated API definitions
from backend.memory.schemas import WorkoutMemory, RecentWorkout
try:
    # Try relative imports first (for package usage)
    from ..api_definitions import (
        WorkoutUploadRequest, # Use updated definition
        WorkoutUploadResponse,
        WorkoutsUploadRequest, # Use updated definition
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
    """Upload a single workout using the RecentWorkout schema."""
    user_id = request.user_id
    workout: RecentWorkout = request.workout # Type hint for clarity

    # Ensure user exists
    user_dir = BaseHandler.ensure_user_exists(user_id)

    # Generate workout ID if not provided
    if not workout.id:
        workout.id = str(uuid.uuid4())

    # Load existing workout memory using the WorkoutMemory schema
    workout_memory_file = user_dir / "workout_memory.json"
    try:
        workout_memory = WorkoutMemory.model_validate(
            BaseHandler.load_json_file(workout_memory_file, default={})
        )
    except Exception as e:
        logger.warning(f"Failed to validate existing workout memory for {user_id}, initializing new: {e}")
        workout_memory = WorkoutMemory(user_id=user_id, last_updated=datetime.now())
        
    # Set user_id and update timestamp if missing
    if not workout_memory.user_id: workout_memory.user_id = user_id
    workout_memory.last_updated = datetime.now()
    
    # Check if workout already exists in memory
    existing_workouts = workout_memory.recent_workouts
    workout_found = False
    for i, existing_workout in enumerate(existing_workouts):
        if existing_workout.id == workout.id:
            existing_workouts[i] = workout # Replace with the new workout object
            workout_found = True
            break
            
    if not workout_found:
        # Add new workout at the beginning of the list
        existing_workouts.insert(0, workout)

    # Update workout memory list
    workout_memory.recent_workouts = existing_workouts

    # Save updated workout memory
    BaseHandler.save_json_file(workout_memory_file, workout_memory.model_dump())

    logger.info(f"Saved workout for user {user_id} with ID: {workout.id}")

    return WorkoutUploadResponse(
        status="success",
        message="Workout saved successfully",
        user_id=user_id,
        workout_id=workout.id
    )

@router.post("/batch", response_model=WorkoutsUploadResponse)
async def upload_workouts(request: WorkoutsUploadRequest) -> WorkoutsUploadResponse:
    """Upload multiple workouts using a list of RecentWorkout schemas."""
    user_id = request.user_id
    workouts_to_add: List[RecentWorkout] = request.workouts # Type hint
    
    # Log received workout types immediately after parsing
    logger.info(f"Received batch upload for user {user_id}. Parsed workout types:")
    for i, w in enumerate(workouts_to_add):
        logger.info(f"  Workout {i+1}: ID={w.id}, workout_type='{w.workout_type}', original_type='{w.original_type}'")

    # Ensure user exists
    user_dir = BaseHandler.ensure_user_exists(user_id)

    # Load existing workout memory using the WorkoutMemory schema
    workout_memory_file = user_dir / "workout_memory.json"
    try:
        workout_memory = WorkoutMemory.model_validate(
            BaseHandler.load_json_file(workout_memory_file, default={})
        )
    except Exception as e:
        logger.warning(f"Failed to validate existing workout memory for {user_id}, initializing new: {e}")
        workout_memory = WorkoutMemory(user_id=user_id, last_updated=datetime.now())
        
    # Set user_id and update timestamp if missing
    if not workout_memory.user_id: workout_memory.user_id = user_id
    workout_memory.last_updated = datetime.now()

    # Get existing workouts from memory
    existing_workouts = workout_memory.recent_workouts

    # Create a deduplication dictionary based on workout start times
    # This handles cases where the same workout might have different IDs
    # (e.g., "1612345678_RUNNING" and "1612345678_RUNNING_JOGGING" for the same timestamp)
    workout_by_timestamp = {}
    
    # Process existing workouts - keep track by timestamp
    for workout in existing_workouts:
        if workout.start_date:
            # Use timestamp as the key for deduplication
            timestamp_key = workout.start_date.timestamp() if isinstance(workout.start_date, datetime) else None
            if timestamp_key:
                workout_by_timestamp[timestamp_key] = workout
    
    # Process new workouts - if a workout with the same timestamp exists, use the new one
    for workout in workouts_to_add:
        if workout.start_date:
            timestamp_key = workout.start_date.timestamp() if isinstance(workout.start_date, datetime) else None
            if timestamp_key:
                workout_by_timestamp[timestamp_key] = workout
    
    # Convert back to a list
    deduplicated_workouts = list(workout_by_timestamp.values())
    
    # Sort by start_date descending
    deduplicated_workouts.sort(key=lambda w: w.start_date or datetime.min, reverse=True)

    # Update workout memory with deduplicated list
    workout_memory.recent_workouts = deduplicated_workouts
    
    # Log deduplication results
    logger.info(f"Deduplication: {len(workouts_to_add)} new + {len(existing_workouts)} existing → {len(deduplicated_workouts)} unique workouts")
    logger.debug(f"Types after deduplication for user {user_id}:")
    for i, w in enumerate(deduplicated_workouts[:5]):  # Log first 5 for brevity
         logger.debug(f"  Final list {i+1}: ID={w.id}, workout_type='{w.workout_type}', original_type='{w.original_type}'")
    if len(deduplicated_workouts) > 5:
         logger.debug(f"  ... and {len(deduplicated_workouts) - 5} more workouts")

    # Save updated workout memory
    saved = BaseHandler.save_json_file(workout_memory_file, workout_memory.model_dump())
    if not saved:
         raise HTTPException(status_code=500, detail="Failed to save workout memory")

    logger.info(f"Saved {len(workouts_to_add)} workouts for user {user_id}")
    processed_ids = [w.id for w in workouts_to_add if w.id] # Recalculate based on input list

    return WorkoutsUploadResponse(
        status="success",
        message=f"Saved {len(workouts_to_add)} workouts successfully",
        user_id=user_id,
        workout_count=len(workouts_to_add),
        workout_ids=processed_ids # Return IDs of workouts processed in this request
    )
