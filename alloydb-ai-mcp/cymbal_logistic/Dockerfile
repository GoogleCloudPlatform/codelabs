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

# Use the official lightweight Python image.
FROM python:3.11-slim

# Allow statements and log messages to immediately appear in the Knative logs
ENV PYTHONUNBUFFERED=True

# Set the working directory in the container to /app
WORKDIR /app

# Copy the local code to the container's workspace.
COPY . .

# Install the uv package manager
RUN pip install --no-cache-dir uv

# Pre-install dependencies at build time.
# By running an arbitrary python command through uv, it resolves and installs the dependencies
# defined in pyproject.toml / uv.lock into the container's environment.
RUN uv run python -c "print('dependencies installed')"

# Run the web service on container startup.
# Cloud Run injects the PORT environment variable (default 8080).
CMD ["sh", "-c", "uv run mesop app.py --port=${PORT:-8080}"]
