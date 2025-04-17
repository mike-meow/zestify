#!/usr/bin/env python3

import os
import json
import datetime
import logging
from typing import Dict, Any, List, Optional, Tuple, Union
import uuid
from dotenv import load_dotenv
import click
from pydantic import BaseModel
import yaml  # Added PyYAML import

from backend.schemas.user_profile import UserProfile
from backend.prompts.onboarding_conversation import SYSTEM_PROMPT, ConversationTurn
from backend.services.openrouter_client import OpenRouterClient, MODELS

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

class ProfileUpdate(BaseModel):
    """Type for profile updates from LLM."""
    key: str
    value: Any

class QuestionResponse(BaseModel):
    """Type for LLM question responses."""
    next_question: ConversationTurn
    response_to_user: str
    profile_update: Optional[ProfileUpdate] = None

class OnboardingConversation:
    def __init__(self, debug: bool = False, model: str = 'gemini') -> None:
        """Initialize the conversation.

        Args:
            debug: Whether to show debug information
            model: The LLM model to use for conversation ('gemini' or 'deepseek')
        """
        # Map model names to OpenRouter model IDs
        model_mapping = {
            'gemini': 'google/gemini-2.0-flash-001',  # Changed to Flash model
            'deepseek': 'deepseek/deepseek-chat-v3-0324:free'
        }

        model_id = model_mapping.get(model)
        if not model_id:
            raise ValueError(f"Invalid model choice: {model}. Must be one of: {', '.join(model_mapping.keys())}")

        self.client = OpenRouterClient(model=model_id)
        self.debug = debug
        logger.info(f"Initializing new conversation session with {model} model")

        # Generate unique ID and timestamp for this user
        self.user_id = str(uuid.uuid4())
        self.timestamp = datetime.datetime.now().isoformat()

        # Initialize user profile from template
        self.user_profile = self._load_template("user_profile.yaml")

        # Initialize health metrics from template
        self.health_metrics = self._load_template("health_metrics.yaml")

        # Set core information in both templates
        self.user_profile.update({
            "user_id": self.user_id,
            "created_at": self.timestamp,
            "updated_at": self.timestamp
        })

        self.health_metrics.update({
            "user_id": self.user_id,
            "last_updated": self.timestamp
        })

        # Link the health metrics file in the user profile
        self.user_profile["health_metrics_file"] = f"health_metrics_{self.user_id}.yaml"

        logger.debug(f"Created new user profile with ID: {self.user_profile['user_id']}")
        self.conversation_history: List[Dict[str, str]] = []
        self.question_count = 0
        self.max_questions = 5

    def _load_template(self, template_name: str) -> Dict[str, Any]:
        """Load a template from the memory_templates directory."""
        # First try the new location (backend/memory_templates)
        template_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "memory_templates", template_name)
        if not os.path.exists(template_path):
            # Fall back to the old location (backend/services/memory_templates)
            template_path = os.path.join(os.path.dirname(__file__), "memory_templates", template_name)
        try:
            with open(template_path, 'r') as f:
                template = yaml.safe_load(f)
                # Remove comments
                if isinstance(template, dict):
                    self._clean_comments_from_dict(template)
                    return template
                else:
                    return {}
        except (FileNotFoundError, yaml.YAMLError) as e:
            logger.warning(f"Could not load template {template_name}: {str(e)}")
            return {}

    def _clean_comments_from_dict(self, data):
        """Remove comments from YAML template (entries starting with #)."""
        if not isinstance(data, dict):
            return

        # Process all items in the dictionary
        for key, value in list(data.items()):
            if isinstance(key, str) and key.startswith('#'):
                del data[key]
            elif isinstance(value, dict):
                self._clean_comments_from_dict(value)
            elif isinstance(value, list):
                for item in value:
                    if isinstance(item, dict):
                        self._clean_comments_from_dict(item)

    def update_profile(self, key: str, value: Any) -> None:
        """Update the user profile or health metrics with nested key support."""
        logger.debug(f"Updating profile field '{key}' with value: {value}")

        # Determine if this is a health metric or user profile field
        if key.startswith("health_metrics.") or key.startswith("vitals.") or key.startswith("measurements."):
            # This is a health metric - remove the prefix and update health_metrics
            if key.startswith("health_metrics."):
                key = key[14:]  # Remove "health_metrics." prefix
            self._update_nested_dict(self.health_metrics, key, value)
            self.health_metrics["last_updated"] = datetime.datetime.now().isoformat()

            # Special handling for certain health metrics to add to history
            if key.startswith("demographics.age"):
                self._update_health_metric_with_history("measurements.height.current", value)
            elif key.startswith("measurements.height"):
                self._update_health_metric_with_history("measurements.height.current", value)
            elif key.startswith("measurements.weight"):
                self._update_health_metric_with_history("measurements.weight.current", value)
        else:
            # This is a regular user profile field
            self._update_nested_dict(self.user_profile, key, value)
            self.user_profile["updated_at"] = datetime.datetime.now().isoformat()

            # Special handling for fitness-related fields to add to timeline
            if key == "fitness_level":
                # Also add to fitness timeline with timestamp
                if "fitness_timeline" not in self.user_profile or not self.user_profile["fitness_timeline"]:
                    self.user_profile["fitness_timeline"] = []

                self.user_profile["fitness_timeline"].append({
                    "timestamp": datetime.datetime.now().isoformat(),
                    "fitness_level": value,
                    "notes": "Initial onboarding assessment"
                })

            # Special handling for goals
            elif key == "primary_goal":
                # Add as an active goal
                if "goals" not in self.user_profile:
                    self.user_profile["goals"] = {"active": [], "completed": []}

                goal_id = str(uuid.uuid4())[:8]  # Short UUID for goal ID
                self.user_profile["goals"]["active"].append({
                    "id": goal_id,
                    "type": value,
                    "description": f"{value} goal from onboarding",
                    "created_at": datetime.datetime.now().isoformat(),
                    "target_date": (datetime.datetime.now() + datetime.timedelta(days=90)).isoformat(),  # 3 months by default
                    "metrics": [
                        {
                            "name": self._get_default_metric_for_goal(value),
                            "current": "",
                            "target": "",
                            "unit": self._get_default_unit_for_goal(value)
                        }
                    ]
                })

            # Special handling for workout preferences
            elif key == "workout_preference":
                # Add to workout locations
                if "preferences" not in self.user_profile:
                    self.user_profile["preferences"] = {}
                if "workout_locations" not in self.user_profile["preferences"]:
                    self.user_profile["preferences"]["workout_locations"] = []

                self.user_profile["preferences"]["workout_locations"].append({
                    "location": value,
                    "priority": 1,  # Primary preference
                    "added_at": datetime.datetime.now().isoformat()
                })

            # Special handling for time availability
            elif key.startswith("preferences.time_availability"):
                # Update the timestamp for time availability
                if "preferences" in self.user_profile and "time_availability" in self.user_profile["preferences"]:
                    self.user_profile["preferences"]["time_availability"]["updated_at"] = datetime.datetime.now().isoformat()

            # Special handling for motivation factors
            elif key == "motivation_factors" and isinstance(value, str):
                # Convert single value to list
                self.user_profile["motivation_factors"] = [value]

        logger.debug(f"Updated profile: {json.dumps(self.user_profile, indent=2)}")
        logger.debug(f"Updated health metrics: {json.dumps(self.health_metrics, indent=2)}")

    def _update_health_metric_with_history(self, metric_path: str, value: Any) -> None:
        """Add a value to a health metric and its history."""
        # Add current value
        self._update_nested_dict(self.health_metrics, metric_path, value)

        # Add to history
        history_path = metric_path.replace("current", "history")

        # Initialize path if it doesn't exist
        if not self._path_exists(self.health_metrics, history_path):
            self._ensure_path_exists(self.health_metrics, history_path)
            current_history = []
        else:
            current_history = self._get_value_at_path(self.health_metrics, history_path)
            if current_history is None:
                current_history = []

        # Add new history entry
        current_history.append({
            "value": value,
            "date": datetime.datetime.now().isoformat(),
            "source": "self-reported during onboarding"
        })

        # Update the history
        self._update_nested_dict(self.health_metrics, history_path, current_history)

    def _get_default_metric_for_goal(self, goal_type: str) -> str:
        """Get a default metric name for a goal type."""
        metrics = {
            "weight_loss": "weight",
            "muscle_gain": "muscle_mass",
            "endurance": "running_distance",
            "general_fitness": "workouts_per_week",
            "flexibility": "stretch_range"
        }
        return metrics.get(goal_type, "progress")

    def _get_default_unit_for_goal(self, goal_type: str) -> str:
        """Get a default unit for a goal type."""
        units = {
            "weight_loss": "kg",
            "muscle_gain": "kg",
            "endurance": "km",
            "general_fitness": "sessions",
            "flexibility": "cm"
        }
        return units.get(goal_type, "units")

    def _path_exists(self, data: Dict[str, Any], path: str) -> bool:
        """Check if a path exists in a nested dictionary."""
        keys = path.split('.')
        current = data

        for k in keys:
            if isinstance(current, dict) and k in current:
                current = current[k]
            else:
                return False

        return True

    def _get_value_at_path(self, data: Dict[str, Any], path: str) -> Any:
        """Get the value at a path in a nested dictionary."""
        keys = path.split('.')
        current = data

        for k in keys:
            if isinstance(current, dict) and k in current:
                current = current[k]
            else:
                return None

        return current

    def _ensure_path_exists(self, data: Dict[str, Any], path: str) -> None:
        """Ensure a path exists in a nested dictionary, creating it if needed."""
        keys = path.split('.')
        current = data

        for k in keys:
            if k not in current:
                current[k] = {}
            current = current[k]

    def _update_nested_dict(self, data: Dict[str, Any], key: str, value: Any) -> None:
        """Update a nested dictionary using dot notation for the key."""
        keys = key.split('.')
        current = data

        # Navigate to the nested location
        for k in keys[:-1]:
            if k not in current:
                current[k] = {}
            current = current[k]

        # Set the value
        current[keys[-1]] = value

    def format_choices(self, choices: Optional[List[Any]]) -> str:
        """Format choices for display."""
        if not choices:
            return ""
        return "\n".join(
            f"{i+1}. {choice.label}" + (f" - {choice.description}" if choice.description else "")
            for i, choice in enumerate(choices)
        )

    def validate_response(self, response: str, question: ConversationTurn) -> Tuple[bool, Any]:
        """Validate user response against question rules."""
        logger.debug(f"Validating response: {response} for question type: {question.response_type}")

        if question.response_type == "number":
            try:
                value = float(response)
                rules = question.validation_rules or {}
                if "min" in rules and value < rules["min"]:
                    logger.debug(f"Validation failed: value {value} below minimum {rules['min']}")
                    return False, f"Value must be at least {rules['min']}"
                if "max" in rules and value > rules["max"]:
                    logger.debug(f"Validation failed: value {value} above maximum {rules['max']}")
                    return False, f"Value must be at most {rules['max']}"
                logger.debug(f"Numeric validation passed: {value}")
                return True, value
            except ValueError:
                logger.debug("Validation failed: not a valid number")
                return False, "Please enter a valid number"

        elif question.response_type == "choice":
            try:
                idx = int(response) - 1
                if 0 <= idx < len(question.choices):
                    value = question.choices[idx].value
                    logger.debug(f"Choice validation passed: selected {value}")
                    return True, value
                logger.debug(f"Choice validation failed: index {idx} out of range")
                return False, "Please select a valid option"
            except ValueError:
                logger.debug("Choice validation failed: not a valid number")
                return False, "Please enter a number corresponding to your choice"

        logger.debug("Text validation passed")
        return True, response

    def get_next_question(self, current_profile: Dict[str, Any]) -> Optional[QuestionResponse]:
        """Get the next question from the LLM based on current profile."""
        logger.info("Getting next question from LLM")

        # Combine profile and health metrics for context
        combined_context = {
            "user_profile": self.user_profile,
            "health_metrics": self.health_metrics
        }

        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"Current user data: {json.dumps(combined_context)}"}
        ]

        logger.debug("Sending messages to LLM:")
        logger.debug(json.dumps(messages, indent=2))

        try:
            response = self.client.chat_completion(
                messages=messages,
                temperature=0.0,
                max_tokens=2000
            )

            if "error" in response:
                logger.error(f"LLM API error: {response['error']}")
                raise Exception(f"LLM API error: {response['error']}")

            # Print complete raw response
            click.secho("\nComplete OpenRouter Response:", fg="yellow")
            click.echo(json.dumps(response, indent=2))

            # Add more detailed logging
            logger.info("Response structure:")
            logger.info(f"Response type: {type(response)}")
            logger.info(f"Response keys: {response.keys() if isinstance(response, dict) else 'Not a dict'}")

            if isinstance(response, dict) and 'choices' in response:
                logger.info(f"Choices: {response['choices']}")
                if len(response['choices']) > 0:
                    logger.info(f"First choice: {response['choices'][0]}")
                    if 'message' in response['choices'][0]:
                        logger.info(f"Message content: {response['choices'][0]['message']}")

            logger.debug("Raw LLM response:")
            logger.debug(json.dumps(response, indent=2))

            content = response.get('choices', [{}])[0].get('message', {}).get('content', {})
            if self.debug:
                click.secho("\nLLM Response:", fg="blue")
                click.echo(json.dumps(content, indent=2))

            # Add detailed logging for content parsing
            logger.info("Content type before parsing:")
            logger.info(f"Type: {type(content)}")
            logger.info("Raw content:")
            logger.info(content)

            # If content is a string, try to parse it as JSON
            if isinstance(content, str):
                # Strip markdown code block if present
                content = content.strip()
                if content.startswith('```json'):
                    content = content[7:]  # Remove ```json prefix
                if content.startswith('```'):
                    content = content[3:]  # Remove ``` prefix
                if content.endswith('```'):
                    content = content[:-3]  # Remove ``` suffix
                content = content.strip()

                try:
                    content = json.loads(content)
                    logger.info("Successfully parsed content string to JSON")
                except json.JSONDecodeError as e:
                    logger.error(f"Failed to parse content as JSON: {e}")
                    logger.error(f"Content after stripping markdown: {content}")
                    raise
            elif not isinstance(content, dict):
                logger.error(f"Unexpected content type: {type(content)}")
                raise ValueError(f"Expected string or dict, got {type(content)}")

            logger.info("Attempting to parse into QuestionResponse")
            logger.info(f"Content structure: {json.dumps(content, indent=2)}")

            # Validate required fields before parsing
            required_fields = {'next_question', 'response_to_user'}
            missing_fields = required_fields - set(content.keys())
            if missing_fields:
                logger.error(f"Missing required fields: {missing_fields}")
                raise ValueError(f"Response missing required fields: {missing_fields}")

            # Validate next_question structure
            next_question = content.get('next_question', {})
            required_question_fields = {'question', 'response_type', 'profile_key'}
            missing_question_fields = required_question_fields - set(next_question.keys())
            if missing_question_fields:
                logger.error(f"Missing required next_question fields: {missing_question_fields}")
                raise ValueError(f"next_question missing required fields: {missing_question_fields}")

            try:
                return QuestionResponse.parse_obj(content)
            except Exception as e:
                logger.error(f"Failed to parse QuestionResponse: {str(e)}")
                logger.error(f"Expected structure: {QuestionResponse.schema_json(indent=2)}")
                raise

        except Exception as e:
            logger.error(f"Error getting next question: {str(e)}")
            raise

    def save_profile(self) -> None:
        """Save both the user profile and health metrics to YAML files."""
        profile_dir = "user_profiles"
        os.makedirs(profile_dir, exist_ok=True)

        # Save user profile
        user_yaml_filename = f"{profile_dir}/profile_{self.user_id}.yaml"
        with open(user_yaml_filename, 'w') as f:
            yaml.safe_dump(self.user_profile, f, default_flow_style=False, sort_keys=False)
        logger.info(f"Saved user profile to {user_yaml_filename}")

        # Save health metrics
        health_yaml_filename = f"{profile_dir}/health_metrics_{self.user_id}.yaml"
        with open(health_yaml_filename, 'w') as f:
            yaml.safe_dump(self.health_metrics, f, default_flow_style=False, sort_keys=False)
        logger.info(f"Saved health metrics to {health_yaml_filename}")

        # Print the profile
        click.secho("\nFinal User Profile:", fg="green")
        click.echo(yaml.safe_dump(self.user_profile, default_flow_style=False, sort_keys=False))

        click.secho("\nHealth Metrics:", fg="blue")
        click.echo(yaml.safe_dump(self.health_metrics, default_flow_style=False, sort_keys=False))

    def run(self) -> None:
        """Run the onboarding conversation."""
        logger.info("Starting onboarding conversation")
        click.secho("Welcome to Zestify! Let's create your personalized wellness profile.\n", fg="green")

        try:
            while self.question_count < self.max_questions:  # Add question limit
                # Get next question from LLM
                question_response = self.get_next_question(self.user_profile)
                if not question_response:
                    logger.info("No more questions from LLM")
                    break

                self.question_count += 1  # Increment question counter
                logger.info(f"Asking question {self.question_count} of {self.max_questions}")

                question = question_response.next_question
                if question_response.response_to_user:
                    click.echo(f"\n{question_response.response_to_user}")

                click.echo(f"\n{question.question}")
                if question.choices:
                    click.echo(self.format_choices(question.choices))

                while True:
                    response = click.prompt("\nYour answer").strip()
                    is_valid, value = self.validate_response(response, question)

                    if is_valid:
                        self.update_profile(question.profile_key, value)
                        # Update any additional profile fields suggested by LLM
                        if question_response.profile_update:
                            logger.debug(f"Applying LLM suggested profile update: {question_response.profile_update}")
                            self.update_profile(
                                question_response.profile_update.key,
                                question_response.profile_update.value
                            )
                        break
                    else:
                        click.secho(f"Error: {value}", fg="red")

            # Save and validate final profile
            logger.info("Finalizing user profile")
            try:
                # Attempt validation but don't require it
                UserProfile(**self.user_profile)
                logger.info("Profile validation successful")
            except Exception as e:
                # Log the validation error but continue with saving
                logger.warning(f"Profile validation failed: {str(e)}")
                logger.warning("Saving incomplete profile anyway")

            self.save_profile()  # Save the profile to file
            click.secho("\nProfile created successfully!", fg="green")

        except Exception as e:
            logger.error(f"Error during conversation: {str(e)}")
            click.secho(f"\nError: {str(e)}", fg="red")
            if self.debug:
                import traceback
                click.echo(traceback.format_exc())

