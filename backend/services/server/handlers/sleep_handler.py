"""
Sleep API handler for Zestify Health AI Server.
"""

import uuid
import logging
from datetime import datetime
from typing import Dict, Any, List
from fastapi import APIRouter, HTTPException

try:
    # Try relative imports first (for package usage)
    from ..api_definitions import SleepUploadRequest, SleepUploadResponse
    from .base_handler import BaseHandler
except ImportError:
    # Fall back to absolute imports (for direct script usage)
    import sys
    import os
    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from api_definitions import SleepUploadRequest, SleepUploadResponse
    from handlers.base_handler import BaseHandler

# Configure logging
logger = logging.getLogger(__name__)

# Create router
router = APIRouter(tags=["Sleep"], prefix="/sleep")

@router.post("", response_model=SleepUploadResponse)
async def upload_sleep(request: SleepUploadRequest) -> SleepUploadResponse:
    """Upload sleep data."""
    user_id = request.user_id
    sleep_sessions = request.sleep_sessions

    # Ensure user exists
    user_dir = BaseHandler.ensure_user_exists(user_id)

    # Load existing sleep data
    sleep_file = user_dir / "sleep.json"
    existing_sleep = BaseHandler.load_json_file(sleep_file, default=[])

    # Create a map of existing sleep sessions by ID for quick lookup
    existing_sleep_map = {s.get("id", ""): s for s in existing_sleep if "id" in s}

    # Process each sleep session
    for sleep in sleep_sessions:
        # Generate ID if not provided
        if not sleep.id:
            sleep.id = str(uuid.uuid4())

        # Convert sleep to dict and remove None values
        sleep_dict = sleep.model_dump(exclude_none=True)

        if sleep.id in existing_sleep_map:
            # Update existing sleep session
            existing_sleep_map[sleep.id].update(sleep_dict)
        else:
            # Add new sleep session
            existing_sleep.append(sleep_dict)

    # Save updated sleep data
    BaseHandler.save_json_file(sleep_file, existing_sleep)

    # No need to save timestamped history files
    # All data is already in the sleep.json file

    logger.info(f"Saved {len(sleep_sessions)} sleep sessions for user {user_id}")

    return SleepUploadResponse(
        status="success",
        message=f"Saved {len(sleep_sessions)} sleep sessions successfully",
        user_id=user_id,
        sleep_count=len(sleep_sessions)
    )
