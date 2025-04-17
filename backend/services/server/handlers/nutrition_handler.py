"""
Nutrition API handler for Zestify Health AI Server.
"""

import uuid
import logging
from datetime import datetime
from typing import Dict, Any, List
from fastapi import APIRouter, HTTPException

try:
    # Try relative imports first (for package usage)
    from ..api_definitions import NutritionUploadRequest, NutritionUploadResponse
    from .base_handler import BaseHandler
except ImportError:
    # Fall back to absolute imports (for direct script usage)
    import sys
    import os
    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from api_definitions import NutritionUploadRequest, NutritionUploadResponse
    from handlers.base_handler import BaseHandler

# Configure logging
logger = logging.getLogger(__name__)

# Create router
router = APIRouter(tags=["Nutrition"], prefix="/nutrition")

@router.post("", response_model=NutritionUploadResponse)
async def upload_nutrition(request: NutritionUploadRequest) -> NutritionUploadResponse:
    """Upload nutrition data."""
    user_id = request.user_id
    nutrition_entries = request.nutrition_entries

    # Ensure user exists
    user_dir = BaseHandler.ensure_user_exists(user_id)

    # Load existing nutrition data
    nutrition_file = user_dir / "nutrition.json"
    existing_nutrition = BaseHandler.load_json_file(nutrition_file, default=[])

    # Create a map of existing nutrition entries by ID for quick lookup
    existing_nutrition_map = {n.get("id", ""): n for n in existing_nutrition if "id" in n}

    # Process each nutrition entry
    for entry in nutrition_entries:
        # Generate ID if not provided
        if not entry.id:
            entry.id = str(uuid.uuid4())

        # Convert entry to dict and remove None values
        entry_dict = entry.model_dump(exclude_none=True)

        if entry.id in existing_nutrition_map:
            # Update existing entry
            existing_nutrition_map[entry.id].update(entry_dict)
        else:
            # Add new entry
            existing_nutrition.append(entry_dict)

    # Save updated nutrition data
    BaseHandler.save_json_file(nutrition_file, existing_nutrition)

    # No need to save timestamped history files
    # All data is already in the nutrition.json file

    logger.info(f"Saved {len(nutrition_entries)} nutrition entries for user {user_id}")

    return NutritionUploadResponse(
        status="success",
        message=f"Saved {len(nutrition_entries)} nutrition entries successfully",
        user_id=user_id,
        entry_count=len(nutrition_entries)
    )
