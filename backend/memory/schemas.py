from pydantic import BaseModel, Field, root_validator
from typing import List, Optional, Dict, Any, Union
from datetime import datetime, date, timedelta

class UserInfo(BaseModel):
    user_id: str
    created_at: datetime
    updated_at: datetime

class HeartRateSummary(BaseModel):
    average: Optional[float]
    min: Optional[float]
    max: Optional[float]
    unit: Optional[str]

class CompactWorkout(BaseModel):
    workout_type: Optional[str] = None
    start_date: Optional[date] = None
    duration_minutes: Optional[float] = None
    distance: Optional[float] = None
    distance_unit: Optional[str] = None
    calories: Optional[float] = None

class RecentWorkout(CompactWorkout):
    id: Optional[str] = None
    start_date: Optional[datetime] = None  # Override with datetime type
    end_date: Optional[datetime] = None
    duration_seconds: Optional[float] = None
    active_energy_burned: Optional[float] = None
    active_energy_burned_unit: Optional[str] = None
    heart_rate_summary: Optional[Dict[str, Any]] = None
    source: Optional[str] = None
    
    def to_compact(self) -> CompactWorkout:
        """Convert to a compact version suitable for LLM consumption."""
        return CompactWorkout(
            workout_type=self.workout_type,
            start_date=self.start_date.date() if self.start_date else None,
            duration_minutes=round(self.duration_seconds / 60, 1) if self.duration_seconds else None,
            distance=self.distance,
            distance_unit=self.distance_unit,
            calories=self.active_energy_burned
        )

class WorkoutPatternFrequency(BaseModel):
    weekly_average: float = 0
    most_active_days: List[str] = []
    consistency_score: float = 0

class WorkoutPatternPreferredTimes(BaseModel):
    morning: float = 0
    afternoon: float = 0
    evening: float = 0

class WorkoutPattern(BaseModel):
    frequency: WorkoutPatternFrequency = WorkoutPatternFrequency()
    preferred_times: WorkoutPatternPreferredTimes = WorkoutPatternPreferredTimes()
    performance_trends: Dict[str, Any] = {}

class CompactWorkoutGoals(BaseModel):
    current_goals: List[str] = []
    completed_goals: List[str] = []

class WorkoutGoal(BaseModel):
    id: str
    description: Optional[str]
    status: Optional[str]
    created_at: Optional[datetime]
    completed_at: Optional[datetime]

class WorkoutGoals(BaseModel):
    current_goals: List[WorkoutGoal] = []
    completed_goals: List[WorkoutGoal] = []
    
    def to_compact(self) -> CompactWorkoutGoals:
        """Convert to a compact version suitable for LLM consumption."""
        return CompactWorkoutGoals(
            current_goals=[g.description for g in self.current_goals if g.description],
            completed_goals=[g.description for g in self.completed_goals if g.description]
        )

class CompactWorkoutMemory(BaseModel):
    recent_workouts: List[CompactWorkout] = []
    workout_patterns: WorkoutPattern 
    workout_goals: CompactWorkoutGoals

class WorkoutMemory(CompactWorkoutMemory):
    user_id: str
    last_updated: datetime
    recent_workouts: List[RecentWorkout] = []  # Override with RecentWorkout type
    workout_goals: WorkoutGoals = WorkoutGoals()  # Override with WorkoutGoals type
    
    def to_compact(self) -> CompactWorkoutMemory:
        """Convert to a compact version suitable for LLM consumption."""
        return CompactWorkoutMemory(
            recent_workouts=[w.to_compact() for w in self.recent_workouts],
            workout_patterns=self.workout_patterns,
            workout_goals=self.workout_goals.to_compact()
        )

class CompactActivity(BaseModel):
    date: date
    steps: int = 0
    distance: float = 0.0
    distance_unit: str = "km"
    active_energy_burned: float = 0.0
    exercise_minutes: int = 0

class Activity(CompactActivity):
    date: datetime  # Override with datetime type
    floors_climbed: int = 0
    active_energy_burned_unit: str = "kcal"
    move_minutes: int = 0
    source: str = "Apple Health"
    
    def to_compact(self) -> CompactActivity:
        """Convert to a compact version suitable for LLM consumption."""
        return CompactActivity(
            date=self.date.date(),
            steps=self.steps,
            distance=self.distance,
            distance_unit=self.distance_unit,
            active_energy_burned=self.active_energy_burned,
            exercise_minutes=self.exercise_minutes
        )

class CompactActivities(BaseModel):
    activities: List[CompactActivity] = []

