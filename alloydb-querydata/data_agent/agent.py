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
import asyncio
from google.auth import default
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.adk.agents.llm_agent import Agent
from google.adk.tools.toolbox_toolset import ToolboxToolset


# MCP Toolbox for Databases  

MCP_SERVER_URL = "http://127.0.0.1:5000"
creds, project_id = default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
if not creds.valid:
    creds.refresh(GoogleAuthRequest())

print(f"Authenticated as project: {project_id}")

mcp_toolset = ToolboxToolset(
    server_url=MCP_SERVER_URL,
)

MODEL_ID = "gemini-3-flash-preview"
cluster_name="alloydb-aip-01"
instance_name="alloydb-aip-01-pr"
location="us-central1"
database_name="quickstart_db"

# Agent configuration

root_agent = Agent(
    model=MODEL_ID,
    name='root_agent',
    description='A helpful assistant for analyst requests.',
    instruction=f"""
    Answer user questions to the best of your knowledge using provided tools.
    Do not try to generate non-existent data but use the grounded data from the database.
    When you answer questions about Cymbal Logistic activity
    use the toolset to run query in the AlloyDB cluster {cluster_name} instance {instance_name} in the location {location}
    in the project {project_id} in the database {database_name}
    """,
    tools=[mcp_toolset],
)
