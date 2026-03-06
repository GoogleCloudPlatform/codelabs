import re

with open('app.py', 'r') as f:
    content = f.read()

# 1. Add instance_name to State
content = content.replace(
    'class State:\n    cluster_name: str = "alloydb-aip-01"\n    location: str = "us-central1"\n    database_name: str = "quickstart_db"',
    'class State:\n    cluster_name: str = "alloydb-aip-01"\n    location: str = "us-central1"\n    instance_name: str = "alloydb-aip-01-primary"\n    database_name: str = "quickstart_db"'
)

# 2. Add handler for instance_name
content = content.replace(
    'def on_location_change(e: me.InputBlurEvent):\n    state = me.state(State)\n    state.location = e.value\n\ndef on_database_name_change',
    'def on_location_change(e: me.InputBlurEvent):\n    state = me.state(State)\n    state.location = e.value\n\ndef on_instance_name_change(e: me.InputBlurEvent):\n    state = me.state(State)\n    state.instance_name = e.value\n\ndef on_database_name_change'
)

# 3. Update run_query_sync signature
content = content.replace(
    'def run_query_sync(request_text, cluster_name, location, database_name, project_id):',
    'def run_query_sync(request_text, cluster_name, location, instance_name, database_name, project_id):'
)

# 4. Update the LLM instruction
content = content.replace(
    'use the toolset to run query in the AlloyDB cluster {cluster_name} in the location {location}\n    in the project {project_id} in the database {database_name}',
    'use the toolset to run query in the AlloyDB cluster {cluster_name} instance {instance_name} in the location {location}\n    in the project {project_id} in the database {database_name}'
)

# 5. Update call to run_query_sync
content = content.replace(
    '''    response_text, headers, rows, debug_text = run_query_sync(
        state.request_text, 
        state.cluster_name, 
        state.location, 
        state.database_name, 
        project_id
    )''',
    '''    response_text, headers, rows, debug_text = run_query_sync(
        state.request_text, 
        state.cluster_name, 
        state.location,
        state.instance_name, 
        state.database_name, 
        project_id
    )'''
)

# 6. Update the sidebar UI
ui_field = '''            me.input(
                label="Instance Name",
                value=state.instance_name,
                on_blur=on_instance_name_change,
                appearance="outline",
                style=me.Style(width="100%", border_radius=4)
            )
            me.input(
                label="Database Name",'''

content = content.replace(
    '            me.input(\n                label="Database Name",',
    ui_field
)

with open('app.py', 'w') as f:
    f.write(content)
