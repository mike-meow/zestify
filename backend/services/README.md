# Health AI Services

This directory contains services for the Health AI application, including CLI commands, server endpoints, and utility functions.

## CLI Commands

The CLI provides a command-line interface to interact with the Health AI application. It includes commands for chatting with the AI coach, managing memory, and running the server.

### Chat Command

The chat command allows you to interact with the AI coach in either standard chat mode or onboarding mode.

```
python -m backend.services.cli chat USER_ID [OPTIONS]
```

Options:

- `--debug`: Show debug information including token counts
- `--model`: Choose the LLM model to use (default: deepseek)
  - Available models: deepseek, claude, gemini, gemini-pro, gemini-thinking
- `--onboarding`: Run in onboarding mode to gather user information

#### Chat Mode

In standard chat mode, the AI coach responds to your questions and requests about health and fitness.

Example:

```
python -m backend.services.cli chat user123 --model claude
```

#### Onboarding Mode

In onboarding mode, the AI coach guides you through a series of questions to create your fitness profile. It will ask about your health background, fitness goals, and workout preferences.

Example:

```
python -m backend.services.cli chat user123 --onboarding --model claude
```

Features of onboarding mode:

- Provides multiple-choice options when appropriate
- Focuses on gathering health and workout information
- Updates your profile with your responses
- Shows a summary of your profile at the end

### Other Commands

- `memory_overview`: View a user's memory
- `server`: Start the local server
- `replay_requests`: Replay requests from a log file
- `list_models`: List available LLM models

## Implementation Details

The CLI uses two primary classes from the `backend.prompts.chat` module:

1. `Chat`: Base class for standard chat interactions
2. `Onboarding`: Specialized class for gathering user information during onboarding

Both classes handle:

- Message history management
- Memory updates
- LLM interactions
- Response parsing

The `Onboarding` class extends `Chat` with additional features like:

- Support for presenting multiple-choice options
- Special handling for workout and health information
- More detailed logging of memory updates

## Usage Examples

Basic chat:

```
$ python -m backend.services.cli chat user123
Coach: How can I help you with your fitness journey today?
You> What's a good beginner workout?
Coach: For beginners, I recommend starting with a simple full-body routine...
```

Onboarding:

```
$ python -m backend.services.cli chat user123 --onboarding
=== Health & Fitness Onboarding ===
Coach: Welcome! I'd like to learn about your fitness goals. What's your primary reason for starting a fitness journey?

Options:
1. Weight loss
2. Build muscle
3. Improve endurance
4. General health
5. Specific sport training
```
