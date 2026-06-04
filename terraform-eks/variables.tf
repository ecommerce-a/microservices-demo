variable "region" {
  type        = string
  description = "AWS region to deploy into"
  default     = "us-east-1"
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
  default     = "online-boutique"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for the app"
  default     = "default"
}

