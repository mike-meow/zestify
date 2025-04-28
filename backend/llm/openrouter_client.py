#!/usr/bin/env python3
"""
OpenRouter API Client

A client for interacting with the OpenRouter API to access various LLM models.
"""

import os
import json
import requests
from typing import Dict, List, Any, Optional, Union
import logging
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables from .env file
env_path = Path('.') / '.env'
load_dotenv(dotenv_path=env_path)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Model configuration
MODELS = {
    # Using Gemini 2.0 Flash Experimental as the default
    "gemini": "google/gemini-2.0-flash-exp:free",
    "gemini-pro": "google/gemini-2.5-pro-preview-03-25",  # Paid tier
    "gemini-flash": "google/gemini-2.5-flash-preview",    # Alternative option
    "gemini-thinking": "google/gemini-2.5-flash-preview:thinking",  # With thinking tokens
    "deepseek": "deepseek/deepseek-chat-v3-0324:free",
    "claude": "anthropic/claude-3-sonnet-20240229"
}

DEFAULT_MODEL = MODELS["deepseek"]

class OpenRouterClient:
    """Client for interacting with the OpenRouter API."""
    
    BASE_URL = "https://openrouter.ai/api/v1"
    
    def __init__(self, api_key: Optional[str] = None, model: Optional[str] = None):
        """
        Initialize the OpenRouter client.
        
        Args:
            api_key: OpenRouter API key. If not provided, will look for OPENROUTER_API_KEY in .env file.
            model: Model to use. If not provided, will use DEFAULT_MODEL.
        """
        # First try the provided API key, then .env file's OPENROUTER_API_KEY
        self.api_key = api_key or os.getenv("OPENROUTER_API_KEY")
        if not self.api_key:
            logger.warning("No API key provided. Please set OPENROUTER_API_KEY in your .env file or pass api_key.")
        
        # Convert model key to full OpenRouter model ID if needed
        if model in MODELS:
            self.default_model = MODELS[model]
        else:
            self.default_model = model or DEFAULT_MODEL
            
        logger.debug(f"Initialized with model ID: {self.default_model}")
        
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://github.com/zestify",  # Update with your app's URL
            "X-Title": "Zestify"  # Update with your app's name
        })
    
    def list_models(self) -> Dict[str, Any]:
        """
        List available models on OpenRouter.
        
        Returns:
            Dict containing available models and their information.
        """
        url = f"{self.BASE_URL}/models"
        
        try:
            response = self.session.get(url)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Error listing models: {e}")
            return {"error": str(e)}
    
    def chat_completion(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 2000,
        stream: bool = False,
        additional_params: Optional[Dict[str, Any]] = None
    ) -> Union[Dict[str, Any], requests.Response]:
        """
        Create a chat completion using OpenRouter.
        
        Args:
            messages: List of message objects with role and content.
            model: Model identifier to use. If None, uses the default model.
            temperature: Sampling temperature (0-1).
            max_tokens: Maximum tokens to generate.
            stream: Whether to stream the response.
            additional_params: Additional parameters to pass to the API.
            
        Returns:
            If stream=False, returns the API response as a dict.
            If stream=True, returns the Response object for streaming.
        """
        url = f"{self.BASE_URL}/chat/completions"
        
        # Determine which model to use, with proper ID conversion
        model_to_use = self.default_model
        if model is not None:
            # Convert the model name to its full ID if it's in our list
            if model in MODELS:
                model_to_use = MODELS[model]
            else:
                # Otherwise use it directly (assuming it's already a valid model ID)
                model_to_use = model
        
        logger.debug(f"Using OpenRouter model ID: {model_to_use}")
        
        payload = {
            "model": model_to_use,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": stream
        }

        logger.debug(f"Using model ID: {payload['model']}")
        
        # For debugging, limit the content display length in logs but show message count
        debug_messages = []
        for msg in messages:
            content = msg.get('content', '')
            content_preview = content[:100] + "..." if len(content) > 100 else content
            debug_messages.append({
                "role": msg.get('role', 'unknown'),
                "content_length": len(content),
                "content_preview": content_preview
            })
        
        logger.debug(f"Sending {len(messages)} messages to OpenRouter:")
        for i, msg in enumerate(debug_messages):
            logger.debug(f"  Message {i+1}: role={msg['role']}, length={msg['content_length']}")
            logger.debug(f"    Preview: {msg['content_preview']}")
        
        # Add any additional parameters
        if additional_params:
            payload.update(additional_params)
        
        try:
            logger.debug(f"Making API request to: {url}")
            if stream:
                response = self.session.post(url, json=payload, stream=True)
                response.raise_for_status()
                return response
            else:
                response = self.session.post(url, json=payload)
                
                # Log response status and headers before raising exception
                logger.debug(f"Response status code: {response.status_code}")
                logger.debug(f"Response headers: {response.headers}")
                
                # For 4xx/5xx responses, log more details
                if not response.ok:
                    logger.error(f"Error response: {response.status_code} {response.reason}")
                    try:
                        error_details = response.json()
                        logger.error(f"Error details: {json.dumps(error_details, indent=2)}")
                    except:
                        logger.error(f"Error response text: {response.text}")
                
                response.raise_for_status()
                return response.json()
        except requests.exceptions.RequestException as e:
            error_msg = str(e)
            logger.error(f"Error creating chat completion: {error_msg}")
            
            # Add more context to the error message
            if hasattr(e, 'response') and e.response is not None:
                try:
                    error_details = e.response.json()
                    logger.error(f"API error details: {json.dumps(error_details, indent=2)}")
                    error_msg = f"{error_msg} - {json.dumps(error_details)}"
                except:
                    if hasattr(e, 'response') and hasattr(e.response, 'text'):
                        logger.error(f"API error response: {e.response.text}")
                        error_msg = f"{error_msg} - {e.response.text}"
            
            return {"error": error_msg}
    
    def process_stream(self, response: requests.Response) -> str:
        """
        Process a streaming response from the API.
        
        Args:
            response: Streaming response from chat_completion.
            
        Returns:
            The complete generated text.
        """
        if not response or not hasattr(response, 'iter_lines'):
            logger.error("Invalid response object for streaming")
            return ""
        
        full_text = ""
        
        for line in response.iter_lines():
            if line:
                line_text = line.decode('utf-8')
                if line_text.startswith('data: '):
                    data_str = line_text[6:]  # Remove 'data: ' prefix
                    if data_str == "[DONE]":
                        break
                    
                    try:
                        data = json.loads(data_str)
                        if 'choices' in data and len(data['choices']) > 0:
                            delta = data['choices'][0].get('delta', {})
                            if 'content' in delta:
                                content = delta['content']
                                full_text += content
                                yield content  # Yield each chunk for real-time processing
                    except json.JSONDecodeError:
                        logger.warning(f"Could not parse JSON from stream: {data_str}")
        
        return full_text
    
    def create_health_prompt(
        self,
        user_query: str,
        user_profile: Dict[str, Any],
        health_data: Dict[str, Any],
        conversation_history: List[Dict[str, str]] = None
    ) -> List[Dict[str, str]]:
        """
        Create a prompt for health-related queries.
        
        Args:
            user_query: The user's question or request.
            user_profile: User profile information.
            health_data: Health data relevant to the query.
            conversation_history: Previous conversation messages.
            
        Returns:
            List of message objects to send to the chat completion API.
        """
        if conversation_history is None:
            conversation_history = []
        
        # System prompt with context
        system_prompt = {
            "role": "system",
            "content": f"""You are a health and fitness AI assistant. You have access to the user's health data and profile.
            
User Profile Summary:
- Name: {user_profile.get('name', 'User')}
- Age: {user_profile.get('age', 'Unknown')}
- Fitness Level: {user_profile.get('fitness_level', 'Unknown')}
- Primary Goal: {user_profile.get('goals', {}).get('primary_goal', 'Not specified')}

Your role is to provide personalized health and fitness guidance based on the user's data and goals.
Be supportive, informative, and evidence-based in your responses.
When making recommendations, consider the user's health conditions, preferences, and fitness level.
Focus on actionable advice that aligns with the user's goals.
"""
        }
        
        # Create the full message list
        messages = [system_prompt] + conversation_history + [
            {"role": "user", "content": user_query}
        ]
        
        return messages
    
    def create_workout_goal_prompt(
        self,
        user_profile: Dict[str, Any],
        workout_history: Dict[str, Any],
        conversation_history: List[Dict[str, str]] = None
    ) -> List[Dict[str, str]]:
        """
        Create a prompt specifically for workout goal setting.
        
        Args:
            user_profile: User profile information.
            workout_history: User's workout history and patterns.
            conversation_history: Previous conversation messages.
            
        Returns:
            List of message objects to send to the chat completion API.
        """
        if conversation_history is None:
            conversation_history = []
        
        # Extract relevant workout information
        recent_workouts = workout_history.get('recent_workouts', [])
        workout_patterns = workout_history.get('workout_patterns', {})
        current_goals = workout_history.get('workout_goals', {}).get('current_goals', [])
        
        # Create a summary of recent activity
        recent_activity_summary = ""
        for workout in recent_workouts[:3]:  # Last 3 workouts
            recent_activity_summary += f"- {workout.get('type', 'workout')} on {workout.get('date', 'unknown date')}: {workout.get('distance_meters', 0)/1000:.1f}km in {workout.get('duration_seconds', 0)//60} minutes\n"
        
        # System prompt with context
        system_prompt = {
            "role": "system",
            "content": f"""You are a health and fitness AI assistant focused on helping the user set and achieve workout goals.
            
User Profile:
- Name: {user_profile.get('name', 'User')}
- Age: {user_profile.get('age', 'Unknown')}
- Fitness Level: {user_profile.get('fitness_level', 'Unknown')}
- Health Conditions: {', '.join([c.get('condition', '') for c in user_profile.get('health_conditions', [])])}
- Preferred Activities: {', '.join([p.get('activity', '') for p in user_profile.get('preferences', {}).get('preferred_activities', [])])}

Recent Activity:
{recent_activity_summary}

Current Goals:
{', '.join([g.get('goal', 'None') for g in current_goals])}

Your task is to help the user set meaningful workout goals. Ask targeted questions to understand their preferences and aspirations.
Offer 2-3 specific goal options based on their fitness level and history.
Each goal should be SMART (Specific, Measurable, Achievable, Relevant, Time-bound).
Present options in a conversational way, making it easy for the user to choose.
"""
        }
        
        # Initial question to start the goal-setting conversation
        initial_question = {
            "role": "assistant",
            "content": """I'd like to help you set some meaningful workout goals. Based on your activity history and preferences, I have a few ideas, but first:

1. Are you looking to focus more on performance (like speed or distance), consistency (regular exercise habit), or specific fitness outcomes (strength, endurance, etc.)?

2. What timeframe are you thinking for your next goal? A few weeks, a couple of months, or longer term?

3. Is there a specific activity you'd like to focus on improving?"""
        }
        
        # Create the full message list
        messages = [system_prompt] + conversation_history
        
        # If there's no conversation history, add the initial question
        if not conversation_history:
            messages.append(initial_question)
        
        return messages


# Example usage
if __name__ == "__main__":
    # This is just for demonstration - in production, use environment variables
    client = OpenRouterClient()
    
    # List available models
    models = client.list_models()
    print("Available models:")
    for model in models.get('data', []):
        print(f"- {model.get('id')}: {model.get('name')}")
    
    # Example chat completion
    messages = [
        {"role": "system", "content": "You are a helpful health and fitness assistant."},
        {"role": "user", "content": "What's a good post-workout recovery routine?"}
    ]
    
    response = client.chat_completion(messages)
    if "error" not in response:
        print("\nResponse:")
        print(response.get('choices', [{}])[0].get('message', {}).get('content', 'No response'))
    else:
        print(f"\nError: {response.get('error')}")
