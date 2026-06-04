# =============================================================================
# DEMO: Terraform using ONLY built-in resources
# No external providers required — works without registry access
# =============================================================================

terraform {
  required_version = ">= 1.6"
}

locals {
  cluster_name  = "future-2.0-demo"
  vpc_cidr      = "10.0.0.0/16"

  subnet_cidrs = {
    k8s_cp      = "10.0.10.0/24"
    k8s_workers = "10.0.11.0/24"
    kafka       = "10.0.12.0/24"
    clickhouse  = "10.0.13.0/24"
    postgres    = "10.0.14.0/24"
    cockroachdb = "10.0.15.0/24"
    minio       = "10.0.16.0/24"
    api_gateway = "10.0.17.0/24"
    monitoring  = "10.0.18.0/24"
  }
}

resource "terraform_data" "vpc" {
  input = {
    name    = "${local.cluster_name}-vpc"
    cidr    = local.vpc_cidr
    subnets = local.subnet_cidrs
  }
}

resource "terraform_data" "k8s_control_plane" {
  depends_on = [terraform_data.vpc]
  input = { count = 3, type = "4 vCPU / 16 GB", disk = "100 GB SSD" }
}

resource "terraform_data" "k8s_workers" {
  depends_on = [terraform_data.vpc]
  input = { count = 3, type = "8 vCPU / 32 GB", disk = "200 GB SSD" }
}

resource "terraform_data" "kafka" {
  depends_on = [terraform_data.vpc]
  input = { count = 3, type = "4 vCPU / 16 GB", disk = "200 GB SSD" }
}

resource "terraform_data" "clickhouse" {
  depends_on = [terraform_data.vpc]
  input = { count = 3, type = "8 vCPU / 32 GB", disk = "500 GB SSD" }
}

resource "terraform_data" "postgres" {
  depends_on = [terraform_data.vpc]
  input = { count = 2, type = "4 vCPU / 16 GB", disk = "200 GB SSD" }
}

resource "terraform_data" "cockroachdb" {
  depends_on = [terraform_data.vpc]
  input = { count = 3, type = "4 vCPU / 16 GB", disk = "100 GB SSD" }
}

resource "terraform_data" "minio" {
  depends_on = [terraform_data.vpc]
  input = { count = 3, type = "4 vCPU / 16 GB", disk = "500 GB HDD" }
}

resource "terraform_data" "api_gateway" {
  depends_on = [terraform_data.vpc]
  input = { count = 2, type = "4 vCPU / 8 GB", disk = "50 GB SSD" }
}

resource "terraform_data" "bastion" {
  depends_on = [terraform_data.vpc]
  input = { count = 1, type = "2 vCPU / 8 GB", disk = "50 GB SSD" }
}

resource "terraform_data" "monitoring" {
  depends_on = [terraform_data.vpc]
  input = { count = 1, type = "4 vCPU / 16 GB", disk = "200 GB SSD" }
}

resource "terraform_data" "applications" {
  depends_on = [
    terraform_data.k8s_control_plane,
    terraform_data.k8s_workers,
    terraform_data.kafka,
    terraform_data.clickhouse,
    terraform_data.postgres,
    terraform_data.cockroachdb,
    terraform_data.minio,
    terraform_data.api_gateway,
    terraform_data.bastion,
    terraform_data.monitoring,
  ]
  input = {
    terraform = "VPC, subnets, Security Groups, VMs, disks, LB, DNS, IAM"
    manual    = "K8s setup, Helm charts, Kafka topics, DB migrations, app configs"
  }
}
