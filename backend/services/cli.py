#!/usr/bin/env python3

import os
import logging
import click

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
@click.option('--model', type=click.Choice(['deepseek', 'gemini']), default='gemini',
              help='LLM model to use for conversation (default: gemini)')
def onboard(debug: bool, model: str) -> None:
    """Start the onboarding process to create your wellness profile."""
    if not os.getenv("OPENROUTER_API_KEY"):
        click.secho("Error: OPENROUTER_API_KEY environment variable is not set", fg="red")
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

def main():
    """Entry point for the Zestify CLI."""
    cli()

if __name__ == "__main__":
    main()
