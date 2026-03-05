variable "cluster_name" { type = string }
variable "vpc_id"       { type = string }
variable "subnet_ids"   { type = list(string) }
variable "environment"  { type = string }
variable "k8s_version"  { type = string; default = "1.29" }

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.0"
  cluster_name    = var.cluster_name
  cluster_version = var.k8s_version
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnet_ids

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    
    general = {
      name           = "general"
      instance_types = ["m5.xlarge"]
      min_size       = 3
      max_size       = 20
      desired_size   = 5
      labels         = { workload = "general" }
    }
    
    ml = {
      name           = "ml"
      instance_types = ["c5.2xlarge"]
      min_size       = 1
      max_size       = 10
      desired_size   = 2
      labels  = { workload = "ml" }
      taints  = [{ key = "workload", value = "ml", effect = "NO_SCHEDULE" }]
    }
    
    media = {
      name           = "media"
      instance_types = ["c5n.xlarge"]
      min_size       = 2
      max_size       = 15
      desired_size   = 3
      labels  = { workload = "media" }
      taints  = [{ key = "workload", value = "media", effect = "NO_SCHEDULE" }]
    }
  }

  cluster_addons = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
    aws-ebs-csi-driver     = { most_recent = true }
    aws-load-balancer-controller = { most_recent = true }
  }
}

output "cluster_endpoint"       { value = module.eks.cluster_endpoint }
output "cluster_name"           { value = module.eks.cluster_name }
output "oidc_provider_arn"      { value = module.eks.oidc_provider_arn }
