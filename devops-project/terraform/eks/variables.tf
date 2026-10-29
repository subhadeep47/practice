# All values come from Ansible (ansible/inventories/<env>/group_vars). Nothing here has a
# default on purpose: a missing value must fail the run instead of silently using a guess.

variable "environment" {
  type        = string
  description = "Environment name, used in resource names and tags"
}

variable "project" {
  type        = string
  description = "Project name, applied as the Project tag on every resource"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "cluster_version" {
  type        = string
  description = "EKS Kubernetes version, e.g. \"1.35\" (quote it so 1.30 does not become 1.3)"
}

variable "cluster_endpoint_public_access" {
  type        = bool
  description = "Whether the Kubernetes API endpoint is reachable from the internet (still IAM-authenticated)"
}

variable "node_instance_types" {
  type        = list(string)
  description = "EC2 instance types of the managed node group"
}

variable "desired_size" {
  type        = number
  description = "Desired node count"
}

variable "max_size" {
  type        = number
  description = "Maximum node count"
}

variable "min_size" {
  type        = number
  description = "Minimum node count"
}

variable "argocd_chart_version" {
  type        = string
  description = "argo-cd Helm chart version"
}

variable "argocd_server_service_type" {
  type        = string
  description = "Service type for the Argo CD server. ClusterIP = reach via kubectl port-forward; LoadBalancer = public endpoint."
}
