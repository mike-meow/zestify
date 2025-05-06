#!/usr/bin/env python3

import os
import logging
import click
from pathlib import Path
from dotenv import load_dotenv
from datetime import datetime

# Load environment variables from .env file
env_path = Path('.') / '.env'
load_dotenv(dotenv_path=env_path)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@click.group()
@click.version_option(version="0.1.0")
def cli():
    """Zestify - Your AI-powered wellness companion."""
    pass

@cli.command()
@click.option('--debug', is_flag=True, help='Show debug information and LLM outputs')
@click.option('--model', type=click.Choice([
    'gemini', 'gemini-pro', 'gemini-flash', 'gemini-thinking', 
    'deepseek', 'deepseek-v3', 'deepseek-r1', 'deepseek-r1-zero',
    'claude', 'claude-3.7-sonnet', 'claude-3.5-sonnet', 'claude-3-opus',
    'gpt-4', 'gpt-4o', 'gpt-4.1']),
    default='deepseek',
    help='LLM model to use for conversation (default: deepseek)')
def onboard(debug: bool, model: str) -> None:
    """
    [DEPRECATED] Start the onboarding process to create your wellness profile.

    This command is deprecated. Please use 'chat --onboarding' instead.
    """
    click.secho("This command is deprecated. Please use 'chat --onboarding' instead.", fg="yellow")
    click.secho("Example: zestify chat USER_ID --onboarding --model claude", fg="yellow")

@cli.command()
@click.option('--host', default='0.0.0.0', help='Host to bind the server to')
@click.option('--port', default=8000, type=int, help='Port to bind the server to')
@click.option('--log-level', default='info',
              type=click.Choice(['debug', 'info', 'warning', 'error', 'critical']),
              help='Log level for the server')
@click.option('--log-requests', is_flag=True, help='Log all requests to a file for replay')
@click.option('--log-file', default='request_log.jsonl', help='File to log requests to')
def server(host: str, port: int, log_level: str, log_requests: bool, log_file: str) -> None:
    """Start the local server for the Zestify Health AI app."""
    # Import the server main module
    from backend.services.server.main import start_server

    click.secho(f"Starting Zestify Health AI server at http://{host}:{port}", fg="green")
    if log_requests:
        click.secho(f"Request logging enabled. Logging to {log_file}", fg="blue")

    start_server(host=host, port=port, log_level=log_level, log_requests=log_requests, log_file=log_file)

@cli.command()
@click.argument('log_file', type=click.Path(exists=True, readable=True))
@click.option('--base-url', default='http://localhost:8000', help='Base URL of the server')
@click.option('--delay', default=0.0, type=float, help='Delay between requests in seconds')
def replay_requests(log_file: str, base_url: str, delay: float) -> None:
    """Replay requests from a log file to the server.

    LOG_FILE is the path to the request log file (in JSONL format).
    """
    import json
    import requests
    import time
    from datetime import datetime

    # Load requests from log file
    try:
        requests_data = []
        with open(log_file, 'r') as f:
            for line in f:
                try:
                    request_data = json.loads(line.strip())
                    requests_data.append(request_data)
                except json.JSONDecodeError:
                    click.secho(f"Error parsing line: {line}", fg="red")
                    continue
    except Exception as e:
        click.secho(f"Error loading log file: {e}", fg="red")
        return

    if not requests_data:
        click.secho("No requests found in log file", fg="yellow")
        return

    click.secho(f"Loaded {len(requests_data)} requests from {log_file}", fg="green")
    click.secho(f"Replaying to {base_url}", fg="blue")

    # Replay requests
    start_time = datetime.now()
    success_count = 0
    error_count = 0

    with click.progressbar(requests_data, label="Replaying requests") as bar:
        for i, request_data in enumerate(bar):
            method = request_data.get('method', 'GET')
            path = request_data.get('path', '/')
            query_params = request_data.get('query_params', {})
            body = request_data.get('body')

            # Build the URL
            url = f"{base_url}{path}"

            # Send the request
            try:
                if method == 'GET':
                    response = requests.get(url, params=query_params)
                elif method == 'POST':
                    response = requests.post(url, params=query_params, json=body)
                elif method == 'PUT':
                    response = requests.put(url, params=query_params, json=body)
                elif method == 'DELETE':
                    response = requests.delete(url, params=query_params)
                elif method == 'PATCH':
                    response = requests.patch(url, params=query_params, json=body)
                else:
                    click.secho(f"Unsupported method: {method}", fg="red")
                    error_count += 1
                    continue

                if 200 <= response.status_code < 300:
                    success_count += 1
                else:
                    error_count += 1
                    click.secho(f"Error {response.status_code} for {method} {url}: {response.text[:100]}", fg="red")
            except requests.RequestException as e:
                error_count += 1
                click.secho(f"Request error for {method} {url}: {e}", fg="red")

            # Add delay if specified
            if delay > 0:
                time.sleep(delay)

    # Print summary
    end_time = datetime.now()
    duration = (end_time - start_time).total_seconds()

    click.secho("\nSummary:", fg="blue")
    click.secho(f"  Total requests: {len(requests_data)}", fg="white")
    click.secho(f"  Successful: {success_count}", fg="green")
    click.secho(f"  Failed: {error_count}", fg="red" if error_count > 0 else "white")
    click.secho(f"  Duration: {duration:.2f} seconds", fg="white")

