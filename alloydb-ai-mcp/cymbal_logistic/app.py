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

import mesop as me
from dataclasses import field
import sys
import os
import asyncio
import pandas as pd
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import uuid
from dotenv import load_dotenv

env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data_agent", ".env")
load_dotenv(env_path)

# Add current directory to path so we can import data_agent

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from data_agent.agent import root_agent
from google.adk.runners import Runner
from google.adk.sessions.in_memory_session_service import InMemorySessionService
from google.genai import types

def on_load(e: me.LoadEvent):
    me.set_theme_mode("light")

@me.stateclass
class State:
    cluster_name: str = "alloydb-aip-01"
    location: str = "us-central1"
    instance_name: str = "alloydb-aip-01-pr"
    database_name: str = "quickstart_db"
    request_text: str = ""
    response_text: str = ""
    is_loading: bool = False
    error_message: str = ""
    grid_headers: list[str] = field(default_factory=list)
    grid_rows: list[list[str]] = field(default_factory=list)
    has_chart: bool = False
    debug_info: str = ""
    enable_debug: bool = False
    
def on_cluster_name_change(e: me.InputBlurEvent):
    state = me.state(State)
    state.cluster_name = e.value

def on_location_change(e: me.InputBlurEvent):
    state = me.state(State)
    state.location = e.value

def on_instance_name_change(e: me.InputBlurEvent):
    state = me.state(State)
    state.instance_name = e.value

def on_database_name_change(e: me.InputBlurEvent):
    state = me.state(State)
    state.database_name = e.value

def on_request_change(e: me.InputBlurEvent):
    state = me.state(State)
    state.request_text = e.value

def on_debug_change(e: me.CheckboxChangeEvent):
    state = me.state(State)
    state.enable_debug = e.checked

class FrontendRunner:
    def __init__(self):
        self.session_service = InMemorySessionService()
        self.runner = Runner(
            app_name="cymbal_logistic_frontend",
            agent=root_agent,
            session_service=self.session_service,
            auto_create_session=True
        )

# We create a new runner instance per request to avoid session locking bugs
def run_query_sync(request_text, cluster_name, location, instance_name, database_name, project_id):
    local_runner = FrontendRunner()
    # The agent instruction is set here
    
    root_agent.instruction = f"""
    Answer user questions to the best of your knowledge using provided tools.
    Do not try to generate non-existent data but use the grounded data from the database.
    When you answer questions about Cymbal Logistic activity
    use the toolset to run query in the AlloyDB cluster {cluster_name} instance {instance_name} in the location {location}
    in the project {project_id} in the database {database_name}
    """
    
    msg = types.Content(
        role="user",
        parts=[types.Part.from_text(text=request_text)]
    )

    full_response = ""
    grid_headers = []
    grid_rows = []
    
    # We need to run the async runner in a sync context because Mesop event handlers are sync/generators
    async def _run():
        response_text = ""
        local_headers = []
        local_rows = []
        debug_logs = []
        try:
            current_session_id = f"session_mesop_{uuid.uuid4().hex[:8]}"
            async for event in local_runner.runner.run_async(
                user_id="mesop_user",
                session_id=current_session_id,
                new_message=msg
            ):
                if event.content and event.content.parts:
                    for p in event.content.parts:
                        if p.text:
                            response_text += p.text
                            
                # Intercept function responses to extract raw data
                if hasattr(event, "get_function_responses"):
                    function_responses = event.get_function_responses()
                    for f_resp in function_responses:
                        # Depending on the ADK wrapper, it could be a raw dict or a structured object
                        data = []
                        if hasattr(f_resp, "response") and hasattr(f_resp.response, "get"):
                            # typical genai format for part.function_response
                            res_dict = f_resp.response
                        elif isinstance(f_resp, dict):
                            res_dict = f_resp
                        else:
                            try:
                                res_dict = f_resp.model_dump()
                            except:
                                res_dict = {}
                                
                        # Suppose AlloyDB MCP returns data under "results" or directly as list
                        # This is a heuristic based on standard tabular MCP returns
                        rows = []
                        if "results" in res_dict and isinstance(res_dict["results"], list):
                            rows = res_dict["results"]
                        elif isinstance(res_dict, list):
                            rows = res_dict
                        elif isinstance(res_dict.get("content"), list):
                            try:
                                content_list = res_dict["content"]
                                for c in content_list:
                                    if isinstance(c, dict) and c.get("type") == "text":
                                        struct = json.loads(c.get("text", "{}"))
                                        if isinstance(struct, list):
                                            rows.extend(struct)
                                        elif isinstance(struct, dict) and "results" in struct:
                                            rows.extend(struct["results"])
                            except:
                                pass
                                
                        if rows and isinstance(rows[0], dict):
                            if not local_headers:
                                local_headers = list(rows[0].keys())
                            for row in rows:
                                local_rows.append([str(row.get(h, "")) for h in local_headers])
                                
                if hasattr(event, "get_function_calls"):
                    calls = event.get_function_calls()
                    if calls:
                        for c in calls:
                            try:
                                if hasattr(c, "name"):
                                    name = c.name
                                    args = c.args
                                elif isinstance(c, dict):
                                    name = c.get("name")
                                    args = c.get("args")
                                else:
                                    name = "Unknown"
                                    args = str(c)
                                debug_logs.append(f"Function Call: {name}\nArguments: {json.dumps(args, indent=2)}")
                            except:
                                debug_logs.append(f"Function Call: {str(c)}")

        except Exception as e:
            response_text = f"Error: {str(e)}"
        return response_text, local_headers, local_rows, "\n\n".join(debug_logs)
        
    # Python 3.7+ async run
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            import nest_asyncio
            nest_asyncio.apply()
            full_response, grid_headers, grid_rows, debug_info = loop.run_until_complete(_run())
        else:
            full_response, grid_headers, grid_rows, debug_info = asyncio.run(_run())
    except RuntimeError:
        full_response, grid_headers, grid_rows, debug_info = asyncio.run(_run())
        
    return full_response, grid_headers, grid_rows, debug_info

