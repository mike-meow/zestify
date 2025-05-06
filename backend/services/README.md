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
  - Available models: deepseek, deepseek-v3, deepseek-r1, deepseek-r1-zero, claude, claude-3.7-sonnet, claude-3.5-sonnet, claude-3-opus, gemini, gemini-pro, gemini-flash, gemini-thinking, gpt-4, gpt-4o, gpt-4.1
  - You can specify multiple models to compare responses side by side:
    - Using space-separated list: `--model "gpt-4o gpt-4.1 gemini-pro"`
    - Using multiple flags: `--model claude --model gpt-4o`
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

Multi-model comparison:

```
$ python -m backend.services.cli chat user123 --model "gpt-4o gpt-4.1"
AI Health Coach initialized with multiple models: gpt-4o, gpt-4.1
Responses from all models will be shown side by side.

You> What's the best way to build endurance?

================================================================================
MODEL RESPONSES:
================================================================================

[gpt-4o]
--------------------------------------------------------------------------------
The best way to build endurance involves a progressive, multi-faceted approach:

1. Start with a baseline assessment to understand your current fitness level.

2. Implement a consistent cardio program that includes:
   - Low-intensity steady-state (LISS) training (60-70% max heart rate) for building aerobic base
   - High-intensity interval training (HIIT) for improving VO2 max and lactate threshold
   - Tempo workouts at moderate intensity (70-80% max heart rate)

3. Follow the principle of progressive overload by gradually increasing:
   - Duration (time or distance)
   - Frequency (sessions per week)
   - Intensity (pace or resistance)

4. Cross-train with different activities like running, cycling, swimming, or rowing to develop well-rounded endurance and prevent overuse injuries.

5. Include strength training 2-3 times weekly, focusing on functional movements and core stability.

6. Pay attention to proper nutrition and hydration to fuel your workouts and recovery.

7. Ensure adequate recovery through proper sleep, rest days, and active recovery.

8. Consider periodization in your training schedule with defined build and recovery phases.

Remember that building endurance is a gradual process that requires consistency over time. Progress should be measured in weeks and months, not days.
--------------------------------------------------------------------------------

[gpt-4.1]
--------------------------------------------------------------------------------
The best way to build endurance involves a progressive, multi-faceted approach:

1. Start with a baseline assessment to understand your current fitness level.

2. Implement a consistent cardio program that includes:
   - Low-intensity steady-state (LISS) training (60-70% max heart rate) for building aerobic base
   - High-intensity interval training (HIIT) for improving VO2 max and lactate threshold
   - Tempo workouts at moderate intensity (70-80% max heart rate)

3. Follow the principle of progressive overload by gradually increasing:
   - Duration (time or distance)
   - Frequency (sessions per week)
   - Intensity (pace or resistance)

4. Cross-train with different activities like running, cycling, swimming, or rowing to develop well-rounded endurance and prevent overuse injuries.

5. Include strength training 2-3 times weekly, focusing on functional movements and core stability.

6. Pay attention to proper nutrition and hydration to fuel your workouts and recovery.

7. Ensure adequate recovery through proper sleep, rest days, and active recovery.

8. Consider periodization in your training schedule with defined build and recovery phases.

Remember that building endurance is a gradual process that requires consistency over time. Progress should be measured in weeks and months, not days.
--------------------------------------------------------------------------------
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
