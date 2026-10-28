variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_version" {
  type        = string
  description = "EKS Kubernetes version (1.34 leaves standard support on 2 Dec 2026)"
  default     = "1.35"
}

variable "node_instance_types" {
  type = list(string)
}

variable "desired_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "min_size" {
  type = number
}

variable "argocd_chart_version" {
  type        = string
  description = "argo-cd Helm chart version"
  default     = "10.8.3"
}

variable "argocd_server_service_type" {
  type        = string
  description = "Service type for the Argo CD server. ClusterIP = reach via kubectl port-forward; LoadBalancer = public endpoint."
  default     = "ClusterIP"
}
