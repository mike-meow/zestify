# Health AI Memory System

This directory contains the memory templates for the Health AI application. The memory system is designed to be:

- **Structured**: Well-defined schemas for different types of health data
- **Composable**: Memory components can be combined as needed
- **Extensible**: Easy to add new memory types or extend existing ones
- **Flexible**: Supports partial updates and queries
- **LLM-friendly**: Easy conversion to YAML for token-efficient LLM interactions

## Memory Types

The system includes the following memory types:

- **User Profile**: Basic user information, preferences, and demographics
- **Health Metrics**: Anthropometric measurements, vital signs, and health conditions
- **Workout Memory**: Workout history, patterns, goals, and recommendations
- **Conversation Memory**: Conversation history, insights, and communication preferences
- **Medical History**: Medical conditions, medications, procedures, and visits
- **Biometrics**: Detailed biometric data from devices (heart rate, sleep, etc.)
- **Goals**: User's health and fitness goals with progress tracking

## Architecture

The memory system is built using Jsonnet for backend storage and processing, with conversion to YAML for LLM interactions:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  Jsonnet Files  │────▶│  Memory System  │────▶│  YAML for LLM   │
│  (Templates)    │     │  (Processing)   │     │  (Interactions) │
│                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Usage

### Basic Operations

The memory system supports these core operations:

1. **Compose Memory**: Combine multiple memory types for a comprehensive view
2. **Format Prompt**: Create LLM prompts with relevant memory context
3. **Call LLM**: Use the formatted prompt to get AI responses
4. **Process Results**: Extract structured data from LLM responses
5. **Update Memory**: Store new information in the appropriate memory components

### Example Flow

```python
# Import memory utilities
import memory_utils

# Compose memory for a user
memory = memory_utils.compose_memory("user_123", {
    "include_workouts": True,
    "recent_workouts_count": 5
})

# Format a prompt for the LLM
prompt = memory_utils.format_prompt(memory, "workout_recommendation", {
    "focus": "endurance"
})

# Call the LLM
llm_response = call_llm(prompt)

# Process the response
structured_data = process_llm_response(llm_response)

# Update the memory
updated_memory = memory_utils.update_memory(memory, structured_data)
```

## File Structure

- `base.jsonnet`: Core memory template structures and utilities
- `user_profile.jsonnet`: User profile memory template
- `health_metrics.jsonnet`: Health metrics memory template
- `workout_memory.jsonnet`: Workout memory template
- `conversation_memory.jsonnet`: Conversation memory template
- `medical_history.jsonnet`: Medical history memory template
- `biometrics.jsonnet`: Biometrics memory template
- `goals.jsonnet`: Goals memory template
- `schemas/`: JSON Schema files for validation
- `../memory_utils.jsonnet`: Utility functions for memory operations

## Implementation Details

### Jsonnet Features Used

- **Local variables**: For reusable components
- **Functions**: For memory operations and transformations
- **Inheritance**: For extending base templates
- **Composition**: For combining memory components
- **External variables**: For dynamic values like timestamps

### Memory Operations

- **Factory methods**: Create new memory instances
- **Update methods**: Modify existing memory
- **Conversion methods**: Transform memory for different formats (e.g., YAML)
- **Query methods**: Extract specific information from memory

## Adding New Memory Types

To add a new memory type:

1. Create a new Jsonnet file extending the base template
2. Define the memory structure and operations
3. Add factory and update methods
4. Add conversion methods for LLM interactions
5. Update the memory utilities to include the new type

## Converting Between Formats

The system supports conversion between formats:

- **Jsonnet to JSON**: For storage and processing
- **JSON to YAML**: For LLM interactions
- **YAML to JSON**: For processing LLM responses
- **JSON to Jsonnet**: For updating memory

## Example Usage

See the `../examples/` directory for example usage of the memory system.