from datetime import datetime

@cli.command()
@click.argument('user_id')
@click.option('--workout-start-date', default=None, help='Start date (YYYY-MM-DD) for workout history overview (default: last year)')
@click.option('--compact', is_flag=True, help='Output a compact version suitable for LLM consumption, removing unnecessary metadata')
def memory_overview(user_id: str, workout_start_date: str, compact: bool):
    """Load and print a memory overview for the user."""
    from backend.memory.manager import OverviewMemoryManager
    import json
    try:
        mm = OverviewMemoryManager(user_id, workout_start_date=workout_start_date)

        if compact:
            # Get the compact memory representation for LLM consumption
            memory_data = mm.get_compact_memory()
            # Convert the Pydantic model to a dictionary
            memory_dict = memory_data.model_dump()
        else:
            # Get the full memory representation
            memory = mm.load_memory()
            memory_dict = memory.model_dump()

        def json_serial(obj):
            if isinstance(obj, datetime):
                return obj.isoformat()
            return str(obj)

        click.secho(json.dumps(memory_dict, indent=2, default=json_serial), fg="cyan")
    except Exception as e:
        click.secho(f"Error: {e}", fg="red")

@cli.command()
@click.argument('user_id')
@click.option('--debug', is_flag=True, help='Show debug information including token counts')
@click.option('--model', default=["deepseek"], multiple=True,
              help='LLM model(s) to use (can specify multiple models separated by spaces or multiple --model flags)')
