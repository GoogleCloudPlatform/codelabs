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
import re
import asyncio
from typing import Any
from dotenv import load_dotenv
from google.adk.models import Gemini
from google.adk.tools.base_tool import BaseTool
from google.adk.tools.mcp_tool import McpToolset, StreamableHTTPConnectionParams
from google.adk.tools.tool_context import ToolContext
from google.auth import default
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.adk.agents.llm_agent import Agent

load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"))


# Google Cloud MCP Server for AlloyDB

MCP_SERVER_URL = "https://alloydb.googleapis.com/mcp"
creds, project_id = default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
if not creds.valid:
    creds.refresh(GoogleAuthRequest())

print(f"Authenticated as project: {project_id}")

# 2. Configure MCP Toolset
# We use StreamableHTTPConnectionParams to pass the auth header
headers = {
    "Authorization": f"Bearer {creds.token}",
    "X-Goog-User-Project": project_id
}
    
connection_params = StreamableHTTPConnectionParams(
    url=MCP_SERVER_URL,
    headers=headers,
    timeout=300.0,
    sse_read_timeout=600.0
)

# Allow execute_sql only for AlloyDB ai/google_ml schema functions, which require
# a non-read-only session for internal plpgsql/telemetry calls; SQL is still
# strictly validated as single-statement read-only SELECT/WITH in before_tool_callback.
ALLOWED_TOOLS = ["execute_sql_read_only", "execute_sql"]

mcp_toolset = McpToolset(
    connection_params=connection_params,
    tool_filter=ALLOWED_TOOLS,
)

_FORBIDDEN_SQL_KEYWORDS = re.compile(
    r"\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|TRUNCATE|GRANT|REVOKE|COPY|CALL|DO|SET|EXECUTE|VACUUM)\b",
    re.IGNORECASE,
)
_AI_SCHEMA_CALL = re.compile(r"\b(ai|google_ml)\.", re.IGNORECASE)


def _strip_sql_literals_and_comments(sql: str) -> str:
    """Remove SQL comments and single-quoted literals before keyword/statement checks."""
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.DOTALL)
    sql = re.sub(r"--[^\n]*", " ", sql)
    sql = re.sub(r"'(?:''|[^'])*'", "''", sql)
    return sql.strip()


def validate_sql_tool_call(
    tool: BaseTool,
    args: dict[str, Any],
    tool_context: ToolContext,
) -> dict[str, Any] | None:
    """Pre-execution guardrail allowing only single read-only SQL statements."""
    if tool.name not in ALLOWED_TOOLS:
        return {"error": f"Tool '{tool.name}' is not permitted."}

    sql = (args.get("sqlStatement") or "").strip()
    if not sql:
        return {"error": "Empty SQL statement is not permitted."}

    cleaned = _strip_sql_literals_and_comments(sql).rstrip(";").strip()

    if ";" in cleaned:
        return {"error": "Multiple SQL statements are not permitted."}

    if not re.match(r"^(SELECT|WITH)\b", cleaned, re.IGNORECASE):
        return {"error": "Only read-only SELECT or WITH queries are permitted."}

    if _FORBIDDEN_SQL_KEYWORDS.search(cleaned):
        return {"error": "Write, DDL, or administrative SQL statements are not permitted."}

    if tool.name == "execute_sql" and not _AI_SCHEMA_CALL.search(cleaned):
        return {
            "error": "Use execute_sql_read_only for standard queries; execute_sql is only permitted for ai/google_ml schema functions."
        }

    return None


MODEL_ID = os.environ.get("MODEL_ID", "gemini-4-hydrogen")
location = os.environ.get("ALLOYDB_LOCATION") or os.environ.get("GOOGLE_CLOUD_LOCATION", "us-west1")
cluster_name = os.environ.get("CLUSTER_NAME", "alloydb-aip-01")
instance_name = os.environ.get("INSTANCE_NAME", "alloydb-aip-01-pr")
database_name = os.environ.get("DATABASE_NAME", "quickstart_db")

# Agent configuration

def build_instruction(
    cluster_name: str = cluster_name,
    instance_name: str = instance_name,
    location: str = location,
    database_name: str = database_name,
    project_id: str = project_id,
    summary: str = "",
    model_id: str = MODEL_ID,
) -> str:
    instruction = f"""
    Answer user questions to the best of your knowledge using provided tools.
    Do not try to generate non-existent data but use the grounded data from the database.
    When you answer questions about Cymbal Logistic activity
    use the toolset to run query in the AlloyDB cluster {cluster_name} instance {instance_name} in the location {location}
    in the project {project_id} in the database {database_name}
    Use ai schema to use AI functions and the models like {model_id} with the functions from the schema.
    Use execute_sql_read_only for standard queries, and execute_sql only when calling ai schema functions.
    """
    if summary:
        instruction = (
            "Here is a summary of the previous conversation context to help you answer subsequent questions:\n"
            f"{summary}\n\n"
            + instruction
        )
    return instruction


def create_agent(instruction: str | None = None, model_id: str = MODEL_ID) -> Agent:
    """Create a fresh Agent instance so per-request instructions are never shared."""
    return Agent(
        model=model_id,
        name='root_agent',
        description='A helpful assistant for analyst requests.',
        instruction=instruction if instruction is not None else build_instruction(model_id=model_id),
        tools=[mcp_toolset],
        before_tool_callback=validate_sql_tool_call,
    )


root_agent = create_agent()

