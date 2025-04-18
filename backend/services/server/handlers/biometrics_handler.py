"""
Biometrics API handler for Zestify Health AI Server.
"""

import logging
from datetime import datetime
from typing import List, Dict, Any, Optional
from fastapi import APIRouter, HTTPException

try:
    # Try relative imports first (for package usage)
    from ..api_definitions import BiometricsUploadRequest, BiometricsUploadResponse
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
    """Upload biometrics data."""
    user_id = request.user_id

    # Ensure user exists
    user_dir = BaseHandler.ensure_user_exists(user_id)

    # Track which metrics were received
    metrics_received = []

    # Load or create biometrics file
    biometrics_file = user_dir / "biometrics.json"

    # Load existing data or create new
    biometrics_data = BaseHandler.load_json_file(biometrics_file, default={
        "user_id": user_id,
        "created_at": datetime.now().isoformat(),
        "updated_at": datetime.now().isoformat(),
        "body_composition": {},
        "vital_signs": {},
    })

    # Process body composition data
    if request.body_composition:
        # Ensure body_composition section exists
        if "body_composition" not in biometrics_data:
            biometrics_data["body_composition"] = {}

        body_comp_data = biometrics_data["body_composition"]

        # Update with new data
        body_comp_data["updated_at"] = datetime.now().isoformat()

        # Process each measurement
        for field, measurement in request.body_composition.model_dump(exclude_none=True).items():
            if measurement:
                metrics_received.append(f"body_composition.{field}")

                # Create field if it doesn't exist
                if field not in body_comp_data:
                    body_comp_data[field] = {
                        "current": measurement.get("value") if isinstance(measurement, dict) else measurement.value,
                        "unit": measurement.get("unit") if isinstance(measurement, dict) else measurement.unit,
                        "history": []
                    }
                else:
                    # Update current value
                    body_comp_data[field]["current"] = measurement.get("value") if isinstance(measurement, dict) else measurement.value
                    body_comp_data[field]["unit"] = measurement.get("unit") if isinstance(measurement, dict) else measurement.unit

                # Check if measurement contains a history array
                if isinstance(measurement, dict) and "history" in measurement and isinstance(measurement["history"], list):
                    logger.info(f"Found history array with {len(measurement['history'])} entries for {field}")

                    # Initialize history if it doesn't exist
                    if "history" not in body_comp_data[field]:
                        body_comp_data[field]["history"] = []

                    # Process each history entry
                    for entry in measurement["history"]:
                        if isinstance(entry, dict) and "value" in entry and "timestamp" in entry:
                            # Create a standardized history entry
                            history_entry = {
                                "value": entry["value"],
                                "timestamp": entry["timestamp"],
                                "source": entry.get("source", "Apple Health"),
                                "notes": entry.get("notes", "")
                            }

                            # Check if this exact entry already exists in history
                            entry_exists = False
                            for existing_entry in body_comp_data[field]["history"]:
                                if (existing_entry["value"] == history_entry["value"] and
                                    existing_entry["timestamp"] == history_entry["timestamp"] and
                                    existing_entry["source"] == history_entry["source"]):
                                    entry_exists = True
                                    break

                            # Only add if this exact entry doesn't already exist
                            if not entry_exists:
                                body_comp_data[field]["history"].insert(0, history_entry)
                else:
                    # Add single entry to history
                    history_entry = {
                        "value": measurement.get("value") if isinstance(measurement, dict) else measurement.value,
                        "timestamp": measurement.get("timestamp", datetime.now().isoformat()) if isinstance(measurement, dict) else measurement.timestamp,
                        "source": measurement.get("source", "Apple Health") if isinstance(measurement, dict) else measurement.source,
                        "notes": (measurement.get("notes") or "") if isinstance(measurement, dict) else (measurement.notes or "")
                    }

                    # Add to history if it doesn't exist
                    if "history" not in body_comp_data[field]:
                        body_comp_data[field]["history"] = []

                    # Check if this exact entry already exists in history
                    entry_exists = False
                    for existing_entry in body_comp_data[field]["history"]:
                        if (existing_entry["value"] == history_entry["value"] and
                            existing_entry["timestamp"] == history_entry["timestamp"] and
                            existing_entry["source"] == history_entry["source"]):
                            entry_exists = True
                            break

                    # Only add if this exact entry doesn't already exist
                    if not entry_exists:
                        body_comp_data[field]["history"].insert(0, history_entry)

                # Store all history entries without limit
                # We want to keep all weight data points

        # Data will be saved at the end

    # Process vital signs data
    if request.vital_signs:
        # Ensure vital_signs section exists
        if "vital_signs" not in biometrics_data:
            biometrics_data["vital_signs"] = {}

        vitals_data = biometrics_data["vital_signs"]

        # Update with new data
        vitals_data["updated_at"] = datetime.now().isoformat()

        # Process each measurement
        for field, measurement in request.vital_signs.model_dump(exclude_none=True).items():
            if measurement:
                metrics_received.append(f"vital_signs.{field}")

                # Create field if it doesn't exist
                if field not in vitals_data:
                    vitals_data[field] = {
                        "current": measurement.get("value") if isinstance(measurement, dict) else measurement.value,
                        "unit": measurement.get("unit") if isinstance(measurement, dict) else measurement.unit,
                        "history": []
                    }
                else:
                    # Update current value
                    vitals_data[field]["current"] = measurement.get("value") if isinstance(measurement, dict) else measurement.value
                    vitals_data[field]["unit"] = measurement.get("unit") if isinstance(measurement, dict) else measurement.unit

                # Check if measurement contains a history array
                if isinstance(measurement, dict) and "history" in measurement and isinstance(measurement["history"], list):
                    logger.info(f"Found history array with {len(measurement['history'])} entries for {field}")

                    # Initialize history if it doesn't exist
                    if "history" not in vitals_data[field]:
                        vitals_data[field]["history"] = []

                    # Process each history entry
                    for entry in measurement["history"]:
                        if isinstance(entry, dict) and "value" in entry and "timestamp" in entry:
                            # Create a standardized history entry
                            history_entry = {
                                "value": entry["value"],
                                "timestamp": entry["timestamp"],
                                "source": entry.get("source", "Apple Health"),
                                "notes": entry.get("notes", "")
                            }

                            # Check if this exact entry already exists in history
                            entry_exists = False
                            for existing_entry in vitals_data[field]["history"]:
                                if (existing_entry["value"] == history_entry["value"] and
                                    existing_entry["timestamp"] == history_entry["timestamp"] and
                                    existing_entry["source"] == history_entry["source"]):
                                    entry_exists = True
                                    break

                            # Only add if this exact entry doesn't already exist
                            if not entry_exists:
                                vitals_data[field]["history"].insert(0, history_entry)
                else:
                    # Add single entry to history
                    history_entry = {
                        "value": measurement.get("value") if isinstance(measurement, dict) else measurement.value,
                        "timestamp": measurement.get("timestamp", datetime.now().isoformat()) if isinstance(measurement, dict) else measurement.timestamp,
                        "source": measurement.get("source", "Apple Health") if isinstance(measurement, dict) else measurement.source,
                        "notes": (measurement.get("notes") or "") if isinstance(measurement, dict) else (measurement.notes or "")
                    }

                    # Add to history if it doesn't exist
                    if "history" not in vitals_data[field]:
                        vitals_data[field]["history"] = []

                    # Check if this exact entry already exists in history
                    entry_exists = False
                    for existing_entry in vitals_data[field]["history"]:
                        if (existing_entry["value"] == history_entry["value"] and
                            existing_entry["timestamp"] == history_entry["timestamp"] and
                            existing_entry["source"] == history_entry["source"]):
                            entry_exists = True
                            break

                    # Only add if this exact entry doesn't already exist
                    if not entry_exists:
                        vitals_data[field]["history"].insert(0, history_entry)

                # Store all history entries without limit
                # We want to keep all vital sign data points

        # Data will be saved at the end

    # Update the timestamp
    biometrics_data["updated_at"] = datetime.now().isoformat()

    # Save the combined biometrics data
    BaseHandler.save_json_file(biometrics_file, biometrics_data)

    # No need to save timestamped history files
    # All data is now in the biometrics.json file

    logger.info(f"Updated biometrics for user {user_id} with metrics: {metrics_received}")

    return BiometricsUploadResponse(
        status="success",
        message="Biometrics data received and saved",
        user_id=user_id,
        metrics_received=metrics_received
    )
