#!/usr/bin/env python3
"""
Example of using the memory system for onboarding.
This demonstrates how to:
1. Initialize empty memories
2. Format a prompt for LLM
3. Process user responses
4. Update memories
"""

import os
import json
import yaml
import datetime
import subprocess
from pathlib import Path

# Set up paths
REPO_ROOT = Path(__file__).parent.parent.parent
# Try the new location first
MEMORY_TEMPLATES_DIR = REPO_ROOT / "memory_templates"
if not MEMORY_TEMPLATES_DIR.exists():
    # Fall back to the old location
    MEMORY_TEMPLATES_DIR = REPO_ROOT / "services" / "memory_templates"
MEMORY_UTILS_PATH = REPO_ROOT / "services" / "memory_utils.jsonnet"

# Ensure jsonnet is installed
try:
    subprocess.run(["jsonnet", "--version"], check=True, capture_output=True)
except (subprocess.CalledProcessError, FileNotFoundError):
    print("Error: jsonnet is not installed or not in PATH.")
    print("Please install jsonnet: https://jsonnet.org/")
    exit(1)

def get_timestamp():
    """Get current timestamp in ISO format."""
    return datetime.datetime.now().isoformat()

def run_jsonnet(jsonnet_file, ext_vars=None):
    """Run jsonnet and return the result as a Python object."""
    if ext_vars is None:
        ext_vars = {}

    # Always include timestamp
    if 'timestamp' not in ext_vars:
        ext_vars['timestamp'] = get_timestamp()

    # Build command
    cmd = ["jsonnet"]
    for key, value in ext_vars.items():
        cmd.extend(["--ext-str", f"{key}={value}"])
    cmd.append(str(jsonnet_file))

    # Run jsonnet
    result = subprocess.run(cmd, check=True, capture_output=True, text=True)

    # Parse JSON output
    return json.loads(result.stdout)

def jsonnet_to_yaml(jsonnet_obj):
    """Convert jsonnet output to YAML string."""
    return yaml.dump(jsonnet_obj, sort_keys=False, default_flow_style=False)

def simulate_llm_call(prompt):
    """Simulate an LLM call for demonstration purposes."""
    print("\n=== LLM PROMPT ===")
    print(prompt)
    print("=== END PROMPT ===\n")

    # In a real implementation, this would call the LLM API
    # For demo purposes, we'll just return a hardcoded response
    return "What is your primary fitness goal for the next 3 months?"

def main():
    # Create a user ID for this session
    user_id = f"user_{int(datetime.datetime.now().timestamp())}"

    # Initialize empty memories by composing them
    memory_utils_code = f"""
    local utils = import '{MEMORY_UTILS_PATH}';
    utils.composeMemory('{user_id}')
    """

    # Save this to a temporary file
    temp_file = REPO_ROOT / "services" / "examples" / "temp_memory.jsonnet"
    with open(temp_file, 'w') as f:
        f.write(memory_utils_code)

    # Run jsonnet to get the initial memory
    memory = run_jsonnet(temp_file)

    # Convert to YAML for inspection
    memory_yaml = jsonnet_to_yaml(memory)
    print(f"Initial memory created for user {user_id}")

    # Simulate onboarding flow
    print("\n=== ONBOARDING FLOW ===")

    # Format prompt for first question
    prompt_code = f"""
    local utils = import '{MEMORY_UTILS_PATH}';
    local memory = {json.dumps(memory)};
    utils.formatPrompt(memory, 'onboarding_question', {{
        'stage': 'initial',
        'question_number': '1'
    }})
    """

    # Save this to a temporary file
    with open(temp_file, 'w') as f:
        f.write(prompt_code)

    # Run jsonnet to get the prompt
    prompt = run_jsonnet(temp_file)

    # Simulate LLM call
    llm_response = simulate_llm_call(prompt)
    print(f"LLM: {llm_response}")

    # Simulate user response
    user_response = "I want to improve my 5K running time and build more endurance."
    print(f"User: {user_response}")

    # Update memory with user response
    # In a real implementation, we might use the LLM to extract structured information
    # For demo purposes, we'll manually create an update

    # Create a goal based on the response
    goal_code = f"""
    local utils = import '{MEMORY_UTILS_PATH}';
    local goals = import '{MEMORY_TEMPLATES_DIR}/goals.jsonnet';

    // Create a new goal
    goals.newGoal(
        'fitness',
        'Improve 5K time',
        'Improve 5K running time and build more endurance',
        '{(datetime.datetime.now() + datetime.timedelta(days=90)).isoformat()}'
    )
    """

    # Save this to a temporary file
    with open(temp_file, 'w') as f:
        f.write(goal_code)

    # Run jsonnet to get the goal
    goal = run_jsonnet(temp_file)

    # Update the memory with the new goal
    update_code = f"""
    local utils = import '{MEMORY_UTILS_PATH}';
    local memory = {json.dumps(memory)};

    // Add the goal to memory
    local goal = {json.dumps(goal)};
    local updated_memory = memory + {{
        goals: memory.goals + {{
            active_goals: memory.goals.active_goals + [goal]
        }}
    }};

    // Also add a conversation record
    local conversation = {{
        id: "conv_" + std.substr(std.md5("{get_timestamp()}"), 0, 8),
        timestamp: "{get_timestamp()}",
        topic: "onboarding",
        summary: "Discussed fitness goals",
        key_points: [
            "User wants to improve 5K running time",
            "User wants to build more endurance"
        ],
        user_sentiment: "motivated",
        action_items: [
            "Create a running training plan",
            "Assess current endurance level"
        ],
        follow_up_required: true,
        follow_up_date: "{(datetime.datetime.now() + datetime.timedelta(days=1)).isoformat()}"
    }};

    updated_memory + {{
        conversations: memory.conversations + {{
            recent_conversations: [conversation] + memory.conversations.recent_conversations
        }}
    }}
    """

    # Save this to a temporary file
    with open(temp_file, 'w') as f:
        f.write(update_code)

    # Run jsonnet to get the updated memory
    updated_memory = run_jsonnet(temp_file)

    # Convert to YAML for LLM
    yaml_code = f"""
    local utils = import '{MEMORY_UTILS_PATH}';
    local memory = {json.dumps(updated_memory)};
    utils.toYaml(memory)
    """

    # Save this to a temporary file
    with open(temp_file, 'w') as f:
        f.write(yaml_code)

    # Run jsonnet to get the YAML
    yaml_obj = run_jsonnet(temp_file)
    yaml_str = jsonnet_to_yaml(yaml_obj)

    print("\n=== UPDATED MEMORY (YAML for LLM) ===")
    print(yaml_str)

    # Format prompt for next question
    prompt_code = f"""
    local utils = import '{MEMORY_UTILS_PATH}';
    local memory = {json.dumps(updated_memory)};
    utils.formatPrompt(memory, 'onboarding_question', {{
        'stage': 'goals',
        'question_number': '2'
    }})
    """

    # Save this to a temporary file
    with open(temp_file, 'w') as f:
        f.write(prompt_code)

    # Run jsonnet to get the prompt
    prompt = run_jsonnet(temp_file)

    # Simulate LLM call for next question
    llm_response = simulate_llm_call(prompt)
    print(f"\nLLM: {llm_response}")

    # Clean up temporary file
    os.remove(temp_file)

    print("\n=== END ONBOARDING FLOW ===")
    print(f"Memory system demonstration complete for user {user_id}")

if __name__ == "__main__":
    main()
