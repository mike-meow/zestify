"""
API Definitions for Zestify Health AI Server

This file defines all API endpoints, request models, and response models for the Zestify Health AI server.
Each endpoint is focused on a specific type of health data.
"""

from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel, Field, field_validator
from enum import Enum


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

class BiometricMeasurement(BaseModel):
    """A single biometric measurement with value, unit, and timestamp"""
    value: float
    unit: str
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())
    source: SourceType = SourceType.MANUAL
    notes: Optional[str] = None


class BodyCompositionData(BaseModel):
    """Body composition data including weight, height, BMI, body fat, etc."""
    weight: Optional[BiometricMeasurement] = None
    height: Optional[BiometricMeasurement] = None
    bmi: Optional[BiometricMeasurement] = None
    body_fat_percentage: Optional[BiometricMeasurement] = None
    lean_body_mass: Optional[BiometricMeasurement] = None
    waist_circumference: Optional[BiometricMeasurement] = None


class VitalSignsData(BaseModel):
    """Vital signs data including heart rate, blood pressure, etc."""
    resting_heart_rate: Optional[BiometricMeasurement] = None
    blood_pressure_systolic: Optional[BiometricMeasurement] = None
    blood_pressure_diastolic: Optional[BiometricMeasurement] = None
    respiratory_rate: Optional[BiometricMeasurement] = None
    blood_oxygen: Optional[BiometricMeasurement] = None
    blood_glucose: Optional[BiometricMeasurement] = None
    body_temperature: Optional[BiometricMeasurement] = None


class BiometricsUploadRequest(BaseRequest):
    """Request model for uploading biometrics data"""
    body_composition: Optional[BodyCompositionData] = None
    vital_signs: Optional[VitalSignsData] = None


class BiometricsUploadResponse(ApiResponse):
    """Response model for biometrics upload"""
    metrics_received: List[str]


# ==================== WORKOUT ENDPOINTS ====================

class WorkoutType(str, Enum):
    """Type of workout"""
    RUNNING = "Running"
    WALKING = "Walking"
    CYCLING = "Cycling"
    SWIMMING = "Swimming"
    STRENGTH_TRAINING = "Strength Training"
    HIIT = "HIIT"
    YOGA = "Yoga"
    PILATES = "Pilates"
    DANCE = "Dance"
    HIKING = "Hiking"
    OTHER = "Other"


class WorkoutIntensity(str, Enum):
    """Intensity of workout"""
    LOW = "Low"
    MODERATE = "Moderate"
    HIGH = "High"
    VERY_HIGH = "Very High"


class WorkoutHeartRateSummary(BaseModel):
    """Summary of heart rate during workout"""
    average: Optional[float] = None
    min: Optional[float] = None
    max: Optional[float] = None
    unit: str = "bpm"


class WorkoutLocationPoint(BaseModel):
    """A single location point during a workout"""
    latitude: float
    longitude: float
    altitude: Optional[float] = None
    timestamp: str


class WorkoutData(BaseModel):
    """Workout data including type, duration, calories, etc."""
    id: Optional[str] = None  # Unique identifier for the workout
    workout_type: WorkoutType
    start_date: str  # ISO format timestamp
    end_date: str  # ISO format timestamp
    duration_seconds: float
    active_energy_burned: Optional[float] = None
    active_energy_burned_unit: Optional[str] = "kcal"
    distance: Optional[float] = None
    distance_unit: Optional[str] = "km"
    heart_rate_summary: Optional[WorkoutHeartRateSummary] = None
    intensity: Optional[WorkoutIntensity] = None
    source: SourceType = SourceType.APPLE_HEALTH
    notes: Optional[str] = None

    # Optional location data - can be large, so we might want to store separately
    # and reference by ID in the future
    location_points: Optional[List[WorkoutLocationPoint]] = None

    @field_validator('end_date')
    def end_date_after_start_date(cls, v, info):
        """Validate that end_date is after start_date"""
        data = info.data
        if 'start_date' in data and v < data['start_date']:
            raise ValueError('end_date must be after start_date')
        return v


