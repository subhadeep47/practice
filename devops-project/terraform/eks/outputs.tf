output "cluster_name" {
  value       = module.eks.cluster_name
  description = "The name of the EKS cluster"
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "Endpoint for the EKS control plane"
}

output "cluster_certificate_authority_data" {
  value       = module.eks.cluster_certificate_authority_data
  description = "Base64 encoded certificate data required to communicate with the cluster"
  sensitive   = true
}

output "node_security_group_id" {
  value       = module.eks.node_security_group_id
  description = "Security group attached to the worker nodes (used to allow pod traffic to RDS)"
}
