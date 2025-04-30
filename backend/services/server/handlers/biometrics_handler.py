"""
Biometrics API handler for Zestify Health AI Server.
"""

import logging
from datetime import datetime
from typing import List, Dict, Any, Optional
from fastapi import APIRouter, HTTPException

# Import schemas and updated API definitions
from backend.memory.schemas import Biometrics # Import the main schema
try:
    # Try relative imports first (for package usage)
    from ..api_definitions import BiometricsUploadRequest, BiometricsUploadResponse # Use updated definitions
    from .base_handler import BaseHandler
except ImportError:
    # Fall back to absolute imports (for direct script usage)
    import sys
    import os
    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from api_definitions import BiometricsUploadRequest, BiometricsUploadResponse
    from handlers.base_handler import BaseHandler

# Configure logging
logger = logging.getLogger(__name__)

# Create router
router = APIRouter(tags=["Biometrics"], prefix="/biometrics")

@router.post("", response_model=BiometricsUploadResponse)
async def upload_biometrics(request: BiometricsUploadRequest) -> BiometricsUploadResponse:
    """Upload biometrics data using the Biometrics schema."""
    user_id = request.user_id
    incoming_biometrics: Biometrics = request.data # Type hint for clarity

    # Ensure user exists
    user_dir = BaseHandler.ensure_user_exists(user_id)

    # Load existing biometrics data using the Biometrics schema
    biometrics_file = user_dir / "biometrics.json"
    try:
        existing_biometrics = Biometrics.model_validate(
            BaseHandler.load_json_file(biometrics_file, default={})
        )
    except Exception as e:
        logger.warning(f"Failed to validate existing biometrics for {user_id}, initializing new: {e}")
        existing_biometrics = Biometrics()
        
    # --- Merge incoming data into existing data --- 
    
    # Use helper to merge lists and remove duplicates based on timestamp
    def merge_readings_list(existing_list, incoming_list):
        if not incoming_list:
            return existing_list
        
        combined = existing_list + incoming_list
        # Use a dictionary to keep only the latest entry for each timestamp
        unique_by_timestamp = { 
            entry.get('date', entry.get('timestamp')): entry 
            for entry in combined if entry.get('date') or entry.get('timestamp') 
        }
        # Convert back to list
        return list(unique_by_timestamp.values())

    # Helper to sort readings by date
    def sort_readings(readings):
        if not readings: return []
        return sorted(readings, key=lambda x: datetime.fromisoformat(x.get('date', x.get('timestamp')).replace("Z", "+00:00")), reverse=True)

    # Merge body composition readings
    if incoming_biometrics.body_composition:
        if not existing_biometrics.body_composition:
            existing_biometrics.body_composition = incoming_biometrics.body_composition
        else:
            existing_biometrics.body_composition.weight_readings = merge_readings_list(
                existing_biometrics.body_composition.weight_readings,
                incoming_biometrics.body_composition.weight_readings
            )
            existing_biometrics.body_composition.bmi_readings = merge_readings_list(
                existing_biometrics.body_composition.bmi_readings,
                incoming_biometrics.body_composition.bmi_readings
            )
            existing_biometrics.body_composition.body_fat_percentage_readings = merge_readings_list(
                existing_biometrics.body_composition.body_fat_percentage_readings,
                incoming_biometrics.body_composition.body_fat_percentage_readings
            )
            # Update legacy fields only if present in incoming data (prefer readings)
            if incoming_biometrics.body_composition.weight and not incoming_biometrics.body_composition.weight_readings:
                existing_biometrics.body_composition.weight = incoming_biometrics.body_composition.weight
            if incoming_biometrics.body_composition.bmi and not incoming_biometrics.body_composition.bmi_readings:
                existing_biometrics.body_composition.bmi = incoming_biometrics.body_composition.bmi
            if incoming_biometrics.body_composition.body_fat_percentage and not incoming_biometrics.body_composition.body_fat_percentage_readings:
                existing_biometrics.body_composition.body_fat_percentage = incoming_biometrics.body_composition.body_fat_percentage
                
    # Merge RHR readings
    existing_biometrics.resting_heart_rate_readings = merge_readings_list(
        existing_biometrics.resting_heart_rate_readings,
        incoming_biometrics.resting_heart_rate_readings
    )
         
    # Merge Sleep Analysis readings
    existing_biometrics.sleep_analysis_readings = merge_readings_list(
        existing_biometrics.sleep_analysis_readings,
        incoming_biometrics.sleep_analysis_readings
    )
         
    # Sort all readings lists after merging
    if existing_biometrics.body_composition:
        existing_biometrics.body_composition.weight_readings = sort_readings(existing_biometrics.body_composition.weight_readings)
        existing_biometrics.body_composition.bmi_readings = sort_readings(existing_biometrics.body_composition.bmi_readings)
        existing_biometrics.body_composition.body_fat_percentage_readings = sort_readings(existing_biometrics.body_composition.body_fat_percentage_readings)
             
    existing_biometrics.resting_heart_rate_readings = sort_readings(existing_biometrics.resting_heart_rate_readings)
    existing_biometrics.sleep_analysis_readings = sort_readings(existing_biometrics.sleep_analysis_readings)
    
    # --- End Merge --- 

    # Save the merged and validated biometrics data using model_dump
    saved = BaseHandler.save_json_file(biometrics_file, existing_biometrics.model_dump())
    if not saved:
        raise HTTPException(status_code=500, detail="Failed to save biometrics data")

    # Determine which high-level metrics were received based on the incoming request data
    metrics_received = []
    if request.data.body_composition:
        if request.data.body_composition.weight_readings or request.data.body_composition.weight: metrics_received.append("body.weight")
        if request.data.body_composition.bmi_readings or request.data.body_composition.bmi: metrics_received.append("body.bmi")
        if request.data.body_composition.body_fat_percentage_readings or request.data.body_composition.body_fat_percentage: metrics_received.append("body.bfp")
    if request.data.resting_heart_rate_readings: metrics_received.append("vitals.rhr")
    if request.data.sleep_analysis_readings: metrics_received.append("vitals.sleep")
    # Add checks for other potential top-level fields in Biometrics if needed

    logger.info(f"Updated biometrics for user {user_id} with metrics: {metrics_received}")

    return BiometricsUploadResponse(
        status="success",
        message="Biometrics data received and saved",
        user_id=user_id,
        metrics_received=metrics_received
    )
