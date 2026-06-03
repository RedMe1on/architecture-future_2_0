variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones for multi-AZ deployment"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (Bastion, NAT, LB)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets per service"
  type        = map(string)
  default = {
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

variable "instance_count" {
  description = "Number of instances per service group"
  type        = map(number)
  default = {
    k8s_cp      = 3
    k8s_workers = 3
    kafka       = 3
    clickhouse  = 3
    postgres    = 1 # +1 replica created separately
    cockroachdb = 3
    minio       = 3
    api_gateway = 2
    bastion     = 1
    monitoring  = 1
  }
}

variable "instance_type" {
  description = "Instance type (vCPU/RAM) per service group"
  type        = map(string)
  default = {
    k8s_cp      = "4 vCPU / 16 GB RAM"
    k8s_workers = "8 vCPU / 32 GB RAM"
    kafka       = "4 vCPU / 16 GB RAM"
    clickhouse  = "8 vCPU / 32 GB RAM"
    postgres    = "4 vCPU / 16 GB RAM"
    cockroachdb = "4 vCPU / 16 GB RAM"
    minio       = "4 vCPU / 16 GB RAM"
    api_gateway = "4 vCPU / 8 GB RAM"
    bastion     = "2 vCPU / 8 GB RAM"
    monitoring  = "4 vCPU / 16 GB RAM"
  }
}

variable "disk_size_gb" {
  description = "Disk size in GB per service group (SSD for all except MinIO HDD)"
  type        = map(number)
  default = {
    k8s_cp      = 100
    k8s_workers = 200
    kafka       = 200
    clickhouse  = 500
    postgres    = 200
    cockroachdb = 100
    minio       = 500
    api_gateway = 50
    bastion     = 50
    monitoring  = 200
  }
}

variable "environment" {
  description = "Deployment environment (dev/staging/prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name tag"
  type        = string
  default     = "future-2.0"
}
