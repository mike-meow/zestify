"""
Activity API handler for Zestify Health AI Server.
"""

import logging
from datetime import datetime
from typing import Dict, Any, List
from fastapi import APIRouter, HTTPException

# Import schemas and updated API definitions
from backend.memory.schemas import Activities, Activity # Import main and single item schemas
try:
    # Try relative imports first (for package usage)
    from ..api_definitions import ActivityUploadRequest, ActivityUploadResponse # Use updated definition
    from .base_handler import BaseHandler
except ImportError:
    # Fall back to absolute imports (for direct script usage)
    import sys
    import os
    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from api_definitions import ActivityUploadRequest, ActivityUploadResponse
    from handlers.base_handler import BaseHandler

# Configure logging
logger = logging.getLogger(__name__)

# Create router
router = APIRouter(tags=["Activities"], prefix="/activities")

@router.post("", response_model=ActivityUploadResponse)
async def upload_activities(request: ActivityUploadRequest) -> ActivityUploadResponse:
    """Upload daily activity data using a list of Activity schemas."""
    user_id = request.user_id
    incoming_activities: List[Activity] = request.activities # Type hint

    # Ensure user exists
    user_dir = BaseHandler.ensure_user_exists(user_id)

    # Load existing activities using the Activities schema
    activities_file = user_dir / "activities.json"
    try:
        existing_activities_model = Activities.model_validate(
             BaseHandler.load_json_file(activities_file, default={})
        )
    except Exception as e:
        logger.warning(f"Failed to validate existing activities for {user_id}, initializing new: {e}")
        existing_activities_model = Activities()
        
    # Get the list of Activity objects
    existing_activities_list = existing_activities_model.activities

    # Create a map of existing activities by date for efficient lookup
    # Make sure date objects are compared correctly (convert incoming string dates)
    existing_activities_map = { 
        act.date.date() : act 
        for act in existing_activities_list if act.date 
    }

    # Process each incoming activity
    processed_count = 0
    for activity in incoming_activities:
        # Ensure incoming activity has a valid date
        if not activity.date:
            logger.warning(f"Skipping activity for user {user_id} due to missing date.")
            continue
        
        # Convert incoming date string to date object for comparison
        try:
            activity_date = activity.date.date() # Assuming incoming date is datetime
        except AttributeError:
             try:
                  activity_date = datetime.fromisoformat(str(activity.date)).date()
             except ValueError:
                  logger.warning(f"Skipping activity for user {user_id} due to invalid date format: {activity.date}")
                  continue

        if activity_date in existing_activities_map:
            # Update existing activity object (replace entirely or merge fields)
            # Replacing is simpler for now
            existing_index = next((i for i, act in enumerate(existing_activities_list) if act.date and act.date.date() == activity_date), None)
            if existing_index is not None:
                existing_activities_list[existing_index] = activity
        else:
            # Add new activity object
            existing_activities_list.append(activity)
            
        processed_count += 1
        
    # Sort the list by date descending
    existing_activities_list.sort(key=lambda x: x.date or datetime.min, reverse=True)

    # Update the model with the modified list
    existing_activities_model.activities = existing_activities_list

    # Save updated activities using model_dump
    saved = BaseHandler.save_json_file(activities_file, existing_activities_model.model_dump())
    if not saved:
         raise HTTPException(status_code=500, detail="Failed to save activity data")

    logger.info(f"Processed {processed_count} activities for user {user_id}")

    return ActivityUploadResponse(
        status="success",
        message=f"Processed {processed_count} activities successfully",
        user_id=user_id,
        activity_count=processed_count
    )
