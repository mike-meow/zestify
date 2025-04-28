# test_memory_schema.py
from backend.memory.schemas import OverallMemory
import json
from pathlib import Path

def test_load_memory_from_json(json_path):
    with open(json_path, 'r') as f:
        data = json.load(f)
    memory = OverallMemory.parse_obj(data)
    print(memory.json(indent=2, exclude_none=True))

if __name__ == "__main__":
    # Change this path to your test file as needed
    test_load_memory_from_json("../../t.json")
