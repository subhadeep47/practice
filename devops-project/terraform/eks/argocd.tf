resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true

  # ClusterIP by default so the Argo CD UI is not exposed to the internet:
  #   kubectl -n argocd port-forward svc/argocd-server 8080:443
  values = [yamlencode({
    server = {
      service = {
        type = var.argocd_server_service_type
      }
    }
  })]

  depends_on = [
    module.eks # Ensures EKS cluster and nodes exist before installing Helm charts
  ]
}
