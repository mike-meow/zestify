from typing import Dict, List, Optional, Union, Any, Annotated
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

    memory: Union[Dict[str, Any], OverallMemory] = Field(default_factory=dict)
    messages: List[Message] = Field(default_factory=list)
    model: str = MODEL
    task: Optional[str] = None
    max_messages: int = 20
    debug: bool = False
    memory_manager: Optional[MemoryManager] = None

    def __init__(self, **data):
        super().__init__(**data)
        # Convert memory to dict if it's an OverallMemory object
        if isinstance(self.memory, OverallMemory):
            # Keep a reference to the original OverallMemory object
            self._memory_obj = self.memory
            # Convert to dict for backward compatibility
            self.memory = self._memory_obj.model_dump()

        # If we have user info but no memory_manager, initialize one
        if self.memory and 'user_info' in self.memory and 'user_id' in self.memory['user_info'] and not self.memory_manager:
            user_id = self.memory['user_info']['user_id']
            self.memory_manager = MemoryManager(user_id)

    @property
    def system_prompt(self) -> str:
        """Get the appropriate system prompt for the current model and task."""
        return get_system_prompt(model=self.model, task=self.task)

    def _trim_messages(self) -> None:
        """Trim message history to keep only the most recent messages"""
        if len(self.messages) > self.max_messages:
            self.messages = self.messages[-self.max_messages:]

    def chat(self, user_input: str, system_prompt: Optional[str] = None) -> Dict[str, Any]:
        """
        Process a user input message and generate a response

        Args:
            user_input: The user's input message
            system_prompt: Optional system prompt to override default

        Returns:
            A dictionary containing the assistant's response and other metadata
        """
        # Ensure we have a memory manager
        if not self.memory_manager and 'user_info' in self.memory and 'user_id' in self.memory['user_info']:
            self.memory_manager = MemoryManager(self.memory['user_info']['user_id'])

        # Get the memory view for the LLM
        memory_view = ""
        if self.memory_manager:
            memory_view = self.memory_manager.get_memory_view()

        # Prepare prompt components
        if not system_prompt:
            # Make sure task has a default value
            task = self.task or "chat"
            system_prompt = get_system_prompt(task=task)
            # If we have memory view, append it to the system prompt
            if memory_view:
                system_prompt = f"{system_prompt}\n\nCURRENT STATE SUMMARY:\n{memory_view}"

        if self.debug:
            logger.debug(f"System prompt: {system_prompt}")
            logger.debug(f"Token count for system prompt: {count_tokens(system_prompt, self.model)}")
            return {}

        # Convert messages format for the LLM client
        formatted_messages = [{"role": "system", "content": system_prompt}]

        # Add historical messages
        for msg in self.messages[-self.max_messages:]:
            formatted_messages.append({"role": msg.role, "content": msg.content})

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

        # Get assistant response content
        assistant_content = result.get("choices", [{}])[0].get("message", {}).get("content", "I couldn't generate a response.")

        # Process response metadata
        response_data = {
            "message": assistant_content,
            "tokens": {
                "prompt": result.get("usage", {}).get("prompt_tokens", 0),
                "completion": result.get("usage", {}).get("completion_tokens", 0),
                "total": result.get("usage", {}).get("total_tokens", 0)
            },
            "model": self.model,
            "memory_updated": False
        }

        # Add assistant message to history
        self.messages.append(Message(role="assistant", content=assistant_content))

        # Save to chat history and update memory
        self._add_to_chat_history("assistant", assistant_content)
        if self.memory_manager:
            self.memory_manager.save()
            response_data["memory_updated"] = True

        return response_data


    def format_prompt(self) -> List[Dict[str, str]]:
        """
        Format the current conversation state into a prompt for the LLM using the new view.

        Returns:
            List of message dictionaries for the LLM API
        """
        # Get memory view using memory manager if available
        memory_view_str = ""
        if self.memory_manager:
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
        Apply a JSON patch to the OverallMemory object.

        Args:
            patch: List of JSON Patch operations

        Returns:
            True if patch was successfully applied, False otherwise
        """
        if not patch:
            logger.info("No memory patch to apply")
            return False

        # Use the memory manager if available
        if self.memory_manager:
            updated_memory = self.memory_manager.apply_json_patch(self.memory, patch)
            if updated_memory:
                self.memory = updated_memory
                return True
            return False

        # Fallback to direct patching if memory manager is not available
        try:
            # Log patch operations
            logger.info(f"Applying memory patch with {len(patch)} operations:")
            for i, op in enumerate(patch):
                op_type = op.get('op', 'unknown')
                path = op.get('path', 'unknown')
                value_preview = str(op.get('value', ''))[:50]
                if len(str(op.get('value', ''))) > 50:
                    value_preview += "..."
                logger.info(f"  Operation {i+1}: {op_type} {path} = {value_preview}")

            # Apply patch to memory dictionary representation
            memory_dict = self.memory.model_dump()
            patch_obj = jsonpatch.JsonPatch(patch)
            patched_memory_dict = patch_obj.apply(memory_dict)

            # Validate and update memory using OverallMemory
            updated_memory = OverallMemory.model_validate(patched_memory_dict)
            self.memory = updated_memory

            logger.info("Memory patch successfully applied")
            return True

        except jsonpatch.JsonPatchConflict as e:
            memory_dict_str = json.dumps(self.memory.model_dump(), indent=2, default=str)
            logger.error(f"JsonPatch conflict applying patch: {e}. Patch: {json.dumps(patch)}. Memory dump (abbreviated): {memory_dict_str[:1000]}...", exc_info=True)
            return False
        except Exception as e:
            memory_dict_str = json.dumps(self.memory.model_dump(), indent=2, default=str)
            logger.error(f"Error applying memory patch: {str(e)}. Patch: {json.dumps(patch)}. Memory dump (abbreviated): {memory_dict_str[:1000]}...", exc_info=True)
            return False

    def _parse_llm_response(self, content: str) -> LLMResponse:
        """
        Parse the LLM response to extract message, memory patch, and options.

        Args:
            content: The raw content from the LLM

        Returns:
            LLMResponse with parsed components
        """
        # Default values
        message = content
        memory_patch = None
        options = None

        # Try to parse JSON response
        try:
            # Find JSON content in the response
            json_match = re.search(r'\{.*\}', content, re.DOTALL)

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

                    return LLMResponse(message=message, memory_patch=memory_patch, options=options)

        except Exception as e:
            logger.warning(f"Failed to parse JSON response: {str(e)}")

        # If JSON parsing failed, just return the raw content as the message
        return LLMResponse(message=message)

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
        Add a message to the chat history in memory if available.

        Args:
            role: The role of the message sender ("user" or "coach")
            content: The message content
        """
        # Use memory_manager for chat history instead of directly modifying memory
        if self.memory_manager:
            message = MemoryMessage(
                timestamp=datetime.now().isoformat(),
                content=content,
                sender=role,
                message_type="text"
            )
            self.memory_manager.add_message(message)
            return

        # Legacy fallback for dict-based memory
        # Ensure chat_history exists and is initialized
        if 'chat_history' not in self.memory or self.memory['chat_history'] is None:
            self.memory['chat_history'] = {'conversations': []}

        # Ensure conversations list exists
        if 'conversations' not in self.memory['chat_history']:
            self.memory['chat_history']['conversations'] = []

        # Add the message
        self.memory['chat_history']['conversations'].append({
            "sender": role,
            "content": content,
            "timestamp": datetime.now(),
            "message_type": "text"
        })

        # Update last interaction time
        self.memory['chat_history']['last_interaction'] = datetime.now()


class Onboarding(Chat):
    """
    Specialized Chat class for onboarding new users.
    Focuses on gathering health and workout information with structured options.
    """
    model: str = "claude"  # Default model for onboarding
    task: str = "onboarding"  # Uses onboarding-specific prompts

    def chat(self, user_input: str, system_prompt: Optional[str] = None) -> Dict[str, Any]:
        """
        Process user input specifically for onboarding, with focus on health and workout information.

        Args:
            user_input: The user's message
            system_prompt: Optional system prompt override

        Returns:
            Dictionary with the assistant's message and metadata
        """
        # Use the parent class implementation
        result = super().chat(user_input, system_prompt)

        # Log onboarding-specific information
        self._log_onboarding_updates(result)

        return result

    def _log_onboarding_updates(self, result: Dict[str, Any]) -> None:
        """
        Log onboarding-specific information about memory updates and options.

        Args:
            result: The response dictionary to analyze
        """
        if result.get("memory_updated", False):
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