@click.group()
@click.version_option(version="0.1.0")
def cli():
    """Zestify - Your AI-powered wellness companion."""
    pass

@cli.command()
@click.option('--debug', is_flag=True, help='Show debug information and LLM outputs')
@click.option('--model', type=click.Choice(['deepseek', 'gemini']), default='gemini',
              help='LLM model to use for conversation (default: gemini)')
def onboard(debug: bool, model: str) -> None:
    """Start the onboarding process to create your wellness profile."""
    if not os.getenv("OPENROUTER_API_KEY"):
        click.secho("Error: OPENROUTER_API_KEY environment variable is not set", fg="red")
        return

    if debug:
        logger.setLevel(logging.DEBUG)

    click.secho(f"Using {model} model for conversation", fg="blue")
    conversation = OnboardingConversation(debug=debug, model=model)
    conversation.run()

@cli.command()
@click.option('--host', default='0.0.0.0', help='Host to bind the server to')
@click.option('--port', default=8000, type=int, help='Port to bind the server to')
@click.option('--log-level', default='info',
              type=click.Choice(['debug', 'info', 'warning', 'error', 'critical']),
              help='Log level for the server')
def server(host: str, port: int, log_level: str) -> None:
    """Start the local server for the Zestify Health AI app."""
    from backend.services.server.main import start_server

    click.secho(f"Starting Zestify Health AI server at http://{host}:{port}", fg="green")
    start_server(host=host, port=port, log_level=log_level)

def main():
    """Entry point for the Zestify CLI."""
    cli()

if __name__ == "__main__":
    main()