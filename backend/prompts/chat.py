from typing import Dict, List, Optional, Union, Any
from enum import Enum
from pydantic import BaseModel, Field
import json
import logging
import os
import re
import tiktoken
import jsonpatch
from datetime import datetime
    
from backend.memory.schemas import CompactOverallMemory
from backend.llm.openrouter_client import OpenRouterClient, MODELS
from backend.prompts.system_prompts import get_system_prompt

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ChatRole(str, Enum):
    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM = "system"

class ContentItem(BaseModel):
    type: str = Field(..., description="Type of content: 'text' or 'image'")
    data: str = Field(..., description="Content data - text string or image URL/base64")
    alt_text: Optional[str] = Field(None, description="Alternative text for images")

class ChatTurn(BaseModel):
    role: str
    content: Union[str, List[ContentItem]] = Field(
        ..., 
        description="Content of the message. Can be a string or a list of ContentItems for multimodal content"
    )

class LLMResponse(BaseModel):
    message: str
    memory_patch: Optional[List[Dict[str, Any]]] = None
    token_count: Optional[int] = None
    prompt_tokens: Optional[int] = None
    memory_updated: bool = False
    options: Optional[List[str]] = None  # Added for Onboarding responses

def count_tokens(text: str, model: str = "gemini") -> int:
    """
    Count the number of tokens in a text string using tiktoken.
    
    Args:
        text: The text to count tokens in
        model: The model name to determine tokenizer
        
    Returns:
        Number of tokens in the text
    """
    try:
        # Select encoding based on the model
        encoding_name = "cl100k_base"  # Default for newer models
        
        if "gpt-4" in model:
            encoding_name = "gpt-4"
        elif "gpt-3.5" in model:
            encoding_name = "gpt-3.5-turbo"
        elif "claude" in model:
            encoding_name = "cl100k_base"  # Claude uses this encoding
            
        # Get the encoding and count tokens
        encoding = (
            tiktoken.encoding_for_model(encoding_name) 
            if encoding_name in ["gpt-4", "gpt-3.5-turbo"] 
            else tiktoken.get_encoding(encoding_name)
        )
        return len(encoding.encode(text))
        
    except Exception as e:
        logger.warning(f"Error counting tokens with tiktoken: {e}")
        
        # Fallback estimation based on model family
        if "gemini" in model:
            # Gemini: ~4 characters per token
            return max(1, int(len(text) / 4))
        else:
            # Others: ~1.3 tokens per word
            return max(1, int(len(text.split()) * 1.3))

