"""
Activity API handler for Zestify Health AI Server.
"""

import logging
from datetime import datetime
from typing import Dict, Any, List
from fastapi import APIRouter, HTTPException

try:
    # Try relative imports first (for package usage)
    from ..api_definitions import ActivityUploadRequest, ActivityUploadResponse
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
    """Upload daily activity data."""
    user_id = request.user_id
    activities = request.activities

    # Ensure user exists
    user_dir = BaseHandler.ensure_user_exists(user_id)

    # Load existing activities
    activities_file = user_dir / "activities.json"
    existing_activities = BaseHandler.load_json_file(activities_file, default=[])

    # Create a map of existing activities by date for quick lookup
    existing_activities_map = {a.get("date", ""): a for a in existing_activities if "date" in a}

    # Process each activity
    for activity in activities:
        # Convert activity to dict and remove None values
        activity_dict = activity.model_dump(exclude_none=True)

        if activity.date in existing_activities_map:
            # Update existing activity
            existing_activities_map[activity.date].update(activity_dict)
        else:
            # Add new activity
            existing_activities.append(activity_dict)

    # Save updated activities
    BaseHandler.save_json_file(activities_file, existing_activities)

    # No need to save timestamped history files
    # All data is already in the main activities.json file

    logger.info(f"Saved {len(activities)} activities for user {user_id}")

    return ActivityUploadResponse(
        status="success",
        message=f"Saved {len(activities)} activities successfully",
        user_id=user_id,
        activity_count=len(activities)
    )
