"""
User API handler for Zestify Health AI Server.
"""

import uuid
from datetime import datetime
from fastapi import APIRouter, HTTPException

try:
    # Try relative imports first (for package usage)
    from ..api_definitions import UserCreateRequest, UserCreateResponse
    from .base_handler import BaseHandler
except ImportError:
    # Fall back to absolute imports (for direct script usage)
    import sys
    import os
    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from api_definitions import UserCreateRequest, UserCreateResponse
    from handlers.base_handler import BaseHandler

# Create router
router = APIRouter(tags=["Users"], prefix="/users")

@router.post("", response_model=UserCreateResponse)
async def create_user(request: UserCreateRequest) -> UserCreateResponse:
    """Create a new user."""
    user_id = request.user_id

    # Ensure user directory exists
    user_dir = BaseHandler.ensure_user_exists(user_id)

    # Create user profile with additional info if provided
    profile_file = user_dir / "profile.json"

    # Load existing profile or create new one
    profile = BaseHandler.load_json_file(profile_file, default={})

    # Update profile with request data
    profile.update({
        "user_id": user_id,
        "created_at": datetime.now().isoformat(),
        "updated_at": datetime.now().isoformat(),
        "name": request.name or "",
        "email": request.email or "",
    })

    # Save profile
    BaseHandler.save_json_file(profile_file, profile)

    return UserCreateResponse(
        status="success",
        message="User created successfully",
        user_id=user_id,
        created_at=profile["created_at"]
    )
