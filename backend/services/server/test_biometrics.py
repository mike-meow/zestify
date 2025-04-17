#!/usr/bin/env python3

import requests
import json
import datetime
import argparse

def main():
    parser = argparse.ArgumentParser(description='Test biometrics upload endpoint')
    parser.add_argument('--host', default='localhost', help='Server host')
    parser.add_argument('--port', default=8000, type=int, help='Server port')
    parser.add_argument('--user-id', required=True, help='User ID to upload biometrics for')
    args = parser.parse_args()
    
    base_url = f"http://{args.host}:{args.port}"
    
    # Sample biometrics data
    biometrics_data = {
        "heart_rate": {
            "resting": {
                "current": 65,
                "unit": "bpm",
                "history": [
                    {
                        "value": 65,
                        "timestamp": datetime.datetime.now().isoformat(),
                        "source": "Apple Health"
                    }
                ]
            },
            "daily_average": {
                "current": 72,
                "unit": "bpm",
                "history": [
                    {
                        "value": 72,
                        "timestamp": datetime.datetime.now().isoformat(),
                        "source": "Apple Health"
                    }
                ]
            }
        },
        "sleep": {
            "total_duration": {
                "current": 7.5,
                "unit": "hours",
                "history": [
                    {
                        "value": 7.5,
                        "timestamp": datetime.datetime.now().isoformat(),
                        "source": "Apple Health"
                    }
                ]
            },
            "deep_sleep": {
                "current": 1.2,
                "unit": "hours",
                "history": [
                    {
                        "value": 1.2,
                        "timestamp": datetime.datetime.now().isoformat(),
                        "source": "Apple Health"
                    }
                ]
            }
        },
        "body_composition": {
            "weight": {
                "current": 70.5,
                "unit": "kg",
                "history": [
                    {
                        "value": 70.5,
                        "timestamp": datetime.datetime.now().isoformat(),
                        "source": "Apple Health"
                    }
                ]
            },
            "body_fat": {
                "current": 15.2,
                "unit": "%",
                "history": [
                    {
                        "value": 15.2,
                        "timestamp": datetime.datetime.now().isoformat(),
                        "source": "Apple Health"
                    }
                ]
            }
        }
    }
    
    # Upload biometrics
    print(f"Uploading biometrics to {base_url}/users/{args.user_id}/biometrics")
    response = requests.post(
        f"{base_url}/users/{args.user_id}/biometrics",
        json=biometrics_data
    )
    
    # Print response
    print(f"Status code: {response.status_code}")
    print(json.dumps(response.json(), indent=2))

if __name__ == "__main__":
    main()
