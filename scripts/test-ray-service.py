#!/usr/bin/env python3
import requests
import json
import time
import sys

def test_ray_service(url):
    """Test the Ray service by checking health endpoint and sending a test prompt.
    
    Args:
        url: The URL of the Ray service to test
        
    Returns:
        bool: True if the test passes, False otherwise
    """
    # Wait a bit for service to be fully ready
    print(f"Testing Ray service at {url}")
    
    # Try to connect
    max_retries = 10
    for i in range(max_retries):
        try:
            response = requests.get(f"{url}/health", timeout=5)
            print(f"Health check status: {response.status_code}")
            if response.status_code == 200:
                print(f"Response: {json.dumps(response.json(), indent=2)}")
                
                # Test with a simple prompt
                prompt_data = {
                    "prompt": "Hello, my name is",
                    "n_predict": 10
                }
                
                print("Sending test prompt...")
                resp = requests.post(url, json=prompt_data, timeout=30)
                print(f"Prompt response status: {resp.status_code}")
                
                if resp.status_code == 200:
                    print(f"Success! Response: {json.dumps(resp.json(), indent=2)}")
                    return True
            
            print(f"Attempt {i+1}/{max_retries} - Service not ready yet, retrying...")
            time.sleep(10)
        except Exception as e:
            print(f"Error connecting to service: {e}")
            time.sleep(5)
    
    print("Ray service test failed")
    return False

if __name__ == "__main__":
    service_url = "http://localhost:30085"
    if len(sys.argv) > 1:
        service_url = sys.argv[1]
    
    success = test_ray_service(service_url)
    if not success:
        sys.exit(1)