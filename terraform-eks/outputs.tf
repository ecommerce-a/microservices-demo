output "ecr_registry" {
  description = "ECR registry base URL — use as --default-repo for Skaffold"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "configure_kubectl" {
  description = "Run this to update your local kubeconfig after provisioning"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}"
}
