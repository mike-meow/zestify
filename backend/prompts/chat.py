from typing import Dict, List, Optional, Any
from enum import Enum
from pydantic import BaseModel, Field, ConfigDict
import json
import logging
import os
import re
import jsonpatch
from datetime import datetime
import uuid

from backend.memory.schemas import OverallMemory
from backend.memory.manager import MemoryManager
from backend.llm.openrouter_client import OpenRouterClient, MODELS
from backend.prompts.system_prompts import get_system_prompt

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Default model to use if not specified
MODEL = os.environ.get("DEFAULT_MODEL", "gemini")

# Simple API error class
class ApiError(Exception):
    """Exception raised for API errors."""
    pass

class MemoryMessage(BaseModel):
    """Message model for storing in memory"""
    timestamp: str
    content: str
    sender: str
    message_type: str = "text"

class ChatRole(str, Enum):
    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM = "system"

class Message(BaseModel):
    role: str
    content: str

class LLMResponse(BaseModel):
    message: str
    memory_patch: Optional[List[Dict[str, Any]]] = None
    token_count: Optional[int] = None
    prompt_tokens: Optional[int] = None
    memory_updated: bool = False
    options: Optional[List[str]] = None  # Added for Onboarding responses

class Chat(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)

    memory_manager: MemoryManager
    messages: List[Message] = Field(default_factory=list)
    model: str = MODEL
    task: Optional[str] = None
    max_messages: int = 20
    debug: bool = False

    def __init__(self, **data):
        # Simple initialization - memory_manager is now required
        super().__init__(**data)


    @property
    def system_prompt(self) -> str:
        """Get the appropriate system prompt for the current model and task."""
        # Ensure task is not None before passing to get_system_prompt
        task = self.task or "general"
        return get_system_prompt(model=self.model, task=task)

    def _trim_messages(self) -> None:
        """Trim message history to keep only the most recent messages"""
        if len(self.messages) > self.max_messages:
            self.messages = self.messages[-self.max_messages:]

    def chat(self, user_input: str) -> LLMResponse:
        """
        Process a user input message and generate a response

        Args:
            user_input: The user's input message
            system_prompt: Optional system prompt to override default

        Returns:
            LLMResponse object containing the assistant's response and other metadata
        """
        # Memory view is now handled directly in format_prompt()

        formatted_messages = self.format_prompt()

        if self.debug:
            logger.debug(f"System prompt: {formatted_messages[0]['content']}")
            logger.debug(f"Token count for system prompt: {count_tokens(formatted_messages[0]['content'], self.model)}")
            return {}


        # Add the new user message
        formatted_messages.append({"role": "user", "content": user_input})

        # Add user message to history
        self.messages.append(Message(role="user", content=user_input))

        # Save to chat history
        self._add_to_chat_history("user", user_input)

        # Generate response using the appropriate model
        client = OpenRouterClient()
        result = client.chat_completion(
            model=self.model,
            messages=formatted_messages,
        )

        # Parse the LLM response to extract structured data
        parsed_response = self._parse_llm_response(result)

        # Add the assistant message to history
        self.messages.append(Message(role="assistant", content=parsed_response.message))

        # Apply memory patch if present
        if parsed_response.memory_patch:
            self.apply_memory_patch(parsed_response.memory_patch)

        logger.info(f"completion tokens: {result.get('usage', {}).get('completion_tokens', 0)}")


        self._add_to_chat_history("assistant", parsed_response.message)

        # Return the parsed response instead of the raw result
        # This ensures we return a consistent LLMResponse object
        return parsed_response


    def format_prompt(self) -> List[Dict[str, str]]:
        """
        Format the current conversation state into a prompt for the LLM using the new view.

        Returns:
            List of message dictionaries for the LLM API
        """
        # Get memory view using memory manager
        memory_view_str = self.memory_manager.get_memory_view()

        # Create system message with context using the view string
        system_message = {
            "role": "system",
            "content": f"{self.system_prompt}\n\nCURRENT STATE SUMMARY:\n{memory_view_str}"
        }

        # Format conversation messages
        formatted_messages = [
            {"role": msg.role, "content": msg.content}
            for msg in self.messages
        ]

        # Combine system message with conversation history
        return [system_message] + formatted_messages

    def apply_memory_patch(self, patch: List[Dict[str, Any]]) -> bool:
        """
        Apply a JSON patch to the memory using the memory manager.

        Args:
            patch: List of JSON Patch operations

        Returns:
            True if patch was successfully applied, False otherwise
        """
        if not patch:
            logger.info("No memory patch to apply")
            return False

        # Load current memory, apply patch, and save
        memory = self.memory_manager.load_memory()
        memory_dict = memory.model_dump()

        # Apply the patch
        updated_memory = self.memory_manager.apply_json_patch(memory_dict, patch)
        if updated_memory:
            self.memory_manager.save()
            return True
        return False



    def _parse_llm_response(self, result: Dict[str, Any]) -> LLMResponse:
        """
        Parse the LLM response to extract message, memory patch, and options.

        Args:
            result: The raw response from the LLM API

        Returns:
            LLMResponse with parsed components
        """
        # Default values
        memory_patch = None
        options = None

        # Extract the message content from the response
        message = result.get("choices", [{}])[0].get("message", {}).get("content", "I couldn't generate a response.")

        # Try to parse JSON response if the message contains JSON
        try:
            # Find JSON content in the response
            json_match = re.search(r'\{.*\}', message, re.DOTALL)

            if json_match:
                json_str = json_match.group(0)
                data = json.loads(json_str)

                if isinstance(data, dict):
                    # Extract message
                    if "message" in data:
                        message = data["message"]

                    # Extract and validate memory patch
                    if "memory_patch" in data and data["memory_patch"] is not None:
                        memory_patch = data["memory_patch"]

                        if not self._validate_memory_patch(memory_patch):
                            memory_patch = None

                    # Extract and validate options
                    if "options" in data and data["options"] is not None:
                        options = data["options"]

                        if not isinstance(options, list):
                            logger.warning("Options is not a list")
                            options = None
        except Exception as e:
            logger.warning(f"Failed to parse JSON response: {str(e)}")

        return LLMResponse(message=message, memory_patch=memory_patch, options=options)

    def _validate_memory_patch(self, memory_patch: Any) -> bool:
        """
        Validate that memory_patch has the correct format.

        Args:
            memory_patch: The memory patch to validate

        Returns:
            True if valid, False otherwise
        """
        if not isinstance(memory_patch, list):
            logger.warning("memory_patch is not a list")
            return False

        # Check each patch operation
        for patch_item in memory_patch:
            if not isinstance(patch_item, dict) or "op" not in patch_item or "path" not in patch_item:
                logger.warning("Invalid memory patch item format")
                return False

        return True

    def _add_to_chat_history(self, role: str, content: str) -> None:
        """
        Add a message to the chat history using the memory manager.

        Args:
            role: The role of the message sender ("user" or "coach")
            content: The message content
        """
        # Create a message object and add it to chat history via memory manager
        message = MemoryMessage(
            timestamp=datetime.now().isoformat(),
            content=content,
            sender=role,
            message_type="text"
        )
        self.memory_manager.add_message(message)