@click.option('--onboarding', is_flag=True, help='Run in onboarding mode to gather user information')
def chat(user_id: str, debug: bool, model: tuple, onboarding: bool) -> None:
    """Start an interactive chat session with your AI health coach.

    You can specify multiple models to compare responses side by side.
    Examples:
      - Single model: chat user123 --model claude
      - Multiple models (space-separated): chat user123 --model "gpt-4o gpt-4.1 gemini-pro"
      - Multiple models (separate flags): chat user123 --model claude --model gpt-4o

    Available models:
      - deepseek: DeepSeek Chat v3 (default, good all-purpose model)
      - deepseek-v3: Full version of DeepSeek Chat v3
      - deepseek-r1: DeepSeek's advanced reasoning model
      - deepseek-r1-zero: Free version of DeepSeek R1 (experimental)
      
      - gemini: Google Gemini 2.0 Flash (fast, efficient)
      - gemini-pro: Google Gemini 2.5 Pro (more capable but costs credits)
      - gemini-flash: Google Gemini 2.5 Flash (balanced performance)
      - gemini-thinking: Gemini with thinking tokens (better reasoning)
      
      - claude: Anthropic Claude 3 Sonnet (excellent for detailed responses)
      - claude-3.7-sonnet: Latest Claude model with improved reasoning
      - claude-3.5-sonnet: Balanced Claude model with good performance
      - claude-3-opus: Most powerful Claude model (highest quality, higher cost)
        
      - gpt-4: OpenAI GPT-4 (powerful general-purpose model)
      - gpt-4o: OpenAI GPT-4o (optimized for speed and efficiency)
      - gpt-4.1: OpenAI GPT-4.1 (latest version with improved reasoning)

    Add the --onboarding flag to switch to onboarding mode, which focuses on gathering
    user information and setting up a fitness profile.
    """
    if not os.getenv("OPENROUTER_API_KEY"):
        click.secho("Error: OPENROUTER_API_KEY is not set in your .env file", fg="red")
        click.secho("Create a .env file with OPENROUTER_API_KEY=your_api_key", fg="yellow")
        return

    # Parse model input - handle both space-separated string and multiple --model flags
    valid_models = [
        'gemini', 'gemini-pro', 'gemini-flash', 'gemini-thinking', 
        'deepseek', 'deepseek-v3', 'deepseek-r1', 'deepseek-r1-zero',
        'claude', 'claude-3.7-sonnet', 'claude-3.5-sonnet', 'claude-3-opus',
        'gpt-4', 'gpt-4o', 'gpt-4.1'
    ]
    
    # Process the model parameter(s)
    models = []
    for m in model:
        # Split by spaces to handle space-separated list in each --model flag
        models.extend(m.split())
    
    # Default to deepseek if somehow no models were specified
    if not models:
        models = ['deepseek']
    
    # Validate models
    invalid_models = [m for m in models if m not in valid_models]
    if invalid_models:
        click.secho(f"Error: Invalid model(s): {', '.join(invalid_models)}", fg="red")
        click.secho(f"Valid models are: {', '.join(valid_models)}", fg="yellow")
        return

    if debug:
        # Set root logger to DEBUG for all components
        logging.getLogger().setLevel(logging.DEBUG)
        # Make sure our specific loggers are set to DEBUG as well
        logging.getLogger('backend').setLevel(logging.DEBUG)
        logger.setLevel(logging.DEBUG)
        logger.debug("Debug mode enabled - verbose logging activated")

    # Import necessary components
    from backend.prompts.chat import Chat, Onboarding, ChatRole
    from backend.memory.manager import OverviewMemoryManager
    import json
    from concurrent.futures import ThreadPoolExecutor

    try:
        # Initialize memory manager (this will create user dir if needed)
        click.secho(f"Initializing memory manager for user: {user_id}", fg="blue")
        mm = OverviewMemoryManager(user_id)

        # Load memory - This will now handle missing files/dirs gracefully
        click.secho("Loading memory...", fg="blue")
        try:
            memory = mm.load_memory()
        except Exception as load_err: # Catch broader errors during loading/validation
            logger.error(f"Critical error loading memory: {load_err}", exc_info=True)
            click.secho(f"Critical error loading memory: {load_err}. Exiting.", fg="red")
            return # Exit if loading fundamentally failed

        # Initialize one chat instance for each model
        chat_instances = {}
        model_colors = {
            'deepseek': 'blue',
            'deepseek-v3': 'blue',
            'deepseek-r1': 'cyan',
            'deepseek-r1-zero': 'cyan',
            'claude': 'magenta',
            'claude-3.7-sonnet': 'magenta',
            'claude-3.5-sonnet': 'bright_magenta',
            'claude-3-opus': 'bright_magenta',
            'gemini': 'green',
            'gemini-pro': 'bright_green',
            'gemini-flash': 'green',
            'gemini-thinking': 'bright_green',
            'gpt-4': 'yellow',
            'gpt-4o': 'bright_yellow',
            'gpt-4.1': 'yellow'
        }
        
        if onboarding:
            # Check if user profile exists, essential for onboarding
            if not memory.user_profile:
                 click.secho("Cannot start onboarding without a user profile. Please ensure user_id is available.", fg="red")
                 return
                 
            # For onboarding, only support a single model
            if len(models) > 1:
                click.secho("Onboarding mode only supports a single model. Using the first specified model.", fg="yellow")
                models = (models[0],)
                
            chat_instances[models[0]] = Onboarding(memory_manager=mm, model=models[0])
            mode_name = "Onboarding Mode"
            # ... (onboarding intro)
            click.secho("\n=== Health & Fitness Onboarding ===", fg="green", bold=True)
            click.secho("This session will help gather information to create your personalized fitness plan.", fg="green")
            click.secho("Answer the questions or type 'exit' to finish early.\n", fg="green")
            # Start with an initial greeting
            # Check if we need to provide initial context or just start
            initial_prompt = "Start onboarding" # Simple starting prompt
            if memory.user_profile.name:
                 initial_prompt = f"Start onboarding for {memory.user_profile.name}"

            initial_response = chat_instances[models[0]].chat(initial_prompt)
            click.secho(f"Coach: {initial_response.get('message', 'No response')}", fg="cyan")
            if 'options' in initial_response and initial_response['options']:
                 click.secho("\nOptions:", fg="yellow")
                 for i, option in enumerate(initial_response['options']):
                      click.secho(f"{i+1}. {option}", fg="yellow")

        else: # Regular chat mode
            for m in models:
                chat_instances[m] = Chat(memory_manager=mm, model=m, debug=debug)
            mode_name = "Chat Mode"
            
            if len(models) == 1:
                click.secho(f"AI Health Coach initialized using {models[0]} model. Type 'exit' or 'quit' to end the session.", fg="green")
            else:
                model_list = ", ".join(models)
                click.secho(f"AI Health Coach initialized with multiple models: {model_list}", fg="green")
                click.secho(f"Responses from all models will be shown side by side.", fg="green")
            
            click.secho("Type 'tokens' to see token counts for the last exchange.", fg="green")

        logger.info(f"Starting chat in {mode_name} with models: {', '.join(models)}")
        last_token_info = {}

        # Main chat loop
        while True:
            user_input = click.prompt("\nYou", prompt_suffix="> ", type=str)
            if user_input.lower() in ["exit", "quit", "q"]:
                break
                
            if user_input.lower() == "tokens" and last_token_info:
                click.secho("\nToken usage for last exchange:", fg="blue")
                for m, (prompt_tokens, completion_tokens) in last_token_info.items():
                    total_tokens = prompt_tokens + (completion_tokens or 0)
                    click.secho(f"  {m}:", fg=model_colors.get(m, 'white'))
                    click.secho(f"    Prompt tokens: {prompt_tokens}", fg="white")
                    click.secho(f"    Completion tokens: {completion_tokens or 'unknown'}", fg="white")
                    click.secho(f"    Total tokens: {total_tokens}", fg="white")
                continue

            # Get responses from all models in parallel
            responses = {}
            
            def get_response(model_name):
                try:
                    return model_name, chat_instances[model_name].chat(user_input)
                except Exception as e:
                    logger.error(f"Error from {model_name}: {str(e)}")
                    return model_name, {"message": f"Error: {str(e)}", "error": True}
            
            with ThreadPoolExecutor(max_workers=len(chat_instances)) as executor:
                future_responses = [executor.submit(get_response, m) for m in chat_instances]
                for future in future_responses:
                    model_name, response = future.result()
                    responses[model_name] = response
                    
                    # Store token counts for later display
                    if hasattr(response, 'token_counts'):
                        last_token_info[model_name] = response.token_counts
                    elif isinstance(response, dict) and 'token_counts' in response:
                        last_token_info[model_name] = response['token_counts']
            
            # Display responses
            if len(responses) == 1:
                # Single model mode - simple display
                model_name = list(responses.keys())[0]
                response = responses[model_name]
                
                # Extract message
                if hasattr(response, 'message'):
                    message = response.message
                else:
                    message = response.get('message', 'No response available')
                
                # Display the message
                click.secho(f"\nCoach ({model_name}): ", fg=model_colors.get(model_name, 'cyan'), nl=False)
                click.secho(f"{message}", fg="white")
                
                # Handle options for onboarding if present
                if onboarding:
                    # Check if response has options attribute or key
                    options = None
                    if hasattr(response, 'options'):
                        options = response.options
                    elif isinstance(response, dict) and 'options' in response:
                        options = response['options']

                    if options:
                        click.secho("\nOptions:", fg="yellow")
                        for i, option in enumerate(options):
                            click.secho(f"{i+1}. {option}", fg="yellow")

                # Show memory update notification if applicable
                memory_updated = False
                if hasattr(response, 'memory_updated'):
                    memory_updated = response.memory_updated
                elif isinstance(response, dict):
                    memory_updated = response.get('memory_updated', False)

                if onboarding and memory_updated:
                    click.secho("\n[Your profile has been updated]", fg="green")
            
            else:
                # Multi-model mode - display responses side by side with dividers
                click.secho("\n" + "="*80, fg="white")
                click.secho("MODEL RESPONSES:", fg="bright_white", bold=True)
                click.secho("="*80, fg="white")
                
                for model_name, response in responses.items():
                    # Extract message
                    if hasattr(response, 'message'):
                        message = response.message
                    else:
                        message = response.get('message', 'No response available')
                    
                    # Display the model name and response
                    click.secho(f"\n[{model_name}]", fg=model_colors.get(model_name, 'cyan'), bold=True)
                    click.secho("-"*80, fg="white")
                    click.secho(f"{message}", fg="white")
                    click.secho("-"*80, fg="white")
            
        # Onboarding summary display if applicable
        if onboarding:
            click.secho("\n=== Your Fitness Profile Summary ===", fg="green", bold=True)
            # Load the latest memory to get the updated profile
            updated_memory = mm.load_memory()
            # Use get_llm_view for a consistent summary
            summary_view = updated_memory.user_profile.get_llm_view() if updated_memory.user_profile else "Profile could not be fully loaded."
            click.secho(summary_view, fg="white")
            click.secho("\nOnboarding completed! You can continue chatting or type 'exit'.", fg="green", bold=True)

        click.secho("\nMemory has been saved automatically.", fg="green")

    except Exception as e:
        logger.error(f"Error in chat session: {str(e)}", exc_info=True)
        click.secho(f"Error: {str(e)}", fg="red")

