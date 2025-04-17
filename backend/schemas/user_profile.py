from enum import Enum
from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel, Field

class FitnessLevel(str, Enum):
    BEGINNER = "beginner"
    INTERMEDIATE = "intermediate"
    ADVANCED = "advanced"

class FitnessGoal(str, Enum):
    WEIGHT_LOSS = "weight_loss"
    MUSCLE_GAIN = "muscle_gain"
    ENDURANCE = "endurance"
    GENERAL_FITNESS = "general_fitness"
    FLEXIBILITY = "flexibility"

class WorkoutPreference(str, Enum):
    HOME = "home"
    GYM = "gym"
    OUTDOORS = "outdoors"
    HYBRID = "hybrid"

class TimeAvailability(BaseModel):
    preferred_time: str = Field(..., description="Preferred time of day for workouts")
    days_per_week: int = Field(..., ge=1, le=7, description="Number of days available for workouts")
    minutes_per_session: int = Field(..., ge=15, le=180, description="Minutes available per workout session")

class HealthMetrics(BaseModel):
    age: int = Field(..., ge=16, le=100)
    weight_kg: float = Field(..., ge=30, le=200)
    height_cm: float = Field(..., ge=100, le=250)
    resting_heart_rate: Optional[int] = Field(None, ge=40, le=200)
    injuries: List[str] = Field(default_factory=list)
    medical_conditions: List[str] = Field(default_factory=list)

class UserProfile(BaseModel):
    """User profile schema for Zestify."""
    user_id: str = Field(..., description="Unique identifier for the user")
    name: str = Field(..., min_length=1)
    fitness_level: FitnessLevel
    primary_goal: FitnessGoal
    secondary_goals: List[FitnessGoal] = Field(default_factory=list)
    workout_preference: WorkoutPreference
    time_availability: TimeAvailability
    health_metrics: HealthMetrics
    equipment_available: List[str] = Field(default_factory=list)
    preferred_activities: List[str] = Field(default_factory=list)
    motivation_factors: List[str] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: datetime = Field(default_factory=datetime.now) 