class WorkoutUploadRequest(BaseRequest):
    """Request model for uploading a single workout"""
    workout: WorkoutData


class WorkoutUploadResponse(ApiResponse):
    """Response model for workout upload"""
    workout_id: str


class WorkoutsUploadRequest(BaseRequest):
    """Request model for uploading multiple workouts"""
    workouts: List[WorkoutData]


class WorkoutsUploadResponse(ApiResponse):
    """Response model for multiple workouts upload"""
    workout_count: int
    workout_ids: List[str]


# ==================== ACTIVITY ENDPOINTS ====================

class DailyActivityData(BaseModel):
    """Daily activity data including steps, distance, floors, etc."""
    date: str  # ISO format date (YYYY-MM-DD)
    steps: Optional[int] = None
    distance: Optional[float] = None
    distance_unit: Optional[str] = "km"
    floors_climbed: Optional[int] = None
    active_energy_burned: Optional[float] = None
    active_energy_burned_unit: Optional[str] = "kcal"
    stand_hours: Optional[int] = None
    exercise_minutes: Optional[int] = None
    source: SourceType = SourceType.APPLE_HEALTH


class ActivityUploadRequest(BaseRequest):
    """Request model for uploading daily activity data"""
    activities: List[DailyActivityData]


class ActivityUploadResponse(ApiResponse):
    """Response model for activity upload"""
    activity_count: int


# ==================== SLEEP ENDPOINTS ====================

class SleepStage(str, Enum):
    """Sleep stages"""
    AWAKE = "Awake"
    LIGHT = "Light"
    DEEP = "Deep"
    REM = "REM"
    UNSPECIFIED = "Unspecified"


class SleepStageData(BaseModel):
    """Data for a single sleep stage"""
    stage: SleepStage
    start_date: str  # ISO format timestamp
    end_date: str  # ISO format timestamp
    duration_seconds: float


class SleepData(BaseModel):
    """Sleep data including start time, end time, duration, etc."""
    id: Optional[str] = None  # Unique identifier for the sleep session
    start_date: str  # ISO format timestamp
    end_date: str  # ISO format timestamp
    duration_seconds: float
    source: SourceType = SourceType.APPLE_HEALTH
    sleep_stages: Optional[List[SleepStageData]] = None
    heart_rate_average: Optional[float] = None
    heart_rate_min: Optional[float] = None
    heart_rate_max: Optional[float] = None
    respiratory_rate_average: Optional[float] = None
    notes: Optional[str] = None

    @field_validator('end_date')
    def end_date_after_start_date(cls, v, info):
        """Validate that end_date is after start_date"""
        data = info.data
        if 'start_date' in data and v < data['start_date']:
            raise ValueError('end_date must be after start_date')
        return v


class SleepUploadRequest(BaseRequest):
    """Request model for uploading sleep data"""
    sleep_sessions: List[SleepData]


class SleepUploadResponse(ApiResponse):
    """Response model for sleep upload"""
    sleep_count: int


# ==================== NUTRITION ENDPOINTS ====================

class NutritionData(BaseModel):
    """Nutrition data including calories, macronutrients, etc."""
    id: Optional[str] = None  # Unique identifier for the meal
    date: str  # ISO format timestamp
    meal_type: Optional[str] = None  # Breakfast, Lunch, Dinner, Snack
    food_name: str
    calories: Optional[float] = None
    protein_grams: Optional[float] = None
    carbohydrates_grams: Optional[float] = None
    fat_grams: Optional[float] = None
    fiber_grams: Optional[float] = None
    sugar_grams: Optional[float] = None
    sodium_milligrams: Optional[float] = None
    serving_size: Optional[float] = None
    serving_unit: Optional[str] = None
    source: SourceType = SourceType.MANUAL
    notes: Optional[str] = None


class NutritionUploadRequest(BaseRequest):
    """Request model for uploading nutrition data"""
    nutrition_entries: List[NutritionData]


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
