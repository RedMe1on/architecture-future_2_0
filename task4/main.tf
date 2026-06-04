terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
  required_version = ">= 1.6"
}

# =============================================================================
# NETWORK: VPC, Subnets, NAT, Internet Gateway, Security Groups
# =============================================================================

resource "random_string" "vpc_cidr_primary" {
  length  = 3
  upper   = false
  numeric = true
  special = false
}

resource "local_file" "network_config" {
  filename = "${path.module}/generated/network_config.yaml"
  content  = <<-EOT
vpc:
  cidr: "${var.vpc_cidr}"
  name: "${random_pet.cluster_name.id}-vpc"

subnets:
  public:
    - cidr: "${var.public_subnet_cidrs[0]}"
      az: "${var.availability_zones[0]}"
      name: "public-${var.availability_zones[0]}"
    - cidr: "${var.public_subnet_cidrs[1]}"
      az: "${var.availability_zones[1]}"
      name: "public-${var.availability_zones[1]}"
    - cidr: "${var.public_subnet_cidrs[2]}"
      az: "${var.availability_zones[2]}"
      name: "public-${var.availability_zones[2]}"

  private_services:
    k8s_control_plane:
      cidr: "${var.private_subnet_cidrs["k8s_cp"]}"
      az: "${var.availability_zones[0]}"
    k8s_workers:
      cidr: "${var.private_subnet_cidrs["k8s_workers"]}"
      az: "${var.availability_zones[1]}"
    kafka:
      cidr: "${var.private_subnet_cidrs["kafka"]}"
      az: "${var.availability_zones[0]}"
    clickhouse:
      cidr: "${var.private_subnet_cidrs["clickhouse"]}"
      az: "${var.availability_zones[1]}"
    postgres:
      cidr: "${var.private_subnet_cidrs["postgres"]}"
      az: "${var.availability_zones[2]}"
    cockroachdb:
      cidr: "${var.private_subnet_cidrs["cockroachdb"]}"
      az: "${var.availability_zones[0]}"
    minio:
      cidr: "${var.private_subnet_cidrs["minio"]}"
      az: "${var.availability_zones[1]}"
    api_gateway:
      cidr: "${var.private_subnet_cidrs["api_gateway"]}"
      az: "${var.availability_zones[2]}"
    monitoring:
      cidr: "${var.private_subnet_cidrs["monitoring"]}"
      az: "${var.availability_zones[0]}"

internet_gateway:
  enabled: true

nat_gateway:
  enabled: true
  public_subnet_index: 0

security_groups:
  k8s_cp:
    rules:
      - port: 6443
        protocol: tcp
        cidr: ["0.0.0.0/0"]
        description: "Kubernetes API"
  kafka:
    rules:
      - port: 9092
        protocol: tcp
        cidr: ["${var.private_subnet_cidrs["k8s_workers"]}"]
        description: "Kafka from K8s workers"
      - port: 9092
        protocol: tcp
        cidr: ["${var.private_subnet_cidrs["api_gateway"]}"]
        description: "Kafka from API Gateway"
  clickhouse:
    rules:
      - port: 8123
        protocol: tcp
        cidr: ["${var.private_subnet_cidrs["k8s_workers"]}"]
        description: "ClickHouse HTTP from Superset"
  postgres:
    rules:
      - port: 5432
        protocol: tcp
        cidr: ["${var.private_subnet_cidrs["k8s_workers"]}"]
        description: "PostgreSQL from K8s"
  cockroachdb:
    rules:
      - port: 26257
        protocol: tcp
        cidr: ["${var.private_subnet_cidrs["k8s_workers"]}"]
        description: "CockroachDB from K8s"
  minio:
    rules:
      - port: 9000
        protocol: tcp
        cidr: ["${var.private_subnet_cidrs["k8s_workers"]}"]
        description: "MinIO S3 from K8s"
    api_gateway:
    rules:
      - port: 443
        protocol: tcp
        cidr: ["0.0.0.0/0"]
        description: "HTTPS from internet"
      - port: 80
        protocol: tcp
        cidr: ["0.0.0.0/0"]
        description: "HTTP (redirect to HTTPS)"
EOT
}

# =============================================================================
# COMPUTE: Virtual Machines per service
# =============================================================================