class Activities(CompactActivities):
    activities: List[Activity] = []  # Override with Activity type

    @root_validator(pre=True)
    def handle_legacy_list(cls, values):
        # Accept a list directly (legacy format)
        if isinstance(values, list):
            return {"activities": values}
        # Accept dict with 'activities' key (new format)
        if isinstance(values, dict) and "activities" in values:
            return values
        # If dict but not wrapped, wrap it
        if isinstance(values, dict):
            return {"activities": [values]}
        return values
        
    def to_compact(self) -> CompactActivities:
        """Convert to a compact version suitable for LLM consumption."""
        return CompactActivities(
            activities=[a.to_compact() for a in self.activities]
        )

class CompactBodyComposition(BaseModel):
    weight: Optional[Dict[str, Any]] = None
    body_fat_percentage: Optional[Dict[str, Any]] = None

class BodyComposition(CompactBodyComposition):
    weight: Dict[str, Any] = {}  # Override with non-optional
    bmi: Dict[str, Any] = {}
    body_fat_percentage: Dict[str, Any] = {}  # Override with non-optional
    
    def to_compact(self) -> CompactBodyComposition:
        """Convert to a compact version suitable for LLM consumption."""
        weight_data = None
        if self.weight and "current" in self.weight:
            weight_data = {
                "current": self.weight["current"],
                "unit": self.weight.get("unit", "kg")
            }
            
        body_fat_data = None
        if self.body_fat_percentage and "current" in self.body_fat_percentage:
            body_fat_data = {
                "current": self.body_fat_percentage["current"],
                "unit": self.body_fat_percentage.get("unit", "percent")
            }
            
        return CompactBodyComposition(weight=weight_data, body_fat_percentage=body_fat_data)

class CompactBiometrics(BaseModel):
    body_composition: CompactBodyComposition

class Biometrics(CompactBiometrics):
    body_composition: BodyComposition = BodyComposition()  # Override with BodyComposition type
    # Add more fields as needed
    
    def to_compact(self) -> CompactBiometrics:
        """Convert to a compact version suitable for LLM consumption."""
        return CompactBiometrics(
            body_composition=self.body_composition.to_compact()
        )

class CompactDemographics(BaseModel):
    age: Optional[int] = None
    gender: Optional[str] = None
    height: Optional[float] = None
    weight: Optional[float] = None

class Demographics(CompactDemographics):
    birth_date: Optional[datetime] = None
    blood_type: Optional[str] = None
    
    def to_compact(self) -> CompactDemographics:
        """Convert to a compact version suitable for LLM consumption."""
        return CompactDemographics(
            age=self.age,
            gender=self.gender,
            height=self.height,
            weight=self.weight
        )

# Define Goal class for user profile goals
class Goal(BaseModel):
    id: str
    description: str
    category: Optional[str] = None
    target_date: Optional[date] = None
    status: str = "active"
    created_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

# Define Goals class to hold user goals by category
class Goals(BaseModel):
    fitness: List[Goal] = []
    nutrition: List[Goal] = []
    wellbeing: List[Goal] = []
    other: List[Goal] = []
    
    def to_compact(self) -> Dict[str, List[str]]:
        """Convert to a compact version with just descriptions."""
        return {
            "fitness": [g.description for g in self.fitness if g.description],
            "nutrition": [g.description for g in self.nutrition if g.description],
            "wellbeing": [g.description for g in self.wellbeing if g.description],
            "other": [g.description for g in self.other if g.description]
        }

class CompactUserProfile(BaseModel):
    name: Optional[str] = None
    demographics: Optional[CompactDemographics] = None
    goals: Optional[Dict[str, List[str]]] = None

class UserProfile(CompactUserProfile):
    user_id: str
    name: Optional[str] = None  # Repeat for clarity
    email: Optional[str]
    created_at: datetime
    updated_at: datetime
    demographics: Demographics = Demographics()  # Override with Demographics type
    goals: Goals = Field(default_factory=Goals)  # Properly typed goals
    
    def to_compact(self) -> CompactUserProfile:
        """Convert to a compact version suitable for LLM consumption."""
        # Create compact demographics only if there are values
        demographics = self.demographics.to_compact() if any([
            self.demographics.age,
            self.demographics.gender,
            self.demographics.height,
            self.demographics.weight
        ]) else None
        
        return CompactUserProfile(
            name=self.name,
            demographics=demographics,
            goals=self.goals.to_compact() if self.goals else None
        )

class WorkoutExercise(BaseModel):
    name: str
    sets: Optional[int] = None
    reps: Optional[int] = None
    duration: Optional[int] = None  # In seconds
    duration_unit: Optional[str] = "seconds"
    weight: Optional[float] = None
    weight_unit: Optional[str] = "kg"
    notes: Optional[str] = None

