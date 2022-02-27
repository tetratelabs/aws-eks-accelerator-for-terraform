terraform {
  required_version = ">= 1.0.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.66.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.6.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.4.1"
    }
  }

  backend "local" {
    path = "local_tf_state/terraform-main.tfstate"
  }
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

data "aws_eks_cluster" "cluster" {
  name = module.aws-eks-accelerator-for-terraform.eks_cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.aws-eks-accelerator-for-terraform.eks_cluster_id
}

provider "aws" {
  region = "us-west-1"
  alias  = "default"
}

provider "kubernetes" {
  experiments {
    manifest_resource = true
  }
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    token                  = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  }
}

locals {
  tenant      = "aws001"  # AWS account name or unique id for tenant
  environment = "preprod" # Environment area eg., preprod or prod
  zone        = "dev"     # Environment with in one sub_tenant or business unit

  kubernetes_version = "1.21"

  vpc_cidr       = "10.0.0.0/16"
  vpc_name       = join("-", [local.tenant, local.environment, local.zone, "vpc"])
  eks_cluster_id = join("-", [local.tenant, local.environment, local.zone, "eks"])

  eks_cluster_domain    = "<cluster_domain>"
  eks_cluster_subdomain = "<cluster_subdomain>"
  acm_domain            = "<acm_domain"

  terraform_version = "Terraform v1.0.1"
}

#---------------------------------------------------------------
# VPC
#---------------------------------------------------------------

module "aws_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "v3.2.0"

  name = local.vpc_name
  cidr = local.vpc_cidr
  azs  = data.aws_availability_zones.available.names

  public_subnets  = [for k, v in data.aws_availability_zones.available.names : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in data.aws_availability_zones.available.names : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  create_igw           = true
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.eks_cluster_id}" = "shared"
    "kubernetes.io/role/elb"                        = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.eks_cluster_id}" = "shared"
    "kubernetes.io/role/internal-elb"               = "1"
  }
}

#---------------------------------------------------------------
# Example to consume aws-eks-accelerator-for-terraform module
#---------------------------------------------------------------

module "aws-eks-accelerator-for-terraform" {
  source = "../.."

  tenant            = local.tenant
  environment       = local.environment
  zone              = local.zone
  terraform_version = local.terraform_version

  # EKS Cluster VPC and Subnet mandatory config
  vpc_id             = module.aws_vpc.vpc_id
  private_subnet_ids = module.aws_vpc.private_subnets

  # EKS CONTROL PLANE VARIABLES
  create_eks         = true
  kubernetes_version = local.kubernetes_version

  # Managed Node Group
  managed_node_groups = {
    mg_4 = {
      node_group_name = "managed-ondemand"
      instance_types  = ["m5.large"]
      subnet_ids      = module.aws_vpc.private_subnets
      desired_size    = "5"
      max_size        = "10"
      min_size        = "3"
    }
  }
}

module "kubernetes-addons" {
  source = "../../modules/kubernetes-addons"

  #---------------------------------------------------------------
  # Globals
  #---------------------------------------------------------------

  eks_cluster_id = module.aws-eks-accelerator-for-terraform.eks_cluster_id

  # Domain for the cluster - to be used with External DNS.
  cluster_domain = local.eks_cluster_domain

  #---------------------------------------------------------------
  # ADD-ONS
  #---------------------------------------------------------------

  enable_aws_load_balancer_controller = true
  enable_cert_manager                 = true
  enable_external_dns                 = true
  enable_ingress_nginx                = true
  ingress_nginx_helm_config = {
    values = [templatefile("${path.module}/nginx-values.yaml", {
      hostname     = local.eks_cluster_subdomain
      ssl_cert_arn = data.aws_acm_certificate.issued.arn
    })]
  }

  depends_on = [module.aws-eks-accelerator-for-terraform.managed_node_groups]
}

data "aws_acm_certificate" "issued" {
  domain   = var.acm_domain
  statuses = ["ISSUED"]
}