resource "random_pet" "cluster_name" {
  length    = 2
  separator = "-"
}

resource "random_password" "db_master_password" {
  length  = 24
  special = false
}

resource "random_password" "kafka_password" {
  length  = 24
  special = false
}

# ---- K8s Control Plane ----
resource "null_resource" "k8s_control_plane" {
  count = var.instance_count["k8s_cp"]

  triggers = {
    cluster_name  = random_pet.cluster_name.id
    node_index    = count.index
    instance_type = var.instance_type["k8s_cp"]
    disk_size_gb  = var.disk_size_gb["k8s_cp"]
    subnet_cidr   = var.private_subnet_cidrs["k8s_cp"]
  }

  provisioner "local-exec" {
    command = "echo '[${random_pet.cluster_name.id}] Provisioned K8s Control Plane node ${count.index + 1}: ${var.instance_type["k8s_cp"]}, ${var.disk_size_gb["k8s_cp"]}GB SSD, subnet ${var.private_subnet_cidrs["k8s_cp"]}' >> ${path.module}/generated/provision.log"
  }
}

# ---- K8s Workers ----
resource "null_resource" "k8s_workers" {
  count = var.instance_count["k8s_workers"]

  triggers = {
    cluster_name  = random_pet.cluster_name.id
    node_index    = count.index
    instance_type = var.instance_type["k8s_workers"]
    disk_size_gb  = var.disk_size_gb["k8s_workers"]
    subnet_cidr   = var.private_subnet_cidrs["k8s_workers"]
    k8s_cp_ready  = join(",", null_resource.k8s_control_plane[*].id)
  }

  provisioner "local-exec" {
    command = "echo '[${random_pet.cluster_name.id}] Provisioned K8s Worker node ${count.index + 1}: ${var.instance_type["k8s_workers"]}, ${var.disk_size_gb["k8s_workers"]}GB SSD, subnet ${var.private_subnet_cidrs["k8s_workers"]}' >> ${path.module}/generated/provision.log"
  }
}

# ---- Kafka ----
resource "null_resource" "kafka" {
  count = var.instance_count["kafka"]

  triggers = {
    cluster_name  = random_pet.cluster_name.id
    node_index    = count.index
    instance_type = var.instance_type["kafka"]
    disk_size_gb  = var.disk_size_gb["kafka"]
    subnet_cidr   = var.private_subnet_cidrs["kafka"]
  }

  provisioner "local-exec" {
    command = "echo '[${random_pet.cluster_name.id}] Provisioned Kafka broker ${count.index + 1}: ${var.instance_type["kafka"]}, ${var.disk_size_gb["kafka"]}GB SSD, subnet ${var.private_subnet_cidrs["kafka"]}' >> ${path.module}/generated/provision.log"
  }
}

# ---- ClickHouse ----
resource "null_resource" "clickhouse" {
  count = var.instance_count["clickhouse"]

  triggers = {
    cluster_name  = random_pet.cluster_name.id
    node_index    = count.index
    instance_type = var.instance_type["clickhouse"]
    disk_size_gb  = var.disk_size_gb["clickhouse"]
    subnet_cidr   = var.private_subnet_cidrs["clickhouse"]
  }

  provisioner "local-exec" {
    command = "echo '[${random_pet.cluster_name.id}] Provisioned ClickHouse node ${count.index + 1}: ${var.instance_type["clickhouse"]}, ${var.disk_size_gb["clickhouse"]}GB SSD, subnet ${var.private_subnet_cidrs["clickhouse"]}' >> ${path.module}/generated/provision.log"
  }
}

# ---- PostgreSQL ----
resource "null_resource" "postgres_primary" {
  triggers = {
    cluster_name    = random_pet.cluster_name.id
    instance_type   = var.instance_type["postgres"]
    disk_size_gb    = var.disk_size_gb["postgres"]
    subnet_cidr     = var.private_subnet_cidrs["postgres"]
    master_password = random_password.db_master_password.result
  }

  provisioner "local-exec" {
    command = "echo '[${random_pet.cluster_name.id}] Provisioned PostgreSQL Primary: ${var.instance_type["postgres"]}, ${var.disk_size_gb["postgres"]}GB SSD, subnet ${var.private_subnet_cidrs["postgres"]}' >> ${path.module}/generated/provision.log"
  }
}

