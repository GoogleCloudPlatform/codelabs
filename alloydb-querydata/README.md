# AlloyDB Deployment Automation

This script automates the deployment of an AlloyDB cluster and primary instance in a Google Cloud project. It handles VPC network preparation for Private Service Access (PSA), generates secure credentials, and provides an optional bastion VM for database access.

## Features

- **Automated Networking**: Detects if VPC peering for Private Service Access is configured. If not, it creates a `/24` IP range (`psa-range`) and connects it to the Service Networking API.
- **Smart Cluster Creation**: Attempts to create a **Free Trial** cluster first. If the project is ineligible or the request fails, it automatically falls back to a **Standard** cluster.
- **Secure Credentials**: Generates a random 16-character password for the initial `postgres` user.
- **Optional Bastion VM**: Can provision a Compute Engine instance (`instance-1`) with the `postgresql-client` pre-installed for immediate connectivity testing.
- **Public IP Support**: Includes a flag to optionally enable inbound and outbound public IPv4 addresses on the primary instance.

## Prerequisites

- [Google Cloud SDK (gcloud)](https://cloud.google.com/sdk/docs/install) installed and authenticated.
- A target Google Cloud project set as default: `gcloud config set project [PROJECT_ID]`.
- Necessary IAM permissions (AlloyDB Admin, Compute Admin, Service Networking Admin).

## Usage

### Basic Deployment
Deploys the cluster and primary instance in `us-central1` using default names.
```bash
./deploy_alloydb.sh
```

### Deployment with Bastion VM
Deploys the cluster, instance, and a VM in `us-central1`.
```bash
./deploy_alloydb.sh --vm
```

### Deployment with Public IP
Deploys the cluster and primary instance, assigning both inbound and outbound public IPv4 addresses to the instance.
```bash
./deploy_alloydb.sh --public-ip
```

### Deployment in a Specific Region
```bash
./deploy_alloydb.sh --region us-east1
```

### Customizing Resource Names and Creating VM
You can override the default names for the cluster, instance, and VM using environment variables:

```bash
CLUSTER_NAME="prod-cluster" \
INSTANCE_NAME="prod-primary" \
VM_NAME="db-bastion" \
./deploy_alloydb.sh --region us-east1 --vm
```

## Configuration Defaults

| Parameter | Default Value | Flag | Environment Variable |
|-----------|---------------|------|----------------------|
| Region    | `us-central1` | `--region` | -              |
| Cluster   | `alloydb-aip-01` | - | `CLUSTER_NAME`    |
| Instance  | `alloydb-aip-01-pr` | - | `INSTANCE_NAME` |
| VM Name   | `instance-1`  | - | `VM_NAME`            |
| Create VM | `false`       | `--vm` | -                |
| Public IP | `false`       | `--public-ip` | -         |
| Network   | `default`     | - | -                    |
| PSA Range | `psa-range`   | - | -                    |

## Post-Deployment
The script will output the generated password at the end. Make sure to save it securely, as it is not stored elsewhere.

## Disclaimer

This is not an officially supported Google product.

## License

This project is licensed under the Apache License, Version 2.0. See the [LICENSE](LICENSE) file for details.