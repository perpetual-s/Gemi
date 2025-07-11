import requests

# Test if server is running
try:
    response = requests.get("http://127.0.0.1:11435/api/health")
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.json()}")
except Exception as e:
    print(f"Server not running: {e}")