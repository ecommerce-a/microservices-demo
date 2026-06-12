data "aws_caller_identity" "current" {}

variable "vpc_id" {
  type        = string
  description = "Existing VPC ID — reuse to avoid the 5-VPC per region limit"
  default     = "vpc-04025ffd1fa10963d"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Existing public subnet IDs across 3 AZs for the EKS cluster"
  default     = ["subnet-03c3797dee67cb411", "subnet-0723c631dbb8b98e0", "subnet-0cdb88450510b2192"]
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for the managed node group"
  default     = "t3.medium"
}

variable "node_desired_size" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 3
}

variable "node_min_size" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 2
}

variable "node_max_size" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 5
}

variable "cielara_scanner_arn" {
  type        = string
  description = "ARN of the cielara-scanner IAM user for EKS read access"
  default     = "arn:aws:iam::127214159096:user/cielara-scanner"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.34"

  cluster_endpoint_public_access = true

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  eks_managed_node_groups = {
    default = {
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      instance_types = [var.node_instance_type]
    }
  }

  # Grants the caller admin access immediately after provisioning
  enable_cluster_creator_admin_permissions = true
}

# Grant cielara-scanner read-only access to the cluster
resource "aws_eks_access_entry" "cielara_scanner" {
  cluster_name  = module.eks.cluster_name
  principal_arn = var.cielara_scanner_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "cielara_scanner_view" {
  cluster_name  = module.eks.cluster_name
  principal_arn = var.cielara_scanner_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.cielara_scanner]
}
