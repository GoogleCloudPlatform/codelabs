# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import pathlib
import requests
from dotenv import load_dotenv
from google.adk import Agent
from google.adk.models import Gemini
from google.adk.skills import load_skill_from_dir
from google.adk.tools.skill_toolset import SkillToolset
from google.auth import default
from google.auth.transport.requests import Request as GoogleAuthRequest

# Load environment variables from .env
load_dotenv(pathlib.Path(__file__).parent / ".env")

_, project_id = default()

project_id = os.getenv("GOOGLE_CLOUD_PROJECT", project_id)
cluster_name = os.getenv("ALLOYDB_CLUSTER", "alloydb-aip-01")
instance_name = os.getenv("ALLOYDB_INSTANCE", "alloydb-aip-01-pr")
location = os.getenv("ALLOYDB_LOCATION", "us-central1")
database_name = os.getenv("ALLOYDB_DATABASE", "quickstart_db")
context_set_id = os.getenv("QUERYDATA_CONTEXTSET", "")

# List of database tables included in QueryData API requests
TABLE_IDS = [
    "real_estate.municipalities",
    "real_estate.cities",
    "real_estate.agents",
    "real_estate.properties",
    "real_estate.schools",
    "real_estate.school_to_property",
    "real_estate.property_transactions",
    "real_estate.secure_offers",
]

print(f"Authenticated as project: {project_id}")

# Calls the QueryData API directly (Python SDK approach)

def call_querydata_api(
    prompt: str,
    target_project_id: str = project_id,
    target_location: str = location,
    target_cluster_id: str = cluster_name,
    target_instance_id: str = instance_name,
    target_database_id: str = database_name,
    target_context_set_id: str = context_set_id,
    target_table_ids: list[str] = TABLE_IDS,
) -> dict:
    """Calls the Gemini Data Analytics QueryData API to translate natural language into SQL, execute it, and return the answer and results.

    Args:
        prompt: The natural language question or request.
        target_project_id: GCP project ID.
        target_location: GCP region/location.
        target_cluster_id: AlloyDB cluster ID.
        target_instance_id: AlloyDB instance ID.
        target_database_id: Target database name.
        target_context_set_id: Full resource name of the context set.
        target_table_ids: List of database tables (schema.table) to include in context.

    Returns:
        JSON response dictionary containing generatedQuery, queryResult (columns and rows), intentExplanation, and naturalLanguageAnswer.
    """
    auth_creds, _ = default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    if not auth_creds.valid:
        auth_creds.refresh(GoogleAuthRequest())

    url = f"https://geminidataanalytics.googleapis.com/v1beta/projects/{target_project_id}/locations/{target_location}:queryData"
    req_headers = {
        "Authorization": f"Bearer {auth_creds.token}",
        "Content-Type": "application/json",
        "X-Goog-User-Project": target_project_id
    }

    alloydb_ref = {
        "databaseReference": {
            "projectId": target_project_id,
            "region": target_location,
            "clusterId": target_cluster_id,
            "instanceId": target_instance_id,
            "databaseId": target_database_id,
            "tableIds": target_table_ids
        }
    }
    if target_context_set_id:
        alloydb_ref["agentContextReference"] = {
            "contextSetId": target_context_set_id
        }

    payload = {
        "prompt": prompt,
        "context": {
            "datasourceReferences": {
                "alloydb": alloydb_ref
            },
            "parameterized_secure_view_parameters": {
                "parameters": {
                    "key": "agent_id",
                    "value": "1"
                }
            }
        },
        "generationOptions": {
            "generateNaturalLanguageAnswer": True,
            "generateQueryResult": True,
            "generateExplanation": True
        }
    }

    response = requests.post(url, headers=req_headers, json=payload, timeout=120)
    response.raise_for_status()
    return response.json()


# ADK File-Based Skill

database_query_skill = load_skill_from_dir(
    pathlib.Path(__file__).parent / "skills" / "database-query-skill"
)

skill_toolset = SkillToolset(
    skills=[database_query_skill]
)

MODEL_ID = "gemini-3.6-flash"

# Agent configuration

root_agent = Agent(
    model=MODEL_ID,
    name='root_agent',
    description='A helpful assistant for analyst requests.',
    instruction=f"""
    Answer user questions to the best of your knowledge using provided tools.
    Do not try to generate non-existent data but use the grounded data from the database.
    When you answer questions about database contents, real estate properties, or sales activity:
    1. Refer to database-query-skill for instructions on querying data using QueryData API.
    2. Use `call_querydata_api` to submit the natural language prompt to the QueryData API.
       CRITICAL: Call `call_querydata_api` EXACTLY ONCE per user request. Do NOT make retries, follow-up calls, or rephrased calls to `call_querydata_api`, even if the result contains zero rows or empty data.
    3. Immediately parse the JSON response from that first `call_querydata_api` call.
    4. Format your final response to the user containing:
       - The generated SQL query (formatted in a Markdown SQL code block).
       - The query results formatted as a Markdown table (constructed from `queryResult.columns` and `queryResult.rows`).
       - The natural language answer (`naturalLanguageAnswer`).
    """,
    tools=[call_querydata_api, skill_toolset],
)