"""
API Definitions for Zestify Health AI Server

This file defines all API endpoints, request models, and response models for the Zestify Health AI server.
Each endpoint is focused on a specific type of health data.
"""

from typing import List, Optional, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field, field_validator
from enum import Enum

# Import core data schemas from backend.memory
from backend.memory.schemas import (
    Biometrics,
    WorkoutMemory,
    Activities,
    SleepAnalysis,
    NutritionLog,
    RecentWorkout,
    Activity,
    SleepEntry,
    NutritionEntry
)


# ==================== COMMON MODELS ====================

class BaseRequest(BaseModel):
    """Base request model for all API endpoints"""
    user_id: str

class ApiResponse(BaseModel):
    """Base response model for all API endpoints"""
    status: str = "success"
    message: str
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())
    user_id: str


class SourceType(str, Enum):
    """Source of health data"""
    APPLE_HEALTH = "Apple Health"
    MANUAL = "Manual Entry"
    DEVICE = "Connected Device"
    OTHER = "Other"


# ==================== USER ENDPOINTS ====================

class UserCreateRequest(BaseRequest):
    """Request model for user creation"""
    name: Optional[str] = None
    email: Optional[str] = None

class UserCreateResponse(ApiResponse):
    """Response model for user creation"""
    created_at: str


# ==================== BIOMETRICS ENDPOINTS ====================

class BiometricsUploadRequest(BaseRequest):
    """Request model for uploading biometrics data using the Biometrics schema"""
    data: Biometrics

class BiometricsUploadResponse(ApiResponse):
    """Response model for biometrics upload"""
    metrics_received: List[str]


# ==================== WORKOUT ENDPOINTS ====================

class WorkoutUploadRequest(BaseRequest):
    """Request model for uploading a single workout using the RecentWorkout schema"""
    workout: RecentWorkout

class WorkoutUploadResponse(ApiResponse):
    """Response model for workout upload"""
    workout_id: str


class WorkoutsUploadRequest(BaseRequest):
    """Request model for uploading multiple workouts using the RecentWorkout schema"""
    workouts: List[RecentWorkout]


class WorkoutsUploadResponse(ApiResponse):
    """Response model for multiple workouts upload"""
    workout_count: int
    workout_ids: List[str]


# ==================== ACTIVITY ENDPOINTS ====================

class ActivityUploadRequest(BaseRequest):
    """Request model for uploading daily activity data using the Activity schema"""
    activities: List[Activity]

class ActivityUploadResponse(ApiResponse):
    """Response model for activity upload"""
    activity_count: int


# ==================== SLEEP ENDPOINTS ====================

class SleepUploadRequest(BaseRequest):
    """Request model for uploading sleep data"""
    sleep_sessions: List[SleepEntry]

class SleepUploadResponse(ApiResponse):
    """Response model for sleep upload"""
    sleep_count: int


# ==================== NUTRITION ENDPOINTS ====================

class NutritionUploadRequest(BaseRequest):
    """Request model for uploading nutrition data"""
    nutrition_entries: List[NutritionEntry]

class NutritionUploadResponse(ApiResponse):
    """Response model for nutrition upload"""
    entry_count: int


# ==================== API ENDPOINTS SUMMARY ====================

"""
API Endpoints:

1. User Management:
   - POST /users
     - Creates a new user
     - Request: UserCreateRequest (includes user_id)
     - Response: UserCreateResponse

2. Biometrics:
   - POST /biometrics
     - Uploads biometrics data (body composition, vital signs)
     - Request: BiometricsUploadRequest (includes user_id)
     - Response: BiometricsUploadResponse

3. Workouts:
   - POST /workouts
     - Uploads a single workout
     - Request: WorkoutUploadRequest (includes user_id)
     - Response: WorkoutUploadResponse

   - POST /workouts/batch
     - Uploads multiple workouts
     - Request: WorkoutsUploadRequest (includes user_id)
     - Response: WorkoutsUploadResponse

4. Activity:
   - POST /activities
     - Uploads daily activity data (steps, distance, etc.)
     - Request: ActivityUploadRequest (includes user_id)
     - Response: ActivityUploadResponse

5. Sleep:
   - POST /sleep
     - Uploads sleep data
     - Request: SleepUploadRequest (includes user_id)
     - Response: SleepUploadResponse

6. Nutrition:
   - POST /nutrition
     - Uploads nutrition data
     - Request: NutritionUploadRequest (includes user_id)
     - Response: NutritionUploadResponse
"""
