import os
import json
from typing import Dict, Any, Union
from datetime import datetime, timedelta, date
from backend.memory.schemas import OverallMemory, CompactOverallMemory

def json_serial(obj):
    if isinstance(obj, datetime):
        return obj.isoformat()
    elif isinstance(obj, date):
        return obj.isoformat()
    return str(obj)  # fallback for other unserializable types

class MemoryManager:
    def __init__(self, user_id: str, data_dir: str = "data"):
        self.user_id = user_id
        self.user_dir = os.path.join(data_dir, user_id)
        if not os.path.isdir(self.user_dir):
            raise FileNotFoundError(f"User directory {self.user_dir} does not exist.")

    def load_memory(self) -> OverallMemory:
        """Load all memory files for the user and merge into a single OverallMemory object."""
        return OverallMemory.from_user_dir(self.user_dir)

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
            import jsonpatch
            return jsonpatch.apply_patch(memory, patch)
        else:
            raise ValueError(f"Unknown patch_format: {patch_format}")

    def save_memory(self, memory: OverallMemory) -> None:
        """Save the updated memory back to the user's files, splitting by top-level key."""
        for key, value in memory.model_dump().items():
            path = os.path.join(self.user_dir, f"{key}.json")
            with open(path, "w") as f:
                json.dump(value, f, indent=2, default=json_serial)

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

class OverviewMemoryManager(MemoryManager):
    def __init__(self, user_id: str, data_dir: str = "data", workout_start_date: str = None):
        super().__init__(user_id, data_dir)
        if workout_start_date is None:
            # Default to one year ago
            self.workout_start_date = (datetime.now() - timedelta(days=365)).date()
        else:
            self.workout_start_date = datetime.strptime(workout_start_date, "%Y-%m-%d").date()

    def load_memory(self) -> OverallMemory:
        memory = super().load_memory()
        
        # Filter workouts
        if memory.workout_memory and memory.workout_memory.recent_workouts:
            # Handle RecentWorkout objects directly
            filtered = [
                w for w in memory.workout_memory.recent_workouts
                if hasattr(w, "start_date") and w.start_date is not None and 
                self._date_in_range(w.start_date)
            ]
            memory.workout_memory.recent_workouts = filtered
            
        # Skip activities data since we're not using it in compact view
        memory.activities = None
        
        # Filter chat history
        if memory.chat_history and memory.chat_history.conversations:
            # Keep only conversations from the last year
            filtered = [
                c for c in memory.chat_history.conversations 
                if c.get("timestamp") and self._date_in_range(c.get("timestamp"))
            ]
            memory.chat_history.conversations = filtered
            
            # Update last_interaction if needed
            if filtered and not memory.chat_history.last_interaction:
                # Find the most recent message timestamp
                timestamps = [
                    c.get("timestamp") for c in filtered 
                    if c.get("timestamp") is not None
                ]
                if timestamps:
                    memory.chat_history.last_interaction = max(timestamps)
        
        return memory

    def get_compact_memory(self) -> CompactOverallMemory:
        """
        Load filtered memory and convert it to a compact version suitable for LLM consumption
        by removing unnecessary metadata.
        """
        memory = self.load_memory()
        return memory.to_compact()

    def _date_in_range(self, date_val: Union[str, datetime, date]) -> bool:
        """
        Check if a date is within the configured range.
        Can handle datetime objects, date objects, or string dates.
        """
        try:
            # If it's already a datetime object
            if isinstance(date_val, datetime):
                d = date_val.date()
                return d >= self.workout_start_date
            
            # If it's already a date object
            if isinstance(date_val, date):
                return date_val >= self.workout_start_date
            
            # If it's a string, try to parse it
            if isinstance(date_val, str):
                try:
                    # Try ISO format first
                    d = datetime.fromisoformat(date_val).date()
                    return d >= self.workout_start_date
                except ValueError:
                    # Fallback to simple date format
                    d = datetime.strptime(date_val, "%Y-%m-%d").date()
                    return d >= self.workout_start_date
            
            return False
        except Exception:
            return False