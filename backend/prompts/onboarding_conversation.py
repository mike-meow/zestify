from typing import Dict, List, Optional
from pydantic import BaseModel, Field

class ConversationChoice(BaseModel):
    label: str = Field(..., description="Display text for the choice")
    value: str = Field(..., description="Internal value for the choice")
    description: Optional[str] = Field(None, description="Optional description or context for the choice")

class ConversationTurn(BaseModel):
    question: str = Field(..., description="The question to ask the user")
    choices: Optional[List[ConversationChoice]] = Field(None, description="Optional list of choices for the user")
    response_type: str = Field(..., description="Expected type of response: choice, text, number, or datetime")
    profile_key: str = Field(..., description="The key in the user profile to update with the response")
    validation_rules: Optional[Dict] = Field(None, description="Optional validation rules for the response")

SYSTEM_PROMPT = """You are an AI fitness coach conducting an onboarding conversation with a new user. Your goal is to gather essential information to create their fitness profile while keeping the conversation engaging and natural. Follow these guidelines:

1. Ask one question at a time
2. Provide multiple-choice options whenever possible
3. Keep questions concise and clear
4. Maintain a friendly, professional tone
5. Respect user privacy and sensitivity around health information
6. Follow the structured output format exactly
7. Use proper field names that match our template structure

The system now uses two separate files: user_profile.yaml and health_metrics.yaml.
For health metrics, use the prefix "health_metrics." (e.g., "health_metrics.age").
The system will automatically route updates to the appropriate file.

Dynamic structure (values change over time):
- Fitness levels are tracked in fitness_timeline
- Goals are tracked in goals.active and goals.completed
- Workout preferences are tracked in preferences.workout_locations
- Health metrics are in a separate file with history tracking

For field paths, use:
- Core info: name
- Fitness: fitness_level (also auto-added to fitness_timeline)
- Goals: primary_goal (auto-converted to a goal object)
- Workout: workout_preference (auto-added to preferences.workout_locations)
- Health: health_metrics.demographics.age (or other health paths)
- Motivation: motivation_factors

For nested fields, use dot notation (e.g., "health_metrics.demographics.age" or "time_availability.preferred_time").

Your response MUST be a valid JSON object with the following structure:
{
    "next_question": {
        "question": "string",
        "choices": [{"label": "string", "value": "string", "description": "string"}] | null,
        "response_type": "choice" | "text" | "number" | "datetime",
        "profile_key": "string",
        "validation_rules": {} | null
    },
    "response_to_user": "string",
    "profile_update": {
        "key": "string",
        "value": "any"
    } | null
}

IMPORTANT:
1. The response must be a single JSON object, not a string or any other format
2. All fields must use double quotes for keys and string values
3. The next_question object must contain all required fields
4. The choices array must contain objects with label and value fields
5. The response_type must be one of: "choice", "text", "number", or "datetime"
6. The profile_key must be a valid dot-notation path for the user profile
7. The validation_rules object is optional and can be null
8. The profile_update object is optional and can be null
"""

ONBOARDING_QUESTIONS = [
    ConversationTurn(
        question="What's your name?",
        response_type="text",
        profile_key="name"
    ),
    ConversationTurn(
        question="What's your current fitness level?",
        choices=[
            ConversationChoice(
                label="Beginner",
                value="beginner",
                description="New to regular exercise or returning after a long break"
            ),
            ConversationChoice(
                label="Intermediate",
                value="intermediate",
                description="Exercise regularly with some experience"
            ),
            ConversationChoice(
                label="Advanced",
                value="advanced",
                description="Very experienced with consistent training"
            )
        ],
        response_type="choice",
        profile_key="fitness_level"
    ),
    ConversationTurn(
        question="What's your primary fitness goal?",
        choices=[
            ConversationChoice(label="Weight Loss", value="weight_loss"),
            ConversationChoice(label="Muscle Gain", value="muscle_gain"),
            ConversationChoice(label="Endurance", value="endurance"),
            ConversationChoice(label="General Fitness", value="general_fitness"),
            ConversationChoice(label="Flexibility", value="flexibility")
        ],
        response_type="choice",
        profile_key="primary_goal"
    ),
    ConversationTurn(
        question="Where do you prefer to work out?",
        choices=[
            ConversationChoice(label="At Home", value="home"),
            ConversationChoice(label="At the Gym", value="gym"),
            ConversationChoice(label="Outdoors", value="outdoors"),
            ConversationChoice(label="Mix of Locations", value="hybrid")
        ],
        response_type="choice",
        profile_key="workout_preference"
    ),
    ConversationTurn(
        question="How old are you?",
        response_type="number",
        profile_key="health_metrics.demographics.age",
        validation_rules={"min": 16, "max": 100}
    ),
    ConversationTurn(
        question="How many days per week can you commit to exercise?",
        response_type="number",
        profile_key="preferences.time_availability.days_per_week",
        validation_rules={"min": 1, "max": 7}
    ),
    ConversationTurn(
        question="How many minutes can you typically spend on a workout session?",
        response_type="number",
        profile_key="preferences.time_availability.minutes_per_session",
        validation_rules={"min": 15, "max": 180}
    ),
    ConversationTurn(
        question="What motivates you most to exercise?",
        choices=[
            ConversationChoice(label="Health Benefits", value="health"),
            ConversationChoice(label="Weight Management", value="weight"),
            ConversationChoice(label="Mental Wellbeing", value="mental_health"),
            ConversationChoice(label="Energy Levels", value="energy"),
            ConversationChoice(label="Appearance", value="appearance"),
            ConversationChoice(label="Social Aspects", value="social")
        ],
        response_type="choice",
        profile_key="motivation_factors"
    )
] 