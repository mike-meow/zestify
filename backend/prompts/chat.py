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

def count_tokens(text: str, model: str = "gemini") -> int:
    """Count the number of tokens in a text string using tiktoken."""
    try:
        # Select encoding based on the model
        if "gpt-4" in model:
            encoding = tiktoken.encoding_for_model("gpt-4")
        elif "gpt-3.5" in model:
            encoding = tiktoken.encoding_for_model("gpt-3.5-turbo")
        elif "claude" in model:
            encoding = tiktoken.encoding_for_model("cl100k_base")  # Claude uses this encoding
        elif "gemini" in model:
            # Gemini uses the same tokenizer as PaLM 2
            # As a fallback, we use cl100k_base which is a close approximation
            encoding = tiktoken.get_encoding("cl100k_base")
        else:
            encoding = tiktoken.get_encoding("cl100k_base")  # Default for newer models
            
        return len(encoding.encode(text))
    except Exception as e:
        logger.warning(f"Error counting tokens with tiktoken: {e}")
        
        # Fallback to smarter estimation for different model families
        if "gemini" in model:
            # Gemini tokenization is roughly 4 characters per token on average
            # This is a better approximation than simply counting words
            char_count = len(text)
            # Include adjustment for whitespace and punctuation
            return max(1, int(char_count / 4))
        else:
            # Fallback to word count with a multiplier for other models
            # This is a very rough estimation, but better than nothing
            words = text.split()
            # Average English word is ~1.3 tokens in most tokenizers
            return max(1, int(len(words) * 1.3))

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

    def format_prompt(self) -> List[Dict[str, str]]:
        """Format the current conversation state into a prompt for the LLM"""
        # Convert memory to JSON string - ensure it's compact
        memory_str = self.memory.model_dump_json(indent=None, exclude_none=True)
        
        # Remove chat_history from memory to avoid duplication
        try:
            memory_dict = json.loads(memory_str)
            if "chat_history" in memory_dict:
                del memory_dict["chat_history"]  # Remove chat_history from memory
            memory_str = json.dumps(memory_dict)
        except Exception as e:
            logger.warning(f"Error removing chat_history from memory: {str(e)}")
        
        # Create system message with context
        system_message = {
            "role": "system",
            "content": f"{self.system_prompt}\n\nMEMORY: {memory_str}"
        }
        
        # Format chat messages
        formatted_messages = []
        for msg in self.messages:
            # Handle multimodal content
            if isinstance(msg.content, list):
                # This is a simplified approach since OpenRouter might not support 
                # all multimodal features. In a production app, this would need more sophistication.
                content_text = " ".join([
                    item.data if item.type == "text" else f"[Image: {item.alt_text or 'No description'}]" 
                    for item in msg.content
                ])
                formatted_messages.append({"role": msg.role, "content": content_text})
            else:
                formatted_messages.append({"role": msg.role, "content": msg.content})
        
        # Combine system message with conversation history
        return [system_message] + formatted_messages
    
    def apply_memory_patch(self, patch: List[Dict[str, Any]]) -> bool:
        """
        Apply a JSON patch to the memory object
        
        Args:
            patch: List of JSON Patch operations
            
        Returns:
            True if patch was successfully applied, False otherwise
        """
        if not patch:
            logger.info("No memory patch to apply")
            return False
            
        try:
            # Print the patch for debugging
            logger.info(f"Applying memory patch with {len(patch)} operations:")
            for i, op in enumerate(patch):
                op_type = op.get('op', 'unknown')
                path = op.get('path', 'unknown')
                value_preview = str(op.get('value', ''))[:50]
                if len(str(op.get('value', ''))) > 50:
                    value_preview += "..."
                logger.info(f"  Operation {i+1}: {op_type} {path} = {value_preview}")
            
            # Convert memory to dict for patching
            memory_dict = self.memory.model_dump()
            
            # Create a JSON patch object and apply it
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
    
    def process_user_input(self, user_input: str, model: str = None, temperature: float = 0.7) -> LLMResponse:
        """
        Process user input and get LLM response
        
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
        
        # Save to chat history if available
        if self.memory.chat_history:
            # Create a chat message directly instead of importing ChatMessage
            self.memory.chat_history.conversations.append({
                "sender": "user", 
                "content": user_input,
                "timestamp": datetime.now(),
                "message_type": "text"
            })
            self.memory.chat_history.last_interaction = datetime.now()
        
        # Format prompt for LLM
        prompt_messages = self.format_prompt()
        
        # Print detailed message information for debugging
        logger.info(f"Sending {len(prompt_messages)} messages to the model")
        for i, msg in enumerate(prompt_messages):
            content_length = len(msg.get('content', ''))
            preview = msg.get('content', '')[:150]
            if len(msg.get('content', '')) > 150:
                preview += "..."
            logger.info(f"Message {i+1}: role={msg.get('role')}, length={content_length}")
            logger.info(f"Preview: {preview}")
        
        # Print full prompt (system message + user input) for debugging
        logger.info("==== FULL PROMPT ====")
        for i, msg in enumerate(prompt_messages):
            role = msg.get('role', 'unknown')
            content = msg.get('content', '')
            logger.info(f"--- Message {i+1} ({role}) ---")
            logger.info(content)
        logger.info("==== END PROMPT ====")
        
        # Count tokens in the prompt
        prompt_text = "\n".join([msg["content"] for msg in prompt_messages])
        prompt_token_count = count_tokens(prompt_text, self.model)
        
        logger.info(f"Prompt token count: {prompt_token_count}")
        
        # Determine the actual OpenRouter model ID that will be used
        actual_model_id = MODELS.get(self.model, self.model)
        logger.info(f"Using model key: '{self.model}', translates to OpenRouter model ID: '{actual_model_id}'")
        
        # Initialize OpenRouter client and make API call
        try:
            client = OpenRouterClient(model=self.model)
            response = client.chat_completion(
                messages=prompt_messages,
                temperature=temperature,
                max_tokens=2000
            )
            
            # Process response
            if "error" in response:
                error_message = response["error"]
                logger.error(f"Error in LLM response: {error_message}")
                return LLMResponse(
                    message=f"I'm sorry, I encountered an error processing your request. Error: {error_message}",
                    prompt_tokens=prompt_token_count
                )
                
            # Extract content from LLM response
            logger.info("Processing LLM response")
            content = response.get('choices', [{}])[0].get('message', {}).get('content', '')
            logger.info(f"Response length: {len(content)} characters")
            logger.info(f"Response preview: {content[:150]}...")
            
            # Parse response and extract message and memory patch
            result = self._parse_llm_response(content)
            
            # Print memory patch details
            if result.memory_patch:
                logger.info(f"Memory patch found with {len(result.memory_patch)} operations:")
                for i, op in enumerate(result.memory_patch):
                    logger.info(f"  Patch {i+1}: {json.dumps(op)}")
                
                # Try to apply the memory patch
                memory_updated = self.apply_memory_patch(result.memory_patch)
                result.memory_updated = memory_updated
            else:
                logger.info("No memory patch found in response")
            
            # Get token counts from the response
            result.prompt_tokens = prompt_token_count
            result.token_count = response.get('usage', {}).get('completion_tokens')
            logger.info(f"Response tokens: {result.token_count}")
            
            # Add assistant message to history
            self.messages.append(ChatTurn(role=ChatRole.ASSISTANT, content=result.message))
            
            # Save assistant message to chat history if available
            if self.memory.chat_history:
                self.memory.chat_history.conversations.append({
                    "sender": "coach", 
                    "content": result.message,
                    "timestamp": datetime.now(),
                    "message_type": "text"
                })
            
            # Trim message history if needed
            self._trim_messages()
            
            return result
            
        except Exception as e:
            logger.error(f"Error processing LLM response: {str(e)}", exc_info=True)
            return LLMResponse(
                message=f"I'm sorry, I encountered an error processing your request. Error: {str(e)}",
                prompt_tokens=prompt_token_count
            )
    
    def _parse_llm_response(self, content: str) -> LLMResponse:
        """
        Parse the LLM response to extract the message and memory patch
        
        Args:
            content: The raw content from the LLM
            
        Returns:
            LLMResponse with message and optional memory patch
        """
        # Default values
        message = content
        memory_patch = None
        
        # Try to parse JSON response
        try:
            # Find the JSON content in the response (handling cases where the model might add markdown or explanation)
            import re
            json_match = re.search(r'\{.*\}', content, re.DOTALL)
            
            if json_match:
                json_str = json_match.group(0)
                data = json.loads(json_str)
                
                if isinstance(data, dict):
                    # Extract message and memory patch from parsed JSON
                    if "message" in data:
                        message = data["message"]
                    
                    if "memory_patch" in data and data["memory_patch"] is not None:
                        memory_patch = data["memory_patch"]
                        
                        # Validate memory patch format (each item should have op and path)
                        if isinstance(memory_patch, list):
                            for patch_item in memory_patch:
                                if not isinstance(patch_item, dict) or "op" not in patch_item or "path" not in patch_item:
                                    logger.warning("Invalid memory patch item format")
                                    memory_patch = None
                                    break
                        else:
                            logger.warning("memory_patch is not a list")
                            memory_patch = None
                    
                    return LLMResponse(message=message, memory_patch=memory_patch)
        except Exception as e:
            logger.warning(f"Failed to parse JSON response: {str(e)}")
            
        # If JSON parsing failed, just return the raw content as the message
        return LLMResponse(message=message)