def submit_query(e: me.ClickEvent):
    state = me.state(State)
    if not state.request_text.strip():
        state.error_message = "Please enter a request."
        return

    state.is_loading = True
    state.error_message = ""
    state.response_text = ""
    yield

    # Since project_id isn't directly configured in the UI we can extract it from the agent module 
    from data_agent.agent import project_id
    
    response_text, headers, rows, debug_text = run_query_sync(
        state.request_text, 
        state.cluster_name, 
        state.location,
        state.instance_name, 
        state.database_name, 
        project_id
    )
    
    state.response_text = response_text
    
    # Fallback to parse JSON from the final response text if no tools intercepted it
    if not headers and not rows and "{" in response_text and "}" in response_text:
        start = response_text.find('{')
        end = response_text.rfind('}')
        if start != -1 and end != -1 and start < end:
            try:
                parsed = json.loads(response_text[start:end+1])
                if isinstance(parsed, dict):
                    if "data" in parsed and isinstance(parsed["data"], list) and "labels" in parsed and isinstance(parsed["labels"], list):
                        headers = ["Label", "Value"]
                        rows = [[str(l), str(v)] for l, v in zip(parsed["labels"], parsed["data"])]
                    elif "data" in parsed and isinstance(parsed["data"], list) and len(parsed["data"]) > 0 and isinstance(parsed["data"][0], dict):
                        headers = list(parsed["data"][0].keys())
                        rows = [[str(r.get(h, "")) for h in headers] for r in parsed["data"]]
                elif isinstance(parsed, list) and len(parsed) > 0 and isinstance(parsed[0], dict):
                    headers = list(parsed[0].keys())
                    rows = [[str(r.get(h, "")) for h in headers] for r in parsed]
            except Exception as e:
                pass

    # 3rd Fallback: Markdown Tables (LLM format: | Column 1 | Column 2 |)
    if not headers and not rows and "|" in response_text:
        lines = response_text.strip().split('\n')
        table_lines = [l.strip() for l in lines if '|' in l]
        if len(table_lines) >= 3:
            sep_idx = -1
            for i, l in enumerate(table_lines):
                if '---' in l or '===' in l:
                    sep_idx = i
                    break
            
            if sep_idx >= 1:
                potential_headers = [h.strip() for h in table_lines[sep_idx-1].strip('|').split('|')]
                headers = potential_headers
                for tl in table_lines[sep_idx+1:]:
                    row_data = [d.strip() for d in tl.strip('|').split('|')]
                    if len(row_data) == len(headers):
                        rows.append(row_data)

    state.grid_headers = headers
    state.grid_rows = rows
    state.debug_info = debug_text
    state.is_loading = False
    
    request_lower = state.request_text.lower()
    state.has_chart = ("chart" in request_lower or "plot" in request_lower) and len(rows) > 0 and len(headers) >= 2
    
    yield

try:
    sec_policy = me.SecurityPolicy(dangerously_disable_trusted_types=True)
except TypeError:
    try:
        sec_policy = me.SecurityPolicy(dangerously_disable_trusted_types_code_execution=True)
    except TypeError:
        sec_policy = None

