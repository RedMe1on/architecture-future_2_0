environment  = "prod"
project_name = "future-2.0"

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

private_subnet_cidrs = {
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

instance_count = {
  k8s_cp      = 3
  k8s_workers = 3
  kafka       = 3
  clickhouse  = 3
  postgres    = 1
  cockroachdb = 3
  minio       = 3
  api_gateway = 2
  bastion     = 1
  monitoring  = 1
}

instance_type = {
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

disk_size_gb = {
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
