import os
import json
import logging
from typing import Dict, Any, Union, List, Optional, Annotated, Callable
from datetime import datetime, timedelta, date
from pathlib import Path
import jsonpatch
from backend.memory.schemas import OverallMemory, CompactOverallMemory, Activities

# Configure logging
logger = logging.getLogger(__name__)

def json_serial(obj):
    if isinstance(obj, datetime):
        return obj.isoformat()
    elif isinstance(obj, date):
        return obj.isoformat()
    return str(obj)  # fallback for other unserializable types

class MemoryManager:
    def __init__(self, user_id: str, data_dir: str = "data"):
        self.user_id = user_id
        self.user_dir = Path(data_dir) / user_id
        # Create the directory if it doesn't exist, instead of raising an error
        if not self.user_dir.is_dir():
            try:
                self.user_dir.mkdir(parents=True, exist_ok=True)
                logger.info(f"Created user directory: {self.user_dir}")
            except OSError as e:
                 # Handle potential race conditions or permission issues
                 logger.error(f"Error creating directory {self.user_dir}: {e}")
                 # Depending on requirements, could re-raise or proceed cautiously
                 # For now, let's proceed, loading will likely yield an empty memory.
                 pass
    
    # Add support for Pydantic serialization and validation
    @classmethod
    def __get_validators__(cls):
        """
        Yield validators for handling MemoryManager in Pydantic models. 
        This is the older Pydantic v1 style which is more compatible.
        """
        yield cls.validate
    
    @classmethod
    def validate(cls, value):
        """
        Validate and convert a value to MemoryManager.
        
        Args:
            value: The value to validate (string, dict, or MemoryManager)
            
        Returns:
            MemoryManager instance
        """
        if value is None:
            return None
        if isinstance(value, cls):
            return value
        if isinstance(value, str):
            return cls(value)
        if isinstance(value, dict) and "user_id" in value:
            return cls(value["user_id"])
        raise ValueError(f"Cannot convert {value} to {cls.__name__}")

    def load_memory(self) -> OverallMemory:
        """Load all memory files for the user and merge into a single OverallMemory object."""
        # Pass user_id to from_user_dir to help initialize UserProfile if needed
        return OverallMemory.from_user_dir(self.user_dir, self.user_id) 

    def get_compact_memory(self) -> CompactOverallMemory:
        """
        Load memory and convert it to a compact version suitable for LLM consumption
        by removing unnecessary metadata.
        """
        memory = self.load_memory()
        return memory.to_compact()

    def update_memory(self, memory: Dict[str, Any], patch: Dict[str, Any], patch_format: str = "merge") -> Dict[str, Any]:
        """
        Update memory in-memory using a patch.
        patch_format: "merge" for JSON Merge Patch (RFC 7386), "patch" for JSON Patch (RFC 6902)
        """
        if patch_format == "merge":
            return self._merge_patch(memory, patch)
        elif patch_format == "patch":
            return jsonpatch.apply_patch(memory, patch)
        else:
            raise ValueError(f"Unknown patch_format: {patch_format}")

    def save_memory(self, memory: OverallMemory) -> None:
        """Save the updated memory back to the user's files, splitting by top-level key."""
        for key, value in memory.model_dump().items():
            path = self.user_dir / f"{key}.json"
            with open(path, "w") as f:
                json.dump(value, f, indent=2, default=json_serial)
    
    def apply_json_patch(self, memory: OverallMemory, patch: List[Dict[str, Any]]) -> Optional[OverallMemory]:
        """
        Apply a JSON patch to the OverallMemory object.
        
        Args:
            memory: The OverallMemory object to update
            patch: List of JSON Patch operations
            
        Returns:
            Updated OverallMemory if patch was successfully applied, None otherwise
        """
        if not patch:
            logger.info("No memory patch to apply")
            return None
            
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
            memory_dict = memory.model_dump()
            patch_obj = jsonpatch.JsonPatch(patch)
            patched_memory_dict = patch_obj.apply(memory_dict)
            
            # Track which components were modified to save them individually later
            modified_components = self._identify_modified_components(patch)
            
            # Validate and update memory using OverallMemory
            updated_memory = OverallMemory.model_validate(patched_memory_dict)
            
            # Save individual components that were modified
            self._save_updated_components(updated_memory, modified_components)
            
            logger.info("Memory patch successfully applied")
            return updated_memory
            
        except jsonpatch.JsonPatchConflict as e:
            logger.error(f"JsonPatch conflict applying patch: {e}. Patch: {json.dumps(patch)}", exc_info=True)
            return None
        except Exception as e:
            logger.error(f"Error applying memory patch: {str(e)}. Patch: {json.dumps(patch)}", exc_info=True)
            return None
    
    def _identify_modified_components(self, patch: List[Dict[str, Any]]) -> List[str]:
        """
        Identify which components were modified in a memory patch.
        
        Args:
            patch: List of JSON Patch operations
            
        Returns:
            List of component names that were modified
        """
        modified_components = set()
        
        for op in patch:
            path = op.get('path', '')
            # Extract the top-level component name from the path
            path_parts = path.split('/')
            if len(path_parts) >= 2 and path_parts[1]:
                component = path_parts[1]
                # Map the path to the corresponding file name
                if component == 'user_profile':
                    modified_components.add('user_profile')
                elif component == 'workout_memory':
                    modified_components.add('workout_memory')
                elif component == 'biometrics':
                    modified_components.add('biometrics')
                elif component == 'activities':
                    modified_components.add('activities')
                elif component == 'workout_plan':
                    modified_components.add('workout_plan')
                elif component == 'chat_history':
                    modified_components.add('chat_history')
        
        return list(modified_components)
    
    def _save_updated_components(self, memory: OverallMemory, component_names: List[str]) -> None:
        """
        Save individual memory components that were modified.
        
        Args:
            memory: The updated OverallMemory object
            component_names: List of component names to save
        """
        if not hasattr(memory, 'user_info') or not memory.user_info or not memory.user_info.user_id:
            logger.warning("Cannot save components: user_id not found in memory")
            return
        
        for component in component_names:
            try:
                # Get the component data from memory
                if component == 'user_profile' and memory.user_profile:
                    file_path = self.user_dir / "user_profile.json"
                    component_data = memory.user_profile.model_dump()
                    # Update timestamps
                    component_data['updated_at'] = datetime.now()
                elif component == 'workout_memory' and memory.workout_memory:
                    file_path = self.user_dir / "workout_memory.json"
                    component_data = memory.workout_memory.model_dump()
                    # Update timestamps
                    component_data['last_updated'] = datetime.now()
                elif component == 'biometrics' and memory.biometrics:
                    file_path = self.user_dir / "biometrics.json"
                    component_data = memory.biometrics.model_dump()
                elif component == 'activities' and memory.activities:
                    file_path = self.user_dir / "activities.json"
                    component_data = memory.activities.model_dump()
                elif component == 'workout_plan' and memory.workout_plan:
                    file_path = self.user_dir / "workout_plan.json"
                    component_data = memory.workout_plan.model_dump()
                    # Update timestamps
                    if 'updated_at' in component_data:
                        component_data['updated_at'] = datetime.now()
                elif component == 'chat_history' and memory.chat_history:
                    file_path = self.user_dir / "chat_history.json"
                    component_data = memory.chat_history.model_dump()
                    # Update last interaction
                    component_data['last_interaction'] = datetime.now()
                else:
                    continue  # Skip if component doesn't exist
                
                # Save component data to file
                with open(file_path, "w") as f:
                    json.dump(component_data, f, indent=2, default=json_serial)
                logger.info(f"Saved updated {component} to {file_path}")
            
            except Exception as e:
                logger.error(f"Error saving {component}: {str(e)}", exc_info=True)

    @staticmethod
    def _merge_patch(target: Dict[str, Any], patch: Dict[str, Any]) -> Dict[str, Any]:
        """Recursively merge patch into target (JSON Merge Patch)."""
        for k, v in patch.items():
            if v is None:
                target.pop(k, None)
            elif isinstance(v, dict) and isinstance(target.get(k), dict):
                MemoryManager._merge_patch(target[k], v)
            else:
                target[k] = v
        return target

    def get_memory_view(self) -> str:
        """
        Load memory and get the LLM view for prompting.
        
        Returns:
            Formatted string representation of memory for LLM consumption
        """
        memory = self.load_memory()
        return memory.get_llm_view()
        
    def add_message(self, message: Any) -> None:
        """
        Add a message to the chat history.
        
        Args:
            message: Message object to add to history
        """
        memory = self.load_memory()
        
        # Ensure chat_history exists
        if memory.chat_history is None:
            from backend.memory.schemas import ChatHistory
            memory.chat_history = ChatHistory(user_id=self.user_id)
            
        # Ensure conversations list exists
        if memory.chat_history.conversations is None:
            memory.chat_history.conversations = []
            
        # Add the message as a dictionary
        memory.chat_history.conversations.append({
            "sender": message.sender,
            "content": message.content,
            "timestamp": message.timestamp,
            "message_type": message.message_type
        })
        
        # Update last interaction time
        memory.chat_history.last_interaction = datetime.now()
        
        # Save the updated chat history
        self._save_updated_components(memory, ["chat_history"])
        
    def save(self) -> None:
        """Save all memory components to disk."""
        memory = self.load_memory()
        self.save_memory(memory)

class OverviewMemoryManager(MemoryManager):
    def __init__(self, user_id: str, data_dir: str = "data"):
        super().__init__(user_id, data_dir)
        # No default date filtering here anymore
        # self.workout_start_date = ... 

    def load_memory(self) -> OverallMemory:
        # Load memory using the base class method
        memory = super().load_memory()
        
        # --- REMOVED Filtering Logic --- 
        # The filtering/display logic is now handled within each component's get_llm_view
        
        # REMOVED: memory.activities = Activities(activities=[])
        
        # REMOVED: Chat history filtering based on date range
        # if memory.chat_history and memory.chat_history.conversations:
        #    ... filtering logic ...
        
        # Return the unfiltered memory object
        return memory

    def get_compact_memory(self) -> CompactOverallMemory:
        # Load the full memory first (load_memory no longer filters)
        memory = self.load_memory()
        # Convert the full memory to compact
        return memory.to_compact()

    # Removed the _date_in_range helper method as it's no longer used here
    # def _date_in_range(...) -> bool:
    #    ...