class WorkoutDay(BaseModel):
    day: str  # e.g., "Monday", "Tuesday", etc.
    focus: Optional[str] = None  # e.g., "Upper Body", "Cardio", etc.
    exercises: List[WorkoutExercise] = []
    notes: Optional[str] = None

class CompactWorkoutPlan(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    days: List[WorkoutDay] = []
    
    @classmethod
    def example(cls) -> 'CompactWorkoutPlan':
        """Provide an example workout plan structure for LLM reference."""
        return cls(
            name="4-Week Strength Building Plan",
            description="A progressive strength plan focusing on compound movements",
            start_date=date.today(),
            end_date=date.today().replace(month=date.today().month+1),
            days=[
                WorkoutDay(
                    day="Monday",
                    focus="Lower Body",
                    exercises=[
                        WorkoutExercise(name="Squats", sets=4, reps=8, weight=80, weight_unit="kg"),
                        WorkoutExercise(name="Lunges", sets=3, reps=12)
                    ]
                ),
                WorkoutDay(
                    day="Wednesday", 
                    focus="Upper Body",
                    exercises=[
                        WorkoutExercise(name="Bench Press", sets=4, reps=8),
                        WorkoutExercise(name="Pull-ups", sets=3, reps=10)
                    ]
                ),
                WorkoutDay(
                    day="Friday",
                    focus="Full Body",
                    exercises=[
                        WorkoutExercise(name="Deadlifts", sets=4, reps=6),
                        WorkoutExercise(name="Overhead Press", sets=3, reps=10)
                    ]
                )
            ]
        )

class WorkoutPlan(CompactWorkoutPlan):
    id: Optional[str] = None
    user_id: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    active: bool = True
    
    def to_compact(self) -> CompactWorkoutPlan:
        """Convert to a compact version suitable for LLM consumption."""
        return CompactWorkoutPlan(
            name=self.name,
            description=self.description,
            start_date=self.start_date,
            end_date=self.end_date,
            days=self.days
        )

class MedicalCondition(BaseModel):
    name: str = ""  # Default empty string instead of requiring non-null
    condition_type: str = "condition"  # condition, medication, allergy
    diagnosed_date: Optional[date] = None
    status: str = "template"  # active, resolved, managed, etc.
    feeling: Optional[str] = None
    
    # Medication-specific fields
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    purpose: Optional[str] = None
    
    notes: Optional[str] = None

class CompactMedicalHistory(BaseModel):
    conditions: List[MedicalCondition] = []
    
    @classmethod
    def example(cls) -> 'CompactMedicalHistory':
        """Provide an example medical history structure for LLM reference."""
        return cls(
            conditions=[
                MedicalCondition(
                    name="Asthma",
                    condition_type="condition",
                    diagnosed_date=date(2015, 5, 15),
                    status="managed",
                    feeling="Well controlled",
                    notes="Exercise-induced, requires inhaler before intense workouts"
                ),
                MedicalCondition(
                    name="Albuterol",
                    condition_type="medication",
                    dosage="90mcg",
                    frequency="As needed before exercise",
                    start_date=date(2015, 5, 20),
                    purpose="Asthma management",
                    status="active"
                ),
                MedicalCondition(
                    name="Peanuts",
                    condition_type="allergy",
                    status="active",
                    notes="Avoid all peanut products"
                ),
                # Empty template showing all possible fields
                MedicalCondition(
                    name="",
                    condition_type="",  # "condition", "medication", or "allergy"
                    diagnosed_date=None,  # Only for conditions
                    status="template",  # "active", "managed", "resolved", etc.
                    feeling=None,  # How the user feels about this condition
                    dosage=None,  # Only for medications
                    frequency=None,  # Only for medications
                    start_date=None,  # Only for medications
                    end_date=None,  # Only for medications
                    purpose=None,  # Only for medications
                    notes=None  # Additional information
                )
            ]
        )

class MedicalHistory(CompactMedicalHistory):
    user_id: Optional[str] = None
    last_updated: Optional[datetime] = None
    
    def __init__(self, **data):
        """Initialize with at least one example condition if empty."""
        super().__init__(**data)
        if not self.conditions:
            # Add a template condition that LLMs can use as reference
            self.conditions = [
                MedicalCondition(
                    name="Template Condition",
                    condition_type="condition",
                    status="template",
                    feeling="This is a template - replace with actual data",
                    notes="This is a template entry - replace with actual medical conditions, medications, or allergies"
                )
            ]
    
    def to_compact(self) -> CompactMedicalHistory:
        """Convert to a compact version suitable for LLM consumption."""
        # Filter out any template conditions when converting to compact
        conditions = [c for c in self.conditions if c.status != "template"]
        
        # If there are no conditions, add an empty template condition
        if not conditions:
            conditions = [
                MedicalCondition(
                    name="",
                    condition_type="",
                    status="template",
                    feeling=None,
                    diagnosed_date=None,
                    dosage=None,
                    frequency=None,
                    start_date=None,
                    end_date=None,
                    purpose=None,
                    notes=None
                )
            ]
            
        # Return with conditions list
        return CompactMedicalHistory(
            conditions=conditions
        )

class ChatMessage(BaseModel):
    sender: str  # "user" or "coach"
    content: str
    timestamp: datetime = Field(default_factory=datetime.now)
    message_type: str = "text"  # text, image, etc.
    metadata: Optional[Dict[str, Any]] = None

class CompactChatHistory(BaseModel):
    conversations: List[Dict[str, Any]] = []  # List of chat message dictionaries
    last_interaction: Optional[datetime] = None
    
    @classmethod
    def example(cls) -> 'CompactChatHistory':
        """Provide an example chat history structure for LLM reference."""
        now = datetime.now()
        yesterday = now - timedelta(days=1)
        return cls(
            conversations=[
                {
                    "sender": "user",
                    "content": "I've been experiencing some knee pain after my runs lately.",
                    "timestamp": yesterday,
                    "message_type": "text"
                },
                {
                    "sender": "coach",
                    "content": "I'm sorry to hear about your knee pain. How long has this been happening? Have you changed anything in your running routine recently?",
                    "timestamp": yesterday,
                    "message_type": "text"
                },
                {
                    "sender": "user",
                    "content": "It started about a week ago. I did increase my mileage from 20 to 25 miles per week.",
                    "timestamp": yesterday,
                    "message_type": "text"
                }
            ],
            last_interaction=now
        )

class ChatHistory(CompactChatHistory):
    user_id: Optional[str] = None
    
    def to_compact(self) -> CompactChatHistory:
        """Convert to a compact version suitable for LLM consumption."""
        # Return the most recent 10 messages to provide context without overwhelming
        recent_conversations = self.conversations[-10:] if len(self.conversations) > 10 else self.conversations
        return CompactChatHistory(
            conversations=recent_conversations,
            last_interaction=self.last_interaction
        )

class CompactOverallMemory(BaseModel):
    workout_memory: Optional[CompactWorkoutMemory] = None
    activities: Optional[CompactActivities] = None
    biometrics: Optional[CompactBiometrics] = None
    user_profile: Optional[CompactUserProfile] = None
    workout_plan: Optional[CompactWorkoutPlan] = None
    medical_history: Optional[CompactMedicalHistory] = None
    chat_history: Optional[CompactChatHistory] = None

class OverallMemory(CompactOverallMemory):
    user_info: Optional[UserInfo] = None
    workout_memory: Optional[WorkoutMemory] = None  # Override with WorkoutMemory type
    activities: Optional[Activities] = None  # Override with Activities type
    biometrics: Optional[Biometrics] = None  # Override with Biometrics type
    user_profile: Optional[UserProfile] = None  # Override with UserProfile type
    workout_plan: Optional[WorkoutPlan] = Field(default_factory=WorkoutPlan)  # Initialize with empty instance
    medical_history: Optional[MedicalHistory] = Field(default_factory=MedicalHistory)  # Initialize with empty instance
    chat_history: Optional[ChatHistory] = Field(default_factory=ChatHistory)  # Initialize with empty instance
    # Add other memory sections as needed

    @classmethod
    def from_user_dir(cls, user_dir: str) -> 'OverallMemory':
        import os
        import json
        memory = {}
        for fname in os.listdir(user_dir):
            if fname.endswith('.json'):
                path = os.path.join(user_dir, fname)
                with open(path, 'r') as f:
                    key = fname.replace('.json', '')
                    memory[key] = json.load(f)
        return cls.model_validate(memory)
        
    def to_compact(self) -> CompactOverallMemory:
        """Convert to a compact version suitable for LLM consumption."""
        return CompactOverallMemory(
            workout_memory=self.workout_memory.to_compact() if self.workout_memory else None,
            activities=None,  # Omit activities data to reduce memory size
            biometrics=self.biometrics.to_compact() if self.biometrics else None,
            user_profile=self.user_profile.to_compact() if self.user_profile else None,
            workout_plan=self.workout_plan.to_compact() if self.workout_plan else None,
            medical_history=self.medical_history.to_compact() if self.medical_history else CompactMedicalHistory(conditions=[]),
            chat_history=self.chat_history.to_compact() if self.chat_history else None
        )