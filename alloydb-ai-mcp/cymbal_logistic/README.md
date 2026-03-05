# Cymbal Logistic Agent

This application is an AI-powered conversational agent that leverages the Google Autonomous Data Kit (ADK) alongside a sleek frontend generated with Google Mesop.

The agent has direct context of the `quickstart_db` logistics database and allows you to use standard natural language requests to analyze operational data. When tabular data is requested, the application will intercept the raw data from the underlying LLM's function calls and display it cleanly as a Pandas-style interactive table beneath the chat block. If a comparative query is made, a fully rendered Matplotlib graph will be generated directly into the UI!

## Prerequisites
- macOS/Linux environment.
- Python 3.10+
- `uv` package manager installed (`curl -LsSf https://astral.sh/uv/install.sh | sh`).
- Your `.env` variables located in `/data_agent/.env` (Project ID, Google Credentials).

## Architecture

1. **Backend / Data Agent**: 
   A Google ADK agent located in `data_agent/agent.py`. It is equipped with an MCP schema client linked to your AlloyDB Postgres instance. 

2. **Frontend Runner**: 
   The application UI is found in `app.py` and runs using `mesop`. The communication to the agent backend is carefully routed through a customized `FrontendRunner` block to ensure multiple async queries don't exhaust the ADK memory limits or crash your session state!

## How To Run

1. Clone the project and configure `data_agent/.env`. Make sure `uv` is installed on your OS.
2. Ensure you are authenticated with GCP via `gcloud auth application-default login`.
3. In the root directory, simply run:
```bash
uv run mesop app.py --port=8080
```
This single command handles any environment and dependency spin-up instantly.
4. Open the displayed URL (typically `http://localhost:8080`) in your browser.

## Deployment

The repository includes a `Dockerfile` designed for a serverless environment like Google Cloud Run. Since this is an interactive app, make sure to attach your database credentials correctly.

1. Install the Google Cloud SDK (`gcloud`).
2. Run the deployment command from the project root:
```bash
gcloud run deploy cymbal-logistic-app \\
  --source . \\
  --region us-central1 \\
  --allow-unauthenticated
```
3. Provide your environment variables (like `PROJECT_ID` and GCP Database configurations) either during the deployment prompt or via the GCP Web Console.

## Features & Usage

- **Natural Language Data**: E.g. _"How many tables are in the database?"_
- **Charts and Plotted Metrics**: Add _"Show me a chart..."_ to your query! The backend `submit_query` function will detect valid array outputs and natively render a bar chart visualization.
- **Debug Inspection**: A convenient UI checkbox in the corner ("Enable Debug Output") reveals the exact tool calls and variables the underlying ADK agent executes over your database. 
