#!/usr/bin/env python3
import requests
import json
import time
import argparse

def test_llama_service(url="http://localhost:30085", prompt="Hello, my name is", n_predict=50):
    """
    Test the LLaMA Ray service with a sample prompt.
    """
    payload = {
        "prompt": prompt,
        "n_predict": n_predict,
        "temperature": 0.7
    }
    
    print(f"Sending request to {url}")
    try:
        response = requests.post(url, json=payload, timeout=60)
        print(f"Status code: {response.status_code}")
        if response.status_code == 200:
            print(f"Response: {json.dumps(response.json(), indent=2)}")
        else:
            print(f"Error response: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test the LLaMA Ray service")
    parser.add_argument("--url", default="http://localhost:30085", help="Service URL")
    parser.add_argument("--prompt", default="Hello, my name is", help="Prompt to send")
    parser.add_argument("--n_predict", type=int, default=50, help="Number of tokens to predict")
    
    args = parser.parse_args()
    test_llama_service(args.url, args.prompt, args.n_predict)