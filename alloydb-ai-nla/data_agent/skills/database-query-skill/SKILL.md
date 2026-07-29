---
name: database-query-skill
description: Query AlloyDB databases via the QueryData API.
---

# Database Query Skill

This skill provides instructions for querying AlloyDB databases in Google Cloud by making direct API calls to the `QueryData` interface.

## Querying Databases using QueryData API

### Step 1: QueryData API Request Structure
Use the QueryData API to submit natural language prompts using environment parameters (`GOOGLE_CLOUD_PROJECT`, `ALLOYDB_LOCATION`, `ALLOYDB_CLUSTER`, `ALLOYDB_INSTANCE`, `ALLOYDB_DATABASE`, and `QUERYDATA_CONTEXTSET`):
- **prompt**: The natural language question or instruction.
- **context**: Contextual information about the data source.
  - `datasourceReferences`: A mapping of datasource types to their references.
    - `alloydb`: Reference to an AlloyDB datasource.
      - `databaseReference`: Database details.
        - `projectId`: Google Cloud project ID (from `GOOGLE_CLOUD_PROJECT`).
        - `region`: Region where AlloyDB cluster is located (from `ALLOYDB_LOCATION`).
        - `clusterId`: ID of the AlloyDB cluster (from `ALLOYDB_CLUSTER`).
        - `instanceId`: ID of the primary AlloyDB instance (from `ALLOYDB_INSTANCE`).
        - `databaseId`: Name of the database (from `ALLOYDB_DATABASE`).
        - `tableIds`: List of database tables included in requests.
      - `agentContextReference`: Reference to a predefined context set that describes the database schema, rules, and examples.
        - `contextSetId`: Resource name of the context set (from `QUERYDATA_CONTEXTSET`, formatted as `projects/{project}/locations/{location}/contextSets/{contextSetId}`).
- `generationOptions`: Options to customize the output.
  - `generateNaturalLanguageAnswer`: Whether to generate a conversational answer.
  - `generateQueryResult`: Whether to execute the query and return the result rows.
  - `generateExplanation`: Whether to generate an explanation of how the query was constructed.

### Step 2: Parse and Format the QueryData API Response
The `QueryData` API automatically translates the natural language prompt into SQL, executes it against the database, and returns the query results along with a natural language answer.

**Single Execution Rule**: Make **EXACTLY ONE** call to QueryData API per request.
- Do **NOT** retry, make follow-up calls, or rephrase the prompt if 0 rows are returned.
- Immediately return whatever response comes back from the first QueryData API call.

Parse the JSON response from `QueryData` API and format the response to the user with the following sections:

1. **Generated SQL**: Display `generatedQuery` in a Markdown SQL code block (` ```sql ... ``` `).
2. **Query Results**: Format `queryResult.columns` and `queryResult.rows` into a clean Markdown table (or indicate 0 rows if empty).
3. **Natural Language Answer**: Present `naturalLanguageAnswer`.

---

## Troubleshooting Common Errors

### AlloyDB & QueryData
- **Cluster/Instance Not Found**: Ensure that segments of the resource path match the expected format exactly.
- **Permissions Error**: Verify that the caller has sufficient IAM permissions (`roles/alloydb.admin` or `roles/alloydb.databaseUser`).

## Reference Directory

- [QueryData API Reference](references/querydata_api.md)