class Chat(BaseModel):
    memory: CompactOverallMemory
    messages: List[ChatTurn] = []
    model: str = "deepseek"
    task: str = "chat"
    max_messages: int = 20  # Maximum number of messages to keep in memory

    @property
    def system_prompt(self) -> str:
        """Get the appropriate system prompt for the current model and task."""
        return get_system_prompt(model=self.model, task=self.task)

    def _trim_messages(self) -> None:
        """Trim message history to keep only the most recent messages"""
        if len(self.messages) > self.max_messages:
            self.messages = self.messages[-self.max_messages:]

    def _format_message_content(self, msg: ChatTurn) -> str:
        """
        Format message content, handling both text and multimodal content.
        
        Args:
            msg: The chat turn to format
            
        Returns:
            Formatted content as a string
        """
        if isinstance(msg.content, list):
            # Handle multimodal content
            return " ".join([
                item.data if item.type == "text" else f"[Image: {item.alt_text or 'No description'}]" 
                for item in msg.content
            ])
        return msg.content

    def format_prompt(self) -> List[Dict[str, str]]:
        """
        Format the current conversation state into a prompt for the LLM.
        
        Returns:
            List of message dictionaries for the LLM API
        """
        # Convert memory to JSON string - ensure it's compact
        memory_str = self.memory.model_dump_json(indent=None, exclude_none=True)
        
        # Remove chat_history from memory to avoid duplication
        try:
            memory_dict = json.loads(memory_str)
            if "chat_history" in memory_dict:
                del memory_dict["chat_history"]
            memory_str = json.dumps(memory_dict)
        except Exception as e:
            logger.warning(f"Error removing chat_history from memory: {str(e)}")
        
        # Create system message with context
        system_message = {
            "role": "system",
            "content": f"{self.system_prompt}\n\nMEMORY: {memory_str}"
        }
        
        # Format conversation messages
        formatted_messages = [
            {"role": msg.role, "content": self._format_message_content(msg)}
            for msg in self.messages
        ]
        
        # Combine system message with conversation history
        return [system_message] + formatted_messages
    
    def apply_memory_patch(self, patch: List[Dict[str, Any]]) -> bool:
        """
        Apply a JSON patch to the memory object.
        
        Args:
            patch: List of JSON Patch operations
            
        Returns:
            True if patch was successfully applied, False otherwise
        """
        if not patch:
            logger.info("No memory patch to apply")
            return False
            
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
            
            # Apply patch to memory
            memory_dict = self.memory.model_dump()
            patch_obj = jsonpatch.JsonPatch(patch)
            patched_memory = patch_obj.apply(memory_dict)
            
            # Validate and update memory
            updated_memory = CompactOverallMemory.model_validate(patched_memory)
            self.memory = updated_memory
            
            logger.info("Memory patch successfully applied")
            return True
            
        except Exception as e:
            logger.error(f"Error applying memory patch: {str(e)}", exc_info=True)
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
        if not self.memory.chat_history:
            return
            
        self.memory.chat_history.conversations.append({
            "sender": role,
            "content": content,
            "timestamp": datetime.now(),
            "message_type": "text"
        })
        
        self.memory.chat_history.last_interaction = datetime.now()
    
    def process_user_input(self, user_input: str, model: str = None, temperature: float = 0.7) -> LLMResponse:
        """
        Process user input and get LLM response.
        
        Args:
            user_input: The user's message
            model: The model to use (optional, overrides the instance model)
            temperature: The temperature for generation (optional)
            
        Returns:
            LLMResponse with message and optional memory patch
        """
        # Update model if specified
        if model:
            self.model = model
            
        # Add user message to history
        self.messages.append(ChatTurn(role=ChatRole.USER, content=user_input))
        
        # Save to chat history
        self._add_to_chat_history("user", user_input)
        
        # Format prompt for LLM
        prompt_messages = self.format_prompt()
        
        # Log messages being sent
        self._log_prompt_messages(prompt_messages)
        
        # Count tokens in the prompt
        prompt_text = "\n".join([msg["content"] for msg in prompt_messages])
        prompt_token_count = count_tokens(prompt_text, self.model)
        logger.info(f"Prompt token count: {prompt_token_count}")
        
        # Get actual model ID from OpenRouter
        actual_model_id = MODELS.get(self.model, self.model)
        logger.info(f"Using model key: '{self.model}', translates to OpenRouter model ID: '{actual_model_id}'")
        
        # Request completion from LLM
        try:
            # Initialize client and send request
            client = OpenRouterClient(model=self.model)
            response = client.chat_completion(
                messages=prompt_messages,
                temperature=temperature,
                max_tokens=2000
            )
            
            # Handle API errors
            if "error" in response:
                return self._handle_api_error(response["error"], prompt_token_count)
                
            # Process successful response
            result = self._process_successful_response(response, prompt_token_count)
            
            # Trim message history if needed
            self._trim_messages()
            
            return result
            
        except Exception as e:
            # Handle any exceptions
            logger.error(f"Error processing LLM response: {str(e)}", exc_info=True)
            return LLMResponse(
                message=f"I'm sorry, I encountered an error processing your request. Error: {str(e)}",
                prompt_tokens=prompt_token_count
            )
    
    def _log_prompt_messages(self, prompt_messages: List[Dict[str, str]]) -> None:
        """
        Log details about the prompt messages for debugging.
        
        Args:
            prompt_messages: The formatted messages to log
        """
        # Log summary of messages
        logger.info(f"Sending {len(prompt_messages)} messages to the model")
        
        # Log preview of each message
        for i, msg in enumerate(prompt_messages):
            content_length = len(msg.get('content', ''))
            preview = msg.get('content', '')[:150]
            if content_length > 150:
                preview += "..."
            logger.info(f"Message {i+1}: role={msg.get('role')}, length={content_length}")
            logger.info(f"Preview: {preview}")
        
        # Log full prompt for debugging
        logger.info("==== FULL PROMPT ====")
        for i, msg in enumerate(prompt_messages):
            role = msg.get('role', 'unknown')
            content = msg.get('content', '')
            logger.info(f"--- Message {i+1} ({role}) ---")
            logger.info(content)
        logger.info("==== END PROMPT ====")
    
    def _handle_api_error(self, error_message: str, prompt_token_count: int) -> LLMResponse:
        """
        Handle API errors from the LLM service.
        
        Args:
            error_message: The error message from the API
            prompt_token_count: The token count of the prompt
            
        Returns:
            LLMResponse with error message
        """
        logger.error(f"Error in LLM response: {error_message}")
        return LLMResponse(
            message=f"I'm sorry, I encountered an error processing your request. Error: {error_message}",
            prompt_tokens=prompt_token_count
        )
    
    def _process_successful_response(self, response: Dict[str, Any], prompt_token_count: int) -> LLMResponse:
        """
        Process a successful response from the LLM.
        
        Args:
            response: The raw response from the LLM API
            prompt_token_count: The token count of the prompt
            
        Returns:
            Processed LLMResponse
        """
        # Extract content from response
        content = response.get('choices', [{}])[0].get('message', {}).get('content', '')
        logger.info(f"Response length: {len(content)} characters")
        logger.info(f"Response preview: {content[:150]}...")
        
        # Parse response
        result = self._parse_llm_response(content)
        
        # Handle memory patch if present
        if result.memory_patch:
            logger.info(f"Memory patch found with {len(result.memory_patch)} operations:")
            for i, op in enumerate(result.memory_patch):
                logger.info(f"  Patch {i+1}: {json.dumps(op)}")
            
            # Apply memory patch
            memory_updated = self.apply_memory_patch(result.memory_patch)
            result.memory_updated = memory_updated
        else:
            logger.info("No memory patch found in response")
        
        # Set token counts
        result.prompt_tokens = prompt_token_count
        result.token_count = response.get('usage', {}).get('completion_tokens')
        logger.info(f"Response tokens: {result.token_count}")
        
        # Add assistant message to history
        self.messages.append(ChatTurn(role=ChatRole.ASSISTANT, content=result.message))
        
        # Save to chat history
        self._add_to_chat_history("coach", result.message)
        
        return result