resource "null_resource" "postgres_replica" {
  depends_on = [null_resource.postgres_primary]

  triggers = {
    cluster_name  = random_pet.cluster_name.id
    instance_type = var.instance_type["postgres"]
    disk_size_gb  = var.disk_size_gb["postgres"]
    subnet_cidr   = var.private_subnet_cidrs["postgres"]
    primary_id    = null_resource.postgres_primary.id
  }

  provisioner "local-exec" {
    command = "echo '[${random_pet.cluster_name.id}] Provisioned PostgreSQL Replica: ${var.instance_type["postgres"]}, ${var.disk_size_gb["postgres"]}GB SSD, subnet ${var.private_subnet_cidrs["postgres"]}' >> ${path.module}/generated/provision.log"
  }
}

# ---- CockroachDB ----
resource "null_resource" "cockroachdb" {
  count = var.instance_count["cockroachdb"]

  triggers = {
    cluster_name  = random_pet.cluster_name.id
    node_index    = count.index
    instance_type = var.instance_type["cockroachdb"]
    disk_size_gb  = var.disk_size_gb["cockroachdb"]
    subnet_cidr   = var.private_subnet_cidrs["cockroachdb"]
  }

  provisioner "local-exec" {
    command = "echo '[${random_pet.cluster_name.id}] Provisioned CockroachDB node ${count.index + 1}: ${var.instance_type["cockroachdb"]}, ${var.disk_size_gb["cockroachdb"]}GB SSD, subnet ${var.private_subnet_cidrs["cockroachdb"]}' >> ${path.module}/generated/provision.log"
  }
}

# ---- MinIO ----
resource "null_resource" "minio" {
  count = var.instance_count["minio"]

  triggers = {
    cluster_name  = random_pet.cluster_name.id
    node_index    = count.index
    instance_type = var.instance_type["minio"]
    disk_size_gb  = var.disk_size_gb["minio"]
    subnet_cidr   = var.private_subnet_cidrs["minio"]
  }

  provisioner "local-exec" {
    command = "echo '[${random_pet.cluster_name.id}] Provisioned MinIO node ${count.index + 1}: ${var.instance_type["minio"]}, ${var.disk_size_gb["minio"]}GB HDD, subnet ${var.private_subnet_cidrs["minio"]}' >> ${path.module}/generated/provision.log"
  }
}

# ---- API Gateway ----
resource "null_resource" "api_gateway" {
  count = var.instance_count["api_gateway"]

  triggers = {
    cluster_name  = random_pet.cluster_name.id
    node_index    = count.index
    instance_type = var.instance_type["api_gateway"]
    disk_size_gb  = var.disk_size_gb["api_gateway"]
    subnet_cidr   = var.private_subnet_cidrs["api_gateway"]
  }

  provisioner "local-exec" {
    command = "echo '[${random_pet.cluster_name.id}] Provisioned API Gateway node ${count.index + 1}: ${var.instance_type["api_gateway"]}, ${var.disk_size_gb["api_gateway"]}GB SSD, subnet ${var.private_subnet_cidrs["api_gateway"]}' >> ${path.module}/generated/provision.log"
  }
}

# ---- Bastion ----
resource "null_resource" "bastion" {
  triggers = {
    cluster_name  = random_pet.cluster_name.id
    instance_type = var.instance_type["bastion"]
    disk_size_gb  = var.disk_size_gb["bastion"]
    subnet_cidr   = var.public_subnet_cidrs[0]
  }

  provisioner "local-exec" {
    command = "echo '[${random_pet.cluster_name.id}] Provisioned Bastion Host: ${var.instance_type["bastion"]}, ${var.disk_size_gb["bastion"]}GB SSD, public subnet ${var.public_subnet_cidrs[0]}' >> ${path.module}/generated/provision.log"
  }
}

