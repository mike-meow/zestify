"""
API Handlers for Zestify Health AI Server

This package contains handlers for all API endpoints.
"""

try:
    # Try relative imports first (for package usage)
    from .user_handler import router as user_router
    from .biometrics_handler import router as biometrics_router
    from .workout_handler import router as workout_router
    from .activity_handler import router as activity_router
    from .sleep_handler import router as sleep_router
    from .nutrition_handler import router as nutrition_router
except ImportError:
    # Fall back to absolute imports (for direct script usage)
    import sys
    import os
    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from handlers.user_handler import router as user_router
    from handlers.biometrics_handler import router as biometrics_router
    from handlers.workout_handler import router as workout_router
    from handlers.activity_handler import router as activity_router
    from handlers.sleep_handler import router as sleep_router
    from handlers.nutrition_handler import router as nutrition_router

__all__ = [
    "user_router",
    "biometrics_router",
    "workout_router",
    "activity_router",
    "sleep_router",
    "nutrition_router",
]