class Onboarding(Chat):
    """
    Specialized Chat class for onboarding new users.
    Focuses on gathering health and workout information with structured options.
    """
    model: str = "claude"  # Default model for onboarding
    task: str = "onboarding"  # Uses onboarding-specific prompts
    
    def process_user_input(self, user_input: str, model: str = None, temperature: float = 0.7) -> LLMResponse:
        """
        Process user input specifically for onboarding, with focus on health and workout information.
        
        Args:
            user_input: The user's message
            model: The model to use (optional, overrides the instance model)
            temperature: The temperature for generation (optional)
            
        Returns:
            LLMResponse with message, options, and memory patch
        """
        # Use the parent class implementation
        result = super().process_user_input(user_input, model, temperature)
        
        # Log onboarding-specific information
        self._log_onboarding_updates(result)
        
        return result
    
    def _log_onboarding_updates(self, result: LLMResponse) -> None:
        """
        Log onboarding-specific information about memory updates and options.
        
        Args:
            result: The LLMResponse to analyze
        """
        # Log memory updates
        if result.memory_updated:
            logger.info("Memory updated during onboarding session")
            
            memory_dict = self.memory.model_dump()
            
            # Check for workout memory updates
            if "workout_memory" in memory_dict:
                workout_memory = memory_dict["workout_memory"]
                
                # Log workout goals
                if "workout_goals" in workout_memory:
                    goals = workout_memory["workout_goals"].get("current_goals", [])
                    if goals:
                        logger.info(f"Updated workout goals: {goals}")
                
                # Log workout preferences
                if "workout_preferences" in workout_memory:
                    logger.info("Updated workout preferences")
            
            # Log user profile updates
            if "user_profile" in memory_dict:
                logger.info("Updated user profile information")
        
        # Log options
        if result.options:
            logger.info(f"Onboarding provided {len(result.options)} options for user choice")
