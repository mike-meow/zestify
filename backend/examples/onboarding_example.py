#!/usr/bin/env python3
"""
Example demonstrating the use of the Onboarding class for health and fitness onboarding.
This example shows how to:
1. Create an empty memory for a new user
2. Initialize the onboarding process
3. Handle responses with options
4. Track memory updates
"""

import json
import logging
import os
from datetime import datetime

from backend.memory.schemas import CompactOverallMemory, ChatHistory, UserProfile, Biometrics
from backend.memory.schemas import WorkoutMemory, MedicalHistory
from backend.prompts.chat import Onboarding

# Configure logging
logging.basicConfig(
    level=logging.INFO, 
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def create_empty_memory():
    """Create an empty memory object for a new user"""
    now = datetime.now()
    
    return CompactOverallMemory(
        user_profile=UserProfile(
            demographics={},
            preferences={},
        ),
        biometrics=Biometrics(
            body_composition={},
            vital_signs={},
        ),
        workout_memory=WorkoutMemory(
            workout_history={},
            workout_plans={},
            workout_goals={
                "current_goals": []
            },
            workout_preferences={},
        ),
        medical_history=MedicalHistory(
            conditions=[]
        ),
        chat_history=ChatHistory(
            conversations=[],
            last_interaction=now
        )
    )

def main():
    """Run the onboarding example"""
    # Create empty memory for a new user
    memory = create_empty_memory()
    
    # Create onboarding instance with default settings
    onboarding = Onboarding(
        memory=memory,
        # Uses default "claude" model and "onboarding" task
    )
    
    print("\n=== Health & Fitness Onboarding ===\n")
    
    # Initial message to start the onboarding process
    print("Starting onboarding process...")
    response = onboarding.chat("Hi, I'm new here and want to start my fitness journey")
    
    # Display the response
    print(f"\nCoach: {response.message}")
    
    # Display options if available
    if response.options:
        print("\nOptions:")
        for i, option in enumerate(response.options):
            print(f"{i+1}. {option}")
    
    print("\n--- Interactive Onboarding Session ---")
    print("Type your responses or 'quit' to exit")
    
    # Interactive onboarding loop
    while True:
        # Get user input
        user_input = input("\nYou: ")
        
        if user_input.lower() in ["exit", "quit", "q"]:
            break
        
        # Process user input
        response = onboarding.chat(user_input)
        
        # Display the response
        print(f"\nCoach: {response.message}")
        
        # Display options if available
        if response.options:
            print("\nOptions:")
            for i, option in enumerate(response.options):
                print(f"{i+1}. {option}")
        
        # Check if memory was updated
        if response.memory_updated:
            print("\n[Your profile has been updated with this information]")
    
    # At the end, display the collected information
    print("\n=== Collected User Information ===")
    
    # Get specific sections that are most relevant
    memory_dict = onboarding.memory.model_dump()
    
    # Show workout goals
    if memory_dict.get("workout_memory", {}).get("workout_goals", {}).get("current_goals"):
        print("\nYour Fitness Goals:")
        for goal in memory_dict["workout_memory"]["workout_goals"]["current_goals"]:
            print(f"- {goal.get('goal', 'Unknown goal')}")
    
    # Show workout preferences if they exist
    if memory_dict.get("workout_memory", {}).get("workout_preferences"):
        print("\nYour Workout Preferences:")
        preferences = memory_dict["workout_memory"]["workout_preferences"]
        for key, value in preferences.items():
            print(f"- {key}: {value}")
    
    # Show health conditions if they exist
    if memory_dict.get("medical_history", {}).get("conditions"):
        print("\nHealth Considerations:")
        for condition in memory_dict["medical_history"]["conditions"]:
            print(f"- {condition.get('name', 'Unknown condition')}")
    
    print("\nOnboarding completed! Your personalized fitness plan is ready.")

if __name__ == "__main__":
    main() 