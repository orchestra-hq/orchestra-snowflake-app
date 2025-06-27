import requests
from typing import Dict, Any

session = requests.Session()
BASE_URL = "https://app.getorchestra.io"


def get_pipeline_runs(api_key: str, limit: int = 100) -> Dict[str, Any]:
    """
    Fetch pipeline runs from Orchestra API

    Args:
        api_key: Orchestra API key
        limit: Maximum number of pipeline runs to fetch

    Returns:
        Dictionary containing pipeline runs data
    """
    url = f"{BASE_URL}/api/engine/public/pipeline_runs"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    params = {"limit": limit}

    try:
        response = session.get(url, headers=headers, params=params)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        return {"error": str(e), "error_code": "API_ERROR", "pipeline_runs": []}


def get_task_runs(api_key: str, limit: int = 100) -> Dict[str, Any]:
    """
    Fetch task runs from Orchestra API

    Args:
        api_key: Orchestra API key
        limit: Maximum number of task runs to fetch

    Returns:
        Dictionary containing task runs data
    """
    url = f"{BASE_URL}/api/engine/public/task_runs"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    params = {"limit": limit}

    try:
        response = session.get(url, headers=headers, params=params)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        return {"error": str(e), "error_code": "API_ERROR", "task_runs": []}


def get_operations(api_key: str) -> Dict[str, Any]:
    """
    Fetch operations from Orchestra API

    Args:
        api_key: Orchestra API key

    Returns:
        Dictionary containing operations data
    """
    url = f"{BASE_URL}/api/engine/public/operations"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}

    try:
        response = session.get(url, headers=headers)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        return {"error": str(e), "error_code": "API_ERROR", "operations": []}