@cli.command()
@click.option('--verbose', is_flag=True, help='Show detailed model information')
def list_models(verbose: bool):
    """List available models from OpenRouter and test connection."""
    from backend.llm.openrouter_client import OpenRouterClient, MODELS
    import json

    # First check our local model mapping
    click.secho("Local model mappings:", fg="blue")
    for model_key, model_id in MODELS.items():
        click.secho(f"  {model_key} -> {model_id}", fg="cyan")

    if not os.getenv("OPENROUTER_API_KEY"):
        click.secho("\nError: OPENROUTER_API_KEY is not set in your .env file", fg="red")
        click.secho("Create a .env file with OPENROUTER_API_KEY=your_api_key", fg="yellow")
        return

    click.secho("\nConnecting to OpenRouter API to fetch available models...", fg="blue")

    try:
        client = OpenRouterClient()
        models = client.list_models()

        if "error" in models:
            click.secho(f"Error connecting to OpenRouter: {models['error']}", fg="red")
            return

        if not models.get('data'):
            click.secho("No models found or unexpected response format", fg="yellow")
            if verbose:
                click.secho(f"Raw response: {json.dumps(models, indent=2)}", fg="yellow")
            return

        click.secho(f"\nFound {len(models['data'])} available models:", fg="green")

        for model in models['data']:
            model_id = model.get('id', 'unknown')
            model_name = model.get('name', 'Unnamed')

            in_our_models = False
            for key, value in MODELS.items():
                if value == model_id:
                    in_our_models = True
                    break

            color = "green" if in_our_models else "white"
            status = " (in app)" if in_our_models else ""
            click.secho(f"  {model_id}: {model_name}{status}", fg=color)

            if verbose:
                context_length = model.get('context_length', 'unknown')
                pricing = model.get('pricing', {})
                click.secho(f"    Context length: {context_length} tokens", fg="cyan")
                if pricing:
                    input_price = pricing.get('input', 0)
                    output_price = pricing.get('output', 0)
                    click.secho(f"    Pricing: ${input_price}/M input tokens, ${output_price}/M output tokens", fg="cyan")

    except Exception as e:
        click.secho(f"Error: {e}", fg="red")
        import traceback
        click.secho(traceback.format_exc(), fg="red")

def main():
    """Main entry point for the CLI."""
    try:
        cli()
    except Exception as e:
        click.secho(f"Error: {str(e)}", fg="red")
        # Use --debug for more detailed error information
        logger.error(f"CLI error: {str(e)}", exc_info=True)

if __name__ == "__main__":
    main()