class Onboarding(Chat):
    """
    Specialized Chat class for onboarding new users.
    Focuses on gathering health and workout information with structured options.
    """
    model: str = "claude"  # Default model for onboarding
    task: str = "onboarding"  # Uses onboarding-specific prompts

    def chat(self, user_input: str, system_prompt: Optional[str] = None) -> LLMResponse:
        """
        Process user input specifically for onboarding, with focus on health and workout information.

        Args:
            user_input: The user's message
            system_prompt: Optional system prompt override

        Returns:
            LLMResponse object with the assistant's message and metadata
        """
        # Use the parent class implementation
        result = super().chat(user_input, system_prompt)

        # Log onboarding-specific information
        self._log_onboarding_updates(result)

        return result

    def _log_onboarding_updates(self, result: LLMResponse) -> None:
        """
        Log onboarding-specific information about memory updates and options.

        Args:
            result: The LLMResponse object to analyze
        """
        if hasattr(result, 'memory_updated') and result.memory_updated:
            logger.info("Memory updated during onboarding session")

def count_tokens(text: str, model: str = "gemini") -> int:
    """
    Estimate the number of tokens in a text string.
    Since tiktoken is not available, using fallback estimations.

    Args:
        text: The text to count tokens in
        model: The model name to determine tokenization strategy

    Returns:
        Estimated number of tokens in the text
    """
    try:
        # Fallback estimation based on model family
        if "gemini" in model:
            # Gemini: ~4 characters per token
            return max(1, int(len(text) / 4))
        else:
            # Others: ~1.3 tokens per word
            return max(1, int(len(text.split()) * 1.3))
    except Exception as e:
        logger.warning(f"Error counting tokens: {e}")
        # Very basic fallback
        return max(1, len(text) // 4)
