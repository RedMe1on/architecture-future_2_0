output "cluster_name" {
  description = "Unique cluster identifier"
  value       = random_pet.cluster_name.id
}

output "vpc_config" {
  description = "VPC and subnet configuration summary"
  value = {
    vpc_cidr           = var.vpc_cidr
    public_subnets     = var.public_subnet_cidrs
    private_subnets    = var.private_subnet_cidrs
    availability_zones = var.availability_zones
  }
}

output "compute_summary" {
  description = "Provisioned compute resources"
  value = {
    k8s_control_plane = {
      count         = var.instance_count["k8s_cp"]
      instance_type = var.instance_type["k8s_cp"]
      disk_gb       = var.disk_size_gb["k8s_cp"]
    }
    k8s_workers = {
      count         = var.instance_count["k8s_workers"]
      instance_type = var.instance_type["k8s_workers"]
      disk_gb       = var.disk_size_gb["k8s_workers"]
    }
    kafka = {
      count         = var.instance_count["kafka"]
      instance_type = var.instance_type["kafka"]
      disk_gb       = var.disk_size_gb["kafka"]
    }
    clickhouse = {
      count         = var.instance_count["clickhouse"]
      instance_type = var.instance_type["clickhouse"]
      disk_gb       = var.disk_size_gb["clickhouse"]
    }
    postgres = {
      count         = var.instance_count["postgres"] + 1
      instance_type = var.instance_type["postgres"]
      disk_gb       = var.disk_size_gb["postgres"]
    }
    cockroachdb = {
      count         = var.instance_count["cockroachdb"]
      instance_type = var.instance_type["cockroachdb"]
      disk_gb       = var.disk_size_gb["cockroachdb"]
    }
    minio = {
      count         = var.instance_count["minio"]
      instance_type = var.instance_type["minio"]
      disk_gb       = var.disk_size_gb["minio"]
    }
    api_gateway = {
      count         = var.instance_count["api_gateway"]
      instance_type = var.instance_type["api_gateway"]
      disk_gb       = var.disk_size_gb["api_gateway"]
    }
    bastion = {
      count         = 1
      instance_type = var.instance_type["bastion"]
      disk_gb       = var.disk_size_gb["bastion"]
    }
    monitoring = {
      count         = 1
      instance_type = var.instance_type["monitoring"]
      disk_gb       = var.disk_size_gb["monitoring"]
    }
  }
}

output "total_resources" {
  description = "Total count of provisioned resources"
  value = {
    total_vms = sum([
      var.instance_count["k8s_cp"],
      var.instance_count["k8s_workers"],
      var.instance_count["kafka"],
      var.instance_count["clickhouse"],
      var.instance_count["postgres"] + 1,
      var.instance_count["cockroachdb"],
      var.instance_count["minio"],
      var.instance_count["api_gateway"],
      1, # bastion
      1, # monitoring
    ])
    total_disk_gb = sum([
      var.instance_count["k8s_cp"] * var.disk_size_gb["k8s_cp"],
      var.instance_count["k8s_workers"] * var.disk_size_gb["k8s_workers"],
      var.instance_count["kafka"] * var.disk_size_gb["kafka"],
      var.instance_count["clickhouse"] * var.disk_size_gb["clickhouse"],
      (var.instance_count["postgres"] + 1) * var.disk_size_gb["postgres"],
      var.instance_count["cockroachdb"] * var.disk_size_gb["cockroachdb"],
      var.instance_count["minio"] * var.disk_size_gb["minio"],
      var.instance_count["api_gateway"] * var.disk_size_gb["api_gateway"],
      1 * var.disk_size_gb["bastion"],
      1 * var.disk_size_gb["monitoring"],
    ])
  }
}

output "credentials" {
  description = "Generated credentials (sensitive)"
  sensitive   = true
  value = {
    db_master_password = random_password.db_master_password.result
    kafka_password     = random_password.kafka_password.result
  }
}

output "generated_files" {
  description = "Paths to generated configuration files"
  value = {
    network_config    = abspath(local_file.network_config.filename)
    inventory         = abspath(local_file.inventory.filename)
    provision_summary = abspath(local_file.provision_summary.filename)
    provision_log     = "${abspath(path.module)}/generated/provision.log"
  }
}
