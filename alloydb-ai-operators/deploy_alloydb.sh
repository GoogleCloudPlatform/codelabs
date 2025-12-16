# Copyright 2025 Google LLC
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

#!/bin/bash

# Default Configuration
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
CLUSTER_NAME=${CLUSTER_NAME:-"alloydb-aip-01"}
INSTANCE_NAME=${INSTANCE_NAME:-"alloydb-aip-01-pr"}
NETWORK="default"
PSA_RANGE_NAME="psa-range"
VM_NAME=${VM_NAME:-"instance-1"}
CREATE_VM=false

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --region) 
            if [[ -n "$2" && "$2" != --* ]]; then
                REGION="$2"
                shift
            else
                echo "Error: --region requires a value."
                exit 1
            fi
            ;;
        --vm) CREATE_VM=true ;; 
        *) echo "Unknown parameter passed: $1"; exit 1 ;; 
    esac
    shift
done

ZONE="${REGION}-a"

echo "----------------------------------------"
echo "Starting AlloyDB Deployment"
echo "Project: $PROJECT_ID"
echo "Region:  $REGION"
echo "Cluster: $CLUSTER_NAME"
echo "----------------------------------------"

# Exit on any subsequent error
set -e

# 0. Enable required APIs
echo "Enabling required APIs..."
gcloud services enable alloydb.googleapis.com \
                       compute.googleapis.com \
                       servicenetworking.googleapis.com \
                       --quiet

# 1. Evaluate and prepare network for Private Service Access (PSA)
echo "Checking network for PSA..."

# Ensure our range exists
RANGE_EXISTS=$(gcloud compute addresses list --filter="name=$PSA_RANGE_NAME" --format="value(name)")
if [[ -z "$RANGE_EXISTS" ]]; then
    echo "Creating PSA range: $PSA_RANGE_NAME"
    gcloud compute addresses create $PSA_RANGE_NAME \
        --global \
        --purpose=VPC_PEERING \
        --prefix-length=24 \
        --network=$NETWORK
fi

# Get existing peering connection info
PEERING_INFO=$(gcloud services vpc-peerings list --network=$NETWORK --service=servicenetworking.googleapis.com --format="json" 2>/dev/null)

if [[ "$PEERING_INFO" == "[]" || -z "$PEERING_INFO" ]]; then
    echo "PSA Peering not found. Connecting service networking..."
    gcloud services vpc-peerings connect \
        --service=servicenetworking.googleapis.com \
        --ranges=$PSA_RANGE_NAME \
        --network=$NETWORK
else
    echo "PSA Peering exists. Checking if range $PSA_RANGE_NAME is included..."
    # Extract ranges using python for reliable JSON parsing
    EXISTING_RANGES=$(echo "$PEERING_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); print(','.join(data[0]['reservedPeeringRanges'])) if data else print('')")
    
    if [[ $EXISTING_RANGES != *"$PSA_RANGE_NAME"* ]]; then
        echo "Range $PSA_RANGE_NAME not in peering. Current ranges: $EXISTING_RANGES"
        echo "Updating connection..."
        NEW_RANGES="${EXISTING_RANGES},${PSA_RANGE_NAME}"
        gcloud services vpc-peerings update \
            --service=servicenetworking.googleapis.com \
            --ranges=$NEW_RANGES \
            --network=$NETWORK
    else
        echo "PSA Peering and range already configured."
    fi
fi

# 2. Generate random password
PASSWORD=$(openssl rand -base64 15 | tr -dc 'a-zA-Z0-0' | head -c 16)

# 3. Create AlloyDB Cluster
echo "Attempting to create AlloyDB cluster..."
set +e
gcloud alloydb clusters create $CLUSTER_NAME \
    --region=$REGION \
    --network=$NETWORK \
    --password=$PASSWORD \
    --subscription-type=TRIAL \
    --quiet

if [ $? -ne 0 ]; then
    echo "Free Trial cluster creation failed or not available. Attempting Standard cluster..."
    gcloud alloydb clusters create $CLUSTER_NAME \
        --region=$REGION \
        --network=$NETWORK \
        --password=$PASSWORD \
        --subscription-type=STANDARD \
        --quiet
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create AlloyDB cluster."
        exit 1
    fi
fi
set -e

# 4. Create Primary Instance
echo "Creating primary instance: $INSTANCE_NAME"
gcloud alloydb instances create $INSTANCE_NAME \
    --cluster=$CLUSTER_NAME \
    --region=$REGION \
    --cpu-count=2 \
    --instance-type=PRIMARY \
    --quiet

# 5. Optional: Create VM
if [ "$CREATE_VM" = true ]; then
    echo "Creating VM: $VM_NAME in zone $ZONE"
    gcloud compute instances create $VM_NAME \
        --zone=$ZONE \
        --network=$NETWORK \
        --metadata=startup-script='#!/bin/bash
        apt-get update
        apt-get install -y postgresql-client' \
        --quiet
fi

echo "----------------------------------------"
echo "Deployment SUCCESSFUL"
echo "Cluster:  $CLUSTER_NAME"
echo "Instance: $INSTANCE_NAME"
echo "Region:   $REGION"
echo "Password: $PASSWORD"
echo "----------------------------------------"
if [ "$CREATE_VM" = true ]; then
    echo "VM $VM_NAME created with psql client."
fi
