resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.46.7" # Use a stable chart version
  namespace        = "argocd"
  create_namespace = true

  # Optional: Expose ArgoCD UI via LoadBalancer (or keep as ClusterIP if using port-forwarding)
  values = [<<-EOT
    server:
      service:
        type: LoadBalancer
  EOT
  ]

  depends_on = [
    module.eks # Ensures EKS cluster is fully running before installing Helm charts
  ]
}