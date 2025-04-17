from backend.services.openrouter_client import OpenRouterClient, MODELS
from typing import List, Dict, Any, Optional
import json

class ConversationHandler:
    def __init__(self, user_id: str, debug: bool = False, model: str = 'gemini') -> None:
        """Initialize the conversation handler.
        
        Args:
            user_id: The ID of the user
            debug: Whether to show debug information
            model: The LLM model to use for conversation
        """
        self.user_id = user_id
        self.debug = debug
        self.client = OpenRouterClient(model=model)
        self.conversation_history: List[Dict[str, str]] = []

    def add_message_to_history(self, role: str, content: str) -> None:
        """Add a message to the conversation history.
        
        Args:
            role: The role of the message sender ('user' or 'assistant')
            content: The content of the message
        """
        self.conversation_history.append({
            "role": role,
            "content": content
        })

    def get_conversation_history(self) -> List[Dict[str, str]]:
        """Get the current conversation history.
        
        Returns:
            List of message dictionaries containing role and content
        """
        return self.conversation_history

    def clear_conversation_history(self) -> None:
        """Clear the conversation history."""
        self.conversation_history = []

    async def send_message(self, message: str) -> str:
        """Send a message and get a response from the model.
        
        Args:
            message: The message to send
            
        Returns:
            The model's response as a string
        """
        # Add user message to history
        self.add_message_to_history("user", message)
        
        try:
            # Get response from the model
            response = await self.client.chat_completion(
                messages=self.conversation_history
            )
            
            if self.debug:
                print(f"Debug - Raw response: {response}")
            
            # If response is a string, try to parse it as JSON
            if isinstance(response, str):
                try:
                    response = json.loads(response.strip())
                except json.JSONDecodeError as e:
                    if self.debug:
                        print(f"Debug - Failed to parse JSON: {e}")
                    # If JSON parsing fails, return the string as is
                    self.add_message_to_history("assistant", response)
                    return response
            
            # Handle dictionary response
            if isinstance(response, dict):
                if 'choices' in response and len(response['choices']) > 0:
                    if 'message' in response['choices'][0] and 'content' in response['choices'][0]['message']:
                        assistant_message = response['choices'][0]['message']['content']
                    else:
                        assistant_message = str(response['choices'][0])
                else:
                    # If it's a simple JSON object, return it as is
                    assistant_message = str(response)
                
                self.add_message_to_history("assistant", assistant_message)
                return assistant_message
            
            # If we get here, something unexpected happened
            error_message = "Failed to get a valid response from the model"
            if self.debug:
                print(f"Debug - Invalid response structure: {response}")
            raise ValueError(error_message)
                
        except Exception as e:
            error_message = f"Error during message processing: {str(e)}"
            if self.debug:
                print(f"Debug - Error: {error_message}")
            raise