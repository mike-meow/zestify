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
@click.option('--model', type=click.Choice(['gemini', 'gemini-pro', 'gemini-thinking', 'deepseek', 'claude']), 
              default='deepseek',
              help='LLM model to use for conversation (default: deepseek)')
def onboard(debug: bool, model: str) -> None:
    """Start the onboarding process to create your wellness profile.
    
    Available models:
      - deepseek: DeepSeek Chat v3 (default, good all-purpose model)
      - gemini: Google Gemini 2.0 Flash (fast, efficient)
      - gemini-pro: Google Gemini 2.5 Pro (more capable but costs credits)
      - claude: Anthropic Claude 3 Sonnet (excellent for detailed responses)
    """
    if not os.getenv("OPENROUTER_API_KEY"):
        click.secho("Error: OPENROUTER_API_KEY is not set in your .env file", fg="red")
        return

    if debug:
        logger.setLevel(logging.DEBUG)

    # Import here to avoid circular imports
    from backend.services.onboarding import OnboardingConversation

    click.secho(f"Using {model} model for conversation", fg="blue")
    conversation = OnboardingConversation(debug=debug, model=model)
    conversation.run()

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
@click.option('--model', type=click.Choice(['gemini', 'gemini-pro', 'gemini-thinking', 'deepseek', 'claude']), 
              default='deepseek',
              help='LLM model to use for chat (default: deepseek)')
def chat(user_id: str, debug: bool, model: str) -> None:
    """Start an interactive chat session with your AI health coach.
    
    Available models:
      - deepseek: DeepSeek Chat v3 (default, good all-purpose model)
      - gemini: Google Gemini 2.0 Flash (fast, efficient)
      - gemini-pro: Google Gemini 2.5 Pro (more capable but costs credits)
      - claude: Anthropic Claude 3 Sonnet (excellent for detailed responses)
    """
    if not os.getenv("OPENROUTER_API_KEY"):
        click.secho("Error: OPENROUTER_API_KEY is not set in your .env file", fg="red")
        click.secho("Create a .env file with OPENROUTER_API_KEY=your_api_key", fg="yellow")
        return

    if debug:
        # Set root logger to DEBUG for all components
        logging.getLogger().setLevel(logging.DEBUG)
        # Make sure our specific loggers are set to DEBUG as well
        logging.getLogger('backend').setLevel(logging.DEBUG)
        logger.setLevel(logging.DEBUG)
        logger.debug("Debug mode enabled - verbose logging activated")

    # Import necessary components
    from backend.prompts.chat import Chat, ChatRole
    from backend.memory.manager import OverviewMemoryManager
    import json

    try:
        # Initialize memory
        click.secho(f"Loading memory for user: {user_id}", fg="blue")
        mm = OverviewMemoryManager(user_id)
        memory = mm.get_compact_memory()
        
        # Initialize chat with specified model
        chat = Chat(memory=memory, model=model)
        
        # Add a system message
        click.secho(f"AI Health Coach initialized using {model} model. Type 'exit' or 'quit' to end the session.", fg="green")
        click.secho("Type 'tokens' to see token counts for the last exchange.", fg="green")
        
        last_token_info = None
        
        # Main chat loop
        while True:
            # Get user input
            user_input = click.prompt("\nYou", prompt_suffix="> ", type=str)
            
            # Check for exit commands
            if user_input.lower() in ['exit', 'quit', 'bye']:
                click.secho("Goodbye!", fg="blue")
                break
                
            # Check for special commands
            if user_input.lower() == 'tokens':
                if last_token_info:
                    click.secho(f"Last exchange:", fg="cyan")
                    click.secho(f"  Prompt tokens: {last_token_info['prompt_tokens']}", fg="cyan")
                    click.secho(f"  Response tokens: {last_token_info['response_tokens']}", fg="cyan")
                    click.secho(f"  Total tokens: {last_token_info['total_tokens']}", fg="cyan")
                else:
                    click.secho("No token information available yet", fg="yellow")
                continue
                
            # Process user input
            try:
                start = datetime.now()
                # No need to specify model here since it's already set on the Chat instance
                response = chat.process_user_input(user_input, temperature=0.7)
                end = datetime.now()
                duration = (end - start).total_seconds()
                
                # Display response
                click.secho(f"\nCoach ({duration:.2f}s)", fg="green", bold=True)
                click.echo(response.message)
                
                # Save token info
                last_token_info = {
                    'prompt_tokens': response.prompt_tokens,
                    'response_tokens': response.token_count,
                    'total_tokens': (response.prompt_tokens or 0) + (response.token_count or 0)
                }
                
                # Show memory update if any
                if response.memory_updated:
                    click.secho(f"\n[Memory updated with {len(response.memory_patch)} operations]", fg="blue")
                    if debug:
                        for op in response.memory_patch:
                            path = op.get('path', '')
                            op_type = op.get('op', '')
                            value_preview = str(op.get('value', ''))[:30]
                            if len(str(op.get('value', ''))) > 30:
                                value_preview += "..."
                            click.secho(f"  {op_type} {path}: {value_preview}", fg="cyan")
            except Exception as e:
                click.secho(f"Error: {str(e)}", fg="red")

    except Exception as e:
        logger.error(f"Error in chat: {str(e)}")
        click.secho(f"Error: {e}", fg="red")
        if debug:
            import traceback
            click.secho(traceback.format_exc(), fg="red")

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
    """Entry point for the Zestify CLI."""
    cli()

if __name__ == "__main__":
    main()
