# Chat and Onboarding Modules

This directory contains modules for handling chat interactions with the LLM, including specialized flows like onboarding.

## Chat Class

The `Chat` class is the base class for handling conversations with the LLM. It manages:

- Message history
- Memory state
- Prompt formatting
- LLM interaction
- Response parsing
- Memory updates

### Basic Usage

```python
from backend.memory.schemas import CompactOverallMemory
from backend.prompts.chat import Chat

# Initialize with user memory
chat = Chat(
    memory=user_memory,
    model="deepseek",  # Default model, but can be changed
    task="chat"       # Default task
)

# Process user input and get response
response = chat.process_user_input("What workout should I do today?")

# Access response components
print(response.message)  # The LLM's response text
print(response.memory_updated)  # Whether memory was updated
print(response.token_count)  # Approximate completion token count
```

## Onboarding Class

The `Onboarding` class extends `Chat` to provide specialized functionality for onboarding new users. Key differences:

- Uses onboarding-specific system prompts focused on health and workout data collection
- Defaults to the Claude model (but can be changed)
- Adds support for presenting options to the user
- Specially formatted responses for memory updates (particularly health and workout plans)

### Onboarding Usage

```python
from backend.memory.schemas import CompactOverallMemory
from backend.prompts.chat import Onboarding

# Initialize with empty user memory
onboarding = Onboarding(
    memory=empty_memory,
    # Uses default "claude" model and "onboarding" task
)

# Start the onboarding process
response = onboarding.process_user_input("I want to start my fitness journey")

# Handle response with options
print(response.message)
if response.options:
    print("Options:")
    for option in response.options:
        print(f"- {option}")
```

## Response Format

Both classes return a `LLMResponse` object with:

- `message`: The text response from the LLM
- `memory_patch`: Optional list of memory update operations
- `memory_updated`: Boolean indicating successful memory update
- `options`: Optional list of options (for Onboarding)
- `token_count`: Approximate completion token count
- `prompt_tokens`: Approximate prompt token count

### Memory Updates

The `memory_patch` field uses JSON Patch format (RFC 6902) to update the user's memory. Common operations include:

```json
[
  {
    "op": "replace",
    "path": "/biometrics/body_composition/weight/current",
    "value": 75.5
  },
  {
    "op": "add",
    "path": "/workout_memory/workout_goals/current_goals/-",
    "value": { "goal": "Run 5k", "target_date": "2025-06-30" }
  },
  { "op": "remove", "path": "/path/to/remove" }
]
```

## Example

See `backend/examples/onboarding_example.py` for a complete example of using the Onboarding class. The example demonstrates:

1. Creating an empty memory for a new user
2. Initializing the onboarding process
3. Handling responses with options
4. Tracking memory updates

## System Prompts

The system prompts are defined in `system_prompts.py` and are selected based on the task type:

- `chat`: For regular conversations with existing users
- `onboarding`: For gathering health and workout information from new users

The onboarding prompts instruct the model to:

- Focus on gathering workout and health information
- Present options when appropriate
- Update memory with relevant health and workout data
- Think deeply about exercise patterns and goals
