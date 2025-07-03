# ignore type errors for _snowflake and requests as they are installed by snowflake
import _snowflake  # type: ignore
import requests  # type: ignore
from typing import Dict, Any

session = requests.Session()
BASE_URL = "https://app.getorchestra.io"


def get_pipeline_runs(page: int = 1, per_page: int = 100) -> Dict[str, Any]:
    """
    Fetch pipeline runs from Orchestra API

    Args:
        api_key: Orchestra API key
        limit: Maximum number of pipeline runs to fetch

    Returns:
        Dictionary containing pipeline runs data
    """
    try:
        response = session.get(
            f"{BASE_URL}/api/engine/public/pipeline_runs",
            headers={
                "Authorization": f"Bearer {_snowflake.get_generic_secret_string('API_KEY')}",
                "Content-Type": "application/json",
            },
            params={"page": page, "per_page": per_page},
        )
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        return {"error": str(e), "error_code": "API_ERROR", "pipeline_runs": []}


def get_task_runs(page: int = 1, per_page: int = 100) -> Dict[str, Any]:
    """
    Fetch task runs from Orchestra API

    Args:
        api_key: Orchestra API key
        limit: Maximum number of task runs to fetch

    Returns:
        Dictionary containing task runs data
    """
    try:
        response = session.get(
            f"{BASE_URL}/api/engine/public/task_runs",
            headers={
                "Authorization": f"Bearer {_snowflake.get_generic_secret_string('API_KEY')}",
                "Content-Type": "application/json",
            },
            params={"page": page, "per_page": per_page},
        )
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        return {"error": str(e), "error_code": "API_ERROR", "task_runs": []}


def get_operations(page: int = 1, per_page: int = 100) -> Dict[str, Any]:
    """
    Fetch operations from Orchestra API

    Args:
        api_key: Orchestra API key

    Returns:
        Dictionary containing operations data
    """
    try:
        response = session.get(
            f"{BASE_URL}/api/engine/public/operations",
            headers={
                "Authorization": f"Bearer {_snowflake.get_generic_secret_string('API_KEY')}",
                "Content-Type": "application/json",
            },
            params={"page": page, "per_page": per_page},
        )
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        return {"error": str(e), "error_code": "API_ERROR", "operations": []}