# ---- Monitoring ----
resource "null_resource" "monitoring" {
  triggers = {
    cluster_name  = random_pet.cluster_name.id
    instance_type = var.instance_type["monitoring"]
    disk_size_gb  = var.disk_size_gb["monitoring"]
    subnet_cidr   = var.private_subnet_cidrs["monitoring"]
  }

  provisioner "local-exec" {
    command = "echo '[${random_pet.cluster_name.id}] Provisioned Monitoring VM: ${var.instance_type["monitoring"]}, ${var.disk_size_gb["monitoring"]}GB SSD, subnet ${var.private_subnet_cidrs["monitoring"]}' >> ${path.module}/generated/provision.log"
  }
}

# =============================================================================
# INVENTORY FILE (output connection info for all provisioned resources)
# =============================================================================

locals {
  all_vms = {
    k8s_control_plane = [for i in range(var.instance_count["k8s_cp"]) : {
      hostname      = "${random_pet.cluster_name.id}-k8s-cp-${i + 1}"
      instance_type = var.instance_type["k8s_cp"]
      disk_gb       = var.disk_size_gb["k8s_cp"]
      subnet        = var.private_subnet_cidrs["k8s_cp"]
      role          = "K8s Control Plane"
    }]
    k8s_workers = [for i in range(var.instance_count["k8s_workers"]) : {
      hostname      = "${random_pet.cluster_name.id}-k8s-worker-${i + 1}"
      instance_type = var.instance_type["k8s_workers"]
      disk_gb       = var.disk_size_gb["k8s_workers"]
      subnet        = var.private_subnet_cidrs["k8s_workers"]
      role          = "K8s Worker"
    }]
    kafka = [for i in range(var.instance_count["kafka"]) : {
      hostname      = "${random_pet.cluster_name.id}-kafka-${i + 1}"
      instance_type = var.instance_type["kafka"]
      disk_gb       = var.disk_size_gb["kafka"]
      subnet        = var.private_subnet_cidrs["kafka"]
      role          = "Kafka Broker"
    }]
    clickhouse = [for i in range(var.instance_count["clickhouse"]) : {
      hostname      = "${random_pet.cluster_name.id}-clickhouse-${i + 1}"
      instance_type = var.instance_type["clickhouse"]
      disk_gb       = var.disk_size_gb["clickhouse"]
      subnet        = var.private_subnet_cidrs["clickhouse"]
      role          = "ClickHouse Node"
    }]
    postgres_primary = {
      hostname      = "${random_pet.cluster_name.id}-postgres-primary"
      instance_type = var.instance_type["postgres"]
      disk_gb       = var.disk_size_gb["postgres"]
      subnet        = var.private_subnet_cidrs["postgres"]
      role          = "PostgreSQL Primary"
    }
    postgres_replica = {
      hostname      = "${random_pet.cluster_name.id}-postgres-replica"
      instance_type = var.instance_type["postgres"]
      disk_gb       = var.disk_size_gb["postgres"]
      subnet        = var.private_subnet_cidrs["postgres"]
      role          = "PostgreSQL Replica"
    }
    cockroachdb = [for i in range(var.instance_count["cockroachdb"]) : {
      hostname      = "${random_pet.cluster_name.id}-cockroachdb-${i + 1}"
      instance_type = var.instance_type["cockroachdb"]
      disk_gb       = var.disk_size_gb["cockroachdb"]
      subnet        = var.private_subnet_cidrs["cockroachdb"]
      role          = "CockroachDB Node"
    }]
    minio = [for i in range(var.instance_count["minio"]) : {
      hostname      = "${random_pet.cluster_name.id}-minio-${i + 1}"
      instance_type = var.instance_type["minio"]
      disk_gb       = var.disk_size_gb["minio"]
      subnet        = var.private_subnet_cidrs["minio"]
      role          = "MinIO Node"
    }]
    api_gateway = [for i in range(var.instance_count["api_gateway"]) : {
      hostname      = "${random_pet.cluster_name.id}-apigw-${i + 1}"
      instance_type = var.instance_type["api_gateway"]
      disk_gb       = var.disk_size_gb["api_gateway"]
      subnet        = var.private_subnet_cidrs["api_gateway"]
      role          = "API Gateway"
    }]
    bastion = {
      hostname      = "${random_pet.cluster_name.id}-bastion"
      instance_type = var.instance_type["bastion"]
      disk_gb       = var.disk_size_gb["bastion"]
      subnet        = var.public_subnet_cidrs[0]
      role          = "Bastion Host"
    }
    monitoring = {
      hostname      = "${random_pet.cluster_name.id}-monitoring"
      instance_type = var.instance_type["monitoring"]
      disk_gb       = var.disk_size_gb["monitoring"]
      subnet        = var.private_subnet_cidrs["monitoring"]
      role          = "Monitoring"
    }
  }
}

