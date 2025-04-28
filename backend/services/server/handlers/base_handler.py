"""
Base handler for all API endpoints.
"""

import os
import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional, List

from fastapi import APIRouter, HTTPException, Depends

# Configure logging
logger = logging.getLogger(__name__)

# Set up paths
REPO_ROOT = Path(__file__).parent.parent.parent.parent.parent
DATA_DIR = REPO_ROOT / "data"

# Create data directory if it doesn't exist
os.makedirs(DATA_DIR, exist_ok=True)

class BaseHandler:
    """Base handler for all API endpoints."""
    
    @staticmethod
    def get_user_dir(user_id: str) -> Path:
        """Get the user directory path."""
        user_dir = DATA_DIR / user_id
        return user_dir
    
    @staticmethod
    def ensure_user_exists(user_id: str) -> Path:
        """Ensure the user exists and return the user directory path."""
        user_dir = BaseHandler.get_user_dir(user_id)
        
        # Create user directory if it doesn't exist
        os.makedirs(user_dir, exist_ok=True)
        
        # Create user info file if it doesn't exist
        user_info_file = user_dir / "user_info.json"
        if not user_info_file.exists():
            user_info = {
                "user_id": user_id,
                "created_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat()
            }
            with open(user_info_file, "w") as f:
                json.dump(user_info, f, indent=2)
            
            logger.info(f"Created new user with ID: {user_id}")
        
        return user_dir
    
    @staticmethod
    def load_json_file(file_path: Path, default: Any = None) -> Any:
        """Load a JSON file."""
        if not file_path.exists():
            return default
        
        try:
            with open(file_path, "r") as f:
                return json.load(f)
        except json.JSONDecodeError:
            logger.error(f"Error parsing JSON file: {file_path}")
            return default
    
    @staticmethod
    def save_json_file(file_path: Path, data: Any) -> bool:
        """Save data to a JSON file."""
        try:
            # Ensure directory exists
            os.makedirs(file_path.parent, exist_ok=True)
            
            with open(file_path, "w") as f:
                json.dump(data, f, indent=2, default=json_serial)
            
            return True
        except Exception as e:
            logger.error(f"Error saving data to {file_path}: {str(e)}")
            return False
    
    @staticmethod
    def generate_response(user_id: str, message: str, **kwargs) -> Dict[str, Any]:
        """Generate a standard API response."""
        response = {
            "status": "success",
            "message": message,
            "user_id": user_id,
            "timestamp": datetime.now().isoformat()
        }
        
        # Add additional fields
        response.update(kwargs)
        
        return response