@me.page(
    path="/",
    on_load=on_load,
    title="Cymbal Logistic Agent",
    security_policy=sec_policy,
)
def app():
    state = me.state(State)
    
    # We inject JS and CSS to force the favicon and input styling to white
    me.html("""
    <script>
        setTimeout(() => {
            // Remove existing favicons
            document.querySelectorAll("link[rel*='icon']").forEach(e => e.remove());
            // Add new favicon
            let link = document.createElement('link');
            link.rel = 'icon';
            link.type = 'image/png';
            link.href = '/static/cymbal_logo_v2.png?v=2';
            document.head.appendChild(link);
            document.title = "Cymbal Logistic Agent";
        }, 100);
    </script>
    <style>
        /* Force inputs to be clean white boxes */
        .mat-mdc-text-field-wrapper, 
        .mdc-text-field { 
            background-color: #FFFFFF !important; 
            border-radius: 4px !important; 
        }
        /* Hide the bottom ripple line */
        .mdc-line-ripple {
            display: none !important;
        }
    </style>
    """)
    
    with me.box(style=me.Style(
        display="flex",
        flex_direction="row",
        height="100vh",
        background="#F0F8FF", # light alice blue
        font_family="Google Sans, Roboto, sans-serif",
        color="#202124"
    )):
        # Left Sidebar (Configurations)
        with me.box(style=me.Style(
            width="300px",
            background="#E3F2FD", # light blue
            padding=me.Padding.all(24),
            border=me.Border(right=me.BorderSide(width=1, style="solid", color="#BBDEFB")),
            display="flex",
            flex_direction="column",
            gap=16
        )):
            me.text("Database Config", type="headline-6", style=me.Style(margin=me.Margin(bottom=16), color="#1A73E8", font_weight="500"))
            
            me.input(
                label="Cluster Name",
                value=state.cluster_name,
                on_blur=on_cluster_name_change,
                appearance="outline",
                style=me.Style(width="100%", border_radius=4)
            )
            me.input(
                label="Location",
                value=state.location,
                on_blur=on_location_change,
                appearance="outline",
                style=me.Style(width="100%", border_radius=4)
            )
            me.input(
                label="Instance Name",
                value=state.instance_name,
                on_blur=on_instance_name_change,
                appearance="outline",
                style=me.Style(width="100%", border_radius=4)
            )
            me.input(
                label="Database Name",
                value=state.database_name,
                on_blur=on_database_name_change,
                appearance="outline",
                style=me.Style(width="100%", border_radius=4)
            )
        
        # Right Main Content
        with me.box(style=me.Style(
            flex_grow=1,
            display="flex",
            flex_direction="column",
            overflow_y="auto"
        )):
            # Hero Header
            with me.box(style=me.Style(
                width="100%", 
                height="120px",
                margin=me.Margin(top=16),
                border_radius=8,
                background="linear-gradient(to bottom, #64B5F6 0%, #1976D2 100%)",
                display="flex",
                flex_direction="row",
                align_items="center",
                padding=me.Padding(left=32, right=32),
                box_shadow="0 2px 4px rgba(0,0,0,0.1)"
            )):
                me.image(
                    src="/static/cymbal_logo_v2.png",
                    style=me.Style(
                        height="80px",
                        margin=me.Margin(right=24),
                        border_radius=8
                    )
                )
                me.text("Cymbal Logistic Agent", type="headline-3", style=me.Style(color="#FFFFFF", font_weight="600", margin=me.Margin(top=0, bottom=0, left=0, right=0)))
            
            # Content Area
            with me.box(style=me.Style(
                padding=me.Padding.all(32),
                display="flex",
                flex_direction="column",
                gap=24
            )):
                # Top Right: Input Area
                with me.box(style=me.Style(
                    background="#E3F2FD", # light blue
                    padding=me.Padding.all(24),
                    border_radius=8,
                    border=me.Border.all(me.BorderSide(width=1, style="solid", color="#BBDEFB")),
                    box_shadow="0 1px 2px 0 rgba(60,64,67,0.3), 0 1px 3px 1px rgba(60,64,67,0.15)",
                    display="flex",
                    flex_direction="column",
                    gap=16
                )):
                    with me.box(style=me.Style(display="flex", justify_content="flex-end", margin=me.Margin(bottom=8))):
                        me.checkbox(
                            label="Enable Debug Output",
                            checked=state.enable_debug,
                            on_change=on_debug_change,
                        )
                        
                    me.textarea(
                        label="Ask a question...",
                        value=state.request_text,
                        on_blur=on_request_change,
                        rows=3,
                        appearance="outline",
                        style=me.Style(width="100%", border_radius=4)
                    )
                    
                    with me.box(style=me.Style(display="flex", justify_content="flex-end")):
                        me.button(
                            "Submit Request",
                            on_click=submit_query,
                            type="raised",
                            color="primary"
                        )
                    
                    if state.error_message:
                        me.text(state.error_message, style=me.Style(color="#D93025", font_weight="500"))
            
                # Bottom Right: Results Area
                if state.is_loading:
                    with me.box(style=me.Style(display="flex", flex_direction="row", gap=12, align_items="center")):
                        me.progress_spinner()
                        me.text("Agent is thinking...", style=me.Style(color="#5F6368", font_weight="500"))
                    
                elif state.response_text:
                    with me.box(style=me.Style(
                        background="#E3F2FD", # light blue
                        padding=me.Padding.all(24),
                        border_radius=8,
                        border=me.Border.all(me.BorderSide(width=1, style="solid", color="#BBDEFB")),
                        box_shadow="0 1px 2px 0 rgba(60,64,67,0.3), 0 1px 3px 1px rgba(60,64,67,0.15)",
                        display="flex",
                        flex_direction="column",
                        gap=24
                    )):
                        if state.has_chart and state.grid_headers and len(state.grid_headers) >= 2:
                            me.text("Data Visualization", type="subtitle-1", style=me.Style(font_weight="bold", color="#1A73E8"))
                        else:
                            me.text("Response", type="subtitle-1", style=me.Style(font_weight="bold", color="#1A73E8"))
                            me.markdown(state.response_text)
                        
                        if state.grid_headers:
                            me.text("Data Query Results", type="subtitle-1", style=me.Style(font_weight="bold", margin=me.Margin(top=16)))
                            with me.box(style=me.Style(max_height="400px", overflow_y="auto")):
                                # me.table format accepts Pandas DataFrames directly
                                try:
                                    df_table = pd.DataFrame(state.grid_rows, columns=state.grid_headers)
                                    me.table(df_table, header=me.TableHeader(sticky=True))
                                except Exception as e:
                                    me.text(f"Could not render table: {str(e)}", style=me.Style(color="red"))
                                
                        if state.has_chart and state.grid_headers and len(state.grid_headers) >= 2:
                            me.text("Chart Analysis", type="subtitle-1", style=me.Style(font_weight="bold", margin=me.Margin(top=16)))
                            
                            try:
                                # Plot a simple bar chart using the first categorical col and first numeric col
                                df = pd.DataFrame(state.grid_rows, columns=state.grid_headers)
                                
                                # Try to convert columns to numeric, first one that succeeds we can plot
                                numeric_col = None
                                category_col = None
                                
                                for col in df.columns[1:]:
                                    try:
                                        # Remove commas so '1,500' parses to 1500
                                        cleaned = df[col].astype(str).str.replace(',', '', regex=False)
                                        df[col] = pd.to_numeric(cleaned)
                                        numeric_col = col
                                        break
                                    except:
                                        pass
                                        
                                if not numeric_col:
                                    # if nothing converts perfectly, just force first non-categorical col
                                    numeric_col = df.columns[1]
                                    cleaned = df[numeric_col].astype(str).str.replace(',', '', regex=False)
                                    df[numeric_col] = pd.to_numeric(cleaned, errors='coerce').fillna(0)
                                    
                                category_col = df.columns[0]
                                
                                fig, ax = plt.subplots(figsize=(8, 4))
                                import numpy as np
                                
                                # Handle potential NaN
                                d = df[[category_col, numeric_col]].dropna()
                                # Sort by numeric column
                                d = d.sort_values(by=numeric_col, ascending=False).head(15) 
                                    
                                ax.bar(d[category_col].astype(str), d[numeric_col], color="#1976D2")
                                ax.set_ylabel(numeric_col)
                                ax.set_xlabel(category_col)
                                ax.set_title(f"Chart: {numeric_col} by {category_col}")
                                plt.xticks(rotation=45, ha='right')
                                plt.tight_layout()
                                
                                # mesop plot takes the figure object and renders it as a base64 img tag safely
                                me.plot(fig, style=me.Style(width="100%", margin=me.Margin(bottom=24)))
                                plt.close(fig)
                            except Exception as e:
                                me.text(f"Could not generate chart automatically: {str(e)}", style=me.Style(color="orange"))
    
                        is_debug_env = os.environ.get("DEBUG", "false").lower() == "true"
                        is_debug = is_debug_env or state.enable_debug
                        if is_debug and state.debug_info:
                            me.text("Debug Execution Logs", type="subtitle-1", style=me.Style(font_weight="bold", margin=me.Margin(top=16)))
                            with me.box(style=me.Style(
                                background="#333333",
                                color="#00FF00",
                                padding=me.Padding.all(16),
                                border_radius=8,
                                font_family="monospace",
                                font_size="14px",
                                white_space="pre-wrap"
                            )):
                                me.text(state.debug_info)