resource "local_file" "inventory" {
  filename = "${path.module}/generated/inventory.yaml"
  content = yamlencode({
    cluster_name   = random_pet.cluster_name.id
    vpc_cidr       = var.vpc_cidr
    vms            = local.all_vms
    db_password    = random_password.db_master_password.result
    kafka_password = random_password.kafka_password.result
  })
}

resource "local_file" "provision_summary" {
  filename = "${path.module}/generated/provision_summary.md"
  content  = <<-EOT
# Provisioning Summary: ${random_pet.cluster_name.id}

## Network
| Component | CIDR |
|-----------|------|
| VPC | ${var.vpc_cidr} |
| Public Subnet 1 | ${var.public_subnet_cidrs[0]} |
| Public Subnet 2 | ${var.public_subnet_cidrs[1]} |
| Public Subnet 3 | ${var.public_subnet_cidrs[2]} |
| Private K8s CP | ${var.private_subnet_cidrs["k8s_cp"]} |
| Private K8s Workers | ${var.private_subnet_cidrs["k8s_workers"]} |
| Private Kafka | ${var.private_subnet_cidrs["kafka"]} |
| Private ClickHouse | ${var.private_subnet_cidrs["clickhouse"]} |
| Private PostgreSQL | ${var.private_subnet_cidrs["postgres"]} |
| Private CockroachDB | ${var.private_subnet_cidrs["cockroachdb"]} |
| Private MinIO | ${var.private_subnet_cidrs["minio"]} |
| Private API Gateway | ${var.private_subnet_cidrs["api_gateway"]} |
| Private Monitoring | ${var.private_subnet_cidrs["monitoring"]} |

## Compute Resources
| Group | Count | Instance Type | Disk (GB) | Role |
|-------|-------|---------------|-----------|------|
| K8s Control Plane | ${var.instance_count["k8s_cp"]} | ${var.instance_type["k8s_cp"]} | ${var.disk_size_gb["k8s_cp"]} | K8s management |
| K8s Workers | ${var.instance_count["k8s_workers"]} | ${var.instance_type["k8s_workers"]} | ${var.disk_size_gb["k8s_workers"]} | Application pods |
| Kafka | ${var.instance_count["kafka"]} | ${var.instance_type["kafka"]} | ${var.disk_size_gb["kafka"]} | Event streaming |
| ClickHouse | ${var.instance_count["clickhouse"]} | ${var.instance_type["clickhouse"]} | ${var.disk_size_gb["clickhouse"]} | OLAP analytics |
| PostgreSQL | 1 + 1 replica | ${var.instance_type["postgres"]} | ${var.disk_size_gb["postgres"]} | Domain databases |
| CockroachDB | ${var.instance_count["cockroachdb"]} | ${var.instance_type["cockroachdb"]} | ${var.disk_size_gb["cockroachdb"]} | Fintech database |
| MinIO | ${var.instance_count["minio"]} | ${var.instance_type["minio"]} | ${var.disk_size_gb["minio"]} | Object storage |
| API Gateway | ${var.instance_count["api_gateway"]} | ${var.instance_type["api_gateway"]} | ${var.disk_size_gb["api_gateway"]} | API routing |
| Bastion | 1 | ${var.instance_type["bastion"]} | ${var.disk_size_gb["bastion"]} | Management access |
| Monitoring | 1 | ${var.instance_type["monitoring"]} | ${var.disk_size_gb["monitoring"]} | Observability |

## Terraform-Managed Components
- VPC, subnets, IGW, NAT Gateway, Security Groups
- All VM instances and attached disks
- Load balancers (ALB/NLB)

## Manual Deployment (Helm / Docker)
- Kubernetes cluster setup (kubeadm / managed K8s)
- Domain API services (Clinic, Fintech, HQ, Partner)
- Apache Superset, DataHub, MLflow, Keycloak + OPA
- Kafka topic configuration, Debezium connectors
- Database schema migrations
EOT
}
